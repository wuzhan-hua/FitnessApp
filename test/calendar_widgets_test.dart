import 'package:fitness_client/domain/entities/workout_models.dart';
import 'package:fitness_client/application/state/session_editor_controller.dart';
import 'package:fitness_client/presentation/pages/session_analysis_page.dart';
import 'package:fitness_client/presentation/pages/session_editor_page.dart';
import 'package:fitness_client/presentation/widgets/calendar/calendar_widgets.dart';
import 'package:fitness_client/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('today with session opens read only page directly', (
    tester,
  ) async {
    final today = _day(DateTime.now());

    await tester.pumpWidget(
      _buildCalendar(
        month: DateTime(today.year, today.month),
        sessions: [_sessionOn(today)],
      ),
    );

    await tester.tap(find.byKey(_calendarDayKey(today)));
    await tester.pumpAndSettle();

    expect(find.text('readOnly=true'), findsOneWidget);
    expect(
      find.text('date=${today.year}-${today.month}-${today.day}'),
      findsOneWidget,
    );
  });

  testWidgets('past day with session opens session analysis page directly', (
    tester,
  ) async {
    final past = _day(DateTime.now()).subtract(const Duration(days: 1));
    final session = _sessionOn(past);

    await tester.pumpWidget(
      _buildCalendar(
        month: DateTime(past.year, past.month),
        sessions: [session],
      ),
    );

    await tester.tap(find.byKey(_calendarDayKey(past)));
    await tester.pumpAndSettle();

    expect(find.text('sessionId=${session.id}'), findsOneWidget);
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
    onGenerateRoute: (settings) {
      if (settings.name == SessionEditorPage.routeName) {
        final args = settings.arguments! as SessionEditorArgs;
        return MaterialPageRoute<SessionEditorExitResult?>(
          builder: (_) => Scaffold(
            body: Column(
              children: [
                Text('readOnly=${args.readOnly}'),
                Text(
                  'date=${args.date.year}-${args.date.month}-${args.date.day}',
                ),
              ],
            ),
          ),
        );
      }
      if (settings.name == SessionAnalysisPage.routeName) {
        final args = settings.arguments! as SessionAnalysisPageArgs;
        return MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: Text('sessionId=${args.sessionId}')),
        );
      }
      return null;
    },
    home: Scaffold(
      body: SizedBox(
        width: 700,
        height: 900,
        child: CalendarBody(
          month: month,
          sessions: sessions,
          onSessionChanged: () {},
        ),
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
