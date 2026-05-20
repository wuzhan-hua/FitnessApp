import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../domain/entities/diet_models.dart';
import '../../domain/entities/workout_models.dart';
import '../../theme/app_theme.dart';
import '../widgets/async_tab_content.dart';
import '../widgets/calendar/calendar_widgets.dart';

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  Future<DateTime?> _showYearMonthPicker(
    BuildContext context,
    DateTime initialMonth,
  ) {
    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        var step = 0;
        var selectedYear = initialMonth.year;
        return StatefulBuilder(
          builder: (context, setState) {
            final title = step == 0 ? '选择年份' : '选择月份';
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 320,
                height: 320,
                child: step == 0
                    ? YearPicker(
                        firstDate: DateTime(2020, 1, 1),
                        lastDate: DateTime(2100, 12, 31),
                        selectedDate: DateTime(selectedYear, 1, 1),
                        currentDate: DateTime.now(),
                        onChanged: (value) {
                          setState(() {
                            selectedYear = value.year;
                            step = 1;
                          });
                        },
                      )
                    : GridView.builder(
                        itemCount: 12,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                        itemBuilder: (context, index) {
                          final month = index + 1;
                          final selected =
                              selectedYear == initialMonth.year &&
                              month == initialMonth.month;
                          return FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: selected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : null,
                            ),
                            onPressed: () {
                              Navigator.of(
                                dialogContext,
                              ).pop(DateTime(selectedYear, month, 1));
                            },
                            child: Text('$month月'),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (step == 1) {
                      setState(() => step = 0);
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(step == 1 ? '返回年份' : '取消'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = monthKey(ref.watch(calendarMonthProvider));
    final sessionsAsync = ref.watch(sessionsByCalendarGridProvider(month));
    final dietSummariesAsync = ref.watch(monthlyDietSummariesProvider(month));
    final calendarDataAsync = _mergeCalendarData(
      sessionsAsync,
      dietSummariesAsync,
    );
    final monthNotifier = ref.read(calendarMonthProvider.notifier);

    void refreshMonthSessions() {
      ref.invalidate(sessionsByCalendarGridProvider(month));
      ref.invalidate(monthlyDietSummariesProvider(month));
    }

    Future<void> refreshCalendar() async {
      refreshMonthSessions();
      await Future.wait([
        ref.read(sessionsByCalendarGridProvider(month).future),
        ref.read(monthlyDietSummariesProvider(month).future),
      ]);
    }

    Future<void> pickMonthYear() async {
      final selected = await _showYearMonthPicker(context, month);
      if (selected == null || !context.mounted) {
        return;
      }
      monthNotifier.state = monthKey(selected);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            CalendarMonthHeader(
              month: month,
              onPrevious: () => monthNotifier.state = monthKey(
                DateTime(month.year, month.month - 1),
              ),
              onNext: () => monthNotifier.state = monthKey(
                DateTime(month.year, month.month + 1),
              ),
              onPickMonthYear: pickMonthYear,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: RefreshIndicator(
                onRefresh: refreshCalendar,
                child: AsyncTabContent<_CalendarPageData>(
                  asyncValue: calendarDataAsync,
                  errorPrefix: '日历加载失败',
                  builder: (context, data) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      CalendarBody(
                        month: month,
                        sessions: data.sessions,
                        dietSummaries: data.dietSummaries,
                        onSessionChanged: refreshMonthSessions,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarPageData {
  const _CalendarPageData({
    required this.sessions,
    required this.dietSummaries,
  });

  final List<WorkoutSession> sessions;
  final Map<DateTime, DailyDietSummary> dietSummaries;
}

AsyncValue<_CalendarPageData> _mergeCalendarData(
  AsyncValue<List<WorkoutSession>> sessionsAsync,
  AsyncValue<Map<DateTime, DailyDietSummary>> dietSummariesAsync,
) {
  if (sessionsAsync.hasError) {
    return AsyncValue.error(
      sessionsAsync.error!,
      sessionsAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (dietSummariesAsync.hasError) {
    return AsyncValue.error(
      dietSummariesAsync.error!,
      dietSummariesAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (sessionsAsync.isLoading ||
      dietSummariesAsync.isLoading ||
      !sessionsAsync.hasValue ||
      !dietSummariesAsync.hasValue) {
    return const AsyncValue.loading();
  }
  return AsyncValue.data(
    _CalendarPageData(
      sessions: sessionsAsync.requireValue,
      dietSummaries: dietSummariesAsync.requireValue,
    ),
  );
}
