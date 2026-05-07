import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/providers.dart';
import '../../domain/entities/diet_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_time.dart';
import '../widgets/async_tab_content.dart';
import '../widgets/section_card.dart';
import 'food_library_page.dart';

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
                              child: _MealRecordList(
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
    required this.weekLabel,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
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
    final progress = summary.totalEnergyKCal <= 0
        ? 0.08
        : (summary.totalEnergyKCal / 2400).clamp(0.08, 1.0);
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
                  sectionsSpace: 0,
                  centerSpaceRadius: 56,
                  sections: [
                    PieChartSectionData(
                      value: progress,
                      color: colors.accent,
                      radius: 16,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: 1 - progress,
                      color: colors.panelAlt,
                      radius: 16,
                      showTitle: false,
                    ),
                  ],
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
                label: '碳水',
                value: '${summary.totalCarb.toStringAsFixed(1)} g',
              ),
            ),
            Expanded(
              child: _MacroStat(
                label: '蛋白质',
                value: '${summary.totalProtein.toStringAsFixed(1)} g',
              ),
            ),
            Expanded(
              child: _MacroStat(
                label: '脂肪',
                value: '${summary.totalFat.toStringAsFixed(1)} g',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MacroStat extends StatelessWidget {
  const _MacroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
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
  const _MealRecordList({required this.records});

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
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.of(context).panelAlt,
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
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${record.grams.toStringAsFixed(0)}g · ${record.foodCategory}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.of(context).textMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${record.energyKCal.toStringAsFixed(0)} kcal',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppTime.formatUtcDateTimeToBeijing(record.consumedAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.of(context).textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
