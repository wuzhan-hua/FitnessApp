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
        actions: [
          IconButton(
            tooltip: '分享',
            onPressed: () => showLatestSnackBar(context, '分享功能开发中'),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
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
            final recommendation = _mealRecommendationFor(args.mealType);
            final mealStatus = _resolveMealStatus(
              mealEnergy: mealEnergy,
              recommendation: recommendation,
            );

            AppLogger.info(
              '餐次分析页加载: date=${args.date.toIso8601String()}, '
              'mealType=${args.mealType.value}, '
              'resolvedRecords=${resolvedRecords.length}, '
              'mealEnergy=${mealEnergy.toStringAsFixed(1)}',
            );
            AppLogger.info('餐次分析页开始构建最小安全内容');

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
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
                    onSaveAsSet: () => showLatestSnackBar(context, '存为套餐功能开发中'),
                    onEditRecord: (record) async {
                      await _editRecord(
                        context: context,
                        ref: ref,
                        service: service,
                        record: record,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _AddDiaryCard(
                    onTap: () async {
                      await _openFoodLibrary(
                        context: context,
                        ref: ref,
                        resolvedRecords: resolvedRecords,
                      );
                    },
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

    return _MealCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: '${mealType.label}建议 ',
                    children: [
                      TextSpan(
                        text:
                            '${recommendation.minKcal.toStringAsFixed(0)}~${recommendation.maxKcal.toStringAsFixed(0)}',
                        style: TextStyle(color: colors.success),
                      ),
                      const TextSpan(text: ' 千卡'),
                    ],
                  ),
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                status.label,
                style: textTheme.titleMedium?.copyWith(
                  color: status.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: colors.panelAlt),
          const SizedBox(height: AppSpacing.lg),
          Row(
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
          ),
          if (mealEnergy <= 0) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '当前餐次还没有热量数据，先添加食物后会自动生成分析。',
                style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MealMacroRing extends StatelessWidget {
  const _MealMacroRing({required this.mealEnergy, required this.nutrientStats});

  final double mealEnergy;
  final List<_MacroStatItem> nutrientStats;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SizedBox(
      width: 106,
      height: 106,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 0,
              centerSpaceRadius: 32,
              sections: _macroSections(nutrientStats, colors),
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
  }
}

class _MealFoodsCard extends StatelessWidget {
  const _MealFoodsCard({
    required this.records,
    required this.totalGrams,
    required this.onSaveAsSet,
    required this.onEditRecord,
  });

  final List<DietRecord> records;
  final double totalGrams;
  final VoidCallback onSaveAsSet;
  final ValueChanged<DietRecord> onEditRecord;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return _MealCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '食物 ${records.length}个（${totalGrams.toStringAsFixed(1)}克）',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSaveAsSet,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '存为套餐',
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (records.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '当前餐次还没有食物，点击底部按钮继续添加。',
                style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < records.length; index++) ...[
                  _MealFoodRow(
                    record: records[index],
                    onTap: () => onEditRecord(records[index]),
                  ),
                  if (index != records.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _AddDiaryCard extends StatelessWidget {
  const _AddDiaryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _MealCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Text(
          '+ 添加日记',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colors.success,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
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
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.panelAlt.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.restaurant_rounded,
                color: colors.textMuted,
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
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
              '${record.energyKCal.toStringAsFixed(0)} 千卡 ›',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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

List<PieChartSectionData> _macroSections(
  List<_MacroStatItem> items,
  AppPalette colors,
) {
  final totalCalories = items.fold(0.0, (sum, item) => sum + item.calories);
  if (totalCalories <= 0) {
    return [
      PieChartSectionData(
        value: 1,
        color: colors.panelAlt,
        radius: 13,
        showTitle: false,
      ),
    ];
  }
  return [
    for (final item in items)
      PieChartSectionData(
        value: item.calories,
        color: item.color,
        radius: 13,
        showTitle: false,
      ),
  ];
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
  if (mealEnergy <= 0 || mealEnergy < recommendation.minKcal) {
    return const _MealStatus(label: '吃少了', color: Color(0xFF5B6B86));
  }
  if (mealEnergy > recommendation.maxKcal) {
    return const _MealStatus(label: '吃多了', color: Color(0xFFF59E0B));
  }
  return const _MealStatus(label: '刚刚好', color: Color(0xFF16A34A));
}
