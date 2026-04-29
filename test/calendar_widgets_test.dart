import 'package:fitness_client/domain/entities/workout_models.dart';
import 'package:fitness_client/presentation/widgets/calendar/calendar_widgets.dart';
import 'package:fitness_client/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('today with session asks to supplement or view', (tester) async {
    final today = _day(DateTime.now());

    await tester.pumpWidget(
      _buildCalendar(
        month: DateTime(today.year, today.month),
        sessions: [_sessionOn(today)],
      ),
    );

    await tester.tap(find.byKey(_calendarDayKey(today)));
    await tester.pumpAndSettle();

    expect(find.text('今日训练'), findsOneWidget);
    expect(find.text('补充今日训练'), findsOneWidget);
    expect(find.text('查看今日训练'), findsOneWidget);
  });

  testWidgets('past day with session asks to backfill or view', (tester) async {
    final past = _day(DateTime.now()).subtract(const Duration(days: 1));

    await tester.pumpWidget(
      _buildCalendar(
        month: DateTime(past.year, past.month),
        sessions: [_sessionOn(past)],
      ),
    );

    await tester.tap(find.byKey(_calendarDayKey(past)));
    await tester.pumpAndSettle();

    expect(find.text('历史训练'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '补录'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '查看'), findsOneWidget);
  });

  testWidgets('past day without session asks before creating draft', (
    tester,
  ) async {
    final past = _day(DateTime.now()).subtract(const Duration(days: 2));

    await tester.pumpWidget(
      _buildCalendar(month: DateTime(past.year, past.month)),
    );

    await tester.tap(find.byKey(_calendarDayKey(past)));
    await tester.pumpAndSettle();

    expect(find.text('补录历史训练'), findsOneWidget);
    expect(find.text('开始补录'), findsOneWidget);
  });
}

Widget _buildCalendar({
  required DateTime month,
  List<WorkoutSession> sessions = const [],
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: SizedBox(
        width: 700,
        height: 900,
        child: CalendarBody(month: month, sessions: sessions),
      ),
    ),
  );
}

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

ValueKey<String> _calendarDayKey(DateTime date) {
  return ValueKey<String>(
    'calendar-day-${date.year}-${date.month}-${date.day}',
  );
}

WorkoutSession _sessionOn(DateTime date) {
  return WorkoutSession(
    id: 'session-${date.millisecondsSinceEpoch}',
    date: date,
    title: '推训练日',
    status: SessionStatus.completed,
    durationMinutes: 60,
    exercises: const [],
  );
}
