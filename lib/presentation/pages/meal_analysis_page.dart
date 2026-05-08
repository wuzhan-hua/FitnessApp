import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/providers.dart';
import '../../data/services/diet_record_service.dart';
import '../../domain/entities/diet_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';
import '../widgets/diet_food_entry_dialog.dart';
import '../widgets/section_card.dart';
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
    return '${DateFormat('M月d日').format(args.date)}${args.mealType.label}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dailyDietSummaryProvider(args.date));
    final service = ref.read(dietRecordServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_resolveTitle())),
      body: SafeArea(
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
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
            final records = fetchedRecords.isNotEmpty
                ? fetchedRecords
                : args.initialRecords;
            final hasRecords = records.isNotEmpty;
            final mealEnergy = _mealEnergy(records);
            final totalGrams = _mealTotalGrams(records);
            final nutrientStats = _buildMacroStats(records);

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (hasRecords)
                  SectionCard(
                    title: '共 ${mealEnergy.toStringAsFixed(0)} kcal',
                    child: _MealNutritionOverview(
                      totalEnergyKCal: mealEnergy,
                      nutrientStats: nutrientStats,
                    ),
                  )
                else
                  SectionCard(
                    title: '餐次分析',
                    child: Text(
                      '当前餐次还没有食物记录，添加食物后即可查看能量和三大营养素分析。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.of(context).textMuted,
                      ),
                    ),
                  ),
                SectionCard(
                  title:
                      '食物共 ${records.length} 个（${totalGrams.toStringAsFixed(0)}g）',
                  child: records.isEmpty
                      ? Text(
                          '当前餐次还没有食物，点击底部按钮继续添加。',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.of(context).textMuted,
                              ),
                        )
                      : Column(
                          children: [
                            for (final record in records)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: _DietRecordTile(
                                  record: record,
                                  onTap: () async {
                                    await _editRecord(
                                      context: context,
                                      ref: ref,
                                      service: service,
                                      record: record,
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Center(
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width * 0.5,
            child: FilledButton(
              onPressed: () async {
                final summary = await ref.read(
                  dailyDietSummaryProvider(args.date).future,
                );
                final fetchedRecords =
                    summary.mealGroups[args.mealType] ?? const [];
                final records = fetchedRecords.isNotEmpty
                    ? fetchedRecords
                    : args.initialRecords;
                if (!context.mounted) {
                  return;
                }
                await Navigator.of(context).pushNamed<void>(
                  FoodLibraryPage.routeName,
                  arguments: FoodLibraryPageArgs(
                    date: args.date,
                    mealType: args.mealType,
                    initialSelectedRecords: records,
                  ),
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.invalidate(dietRecordsByDateProvider(args.date));
                  ref.invalidate(dailyDietSummaryProvider(args.date));
                });
              },
              child: const Text('添加食物'),
            ),
          ),
        ),
      ),
    );
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

class _MealNutritionOverview extends StatelessWidget {
  const _MealNutritionOverview({
    required this.totalEnergyKCal,
    required this.nutrientStats,
  });

  final double totalEnergyKCal;
  final List<_MacroStatItem> nutrientStats;

  @override
  Widget build(BuildContext context) {
    final hasMacroData = nutrientStats.any((item) => item.calories > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (hasMacroData)
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 2,
                    centerSpaceRadius: 56,
                    sections: [
                      for (final item in nutrientStats)
                        PieChartSectionData(
                          value: item.ratio <= 0 ? 0.01 : item.ratio,
                          color: item.color,
                          radius: 18,
                          showTitle: false,
                        ),
                    ],
                  ),
                )
              else
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).panelAlt,
                    shape: BoxShape.circle,
                  ),
                ),
              if (!hasMacroData)
                Text(
                  '暂无营养数据',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.of(context).textMuted,
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '共 ${totalEnergyKCal.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'kcal',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.of(context).textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final item in nutrientStats)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _MacroLegendTile(item: item),
          ),
      ],
    );
  }
}

class _MacroLegendTile extends StatelessWidget {
  const _MacroLegendTile({required this.item});

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.percentLabel} · ${item.grams.toStringAsFixed(1)}g',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DietRecordTile extends StatelessWidget {
  const _DietRecordTile({required this.record, required this.onTap});

  final DietRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.panelAlt,
            borderRadius: AppRadius.card,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.foodName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.grams.toStringAsFixed(0)}g · ${record.foodCategory}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${record.energyKCal.toStringAsFixed(0)} kcal',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
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
      color: const Color(0xFFEF4444),
    ),
    _MacroStatItem(
      label: '脂肪',
      grams: totalFat,
      calories: fatCalories,
      ratio: ratioOf(fatCalories),
      color: AppPalette.light.warning,
    ),
    _MacroStatItem(
      label: '碳水',
      grams: totalCarb,
      calories: carbCalories,
      ratio: ratioOf(carbCalories),
      color: AppPalette.light.success,
    ),
  ];
}
