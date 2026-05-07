import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../domain/entities/diet_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_tile.dart';

class FoodEntryPageArgs {
  const FoodEntryPageArgs({required this.food, required this.date});

  final FoodItem food;
  final DateTime date;
}

class FoodEntryPage extends ConsumerWidget {
  const FoodEntryPage({super.key, required this.args});

  static const routeName = '/food-entry';

  final FoodEntryPageArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(foodEntryControllerProvider(args.food));
    final controller = ref.read(
      foodEntryControllerProvider(args.food).notifier,
    );
    final calculation = controller.calculation;

    return Scaffold(
      appBar: AppBar(title: const Text('记录饮食')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            SectionCard(
              title: '食物信息',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    args.food.foodName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    args.food.category,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.of(context).textMuted,
                    ),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: '录入信息',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '摄入克数',
                      suffixText: 'g',
                    ),
                    controller: TextEditingController(text: state.gramsInput)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: state.gramsInput.length),
                      ),
                    onChanged: controller.updateGrams,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final mealType in MealType.values)
                        ChoiceChip(
                          label: Text(mealType.label),
                          selected: mealType == state.mealType,
                          onSelected: (_) =>
                              controller.updateMealType(mealType),
                        ),
                    ],
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      state.error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SectionCard(
              title: '本次摄入',
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.8,
                children: [
                  StatTile(
                    label: '热量',
                    value: '${calculation.energyKCal.toStringAsFixed(0)} kcal',
                  ),
                  StatTile(
                    label: '蛋白质',
                    value: '${calculation.protein.toStringAsFixed(1)} g',
                  ),
                  StatTile(
                    label: '脂肪',
                    value: '${calculation.fat.toStringAsFixed(1)} g',
                  ),
                  StatTile(
                    label: '碳水',
                    value: '${calculation.carb.toStringAsFixed(1)} g',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.md),
        child: FilledButton(
          onPressed: state.isSubmitting
              ? null
              : () async {
                  try {
                    await controller.submit(args.date);
                    if (!context.mounted) {
                      return;
                    }
                    ref.invalidate(dietRecordsByDateProvider(args.date));
                    ref.invalidate(dailyDietSummaryProvider(args.date));
                    showLatestSnackBar(context, '饮食记录已保存');
                    Navigator.of(context).pop(true);
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
          child: Text(state.isSubmitting ? '保存中...' : '保存记录'),
        ),
      ),
    );
  }
}
