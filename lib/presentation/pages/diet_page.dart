import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/providers.dart';
import '../../domain/entities/diet_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';
import '../widgets/async_tab_content.dart';
import '../widgets/diet_food_entry_dialog.dart';
import '../widgets/section_card.dart';
import 'food_library_page.dart';
import 'meal_analysis_page.dart';

class DietPage extends ConsumerWidget {
  const DietPage({super.key});

  String _resolveTitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) {
      return '今天';
    }
    if (diff == -1) {
      return '昨天';
    }
    if (diff == 1) {
      return '明天';
    }
    return DateFormat('yyyy-MM-dd').format(target);
  }

  List<DateTime> _weekDays(DateTime selectedDate) {
    final normalized = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final sunday = normalized.subtract(Duration(days: normalized.weekday % 7));
    return List<DateTime>.generate(
      7,
      (index) => sunday.add(Duration(days: index)),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return DateUtils.isSameDay(
      DateTime(now.year, now.month, now.day),
      DateTime(date.year, date.month, date.day),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDietDateProvider);
    final summaryAsync = ref.watch(dailyDietSummaryProvider(selectedDate));
    final weekDays = _weekDays(selectedDate);

    return Scaffold(
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            for (final mealType in MealType.values)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: mealType == MealType.values.last ? 0 : AppSpacing.xs,
                  ),
                  child: FilledButton.tonal(
                    onPressed: () async {
                      await Navigator.of(context).pushNamed<void>(
                        FoodLibraryPage.routeName,
                        arguments: FoodLibraryPageArgs(
                          date: selectedDate,
                          mealType: mealType,
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(
                        horizontal: -1,
                        vertical: -1,
                      ),
                      textStyle: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('+${mealType.label}', maxLines: 1),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _resolveTitle(selectedDate),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    for (var index = 0; index < weekDays.length; index++)
                      Expanded(
                        child: _WeekDayChip(
                          date: weekDays[index],
                          isSelected: DateUtils.isSameDay(
                            weekDays[index],
                            selectedDate,
                          ),
                          isToday: _isToday(weekDays[index]),
                          weekLabel: const ['日', '一', '二', '三', '四', '五', '六'],
                          onTap: () {
                            ref.read(selectedDietDateProvider.notifier).state =
                                weekDays[index];
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: AsyncTabContent<DailyDietSummary>(
                  asyncValue: summaryAsync,
                  errorPrefix: '饮食数据加载失败',
                  builder: (context, summary) {
                    return ListView(
                      children: [
                        SectionCard(
                          title: '当日饮食',
                          child: _DietSummaryRing(summary: summary),
                        ),
                        if (summary.recordCount == 0)
                          const SectionCard(
                            title: '当日记录',
                            child: Text('当前日期暂无饮食记录，点击底部餐次开始添加。'),
                          )
                        else
                          for (final mealType in MealType.values)
                            SectionCard(
                              title: mealType.label,
                              trailing: _MealCardTrailing(
                                totalEnergyKCal: _mealEnergy(
                                  summary.mealGroups[mealType] ?? const [],
                                ),
                              ),
                              child: _MealRecordList(
                                date: selectedDate,
                                mealType: mealType,
                                records:
                                    summary.mealGroups[mealType] ?? const [],
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
      ),
    );
  }
}

class _WeekDayChip extends StatelessWidget {
  const _WeekDayChip({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.weekLabel,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final List<String> weekLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final weekdayIndex = date.weekday % 7;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: !isSelected && isToday
              ? Border.all(color: colors.accent.withValues(alpha: 0.55))
              : null,
        ),
        child: Column(
          children: [
            Text(
              weekLabel[weekdayIndex],
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? Colors.white
                    : AppColors.of(context).textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isSelected
                    ? Colors.white
                    : AppColors.of(context).textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DietSummaryRing extends StatelessWidget {
  const _DietSummaryRing({required this.summary});

  final DailyDietSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final macroSections = _dietMacroSections(summary, colors);
    return Column(
      children: [
        SizedBox(
          height: 184,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 2,
                  centerSpaceRadius: 56,
                  sections: macroSections,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    summary.totalEnergyKCal.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'kcal',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _MacroStat(
                label: _MacroNutrient.carb.label,
                value: '${summary.totalCarb.toStringAsFixed(1)} g',
                dotColor: _MacroNutrient.carb.color(colors),
              ),
            ),
            Expanded(
              child: _MacroStat(
                label: _MacroNutrient.protein.label,
                value: '${summary.totalProtein.toStringAsFixed(1)} g',
                dotColor: _MacroNutrient.protein.color(colors),
              ),
            ),
            Expanded(
              child: _MacroStat(
                label: _MacroNutrient.fat.label,
                value: '${summary.totalFat.toStringAsFixed(1)} g',
                dotColor: _MacroNutrient.fat.color(colors),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MacroStat extends StatelessWidget {
  const _MacroStat({
    required this.label,
    required this.value,
    required this.dotColor,
  });

  final String label;
  final String value;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _MealRecordList extends StatelessWidget {
  const _MealRecordList({
    required this.date,
    required this.mealType,
    required this.records,
  });

  final DateTime date;
  final MealType mealType;
  final List<DietRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Text(
        '暂无记录',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.of(context).textMuted),
      );
    }
    return Column(
      children: [
        for (final record in records)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _DietMealRecordTile(
              record: record,
              onTap: () async {
                await _editDietRecord(
                  context: context,
                  record: record,
                  date: date,
                );
              },
            ),
          ),
        if (records.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () async {
                final mealRecords = records;
                await Navigator.of(context).pushNamed<void>(
                  MealAnalysisPage.routeName,
                  arguments: MealAnalysisPageArgs(
                    date: date,
                    mealType: mealType,
                    initialRecords: mealRecords,
                  ),
                );
              },
              child: Text('查看${mealType.label}分析'),
            ),
          ),
      ],
    );
  }
}

class _MealCardTrailing extends StatelessWidget {
  const _MealCardTrailing({required this.totalEnergyKCal});

  final double totalEnergyKCal;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${totalEnergyKCal.toStringAsFixed(0)} kcal',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        Icon(Icons.chevron_right_rounded, size: 18, color: colors.textMuted),
      ],
    );
  }
}

class _DietMealRecordTile extends StatelessWidget {
  const _DietMealRecordTile({required this.record, required this.onTap});

  final DietRecord record;
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
                    const SizedBox(height: 2),
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

Future<void> _editDietRecord({
  required BuildContext context,
  required DietRecord record,
  required DateTime date,
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
  if (grams == null || !context.mounted) {
    return;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  final service = container.read(dietRecordServiceProvider);
  try {
    await service.updateDietRecordGrams(record: record, grams: grams);
    if (!context.mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      container.invalidate(dietRecordsByDateProvider(date));
      container.invalidate(dailyDietSummaryProvider(date));
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

double _mealEnergy(List<DietRecord> records) {
  return records.fold(0, (sum, item) => sum + item.energyKCal);
}

List<PieChartSectionData> _dietMacroSections(
  DailyDietSummary summary,
  AppPalette colors,
) {
  final proteinCalories = summary.totalProtein * 4;
  final fatCalories = summary.totalFat * 9;
  final carbCalories = summary.totalCarb * 4;
  final total = proteinCalories + fatCalories + carbCalories;
  if (total <= 0) {
    return [
      PieChartSectionData(
        value: 1,
        color: const Color(0xFFE5E7EB),
        radius: 16,
        showTitle: false,
      ),
    ];
  }
  return [
    PieChartSectionData(
      value: proteinCalories / total,
      color: _MacroNutrient.protein.color(colors),
      radius: 16,
      showTitle: false,
    ),
    PieChartSectionData(
      value: fatCalories / total,
      color: _MacroNutrient.fat.color(colors),
      radius: 16,
      showTitle: false,
    ),
    PieChartSectionData(
      value: carbCalories / total,
      color: _MacroNutrient.carb.color(colors),
      radius: 16,
      showTitle: false,
    ),
  ];
}

enum _MacroNutrient { protein, fat, carb }

extension _MacroNutrientX on _MacroNutrient {
  String get label {
    switch (this) {
      case _MacroNutrient.protein:
        return '蛋白质';
      case _MacroNutrient.fat:
        return '脂肪';
      case _MacroNutrient.carb:
        return '碳水';
    }
  }

  Color color(AppPalette palette) {
    switch (this) {
      case _MacroNutrient.protein:
        return const Color(0xFFFCA5A5);
      case _MacroNutrient.fat:
        return const Color(0xFFFCD34D);
      case _MacroNutrient.carb:
        return const Color(0xFF86EFAC);
    }
  }
}
