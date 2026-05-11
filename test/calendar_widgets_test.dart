import 'package:fitness_client/domain/entities/workout_models.dart';
import 'package:fitness_client/domain/entities/diet_models.dart';
import 'package:fitness_client/application/state/session_editor_controller.dart';
import 'package:fitness_client/presentation/pages/session_analysis_page.dart';
import 'package:fitness_client/presentation/pages/session_editor_page.dart';
import 'package:fitness_client/presentation/widgets/calendar/calendar_widgets.dart';
import 'package:fitness_client/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('non-today training cells have no border while today keeps highlight', (
    tester,
  ) async {
    final today = _day(DateTime.now());
    final chestA = today.subtract(const Duration(days: 2));
    final chestB = today.subtract(const Duration(days: 1));
    final todayTraining = today;

    await tester.pumpWidget(
      _buildCalendar(
        month: DateTime(today.year, today.month),
        sessions: [
          _sessionWithTitle(chestA, '胸训练日'),
          _sessionWithTitle(chestB, '推训练日'),
          _sessionWithTitle(todayTraining, '背训练日'),
        ],
      ),
    );

    final chestAContainer = _cellContainer(tester, chestA);
    final chestBContainer = _cellContainer(tester, chestB);
    final todayContainer = _cellContainer(tester, todayTraining);

    expect(
      ((chestAContainer.decoration! as BoxDecoration).border! as Border)
          .top
          .color,
      Colors.transparent,
    );
    expect(
      ((chestBContainer.decoration! as BoxDecoration).border! as Border)
          .top
          .color,
      Colors.transparent,
    );
    expect(
      ((todayContainer.decoration! as BoxDecoration).border! as Border)
          .top
          .color,
      AppColors.of(
        tester.element(find.byKey(_calendarDayKey(todayTraining))),
      ).accent.withValues(alpha: 0.72),
    );
  });

  testWidgets('shows kcal for diet-only and training days', (tester) async {
    final today = _day(DateTime.now());
    final dietOnlyDay = today;
    final trainingDay = today.subtract(const Duration(days: 1));

    await tester.pumpWidget(
      _buildCalendar(
        month: DateTime(today.year, today.month),
        sessions: [_sessionWithTitle(trainingDay, '胸训练日')],
        dietSummaries: {
          dietOnlyDay: _dietSummary(dietOnlyDay, 520),
          trainingDay: _dietSummary(trainingDay, 860),
        },
      ),
    );

    expect(find.text('520 卡'), findsOneWidget);
    expect(find.text('860 卡'), findsOneWidget);
    expect(find.text('未训练'), findsOneWidget);
    expect(find.text('胸'), findsOneWidget);
  });

  testWidgets('shows colored training labels for strength, cardio and rest day', (
    tester,
  ) async {
    final today = _day(DateTime.now());
    final strengthDay = today.subtract(const Duration(days: 3));
    final cardioDay = today.subtract(const Duration(days: 2));
    final restDay = today.subtract(const Duration(days: 1));
    final noSessionDay = today.subtract(const Duration(days: 4));

    await tester.pumpWidget(
      _buildCalendar(
        month: DateTime(today.year, today.month),
        sessions: [
          _sessionWithTitle(strengthDay, '胸训练日'),
          _sessionWithTitle(cardioDay, '有氧训练日'),
          _sessionWithTitle(restDay, '休息日'),
        ],
      ),
    );

    final strengthLabel = tester.widget<Text>(
      find.byKey(_trainingLabelKey(strengthDay)),
    );
    final cardioLabel = tester.widget<Text>(
      find.byKey(_trainingLabelKey(cardioDay)),
    );
    final restLabel = tester.widget<Text>(
      find.byKey(_trainingLabelKey(restDay)),
    );

    expect(find.byKey(_trainingLabelKey(strengthDay)), findsOneWidget);
    expect(find.byKey(_trainingLabelKey(cardioDay)), findsOneWidget);
    expect(find.byKey(_trainingLabelKey(restDay)), findsOneWidget);
    expect(find.byKey(_trainingLabelKey(noSessionDay)), findsNothing);
    expect(
      strengthLabel.style?.color,
      AppColors.of(
        tester.element(find.byKey(_calendarDayKey(strengthDay))),
      ).textPrimary,
    );
    expect(
      cardioLabel.style?.color,
      AppColors.of(
        tester.element(find.byKey(_calendarDayKey(cardioDay))),
      ).textPrimary,
    );
    expect(
      restLabel.style?.color,
      const Color(0xFFD35D6E),
    );
  });

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
  Map<DateTime, DailyDietSummary> dietSummaries = const {},
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
          dietSummaries: dietSummaries,
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

ValueKey<String> _trainingLabelKey(DateTime date) {
  return ValueKey<String>(
    'calendar-training-label-${date.year}-${date.month}-${date.day}',
  );
}

WorkoutSession _sessionOn(DateTime date) {
  return _sessionWithTitle(date, '推训练日');
}

WorkoutSession _sessionWithTitle(DateTime date, String title) {
  return WorkoutSession(
    id: 'session-${date.millisecondsSinceEpoch}',
    date: date,
    title: title,
    status: SessionStatus.completed,
    durationMinutes: 60,
    exercises: const [],
  );
}

Container _cellContainer(WidgetTester tester, DateTime date) {
  final containerFinder = find.descendant(
    of: find.byKey(_calendarDayKey(date)),
    matching: find.byType(Container),
  );
  return tester.widgetList<Container>(containerFinder).firstWhere(
    (container) => container.decoration is BoxDecoration,
  );
}

DailyDietSummary _dietSummary(DateTime date, double kcal) {
  return DailyDietSummary.fromRecords(date, [
    DietRecord(
      id: 'diet-${date.millisecondsSinceEpoch}-$kcal',
      userId: 'user-1',
      consumedAt: date.add(const Duration(hours: 8)),
      mealType: MealType.breakfast,
      foodCode: 'code',
      foodName: 'food',
      foodCategory: 'category',
      grams: 100,
      energyKCal: kcal,
      protein: 10,
      fat: 10,
      carb: 10,
      dietaryFiber: 1,
      cholesterol: 0,
      sodium: 0,
      createdAt: date.add(const Duration(hours: 8)),
    ),
  ]);
}
