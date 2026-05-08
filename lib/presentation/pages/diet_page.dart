import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/providers.dart';
import '../../application/state/app_settings.dart';
import '../../domain/entities/diet_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';
import '../widgets/async_tab_content.dart';
import '../widgets/diet_food_entry_dialog.dart';
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

  Future<void> _openFoodLibrary({
    required BuildContext context,
    required WidgetRef ref,
    required DateTime selectedDate,
    required MealType mealType,
  }) async {
    final saved = await Navigator.of(context).pushNamed<bool>(
      FoodLibraryPage.routeName,
      arguments: FoodLibraryPageArgs(date: selectedDate, mealType: mealType),
    );
    if (!context.mounted) {
      return;
    }
    if (saved == true) {
      ref.invalidate(dietRecordsByDateProvider(selectedDate));
      ref.invalidate(dailyDietSummaryProvider(selectedDate));
      showLatestSnackBar(context, '${mealType.label}已保存');
    }
  }

  Future<void> _openDatePicker({
    required BuildContext context,
    required WidgetRef ref,
    required DateTime selectedDate,
    required _DietTargets targets,
  }) async {
    final picked = await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _DietCalendarSheet(initialDate: selectedDate, targets: targets);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.08),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
    if (picked == null || !context.mounted) {
      return;
    }
    final nextDate = DateTime(picked.year, picked.month, picked.day);
    ref.read(selectedDietDateProvider.notifier).state = nextDate;
    ref.invalidate(dailyDietSummaryProvider(nextDate));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDietDateProvider);
    final summaryAsync = ref.watch(dailyDietSummaryProvider(selectedDate));
    final settings = ref.watch(settingsProvider);
    final weekDays = _weekDays(selectedDate);
    final targets = _DietTargets.fromSettings(settings);

    return Scaffold(
      bottomNavigationBar: _MealQuickAddBar(
        onTap: (mealType) => _openFoodLibrary(
          context: context,
          ref: ref,
          selectedDate: selectedDate,
          mealType: mealType,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: Column(
            children: [
              _DietHeader(
                title: _resolveTitle(selectedDate),
                onPreviousDay: () {
                  ref.read(selectedDietDateProvider.notifier).state =
                      selectedDate.subtract(const Duration(days: 1));
                },
                onPickDate: () => _openDatePicker(
                  context: context,
                  ref: ref,
                  selectedDate: selectedDate,
                  targets: targets,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
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
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: AsyncTabContent<DailyDietSummary>(
                  asyncValue: summaryAsync,
                  errorPrefix: '饮食数据加载失败',
                  builder: (context, summary) {
                    return ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      children: [
                        _DailyDietOverviewCard(
                          summary: summary,
                          targets: targets,
                          onAdviceTap: () =>
                              showLatestSnackBar(context, '今日饮食建议已按当前资料估算'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (summary.recordCount == 0)
                          const _DietEmptyState()
                        else
                          for (final mealType in MealType.values)
                            if ((summary.mealGroups[mealType] ?? const [])
                                .isNotEmpty) ...[
                              _MealCard(
                                date: selectedDate,
                                mealType: mealType,
                                records:
                                    summary.mealGroups[mealType] ??
                                    const <DietRecord>[],
                                targets: targets,
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
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

class _DietHeader extends StatelessWidget {
  const _DietHeader({
    required this.title,
    required this.onPreviousDay,
    required this.onPickDate,
  });

  final String title;
  final VoidCallback onPreviousDay;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: '前一天',
              onPressed: onPreviousDay,
              icon: const Icon(Icons.chevron_left_rounded, size: 32),
              color: colors.textPrimary,
              padding: EdgeInsets.zero,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPickDate,
              borderRadius: AppRadius.chip,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 136, maxWidth: 220),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: colors.panel.withValues(alpha: 0.72),
                    borderRadius: AppRadius.chip,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 22,
                        color: colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
    final selectedColor = colors.accent.withValues(alpha: 0.2);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 48),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: !isSelected && isToday
              ? Border.all(color: colors.accent.withValues(alpha: 0.35))
              : null,
        ),
        child: Center(
          child: Text(
            weekLabel[weekdayIndex],
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: isSelected ? colors.accent : colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyDietOverviewCard extends StatelessWidget {
  const _DailyDietOverviewCard({
    required this.summary,
    required this.targets,
    required this.onAdviceTap,
  });

  final DailyDietSummary summary;
  final _DietTargets targets;
  final VoidCallback onAdviceTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final remaining = math.max(0.0, targets.calories - summary.totalEnergyKCal);
    return _DietSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  size: 14,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CRD 饮食',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                color: colors.textMuted.withValues(alpha: 0.45),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _OverviewMetric(
                  label: '饮食摄入',
                  value: summary.totalEnergyKCal.toStringAsFixed(0),
                ),
              ),
              _RemainingEnergyRing(
                consumed: summary.totalEnergyKCal,
                remaining: remaining,
                targets: targets,
              ),
              const Expanded(
                child: _OverviewMetric(label: '运动消耗', value: '0'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _MacroProgressStat(
                  label: _MacroNutrient.carb.label,
                  value: summary.totalCarb,
                  target: targets.carb,
                  color: _MacroNutrient.carb.color(colors),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MacroProgressStat(
                  label: _MacroNutrient.protein.label,
                  value: summary.totalProtein,
                  target: targets.protein,
                  color: _MacroNutrient.protein.color(colors),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MacroProgressStat(
                  label: _MacroNutrient.fat.label,
                  value: summary.totalFat,
                  target: targets.fat,
                  color: _MacroNutrient.fat.color(colors),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: onAdviceTap,
            icon: Icon(Icons.flatware_rounded, color: colors.accent, size: 17),
            label: const Text('今日饮食建议'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: colors.accent,
              side: BorderSide(color: colors.accent.withValues(alpha: 0.32)),
              backgroundColor: colors.accent.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textMuted.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _RemainingEnergyRing extends StatelessWidget {
  const _RemainingEnergyRing({
    required this.consumed,
    required this.remaining,
    required this.targets,
  });

  final double consumed;
  final double remaining;
  final _DietTargets targets;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const progressColor = Color(0xFF35D88A);
    final ratio = targets.calories <= 0
        ? 0.0
        : (consumed / targets.calories).clamp(0.0, 1.0);
    final hasProgress = consumed > 0 && ratio > 0;
    final backgroundColor = Theme.of(context).brightness == Brightness.dark
        ? colors.panelAlt.withValues(alpha: 0.65)
        : const Color(0xFFF3F4FA);
    return SizedBox(
      width: 170,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 0,
              centerSpaceRadius: 61,
              sections: [
                if (hasProgress)
                  PieChartSectionData(
                    value: ratio,
                    color: progressColor,
                    radius: 10,
                    showTitle: false,
                  ),
                PieChartSectionData(
                  value: hasProgress ? math.max(0.0001, 1 - ratio) : 1,
                  color: backgroundColor,
                  radius: 10,
                  showTitle: false,
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '还可以吃(千卡)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textMuted.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                remaining.toStringAsFixed(0),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 33,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                '推荐预算 ${targets.calories.toStringAsFixed(0)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textMuted.withValues(alpha: 0.7),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroProgressStat extends StatelessWidget {
  const _MacroProgressStat({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });

  final String label;
  final double value;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ratio = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: AppRadius.chip,
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 3.5,
            backgroundColor: colors.panelAlt,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${value.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} 克',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.date,
    required this.mealType,
    required this.records,
    required this.targets,
  });

  final DateTime date;
  final MealType mealType;
  final List<DietRecord> records;
  final _DietTargets targets;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final mealEnergy = _mealEnergy(records);
    final recommendation = targets.mealRange(mealType);
    return _DietSurface(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: () async {
            await Navigator.of(context).pushNamed<void>(
              MealAnalysisPage.routeName,
              arguments: MealAnalysisPageArgs(
                date: date,
                mealType: mealType,
                initialRecords: records,
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colors.textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          TextSpan(text: mealType.label),
                          TextSpan(
                            text:
                                '  建议 ${recommendation.min.toStringAsFixed(0)} - ${recommendation.max.toStringAsFixed(0)} 千卡',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.textMuted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${mealEnergy.toStringAsFixed(0)}千卡',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textMuted,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textMuted.withValues(alpha: 0.5),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final record in records)
                _DietMealRecordTile(
                  record: record,
                  onTap: () async {
                    await _editDietRecord(
                      context: context,
                      record: record,
                      date: date,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.panelAlt.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _foodIcon(record.foodCategory),
                  color: colors.accent.withValues(alpha: 0.78),
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.foodName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${record.grams.toStringAsFixed(0)}克',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${record.energyKCal.toStringAsFixed(0)}千卡',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.textMuted,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textMuted.withValues(alpha: 0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DietEmptyState extends StatelessWidget {
  const _DietEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.textMuted.withValues(alpha: 0.22),
          width: 1,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.rice_bowl_rounded,
            color: colors.textMuted.withValues(alpha: 0.16),
            size: 58,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '记录下今日的饮食吧',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textMuted.withValues(alpha: 0.72),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DietCalendarSheet extends ConsumerStatefulWidget {
  const _DietCalendarSheet({required this.initialDate, required this.targets});

  final DateTime initialDate;
  final _DietTargets targets;

  @override
  ConsumerState<_DietCalendarSheet> createState() => _DietCalendarSheetState();
}

class _DietCalendarSheetState extends ConsumerState<_DietCalendarSheet> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      1,
    );
  }

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final selectedDate = _day(widget.initialDate);
    final summariesAsync = ref.watch(
      monthlyDietSummariesProvider(_visibleMonth),
    );
    final mediaQuery = MediaQuery.of(context);
    final maxPanelHeight = mediaQuery.size.height * 0.72;
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxPanelHeight),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.panel,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DietCalendarSheetHeader(
                      selectedDate: selectedDate,
                      onClose: () => Navigator.of(context).pop(),
                      onPreviousMonth: () {
                        setState(() {
                          _visibleMonth = DateTime(
                            _visibleMonth.year,
                            _visibleMonth.month - 1,
                            1,
                          );
                        });
                      },
                      onNextMonth: () {
                        setState(() {
                          _visibleMonth = DateTime(
                            _visibleMonth.year,
                            _visibleMonth.month + 1,
                            1,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      DateFormat('yyyy 年 MM 月').format(_visibleMonth),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _DietCalendarWeekHeader(),
                    const SizedBox(height: AppSpacing.sm),
                    summariesAsync.when(
                      loading: () => const SizedBox(
                        height: 310,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stackTrace) => SizedBox(
                        height: 310,
                        child: Center(
                          child: Text(
                            AppError.from(
                              error,
                              fallbackMessage: '月历加载失败，请稍后重试。',
                            ).message,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.textMuted),
                          ),
                        ),
                      ),
                      data: (summaries) => _DietCalendarGrid(
                        visibleMonth: _visibleMonth,
                        selectedDate: selectedDate,
                        summaries: summaries,
                        targets: widget.targets,
                        onSelectDate: (date) => Navigator.of(context).pop(date),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _DietCalendarLegend(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DietCalendarSheetHeader extends StatelessWidget {
  const _DietCalendarSheetHeader({
    required this.selectedDate,
    required this.onClose,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime selectedDate;
  final VoidCallback onClose;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: '上个月',
              onPressed: onPreviousMonth,
              icon: const Icon(Icons.chevron_left_rounded, size: 30),
              color: colors.textPrimary,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClose,
              borderRadius: AppRadius.chip,
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.panelAlt.withValues(alpha: 0.62),
                  borderRadius: AppRadius.chip,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MM月dd日').format(selectedDate),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_drop_up_rounded,
                      color: colors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: '下个月',
              onPressed: onNextMonth,
              icon: const Icon(Icons.chevron_right_rounded, size: 30),
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DietCalendarWeekHeader extends StatelessWidget {
  const _DietCalendarWeekHeader();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const labels = ['日', '一', '二', '三', '四', '五', '六'];
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _DietCalendarGrid extends StatelessWidget {
  const _DietCalendarGrid({
    required this.visibleMonth,
    required this.selectedDate,
    required this.summaries,
    required this.targets,
    required this.onSelectDate,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final Map<DateTime, DailyDietSummary> summaries;
  final _DietTargets targets;
  final ValueChanged<DateTime> onSelectDate;

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final startDay = firstDay.subtract(Duration(days: firstDay.weekday % 7));
    final today = _day(DateTime.now());
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 42,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (context, index) {
        final date = _day(startDay.add(Duration(days: index)));
        return _DietCalendarDayCell(
          date: date,
          inVisibleMonth: date.month == visibleMonth.month,
          isSelected: DateUtils.isSameDay(date, selectedDate),
          isToday: DateUtils.isSameDay(date, today),
          status: _dietCalendarStatusFromSummary(
            summaries[date],
            targets: targets,
          ),
          onTap: () => onSelectDate(date),
        );
      },
    );
  }
}

class _DietCalendarDayCell extends StatelessWidget {
  const _DietCalendarDayCell({
    required this.date,
    required this.inVisibleMonth,
    required this.isSelected,
    required this.isToday,
    required this.status,
    required this.onTap,
  });

  final DateTime date;
  final bool inVisibleMonth;
  final bool isSelected;
  final bool isToday;
  final _DietCalendarStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textColor = inVisibleMonth
        ? colors.textPrimary
        : colors.textMuted.withValues(alpha: 0.36);
    final highlightColor = colors.accent.withValues(alpha: 0.18);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isSelected)
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(18),
                ),
              )
            else if (isToday)
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.28),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            if (status == _DietCalendarStatus.good)
              SizedBox(
                width: 42,
                height: 42,
                child: PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 0,
                    centerSpaceRadius: 17,
                    sections: [
                      PieChartSectionData(
                        value: 0.28,
                        color: const Color(0xFF35D88A),
                        radius: 3,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 0.72,
                        color: colors.panelAlt.withValues(alpha: 0.48),
                        radius: 3,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 12,
              child: Text(
                '${date.day}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: status == _DietCalendarStatus.low
                      ? const Color(0xFFF6C945)
                      : textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (status == _DietCalendarStatus.low ||
                status == _DietCalendarStatus.high)
              Positioned(
                bottom: 7,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: status.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DietCalendarLegend extends StatelessWidget {
  const _DietCalendarLegend();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        _DietCalendarLegendItem(
          color: _DietCalendarStatus.high.color,
          label: '吃多了',
        ),
        const SizedBox(width: AppSpacing.md),
        _DietCalendarLegendItem(
          color: _DietCalendarStatus.good.color,
          label: '合适',
        ),
        const SizedBox(width: AppSpacing.md),
        _DietCalendarLegendItem(
          color: _DietCalendarStatus.low.color,
          label: '吃少了',
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('关闭', style: TextStyle(color: colors.textMuted)),
        ),
      ],
    );
  }
}

class _DietCalendarLegendItem extends StatelessWidget {
  const _DietCalendarLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

enum _DietCalendarStatus { none, high, good, low }

_DietCalendarStatus _dietCalendarStatusFromSummary(
  DailyDietSummary? summary, {
  required _DietTargets targets,
}) {
  if (summary == null || summary.recordCount == 0) {
    return _DietCalendarStatus.none;
  }
  final targetCalories = targets.calories;
  if (targetCalories <= 0) {
    return _DietCalendarStatus.none;
  }
  final ratio = summary.totalEnergyKCal / targetCalories;
  if (ratio < 0.9) {
    return _DietCalendarStatus.low;
  }
  if (ratio > 1.1) {
    return _DietCalendarStatus.high;
  }
  return _DietCalendarStatus.good;
}

extension _DietCalendarStatusX on _DietCalendarStatus {
  Color get color {
    switch (this) {
      case _DietCalendarStatus.high:
        return const Color(0xFFFF6B6B);
      case _DietCalendarStatus.good:
        return const Color(0xFF35D88A);
      case _DietCalendarStatus.low:
        return const Color(0xFFF6C945);
      case _DietCalendarStatus.none:
        return Colors.transparent;
    }
  }
}

class _MealQuickAddBar extends StatelessWidget {
  const _MealQuickAddBar({required this.onTap});

  final ValueChanged<MealType> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final mealType in MealType.values)
              Expanded(
                child: _MealQuickAddItem(
                  mealType: mealType,
                  onTap: () => onTap(mealType),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MealQuickAddItem extends StatelessWidget {
  const _MealQuickAddItem({required this.mealType, required this.onTap});

  final MealType mealType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_mealIcon(mealType), color: colors.textPrimary, size: 23),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '+${mealType.label}',
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DietSurface extends StatelessWidget {
  const _DietSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _DietTargets {
  const _DietTargets({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carb,
  });

  final double calories;
  final double protein;
  final double fat;
  final double carb;

  static const defaults = _DietTargets(
    calories: 1900,
    protein: 76,
    fat: 59,
    carb: 267,
  );

  factory _DietTargets.fromSettings(AppSettings settings) {
    final birthDate = settings.birthDate;
    final height = settings.heightCm;
    final weight = settings.weightKg;
    final gender = settings.gender?.trim();
    if (birthDate == null ||
        height == null ||
        weight == null ||
        height <= 0 ||
        weight <= 0 ||
        gender == null ||
        gender.isEmpty ||
        gender == '其他' ||
        gender == '不透露') {
      return defaults;
    }

    final age = _ageFromBirthDate(birthDate);
    if (age <= 0) {
      return defaults;
    }

    final base = 10 * weight + 6.25 * height - 5 * age;
    final bmr = gender == '女' ? base - 161 : base + 5;
    final activityFactor = _activityFactor(settings.activityLevel);
    final goalFactor = _goalFactor(settings.trainingGoal);
    final calories = (bmr * activityFactor * goalFactor).clamp(1200.0, 4200.0);
    final protein = (weight * 1.8).clamp(60.0, 220.0);
    final fat = ((calories * 0.25) / 9).clamp(35.0, 140.0);
    final carbCalories = math.max(0.0, calories - protein * 4 - fat * 9);
    final carb = (carbCalories / 4).clamp(80.0, 520.0);

    return _DietTargets(
      calories: calories,
      protein: protein,
      fat: fat,
      carb: carb,
    );
  }

  _MealEnergyRange mealRange(MealType mealType) {
    final ratio = switch (mealType) {
      MealType.breakfast => 0.25,
      MealType.lunch => 0.35,
      MealType.dinner => 0.30,
      MealType.snack => 0.10,
    };
    final target = calories * ratio;
    return _MealEnergyRange(min: target * 0.9, max: target * 1.1);
  }
}

class _MealEnergyRange {
  const _MealEnergyRange({required this.min, required this.max});

  final double min;
  final double max;
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

int _ageFromBirthDate(DateTime birthDate) {
  final now = DateTime.now();
  var age = now.year - birthDate.year;
  final hadBirthday =
      now.month > birthDate.month ||
      (now.month == birthDate.month && now.day >= birthDate.day);
  if (!hadBirthday) {
    age -= 1;
  }
  return age;
}

double _activityFactor(String? activityLevel) {
  switch (activityLevel) {
    case '久坐':
      return 1.2;
    case '轻度活跃':
      return 1.375;
    case '中度活跃':
      return 1.55;
    case '高活跃':
      return 1.725;
    default:
      return 1.2;
  }
}

double _goalFactor(String? trainingGoal) {
  switch (trainingGoal) {
    case '减脂':
      return 0.85;
    case '增肌':
      return 1.10;
    case '提升力量':
      return 1.05;
    default:
      return 1.0;
  }
}

IconData _mealIcon(MealType mealType) {
  switch (mealType) {
    case MealType.breakfast:
      return Icons.trip_origin_rounded;
    case MealType.lunch:
      return Icons.lunch_dining_rounded;
    case MealType.dinner:
      return Icons.ramen_dining_rounded;
    case MealType.snack:
      return Icons.apple_rounded;
  }
}

IconData _foodIcon(String category) {
  if (category.contains('蛋') || category.contains('奶')) {
    return Icons.egg_alt_rounded;
  }
  if (category.contains('肉') ||
      category.contains('禽') ||
      category.contains('鱼')) {
    return Icons.set_meal_rounded;
  }
  if (category.contains('谷') ||
      category.contains('粮') ||
      category.contains('薯')) {
    return Icons.rice_bowl_rounded;
  }
  if (category.contains('水果')) {
    return Icons.apple_rounded;
  }
  return Icons.restaurant_rounded;
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
        return '碳水化合物';
    }
  }

  Color color(AppPalette palette) {
    switch (this) {
      case _MacroNutrient.protein:
        return const Color(0xFFFCA5A5);
      case _MacroNutrient.fat:
        return const Color(0xFFFCD34D);
      case _MacroNutrient.carb:
        return palette.accent;
    }
  }
}
