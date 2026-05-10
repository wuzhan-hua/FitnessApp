import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../application/state/session_editor_controller.dart';
import '../../../domain/entities/diet_models.dart';
import '../../../domain/entities/workout_models.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/snackbar_helper.dart';
import '../../pages/session_analysis_page.dart';
import '../../pages/session_editor_page.dart';

class CalendarMonthHeader extends StatelessWidget {
  const CalendarMonthHeader({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onPickMonthYear,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickMonthYear;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: AppRadius.card,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: InkWell(
              borderRadius: AppRadius.card,
              onTap: onPickMonthYear,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  DateFormat('yyyy年MM月').format(month),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontSize: 24),
                ),
              ),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class CalendarBody extends StatelessWidget {
  const CalendarBody({
    super.key,
    required this.month,
    required this.sessions,
    required this.dietSummaries,
    required this.onSessionChanged,
  });

  final DateTime month;
  final List<WorkoutSession> sessions;
  final Map<DateTime, DailyDietSummary> dietSummaries;
  final VoidCallback onSessionChanged;

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final firstDay = DateTime(month.year, month.month, 1);
    final startOffset = firstDay.weekday - 1;
    final startDay = firstDay.subtract(Duration(days: startOffset));

    final dayMap = {
      for (final session in sessions) _day(session.date): session,
    };

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: colors.panelAlt,
              borderRadius: AppRadius.card,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _WeekLabel('一'),
                _WeekLabel('二'),
                _WeekLabel('三'),
                _WeekLabel('四'),
                _WeekLabel('五'),
                _WeekLabel('六'),
                _WeekLabel('日'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final crossSpacing = compact ? 4.0 : 8.0;
              final cellAspect = compact ? 0.72 : 0.88;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: crossSpacing,
                  mainAxisSpacing: crossSpacing,
                  childAspectRatio: cellAspect,
                ),
                itemCount: 42,
                itemBuilder: (context, index) {
                  final day = startDay.add(Duration(days: index));
                  final session = dayMap[_day(day)];
                  final inCurrentMonth = day.month == month.month;
                  final today = _day(DateTime.now()) == _day(day);
                  return _CalendarCell(
                    key: ValueKey<String>(
                      'calendar-day-${day.year}-${day.month}-${day.day}',
                    ),
                    day: day,
                    session: session,
                    dietSummary: dietSummaries[_day(day)],
                    inMonth: inCurrentMonth,
                    compact: compact,
                    isToday: today,
                    onSessionChanged: onSessionChanged,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeekLabel extends StatelessWidget {
  const _WeekLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    super.key,
    required this.day,
    required this.session,
    required this.dietSummary,
    required this.inMonth,
    required this.compact,
    required this.isToday,
    required this.onSessionChanged,
  });

  final DateTime day;
  final WorkoutSession? session;
  final DailyDietSummary? dietSummary;
  final bool inMonth;
  final bool compact;
  final bool isToday;
  final VoidCallback onSessionChanged;

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<void> _handleTap(BuildContext context) async {
    final today = _day(DateTime.now());
    final selectedDay = _day(day);
    final hasSession = session != null;

    if (selectedDay.isAfter(today)) {
      showLatestSnackBar(context, '未来日期不可补录');
      return;
    }

    if (hasSession && selectedDay.isBefore(today)) {
      await _openSessionAnalysis(context, sessionId: session!.id);
      return;
    }

    if (hasSession) {
      await _openEditor(
        context,
        mode: SessionMode.backfill,
        sessionId: session!.id,
        readOnly: true,
      );
      return;
    }

    if (selectedDay.isBefore(today)) {
      final confirmed = await _showCreateBackfillDialog(context);
      if (!context.mounted || confirmed != true) {
        return;
      }
      await _openEditor(
        context,
        mode: SessionMode.backfill,
        createOnSaveOnly: true,
      );
      return;
    }

    await _openEditor(
      context,
      mode: SessionMode.newSession,
      createOnSaveOnly: true,
    );
  }

  Future<void> _openSessionAnalysis(
    BuildContext context, {
    required String sessionId,
  }) async {
    await Navigator.of(context).pushNamed<void>(
      SessionAnalysisPage.routeName,
      arguments: SessionAnalysisPageArgs(sessionId: sessionId),
    );
  }

  Future<bool?> _showCreateBackfillDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('补录历史训练'),
        content: const Text('该日期暂无训练记录，是否开始补录？保存后才会创建训练会话。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('开始补录'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    required SessionMode mode,
    String? sessionId,
    bool readOnly = false,
    bool createOnSaveOnly = false,
  }) async {
    final result = await Navigator.of(context)
        .pushNamed<SessionEditorExitResult>(
          SessionEditorPage.routeName,
          arguments: SessionEditorArgs(
            date: day,
            mode: mode,
            sessionId: sessionId,
            readOnly: readOnly,
            createOnSaveOnly: createOnSaveOnly,
          ),
        );
    if (!context.mounted || result == null) {
      return;
    }
    switch (result) {
      case SessionEditorExitResult.savedProgress:
      case SessionEditorExitResult.completed:
      case SessionEditorExitResult.autosaved:
        onSessionChanged();
      case SessionEditorExitResult.autosaveFailed:
      case SessionEditorExitResult.discarded:
        break;
    }
    final message = switch (result) {
      SessionEditorExitResult.savedProgress => '训练进度已保存',
      SessionEditorExitResult.completed => '训练记录已完成',
      SessionEditorExitResult.autosaved => '已自动保存当前内容',
      SessionEditorExitResult.autosaveFailed => '自动保存失败，本次修改未保存',
      SessionEditorExitResult.discarded => null,
    };
    if (message != null) {
      showLatestSnackBar(context, message);
    }
  }

  String _trainingTypeLabel(String title) {
    final normalized = title.trim();
    if (normalized.contains('休息')) {
      return '休息日';
    }
    if (normalized.contains('有氧')) {
      return '有氧';
    }
    if (normalized.contains('胸') || normalized.contains('推')) {
      return '胸';
    }
    if (normalized.contains('背') || normalized.contains('拉')) {
      return '背';
    }
    if (normalized.contains('腿') || normalized.contains('下肢')) {
      return '腿';
    }
    if (normalized.contains('肩')) {
      return '肩';
    }
    if (normalized.contains('手臂')) {
      return '手臂';
    }
    if (normalized.contains('核心')) {
      return '核心';
    }
    return '训练';
  }

  _CalendarCellTone _trainingTone(AppPalette colors) {
    return _CalendarCellTone(
      fill: colors.panel,
      border: const Color(0xFF8AA4D6),
      text: colors.textPrimary,
    );
  }

  String _formatKcalText(double totalEnergyKCal) {
    return '${totalEnergyKCal.toStringAsFixed(0)} 卡';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasSession = session != null;
    final today = _day(DateTime.now());
    final isFutureDay = _day(day).isAfter(today);
    final trainingLabel = hasSession ? _trainingTypeLabel(session!.title) : null;
    final tone = hasSession
        ? _trainingTone(colors)
        : _CalendarCellTone(
            fill: colors.panel,
            border: Colors.transparent,
            text: colors.textPrimary,
          );
    final hasDiet = (dietSummary?.totalEnergyKCal ?? 0) > 0;
    final kcalText = hasDiet
        ? _formatKcalText(dietSummary!.totalEnergyKCal)
        : null;
    final borderColor = isToday
        ? colors.accent.withValues(alpha: 0.72)
        : hasSession
        ? tone.border
        : Colors.transparent;
    final dayTextColor = inMonth
        ? colors.textPrimary
        : colors.textMuted.withValues(alpha: 0.6);

    return InkWell(
      borderRadius: AppRadius.card,
      onTap: () => _handleTap(context),
      child: Container(
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: AppRadius.card,
          border: Border.all(
            color: borderColor,
            width: isToday ? 1.5 : 1,
          ),
        ),
        padding: EdgeInsets.all(compact ? 5 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${day.day}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: dayTextColor,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 12 : 14,
              ),
            ),
            const Spacer(),
            if (kcalText != null)
              Padding(
                padding: EdgeInsets.only(bottom: compact ? 1 : 2),
                child: Text(
                  kcalText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted.withValues(
                      alpha: inMonth ? 0.88 : 0.65,
                    ),
                    fontSize: compact ? 7 : 8,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            if (hasSession)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trainingLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textPrimary.withValues(
                        alpha: inMonth ? 0.95 : 0.72,
                      ),
                      fontWeight: FontWeight.w600,
                      fontSize: compact ? 8.8 : 10,
                      height: 1.05,
                    ),
                  ),
                  Text(
                    '${session!.durationMinutes}分',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textMuted.withValues(
                        alpha: inMonth ? 0.88 : 0.68,
                      ),
                      fontSize: compact ? 8.4 : 9.5,
                      height: 1.05,
                    ),
                  ),
                ],
              )
            else if (!isFutureDay)
              Text(
                isToday ? '未训练' : '补录',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                  fontSize: compact ? 8.8 : 10,
                  height: 1.05,
                ),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _CalendarCellTone {
  const _CalendarCellTone({
    required this.fill,
    required this.border,
    required this.text,
  });

  final Color fill;
  final Color border;
  final Color text;
}
