import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../application/state/food_selection_state.dart';
import '../../domain/entities/diet_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';
import '../widgets/async_tab_content.dart';
import '../widgets/diet_food_entry_dialog.dart';

const _allFoodCategory = '';

class FoodLibraryPageArgs {
  const FoodLibraryPageArgs({
    required this.date,
    required this.mealType,
    this.initialSelectedRecords = const [],
  });

  final DateTime date;
  final MealType mealType;
  final List<DietRecord> initialSelectedRecords;
}

class FoodLibraryPage extends ConsumerStatefulWidget {
  const FoodLibraryPage({super.key, required this.args});

  static const routeName = '/food-library';

  final FoodLibraryPageArgs args;

  @override
  ConsumerState<FoodLibraryPage> createState() => _FoodLibraryPageState();
}

class _FoodLibraryPageState extends ConsumerState<FoodLibraryPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    Future<void>(() {
      if (!mounted) {
        return;
      }
      ref.read(selectedFoodCategoryProvider.notifier).state = _allFoodCategory;
      ref.read(foodSearchKeywordProvider.notifier).state = '';
      final controller = ref.read(
        foodSelectionControllerProvider(widget.args.mealType).notifier,
      );
      if (widget.args.initialSelectedRecords.isNotEmpty) {
        controller.initializeWithRecords(widget.args.initialSelectedRecords);
      } else {
        controller.resetSelection();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(foodLibraryProvider);
    final categoriesAsync = ref.watch(foodCategoriesProvider);
    final selectedCategory = ref.watch(selectedFoodCategoryProvider);
    final colors = AppColors.of(context);
    final selectionState = ref.watch(
      foodSelectionControllerProvider(widget.args.mealType),
    );
    final selectionController = ref.read(
      foodSelectionControllerProvider(widget.args.mealType).notifier,
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.args.mealType.label)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: _SelectionBar(
          state: selectionState,
          mealType: widget.args.mealType,
          onPreview: () async {
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: colors.panel,
              builder: (sheetContext) {
                return _SelectedFoodsSheet(
                  mealType: widget.args.mealType,
                  onRemove: selectionController.removeFood,
                  onEdit: (entry) async {
                    Navigator.of(sheetContext).pop();
                    await _openFoodEntryDialog(
                      context: context,
                      food: entry.food,
                      initialGrams: entry.grams,
                      confirmLabel: '更新',
                      onConfirm: (grams) {
                        selectionController.addOrUpdateFood(entry.food, grams);
                        showLatestSnackBar(context, '已更新食物克数');
                      },
                    );
                  },
                );
              },
            );
          },
          onSave: selectionState.isSubmitting
              ? null
              : () async {
                  try {
                    await selectionController.saveAll(widget.args.date);
                    if (!context.mounted) {
                      return;
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref.invalidate(
                        dietRecordsByDateProvider(widget.args.date),
                      );
                      ref.invalidate(
                        dailyDietSummaryProvider(widget.args.date),
                      );
                    });
                    showLatestSnackBar(
                      context,
                      '${widget.args.mealType.label}已保存 ${selectionState.itemCount} 项',
                    );
                    selectionController.resetSelection();
                    Navigator.of(context).pop();
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }
                    final appError = AppError.from(
                      error,
                      fallbackMessage: '保存饮食记录失败，请稍后重试。',
                    );
                    showLatestSnackBar(context, appError.message);
                  }
                },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索食物名称',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            ref.read(foodSearchKeywordProvider.notifier).state =
                                '';
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: colors.panel,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colors.accent.withValues(alpha: 0.26),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.accent, width: 1.4),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colors.accent.withValues(alpha: 0.26),
                    ),
                  ),
                ),
                onChanged: (value) {
                  ref.read(foodSearchKeywordProvider.notifier).state = value;
                  setState(() {});
                },
              ),
            ),
            Expanded(
              child: categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    AppError.from(
                      error,
                      fallbackMessage: '加载食物分类失败，请稍后重试。',
                    ).message,
                  ),
                ),
                data: (categories) {
                  final categoryOptions = <String>[
                    _allFoodCategory,
                    ...categories,
                  ];
                  final activeCategory = selectedCategory ?? _allFoodCategory;
                  if (selectedCategory == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) {
                        return;
                      }
                      ref.read(selectedFoodCategoryProvider.notifier).state =
                          _allFoodCategory;
                    });
                  }
                  return Row(
                    children: [
                      _FoodCategorySidebar(
                        categories: categoryOptions,
                        selectedCategory: activeCategory,
                        onSelect: (category) {
                          ref
                                  .read(selectedFoodCategoryProvider.notifier)
                                  .state =
                              category;
                        },
                      ),
                      Expanded(
                        child: AsyncTabContent<List<FoodItem>>(
                          asyncValue: foodsAsync,
                          errorPrefix: '食物库加载失败',
                          builder: (context, foods) {
                            if (foods.isEmpty) {
                              return const Center(child: Text('没有匹配的食物'));
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                0,
                                AppSpacing.md,
                                AppSpacing.md,
                              ),
                              itemCount: foods.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                final food = foods[index];
                                return _FoodListTile(
                                  food: food,
                                  onTap: () async {
                                    await _openFoodEntryDialog(
                                      context: context,
                                      food: food,
                                      confirmLabel: '加入',
                                      onConfirm: (grams) {
                                        selectionController.addOrUpdateFood(
                                          food,
                                          grams,
                                        );
                                        showLatestSnackBar(
                                          context,
                                          '已加入${widget.args.mealType.label}',
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFoodEntryDialog({
    required BuildContext context,
    required FoodItem food,
    required String confirmLabel,
    double initialGrams = 100,
    required ValueChanged<double> onConfirm,
  }) async {
    final grams = await showDietFoodEntryDialog(
      context: context,
      title: food.foodName,
      subtitle: food.category,
      confirmLabel: confirmLabel,
      initialGrams: initialGrams,
      calculationBuilder: (value) => DietEntryCalculation.fromFood(food, value),
    );
    if (grams == null) {
      return;
    }
    onConfirm(grams);
  }
}

class _FoodCategorySidebar extends StatelessWidget {
  const _FoodCategorySidebar({
    required this.categories,
    required this.selectedCategory,
    required this.onSelect,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: 98,
      color: colors.panelAlt,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = selectedCategory == category;
          final categoryLabel = category.isEmpty ? '全部' : category;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelect(category),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected ? colors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  categoryLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : colors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FoodListTile extends StatelessWidget {
  const _FoodListTile({required this.food, required this.onTap});

  final FoodItem food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: AppRadius.card,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.foodName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      food.category,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${food.energyKCal.toStringAsFixed(0)} kcal/100g  ·  碳水 ${food.carb.toStringAsFixed(1)}g  ·  蛋白质 ${food.protein.toStringAsFixed(1)}g  ·  脂肪 ${food.fat.toStringAsFixed(1)}g',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.add_circle_outline, color: colors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.state,
    required this.mealType,
    required this.onPreview,
    required this.onSave,
  });

  final FoodSelectionState state;
  final MealType mealType;
  final VoidCallback onPreview;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: Ink(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onPreview,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.breakfast_dining_outlined,
                            color: colors.textPrimary,
                          ),
                          if (state.itemCount > 0)
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${state.itemCount}',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mealType.label,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            state.itemCount == 0
                                ? '还没有已选食物'
                                : '已选择 ${state.itemCount} 个食物',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: onSave,
              child: Text(state.isSubmitting ? '保存中...' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedFoodsSheet extends ConsumerWidget {
  const _SelectedFoodsSheet({
    required this.mealType,
    required this.onRemove,
    required this.onEdit,
  });

  final MealType mealType;
  final ValueChanged<String> onRemove;
  final ValueChanged<SelectedFoodEntry> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final selectionState = ref.watch(foodSelectionControllerProvider(mealType));
    final items = selectionState.items;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '已选择食物',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            if (items.isEmpty)
              Text(
                '当前还没有已选食物',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final calculation = item.calculation;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: AppRadius.card,
                        onTap: () => onEdit(item),
                        child: Ink(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: colors.panelAlt,
                            borderRadius: AppRadius.card,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.food.foodName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.grams.toStringAsFixed(0)}g',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      '${calculation.energyKCal.toStringAsFixed(0)} kcal · 碳水 ${calculation.carb.toStringAsFixed(1)}g · 蛋白质 ${calculation.protein.toStringAsFixed(1)}g · 脂肪 ${calculation.fat.toStringAsFixed(1)}g',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: colors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              IconButton(
                                onPressed: () => onEdit(item),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () => onRemove(item.foodCode),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
