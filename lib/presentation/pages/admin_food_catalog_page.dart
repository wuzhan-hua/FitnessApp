import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../domain/entities/diet_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';

List<FoodItem> _rebuildFoodSortOrders(List<FoodItem> items) {
  return items.asMap().entries.map((entry) {
    final json = entry.value.toJson()..['sort_order'] = entry.key;
    return FoodItem.fromJson(json);
  }).toList();
}

List<FoodCategory> _rebuildCategorySortOrders(List<FoodCategory> categories) {
  return categories.asMap().entries.map((entry) {
    final category = entry.value;
    return FoodCategory(
      id: category.id,
      name: category.name,
      sortOrder: entry.key,
      isActive: category.isActive,
    );
  }).toList();
}

class AdminFoodCatalogPage extends ConsumerStatefulWidget {
  const AdminFoodCatalogPage({super.key});

  static const routeName = '/admin-food-catalog';

  @override
  ConsumerState<AdminFoodCatalogPage> createState() =>
      _AdminFoodCatalogPageState();
}

class _AdminFoodCatalogPageState extends ConsumerState<AdminFoodCatalogPage> {
  String? _selectedCategoryId;
  List<FoodItem> _items = const [];
  String? _itemsCategoryId;
  List<FoodCategory> _categories = const [];
  bool _hasOrderChanges = false;
  bool _hasCategoryOrderChanges = false;
  bool _isSavingOrder = false;
  bool _isSavingCategoryOrder = false;

  Future<void> _saveOrder(
    String categoryId,
    List<FoodItem> currentItems,
  ) async {
    if (_isSavingOrder || !_hasOrderChanges) {
      return;
    }
    final orderedItems = _rebuildFoodSortOrders(currentItems);
    final orderedFoodIds = orderedItems
        .map((item) => item.id ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (orderedFoodIds.length != orderedItems.length) {
      showLatestSnackBar(context, '食物数据缺少 ID，无法保存排序。');
      return;
    }
    setState(() => _isSavingOrder = true);
    try {
      final savedFoodIds = await ref
          .read(foodLibraryServiceProvider)
          .saveFoodOrders(
            categoryId: categoryId,
            orderedFoodIds: orderedFoodIds,
          );
      final savedPrefix = savedFoodIds.take(orderedFoodIds.length).toList();
      final orderMatched =
          savedPrefix.length == orderedFoodIds.length &&
          List.generate(
            orderedFoodIds.length,
            (index) => savedPrefix[index] == orderedFoodIds[index],
          ).every((matched) => matched);
      if (!orderMatched) {
        final expected = orderedFoodIds.take(3).join(', ');
        final actual = savedPrefix.take(3).join(', ');
        throw AppError(message: '排序保存未生效，请重试。期望：$expected；实际：$actual');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _items = orderedItems;
        _itemsCategoryId = categoryId;
        _hasOrderChanges = false;
      });
      _invalidateFoodProviders(categoryId: categoryId);
      showLatestSnackBar(context, '食物排序已保存');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showLatestSnackBar(
        context,
        AppError.from(error, fallbackMessage: '保存食物排序失败，请稍后重试。').message,
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingOrder = false);
      }
    }
  }

  Future<void> _saveCategoryOrder() async {
    if (_isSavingCategoryOrder || !_hasCategoryOrderChanges) {
      return;
    }
    final orderedCategoryIds = _categories
        .map((category) => category.id)
        .where((id) => id.isNotEmpty)
        .toList();
    if (orderedCategoryIds.length != _categories.length) {
      showLatestSnackBar(context, '分类数据缺少 ID，无法保存排序。');
      return;
    }
    setState(() => _isSavingCategoryOrder = true);
    try {
      final savedCategoryIds = await ref
          .read(foodLibraryServiceProvider)
          .saveCategoryOrders(
            orderedCategoryIds: orderedCategoryIds,
          );
      final savedPrefix = savedCategoryIds.take(orderedCategoryIds.length).toList();
      final orderMatched =
          savedPrefix.length == orderedCategoryIds.length &&
          List.generate(
            orderedCategoryIds.length,
            (index) => savedPrefix[index] == orderedCategoryIds[index],
          ).every((matched) => matched);
      if (!orderMatched) {
        final expected = orderedCategoryIds.take(3).join(', ');
        final actual = savedPrefix.take(3).join(', ');
        throw AppError(message: '分类排序保存未生效，请重试。期望：$expected；实际：$actual');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = const [];
        _hasCategoryOrderChanges = false;
      });
      _invalidateFoodProviders(categoryId: _selectedCategoryId);
      showLatestSnackBar(context, '分类排序已保存');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showLatestSnackBar(
        context,
        AppError.from(error, fallbackMessage: '保存分类排序失败，请稍后重试。').message,
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingCategoryOrder = false);
      }
    }
  }

  Future<void> _editCategoryOrder(
    FoodCategory category,
    List<FoodCategory> currentCategories,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _EditFoodOrderDialog(currentPosition: category.sortOrder + 1),
    );
    if (!mounted || result == null) {
      return;
    }
    final parsed = int.tryParse(result);
    if (parsed == null) {
      showLatestSnackBar(context, '请输入有效排序名次');
      return;
    }
    final currentIndex = currentCategories.indexWhere(
      (current) => current.id == category.id,
    );
    if (currentIndex < 0 || currentCategories.isEmpty) {
      return;
    }
    final targetIndex = parsed.clamp(1, currentCategories.length) - 1;
    if (targetIndex == currentIndex) {
      return;
    }
    final reordered = [...currentCategories];
    final moved = reordered.removeAt(currentIndex);
    reordered.insert(targetIndex, moved);
    setState(() {
      _categories = _rebuildCategorySortOrders(reordered);
      _hasCategoryOrderChanges = true;
      _selectedCategoryId = category.id;
    });
    showLatestSnackBar(context, '分类已移动到第 ${targetIndex + 1} 位');
  }

  Future<void> _editItemOrder(
    String categoryId,
    FoodItem item,
    List<FoodItem> currentItems,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _EditFoodOrderDialog(currentPosition: item.sortOrder + 1),
    );
    if (!mounted || result == null) {
      return;
    }
    final parsed = int.tryParse(result);
    if (parsed == null) {
      showLatestSnackBar(context, '请输入有效排序名次');
      return;
    }
    final currentIndex = currentItems.indexWhere(
      (current) => current.id == item.id,
    );
    if (currentIndex < 0 || currentItems.isEmpty) {
      return;
    }
    final targetIndex = parsed.clamp(1, currentItems.length) - 1;
    if (targetIndex == currentIndex) {
      return;
    }
    final reordered = [...currentItems];
    final moved = reordered.removeAt(currentIndex);
    reordered.insert(targetIndex, moved);
    setState(() {
      _items = _rebuildFoodSortOrders(reordered);
      _itemsCategoryId = categoryId;
      _hasOrderChanges = true;
    });
    showLatestSnackBar(context, '已移动到第 ${targetIndex + 1} 位');
  }

  Future<void> _openFoodForm({
    FoodItem? item,
    required List<FoodCategory> categories,
  }) async {
    final result = await showDialog<_FoodFormResult>(
      context: context,
      builder: (_) => _FoodFormDialog(item: item, categories: categories),
    );
    if (result == null) {
      return;
    }
    try {
      if (item == null) {
        await ref
            .read(foodLibraryServiceProvider)
            .createFood(food: result.food, categoryId: result.categoryId);
        if (!mounted) {
          return;
        }
        showLatestSnackBar(context, '食物已新增');
      } else {
        await ref
            .read(foodLibraryServiceProvider)
            .updateFood(
              id: item.id!,
              food: result.food,
              categoryId: result.categoryId,
            );
        if (!mounted) {
          return;
        }
        showLatestSnackBar(context, '食物已保存');
      }
      _invalidateFoodProviders(categoryId: result.categoryId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showLatestSnackBar(
        context,
        AppError.from(error, fallbackMessage: '保存食物失败，请稍后重试。').message,
      );
    }
  }

  Future<void> _createCategory() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateCategoryDialog(),
    );
    if (result == null || result.trim().isEmpty) {
      return;
    }
    try {
      final category = await ref
          .read(foodLibraryServiceProvider)
          .createCategory(result);
      _invalidateFoodProviders();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedCategoryId = category.id;
        _items = const [];
        _itemsCategoryId = null;
        _hasOrderChanges = false;
        _hasCategoryOrderChanges = false;
      });
      showLatestSnackBar(context, '分类已新增');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showLatestSnackBar(
        context,
        AppError.from(error, fallbackMessage: '新增分类失败，请稍后重试。').message,
      );
    }
  }

  void _invalidateFoodProviders({String? categoryId}) {
    ref.invalidate(adminFoodCategoriesProvider);
    ref.invalidate(adminFoodCatalogItemsProvider(categoryId));
    ref.invalidate(foodLibraryProvider);
    ref.invalidate(foodCategoriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(currentUserIsAdminProvider);
    final categoriesAsync = ref.watch(adminFoodCategoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('食物库管理')),
      body: isAdminAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            AppError.from(error, fallbackMessage: '加载权限失败，请稍后重试。').message,
          ),
        ),
        data: (isAdmin) {
          if (!isAdmin) {
            return const Center(child: Text('当前账号没有管理员权限'));
          }
          return _AdminFoodBody(
            categoriesAsync: categoriesAsync,
            selectedCategoryId: _selectedCategoryId,
            items: _items,
            itemsCategoryId: _itemsCategoryId,
            localCategories: _categories,
            hasOrderChanges: _hasOrderChanges,
            hasCategoryOrderChanges: _hasCategoryOrderChanges,
            isSavingOrder: _isSavingOrder,
            isSavingCategoryOrder: _isSavingCategoryOrder,
            onCreateCategory: _createCategory,
            onSelectCategory: (categoryId) {
              setState(() {
                _selectedCategoryId = categoryId;
                _items = const [];
                _itemsCategoryId = null;
                _hasOrderChanges = false;
              });
            },
            onSetSelectedCategory: (categoryId) {
              setState(() => _selectedCategoryId = categoryId);
            },
            onCreateFood: (categories) => _openFoodForm(categories: categories),
            onEditFood: (item, categories) =>
                _openFoodForm(item: item, categories: categories),
            onEditCategoryOrder: _editCategoryOrder,
            onEditOrder: _editItemOrder,
            onSaveOrder: _saveOrder,
            onSaveCategoryOrder: _saveCategoryOrder,
          );
        },
      ),
    );
  }
}

class _AdminFoodBody extends ConsumerWidget {
  const _AdminFoodBody({
    required this.categoriesAsync,
    required this.selectedCategoryId,
    required this.items,
    required this.itemsCategoryId,
    required this.localCategories,
    required this.hasOrderChanges,
    required this.hasCategoryOrderChanges,
    required this.isSavingOrder,
    required this.isSavingCategoryOrder,
    required this.onCreateCategory,
    required this.onSelectCategory,
    required this.onSetSelectedCategory,
    required this.onCreateFood,
    required this.onEditFood,
    required this.onEditCategoryOrder,
    required this.onEditOrder,
    required this.onSaveOrder,
    required this.onSaveCategoryOrder,
  });

  final AsyncValue<List<FoodCategory>> categoriesAsync;
  final String? selectedCategoryId;
  final List<FoodItem> items;
  final String? itemsCategoryId;
  final List<FoodCategory> localCategories;
  final bool hasOrderChanges;
  final bool hasCategoryOrderChanges;
  final bool isSavingOrder;
  final bool isSavingCategoryOrder;
  final VoidCallback onCreateCategory;
  final ValueChanged<String> onSelectCategory;
  final ValueChanged<String> onSetSelectedCategory;
  final ValueChanged<List<FoodCategory>> onCreateFood;
  final void Function(FoodItem item, List<FoodCategory> categories) onEditFood;
  final void Function(
    FoodCategory category,
    List<FoodCategory> currentCategories,
  )
  onEditCategoryOrder;
  final void Function(
    String categoryId,
    FoodItem item,
    List<FoodItem> currentItems,
  )
  onEditOrder;
  final void Function(String categoryId, List<FoodItem> currentItems)
  onSaveOrder;
  final VoidCallback onSaveCategoryOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          AppError.from(error, fallbackMessage: '加载食物分类失败，请稍后重试。').message,
        ),
      ),
      data: (remoteCategories) {
        final categories = hasCategoryOrderChanges
            ? localCategories
            : remoteCategories;
        if (categories.isEmpty) {
          return Center(
            child: FilledButton.icon(
              onPressed: onCreateCategory,
              icon: const Icon(Icons.add),
              label: const Text('新增食物分类'),
            ),
          );
        }
        final activeCategoryId = selectedCategoryId ?? categories.first.id;
        final activeCategory = categories.firstWhere(
          (category) => category.id == activeCategoryId,
          orElse: () => categories.first,
        );
        if (selectedCategoryId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onSetSelectedCategory(activeCategory.id);
          });
        }
        final itemsAsync = ref.watch(
          adminFoodCatalogItemsProvider(activeCategory.id),
        );
        return Row(
          children: [
            _FoodAdminCategorySidebar(
              categories: categories,
              selectedCategoryId: activeCategory.id,
              onSelect: onSelectCategory,
              onEditOrder: (category) =>
                  onEditCategoryOrder(category, categories),
              onCreateCategory: onCreateCategory,
              onSaveOrder: onSaveCategoryOrder,
              hasOrderChanges: hasCategoryOrderChanges,
              isSavingOrder: isSavingCategoryOrder,
            ),
            Expanded(
              child: itemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    AppError.from(
                      error,
                      fallbackMessage: '加载食物列表失败，请稍后重试。',
                    ).message,
                  ),
                ),
                data: (data) {
                  final useLocalItems =
                      itemsCategoryId == activeCategory.id &&
                      items.isNotEmpty &&
                      (hasOrderChanges || !isSavingOrder);
                  final displayItems = useLocalItems
                      ? items
                      : _rebuildFoodSortOrders(data);
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: colors.textMuted.withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${activeCategory.name} 食物排序',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => onCreateFood(categories),
                                  icon: const Icon(Icons.add),
                                  label: const Text('新增食物'),
                                ),
                                FilledButton.icon(
                                  onPressed: hasOrderChanges && !isSavingOrder
                                      ? () => onSaveOrder(
                                          activeCategory.id,
                                          displayItems,
                                        )
                                      : null,
                                  icon: isSavingOrder
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    isSavingOrder ? '保存中...' : '保存排序',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: displayItems.isEmpty
                            ? const Center(child: Text('当前分类暂无食物'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                itemCount: displayItems.length,
                                itemBuilder: (context, index) {
                                  final item = displayItems[index];
                                  return _FoodAdminTile(
                                    key: ValueKey(item.id ?? item.foodCode),
                                    item: item,
                                    index: index,
                                    onEdit: () => onEditFood(item, categories),
                                    onEditOrder: () => onEditOrder(
                                      activeCategory.id,
                                      item,
                                      displayItems,
                                    ),
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
        );
      },
    );
  }
}

class _FoodAdminCategorySidebar extends StatelessWidget {
  const _FoodAdminCategorySidebar({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
    required this.onEditOrder,
    required this.onCreateCategory,
    required this.onSaveOrder,
    required this.hasOrderChanges,
    required this.isSavingOrder,
  });

  final List<FoodCategory> categories;
  final String selectedCategoryId;
  final ValueChanged<String> onSelect;
  final ValueChanged<FoodCategory> onEditOrder;
  final VoidCallback onCreateCategory;
  final VoidCallback onSaveOrder;
  final bool hasOrderChanges;
  final bool isSavingOrder;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: 98,
      color: colors.panelAlt,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final category = categories[index];
                final selected = category.id == selectedCategoryId;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onSelect(category.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? colors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            category.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : colors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 28,
                            child: OutlinedButton(
                              onPressed: () => onEditOrder(category),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: selected
                                    ? Colors.white
                                    : colors.accent,
                                side: BorderSide(
                                  color: selected
                                      ? Colors.white.withValues(alpha: 0.64)
                                      : colors.accent.withValues(alpha: 0.42),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('排序'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: hasOrderChanges && !isSavingOrder
                    ? onSaveOrder
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  isSavingOrder ? '保存中' : '保存排序',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: hasOrderChanges && !isSavingOrder
                        ? Colors.white
                        : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: IconButton.filledTonal(
              onPressed: onCreateCategory,
              icon: const Icon(Icons.add),
              tooltip: '新增分类',
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodAdminTile extends StatelessWidget {
  const _FoodAdminTile({
    super.key,
    required this.item,
    required this.index,
    required this.onEdit,
    required this.onEditOrder,
  });

  final FoodItem item;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onEditOrder;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: item.isActive
                      ? colors.accent.withValues(alpha: 0.12)
                      : colors.textMuted.withValues(alpha: 0.12),
                  foregroundColor: item.isActive
                      ? colors.accent
                      : colors.textMuted,
                  child: Text('${index + 1}'),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item.foodName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!item.isActive)
                  Text(
                    '已停用',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                '${item.foodCode} · ${item.energyKCal.toStringAsFixed(0)} kcal · 蛋白 ${item.protein.toStringAsFixed(1)}g · 脂肪 ${item.fat.toStringAsFixed(1)}g · 碳水 ${item.carb.toStringAsFixed(1)}g',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  SizedBox(
                    width: 88,
                    child: OutlinedButton(
                      onPressed: onEditOrder,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('排序'),
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: OutlinedButton(
                      onPressed: onEdit,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('编辑'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodFormResult {
  const _FoodFormResult({required this.food, required this.categoryId});

  final FoodItem food;
  final String categoryId;
}

class _FoodFormDialog extends StatefulWidget {
  const _FoodFormDialog({required this.categories, this.item});

  final List<FoodCategory> categories;
  final FoodItem? item;

  @override
  State<_FoodFormDialog> createState() => _FoodFormDialogState();
}

class _FoodFormDialogState extends State<_FoodFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _categoryId;
  late final Map<String, TextEditingController> _controllers;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _categoryId = item?.categoryId ?? widget.categories.first.id;
    _isActive = item?.isActive ?? true;
    _controllers = {
      'foodCode': TextEditingController(
        text:
            item?.foodCode ?? 'custom-${DateTime.now().millisecondsSinceEpoch}',
      ),
      'foodName': TextEditingController(text: item?.foodName ?? ''),
      'edible': TextEditingController(text: _format(item?.edible ?? 100)),
      'water': TextEditingController(text: _format(item?.water ?? 0)),
      'energyKCal': TextEditingController(text: _format(item?.energyKCal ?? 0)),
      'energyKJ': TextEditingController(text: _format(item?.energyKJ ?? 0)),
      'protein': TextEditingController(text: _format(item?.protein ?? 0)),
      'fat': TextEditingController(text: _format(item?.fat ?? 0)),
      'carb': TextEditingController(text: _format(item?.carb ?? 0)),
      'dietaryFiber': TextEditingController(
        text: _format(item?.dietaryFiber ?? 0),
      ),
      'cholesterol': TextEditingController(
        text: _format(item?.cholesterol ?? 0),
      ),
      'ash': TextEditingController(text: _format(item?.ash ?? 0)),
      'vitaminA': TextEditingController(text: _format(item?.vitaminA ?? 0)),
      'carotene': TextEditingController(text: _format(item?.carotene ?? 0)),
      'retinol': TextEditingController(text: _format(item?.retinol ?? 0)),
      'thiamin': TextEditingController(text: _format(item?.thiamin ?? 0)),
      'riboflavin': TextEditingController(text: _format(item?.riboflavin ?? 0)),
      'niacin': TextEditingController(text: _format(item?.niacin ?? 0)),
      'vitaminC': TextEditingController(text: _format(item?.vitaminC ?? 0)),
      'vitaminETotal': TextEditingController(
        text: _format(item?.vitaminETotal ?? 0),
      ),
      'vitaminE1': TextEditingController(text: _format(item?.vitaminE1 ?? 0)),
      'vitaminE2': TextEditingController(text: _format(item?.vitaminE2 ?? 0)),
      'vitaminE3': TextEditingController(text: _format(item?.vitaminE3 ?? 0)),
      'calcium': TextEditingController(text: _format(item?.calcium ?? 0)),
      'phosphorus': TextEditingController(text: _format(item?.phosphorus ?? 0)),
      'potassium': TextEditingController(text: _format(item?.potassium ?? 0)),
      'sodium': TextEditingController(text: _format(item?.sodium ?? 0)),
      'magnesium': TextEditingController(text: _format(item?.magnesium ?? 0)),
      'iron': TextEditingController(text: _format(item?.iron ?? 0)),
      'zinc': TextEditingController(text: _format(item?.zinc ?? 0)),
      'selenium': TextEditingController(text: _format(item?.selenium ?? 0)),
      'copper': TextEditingController(text: _format(item?.copper ?? 0)),
      'manganese': TextEditingController(text: _format(item?.manganese ?? 0)),
      'remark': TextEditingController(text: item?.remark ?? ''),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item == null ? '新增食物' : '编辑食物';
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: '分类'),
                  items: widget.categories
                      .map(
                        (category) => DropdownMenuItem<String>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _categoryId = value);
                    }
                  },
                ),
                _textField('foodCode', '食物编码', required: true),
                _textField('foodName', '食物名称', required: true),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _numberField('edible', '可食部'),
                    _numberField('water', '水分'),
                    _numberField('energyKCal', '千卡'),
                    _numberField('energyKJ', '千焦'),
                    _numberField('protein', '蛋白质'),
                    _numberField('fat', '脂肪'),
                    _numberField('carb', '碳水'),
                    _numberField('dietaryFiber', '膳食纤维'),
                    _numberField('cholesterol', '胆固醇'),
                    _numberField('ash', '灰分'),
                    _numberField('vitaminA', '维生素A'),
                    _numberField('carotene', '胡萝卜素'),
                    _numberField('retinol', '视黄醇'),
                    _numberField('thiamin', '硫胺素'),
                    _numberField('riboflavin', '核黄素'),
                    _numberField('niacin', '烟酸'),
                    _numberField('vitaminC', '维生素C'),
                    _numberField('vitaminETotal', '维生素E'),
                    _numberField('vitaminE1', '维生素E1'),
                    _numberField('vitaminE2', '维生素E2'),
                    _numberField('vitaminE3', '维生素E3'),
                    _numberField('calcium', '钙'),
                    _numberField('phosphorus', '磷'),
                    _numberField('potassium', '钾'),
                    _numberField('sodium', '钠'),
                    _numberField('magnesium', '镁'),
                    _numberField('iron', '铁'),
                    _numberField('zinc', '锌'),
                    _numberField('selenium', '硒'),
                    _numberField('copper', '铜'),
                    _numberField('manganese', '锰'),
                  ],
                ),
                _textField('remark', '备注'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }

  Widget _textField(String key, String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: TextFormField(
        controller: _controllers[key],
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label不能为空';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _numberField(String key, String label) {
    return SizedBox(
      width: 160,
      child: TextFormField(
        controller: _controllers[key],
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '必填';
          }
          if (double.tryParse(value) == null) {
            return '请输入数字';
          }
          return null;
        },
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final category = widget.categories.firstWhere(
      (item) => item.id == _categoryId,
      orElse: () => widget.categories.first,
    );
    final foodName = _text('foodName');
    final item = FoodItem(
      id: widget.item?.id,
      foodCode: _text('foodCode'),
      foodName: foodName,
      category: category.name,
      categoryId: category.id,
      edible: _num('edible', fallback: 100),
      water: _num('water'),
      energyKCal: _num('energyKCal'),
      energyKJ: _num('energyKJ'),
      protein: _num('protein'),
      fat: _num('fat'),
      carb: _num('carb'),
      dietaryFiber: _num('dietaryFiber'),
      cholesterol: _num('cholesterol'),
      ash: _num('ash'),
      vitaminA: _num('vitaminA'),
      carotene: _num('carotene'),
      retinol: _num('retinol'),
      thiamin: _num('thiamin'),
      riboflavin: _num('riboflavin'),
      niacin: _num('niacin'),
      vitaminC: _num('vitaminC'),
      vitaminETotal: _num('vitaminETotal'),
      vitaminE1: _num('vitaminE1'),
      vitaminE2: _num('vitaminE2'),
      vitaminE3: _num('vitaminE3'),
      calcium: _num('calcium'),
      phosphorus: _num('phosphorus'),
      potassium: _num('potassium'),
      sodium: _num('sodium'),
      magnesium: _num('magnesium'),
      iron: _num('iron'),
      zinc: _num('zinc'),
      selenium: _num('selenium'),
      copper: _num('copper'),
      manganese: _num('manganese'),
      remark: _text('remark').isEmpty ? null : _text('remark'),
      searchKeywords: _keywords(foodName),
      sortOrder: widget.item?.sortOrder ?? 0,
      source: widget.item?.source ?? 'admin',
      isActive: _isActive,
    );
    Navigator.of(
      context,
    ).pop(_FoodFormResult(food: item, categoryId: category.id));
  }

  String _text(String key) => _controllers[key]!.text.trim();

  double _num(String key, {double fallback = 0}) {
    return double.tryParse(_text(key)) ?? fallback;
  }

  String _format(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _keywords(String foodName) {
    final chars = foodName
        .split('')
        .where((char) => RegExp(r'[\u4e00-\u9fa5a-zA-Z0-9]').hasMatch(char))
        .join(' ');
    return '$foodName $chars'.trim();
  }
}

class _EditFoodOrderDialog extends StatefulWidget {
  const _EditFoodOrderDialog({required this.currentPosition});

  final int currentPosition;

  @override
  State<_EditFoodOrderDialog> createState() => _EditFoodOrderDialogState();
}

class _EditFoodOrderDialogState extends State<_EditFoodOrderDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.currentPosition}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('调整排序名次'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: '目标名次',
          helperText: '当前第 ${widget.currentPosition} 位',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('确认'),
        ),
      ],
    );
  }
}

class _CreateCategoryDialog extends StatefulWidget {
  const _CreateCategoryDialog();

  @override
  State<_CreateCategoryDialog> createState() => _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends State<_CreateCategoryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增食物分类'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(labelText: '分类名称'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
