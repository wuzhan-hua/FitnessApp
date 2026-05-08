import 'package:fl_chart/fl_chart.dart';
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
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: summaryAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text(
                      AppError.from(
                        error,
                        fallbackMessage: '餐次分析加载失败，请稍后重试。',
                      ).message,
                      textAlign: TextAlign.center,
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
                    final recommendation = _mealRecommendationFor(args.mealType);
                    final mealStatus = _resolveMealStatus(
                      mealEnergy: mealEnergy,
                      recommendation: recommendation,
                    );

                    AppLogger.info(
                      '餐次分析页加载: date=${args.date.toIso8601String()}, '
                      'mealType=${args.mealType.value}, '
                      'fetchedRecords=${fetchedRecords.length}, '
                      'initialRecords=${args.initialRecords.length}, '
                      'resolvedRecords=${resolvedRecords.length}, '
                      'mealEnergy=${mealEnergy.toStringAsFixed(1)}',
                    );
                    AppLogger.info(
                      '餐次分析页渲染正式样式: records=${resolvedRecords.length}, '
                      'status=${mealStatus.label}',
                    );

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MealNutritionCard(
                            mealType: args.mealType,
                            mealEnergy: mealEnergy,
                            nutrientStats: nutrientStats,
                            recommendation: recommendation,
                            status: mealStatus,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _MealFoodsCard(
                            records: resolvedRecords,
                            totalGrams: totalGrams,
                            onAddDiaryTap: () async {
                              await _openFoodLibrary(
                                context: context,
                                ref: ref,
                                resolvedRecords: resolvedRecords,
                              );
                            },
                            onEditRecord: (record) async {
                              await _editRecord(
                                context: context,
                                ref: ref,
                                service: service,
                                record: record,
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SizedBox(
          height: 56,
          child: FilledButton(
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              textStyle: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
    await Navigator.of(context).pushNamed<void>(
      FoodLibraryPage.routeName,
      arguments: FoodLibraryPageArgs(
        date: args.date,
        mealType: args.mealType,
        initialSelectedRecords: resolvedRecords,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(dietRecordsByDateProvider(args.date));
      ref.invalidate(dailyDietSummaryProvider(args.date));
    });
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

class _MealNutritionCard extends StatelessWidget {
  const _MealNutritionCard({
    required this.mealType,
    required this.mealEnergy,
    required this.nutrientStats,
    required this.recommendation,
    required this.status,
  });

  final MealType mealType;
  final double mealEnergy;
  final List<_MacroStatItem> nutrientStats;
  final _MealRecommendation recommendation;
  final _MealStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                    children: [
                      TextSpan(text: '${mealType.label}建议 '),
                      TextSpan(
                        text:
                            '${recommendation.minKcal.toStringAsFixed(0)}-${recommendation.maxKcal.toStringAsFixed(0)}',
                        style: TextStyle(color: colors.success),
                      ),
                      const TextSpan(text: ' 千卡'),
                    ],
                  ),
                ),
              ),
              Text(
                status.label,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: status.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            height: 1,
            color: colors.panelAlt.withValues(alpha: 0.9),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 360;
              if (isCompact) {
                return Column(
                  children: [
                    _MealMacroRing(
                      mealEnergy: mealEnergy,
                      nutrientStats: nutrientStats,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (var index = 0; index < nutrientStats.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == nutrientStats.length - 1
                              ? 0
                              : AppSpacing.sm,
                        ),
                        child: _MacroStatRow(item: nutrientStats[index]),
                      ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _MealMacroRing(
                    mealEnergy: mealEnergy,
                    nutrientStats: nutrientStats,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      children: [
                        for (var index = 0; index < nutrientStats.length; index++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index == nutrientStats.length - 1
                                  ? 0
                                  : AppSpacing.sm,
                            ),
                            child: _MacroStatRow(item: nutrientStats[index]),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          if (mealEnergy <= 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '当前餐次还没有热量数据，先添加食物后会自动生成分析。',
              style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: colors.panelAlt.withValues(alpha: 0.45),
              borderRadius: const BorderRadius.all(Radius.circular(18)),
            ),
            child: Text(
              '+ 添加日记',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealMacroRing extends StatelessWidget {
  const _MealMacroRing({
    required this.mealEnergy,
    required this.nutrientStats,
  });

  final double mealEnergy;
  final List<_MacroStatItem> nutrientStats;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    try {
      return SizedBox(
        width: 122,
        height: 122,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: 0,
                centerSpaceRadius: 34,
                sections: _macroSections(nutrientStats),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mealEnergy.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '千卡',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ],
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        '餐次分析页圆环图渲染失败',
        error: error,
        stackTrace: stackTrace,
      );
      return Container(
        width: 122,
        height: 122,
        decoration: BoxDecoration(
          color: colors.panelAlt.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mealEnergy.toStringAsFixed(0),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '千卡',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      );
    }
  }
}

class _MacroStatRow extends StatelessWidget {
  const _MacroStatRow({required this.item});

  final _MacroStatItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            item.label,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            item.percentLabel,
            textAlign: TextAlign.right,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 64,
          child: Text(
            '${item.grams.toStringAsFixed(1)}克',
            textAlign: TextAlign.right,
            style: textTheme.titleSmall?.copyWith(color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _MealFoodsCard extends StatelessWidget {
  const _MealFoodsCard({
    required this.records,
    required this.totalGrams,
    required this.onAddDiaryTap,
    required this.onEditRecord,
  });

  final List<DietRecord> records;
  final double totalGrams;
  final Future<void> Function() onAddDiaryTap;
  final Future<void> Function(DietRecord record) onEditRecord;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '食物 ${records.length} 个（${totalGrams.toStringAsFixed(1)}克）',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '存为套餐',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.success.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (records.isEmpty)
            Text(
              '当前餐次还没有食物，点击底部按钮继续添加。',
              style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
            )
          else
            Column(
              children: [
                for (var index = 0; index < records.length; index++) ...[
                  _MealFoodRow(
                    record: records[index],
                    onTap: () async => onEditRecord(records[index]),
                  ),
                  if (index != records.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            onTap: () async => onAddDiaryTap(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: colors.panelAlt.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.all(Radius.circular(18)),
              ),
              child: Text(
                '+ 添加日记',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.success,
                ),
              ),
            ),
          ),
        ],
      ),
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
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              gradient: LinearGradient(
                colors: [
                  record.macroAccentColor.withValues(alpha: 0.28),
                  record.macroAccentColor.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.restaurant_rounded,
              color: record.macroAccentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.foodName,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.grams.toStringAsFixed(0)}克${record.foodCategory.isEmpty ? '' : ' · ${record.foodCategory}'}',
                  style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${record.energyKCal.toStringAsFixed(0)}千卡',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textMuted,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealRecommendation {
  const _MealRecommendation({required this.minKcal, required this.maxKcal});

  final double minKcal;
  final double maxKcal;
}

class _MealStatus {
  const _MealStatus({required this.label, required this.color});

  final String label;
  final Color color;
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
      color: _proteinColor,
    ),
    _MacroStatItem(
      label: '脂肪',
      grams: totalFat,
      calories: fatCalories,
      ratio: ratioOf(fatCalories),
      color: _fatColor,
    ),
    _MacroStatItem(
      label: '碳水化合物',
      grams: totalCarb,
      calories: carbCalories,
      ratio: ratioOf(carbCalories),
      color: _carbColor,
    ),
  ];
}

List<PieChartSectionData> _macroSections(List<_MacroStatItem> items) {
  final totalCalories = items.fold(0.0, (sum, item) => sum + item.calories);
  if (totalCalories <= 0) {
    return [
      PieChartSectionData(
        value: 1,
        color: const Color(0xFFEAEFF7),
        radius: 14,
        showTitle: false,
      ),
    ];
  }
  return items
      .map(
        (item) => PieChartSectionData(
          value: item.calories,
          color: item.color,
          radius: 14,
          showTitle: false,
        ),
      )
      .toList(growable: false);
}

_MealRecommendation _mealRecommendationFor(MealType mealType) {
  switch (mealType) {
    case MealType.breakfast:
      return const _MealRecommendation(minKcal: 420, maxKcal: 650);
    case MealType.lunch:
      return const _MealRecommendation(minKcal: 520, maxKcal: 820);
    case MealType.dinner:
      return const _MealRecommendation(minKcal: 480, maxKcal: 760);
    case MealType.snack:
      return const _MealRecommendation(minKcal: 120, maxKcal: 280);
  }
}

_MealStatus _resolveMealStatus({
  required double mealEnergy,
  required _MealRecommendation recommendation,
}) {
  if (mealEnergy <= 0) {
    return const _MealStatus(
      label: '待记录',
      color: Color(0xFF94A3B8),
    );
  }
  if (mealEnergy < recommendation.minKcal) {
    return const _MealStatus(label: '吃少了', color: Color(0xFF16A34A));
  }
  if (mealEnergy > recommendation.maxKcal) {
    return const _MealStatus(label: '吃多了', color: Color(0xFFF59E0B));
  }
  return const _MealStatus(label: '刚刚好', color: Color(0xFF1D72FF));
}

const Color _proteinColor = Color(0xFFF8A8B5);
const Color _fatColor = Color(0xFFF7C27A);
const Color _carbColor = Color(0xFF93E5C2);

extension on DietRecord {
  Color get macroAccentColor {
    final proteinCalories = protein * 4;
    final fatCalories = fat * 9;
    final carbCalories = carb * 4;
    if (proteinCalories >= fatCalories && proteinCalories >= carbCalories) {
      return _proteinColor;
    }
    if (fatCalories >= carbCalories) {
      return _fatColor;
    }
    return _carbColor;
  }
}
