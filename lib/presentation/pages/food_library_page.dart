import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../domain/entities/diet_models.dart';
import '../../theme/app_theme.dart';
import '../widgets/async_tab_content.dart';
import '../widgets/section_card.dart';
import 'food_entry_page.dart';

class FoodLibraryPageArgs {
  const FoodLibraryPageArgs({required this.date});

  final DateTime date;
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

    return Scaffold(
      appBar: AppBar(title: const Text('食物库')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              SectionCard(
                title: '搜索',
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: '搜索食物名称',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        ref.read(foodSearchKeywordProvider.notifier).state =
                            value;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    categoriesAsync.when(
                      loading: () =>
                          const LinearProgressIndicator(minHeight: 2),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (categories) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.sm,
                              ),
                              child: ChoiceChip(
                                label: const Text('全部'),
                                selected: selectedCategory == null,
                                onSelected: (_) {
                                  ref
                                          .read(
                                            selectedFoodCategoryProvider
                                                .notifier,
                                          )
                                          .state =
                                      null;
                                },
                              ),
                            ),
                            for (final category in categories)
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpacing.sm,
                                ),
                                child: ChoiceChip(
                                  label: Text(category),
                                  selected: selectedCategory == category,
                                  onSelected: (_) {
                                    ref
                                            .read(
                                              selectedFoodCategoryProvider
                                                  .notifier,
                                            )
                                            .state =
                                        category;
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
                      itemCount: foods.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final food = foods[index];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            title: Text(
                              food.foodName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xs,
                              ),
                              child: Text(
                                '${food.category} · ${food.energyKCal.toStringAsFixed(0)} kcal/100g · 蛋白质 ${food.protein.toStringAsFixed(1)}g · 脂肪 ${food.fat.toStringAsFixed(1)}g · 碳水 ${food.carb.toStringAsFixed(1)}g',
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.of(context).pushNamed<bool>(
                                FoodEntryPage.routeName,
                                arguments: FoodEntryPageArgs(
                                  food: food,
                                  date: widget.args.date,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
