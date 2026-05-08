import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/providers.dart';
import '../../data/services/diet_record_service.dart';
import '../../domain/entities/diet_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/app_logger.dart';
import '../../utils/snackbar_helper.dart';
import '../widgets/diet_food_entry_dialog.dart';
import 'food_library_page.dart';

class MealAnalysisPageArgs {
  const MealAnalysisPageArgs({
    required this.date,
    required this.mealType,
    this.initialRecords = const [],
  });

  final DateTime date;
  final MealType mealType;
  final List<DietRecord> initialRecords;
}

class MealAnalysisPage extends ConsumerWidget {
  const MealAnalysisPage({super.key, required this.args});

  static const routeName = '/meal-analysis';

  final MealAnalysisPageArgs args;

  String _resolveTitle() {
    return '${DateFormat('MM/dd').format(args.date)} ${args.mealType.label}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dailyDietSummaryProvider(args.date));
    final service = ref.read(dietRecordServiceProvider);
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          _resolveTitle(),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      backgroundColor: colors.background,
      body: SafeArea(
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: Text(
                AppError.from(
                  error,
                  fallbackMessage: '餐次分析加载失败，请稍后重试。',
                ).message,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (summary) {
            final fetchedRecords =
                summary.mealGroups[args.mealType] ?? const [];
            final resolvedRecords = fetchedRecords.isNotEmpty
                ? fetchedRecords
                : args.initialRecords;
            final mealEnergy = _mealEnergy(resolvedRecords);
            final totalGrams = _mealTotalGrams(resolvedRecords);
            final nutrientStats = _buildMacroStats(resolvedRecords);

            AppLogger.info(
              '餐次分析页加载: date=${args.date.toIso8601String()}, '
              'mealType=${args.mealType.value}, '
              'resolvedRecords=${resolvedRecords.length}, '
              'mealEnergy=${mealEnergy.toStringAsFixed(1)}',
            );
            AppLogger.info('餐次分析页开始构建最小安全内容');

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.panel,
                      borderRadius: AppRadius.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '共 ${mealEnergy.toStringAsFixed(0)} kcal',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (
                          var index = 0;
                          index < nutrientStats.length;
                          index++
                        )
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index == nutrientStats.length - 1
                                  ? 0
                                  : AppSpacing.sm,
                            ),
                            child: _MacroStatRow(item: nutrientStats[index]),
                          ),
                        if (mealEnergy <= 0) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            '当前餐次还没有热量数据，先添加食物后会自动生成分析。',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.panel,
                      borderRadius: AppRadius.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '食物共 ${resolvedRecords.length} 个（${totalGrams.toStringAsFixed(1)}克）',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (resolvedRecords.isEmpty)
                          Text(
                            '当前餐次还没有食物，点击底部按钮继续添加。',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.textMuted),
                          )
                        else
                          Column(
                            children: [
                              for (
                                var index = 0;
                                index < resolvedRecords.length;
                                index++
                              ) ...[
                                _MealFoodRow(
                                  record: resolvedRecords[index],
                                  onTap: () async {
                                    await _editRecord(
                                      context: context,
                                      ref: ref,
                                      service: service,
                                      record: resolvedRecords[index],
                                    );
                                  },
                                ),
                                if (index != resolvedRecords.length - 1)
                                  const SizedBox(height: AppSpacing.md),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Align(
            heightFactor: 1,
            alignment: Alignment.center,
            child: SizedBox(
              width: 220,
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                onPressed: () async {
                  final summary = await ref.read(
                    dailyDietSummaryProvider(args.date).future,
                  );
                  final fetchedRecords =
                      summary.mealGroups[args.mealType] ?? const [];
                  final resolvedRecords = fetchedRecords.isNotEmpty
                      ? fetchedRecords
                      : args.initialRecords;
                  if (!context.mounted) {
                    return;
                  }
                  await _openFoodLibrary(
                    context: context,
                    ref: ref,
                    resolvedRecords: resolvedRecords,
                  );
                },
                child: const Text('添加食物'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFoodLibrary({
    required BuildContext context,
    required WidgetRef ref,
    required List<DietRecord> resolvedRecords,
  }) async {
    if (!context.mounted) {
      return;
    }
    final saved = await Navigator.of(context).pushNamed<bool>(
      FoodLibraryPage.routeName,
      arguments: FoodLibraryPageArgs(
        date: args.date,
        mealType: args.mealType,
        initialSelectedRecords: resolvedRecords,
      ),
    );
    if (!context.mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(dietRecordsByDateProvider(args.date));
      ref.invalidate(dailyDietSummaryProvider(args.date));
    });
    if (saved == true) {
      showLatestSnackBar(context, '${args.mealType.label}已保存');
    }
  }

  Future<void> _editRecord({
    required BuildContext context,
    required WidgetRef ref,
    required DietRecordService service,
    required DietRecord record,
  }) async {
    final grams = await showDietFoodEntryDialog(
      context: context,
      title: record.foodName,
      subtitle: record.foodCategory,
      confirmLabel: '更新',
      initialGrams: record.grams,
      calculationBuilder: (value) =>
          DietEntryCalculation.fromRecord(record, value),
    );
    if (grams == null) {
      return;
    }
    try {
      await service.updateDietRecordGrams(record: record, grams: grams);
      if (!context.mounted) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(dietRecordsByDateProvider(args.date));
        ref.invalidate(dailyDietSummaryProvider(args.date));
      });
      showLatestSnackBar(context, '已更新食物克数');
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      final appError = AppError.from(error, fallbackMessage: '更新食物失败，请稍后重试。');
      showLatestSnackBar(context, appError.message);
    }
  }
}

class _MacroStatRow extends StatelessWidget {
  const _MacroStatRow({required this.item});

  final _MacroStatItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            item.label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '${item.percentLabel} ${item.grams.toStringAsFixed(1)}g',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

class _MealFoodRow extends StatelessWidget {
  const _MealFoodRow({required this.record, required this.onTap});

  final DietRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.foodName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.grams.toStringAsFixed(0)}克${record.foodCategory.isEmpty ? '' : ' · ${record.foodCategory}'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${record.energyKCal.toStringAsFixed(0)}千卡 >',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MacroStatItem {
  const _MacroStatItem({
    required this.label,
    required this.grams,
    required this.calories,
    required this.ratio,
    required this.color,
  });

  final String label;
  final double grams;
  final double calories;
  final double ratio;
  final Color color;

  String get percentLabel => '${(ratio * 100).toStringAsFixed(0)}%';
}

double _mealEnergy(List<DietRecord> records) {
  return records.fold(0, (sum, item) => sum + item.energyKCal);
}

double _mealTotalGrams(List<DietRecord> records) {
  return records.fold(0, (sum, item) => sum + item.grams);
}

List<_MacroStatItem> _buildMacroStats(List<DietRecord> records) {
  final totalProtein = records.fold(0.0, (sum, item) => sum + item.protein);
  final totalFat = records.fold(0.0, (sum, item) => sum + item.fat);
  final totalCarb = records.fold(0.0, (sum, item) => sum + item.carb);
  final proteinCalories = totalProtein * 4;
  final fatCalories = totalFat * 9;
  final carbCalories = totalCarb * 4;
  final totalMacroCalories = proteinCalories + fatCalories + carbCalories;

  double ratioOf(double calories) {
    if (totalMacroCalories <= 0) {
      return 0;
    }
    return calories / totalMacroCalories;
  }

  return [
    _MacroStatItem(
      label: '蛋白质',
      grams: totalProtein,
      calories: proteinCalories,
      ratio: ratioOf(proteinCalories),
      color: const Color(0xFFF8A8B5),
    ),
    _MacroStatItem(
      label: '脂肪',
      grams: totalFat,
      calories: fatCalories,
      ratio: ratioOf(fatCalories),
      color: const Color(0xFFF7C27A),
    ),
    _MacroStatItem(
      label: '碳水',
      grams: totalCarb,
      calories: carbCalories,
      ratio: ratioOf(carbCalories),
      color: const Color(0xFF93E5C2),
    ),
  ];
}
