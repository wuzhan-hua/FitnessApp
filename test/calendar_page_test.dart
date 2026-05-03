import 'package:fitness_client/application/providers/providers.dart';
import 'package:fitness_client/data/repositories/workout_repository.dart';
import 'package:fitness_client/domain/entities/workout_models.dart';
import 'package:fitness_client/presentation/pages/calendar_page.dart';
import 'package:fitness_client/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CalendarRangeRepo implements WorkoutRepository {
  @override
  Future<List<WorkoutSession>> getSessionsInRange({
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) async {
    return [
      _session(DateTime(2026, 4, 27), title: '腿训练日', durationMinutes: 130),
      _session(DateTime(2026, 4, 28), title: '胸训练日', durationMinutes: 120),
      _session(DateTime(2026, 4, 29), title: '背训练日', durationMinutes: 130),
    ].where((session) {
      final date = DateTime(
        session.date.year,
        session.date.month,
        session.date.day,
      );
      return !date.isBefore(fromInclusive) && date.isBefore(toExclusive);
    }).toList();
  }

  @override
  Future<List<WorkoutSession>> getSessionsByMonth(DateTime month) async =>
      const [];

  @override
  Future<HomeSnapshot> getHomeSnapshot(DateTime date) {
    throw UnimplementedError();
  }

  @override
  Future<WorkoutSession?> getActiveSessionByDate(DateTime date) {
    throw UnimplementedError();
  }

  @override
  Future<AnalyticsSnapshot> getAnalyticsSnapshot({
    required DateTime from,
    required DateTime to,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WorkoutSession?> getSessionByDate(DateTime date) {
    throw UnimplementedError();
  }

  @override
  Future<WorkoutSession?> getSessionById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<List<WorkoutSession>> getRecentSessions({int limit = 10}) {
    throw UnimplementedError();
  }

  @override
  Future<WorkoutSession> saveSession(WorkoutSession session) {
    throw UnimplementedError();
  }

  @override
  Future<WorkoutSession> startOrGetSession(
    DateTime date, {
    required SessionMode mode,
    String? sessionId,
    bool preferActiveSession = false,
  }) {
    throw UnimplementedError();
  }

  WorkoutSession _session(
    DateTime date, {
    required String title,
    required int durationMinutes,
  }) {
    return WorkoutSession(
      id: 'session-${date.year}-${date.month}-${date.day}',
      date: date,
      title: title,
      status: SessionStatus.completed,
      durationMinutes: durationMinutes,
      exercises: const [],
    );
  }
}

void main() {
  testWidgets('五月页会显示四月底跨月格子的真实训练', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutRepositoryProvider.overrideWithValue(_CalendarRangeRepo()),
          calendarMonthProvider.overrideWith((ref) => DateTime(2026, 5, 1)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: CalendarPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026年05月'), findsOneWidget);
    expect(find.text('腿'), findsOneWidget);
    expect(find.text('胸'), findsOneWidget);
    expect(find.text('背'), findsOneWidget);
    expect(find.text('130分'), findsNWidgets(2));
    expect(find.text('120分'), findsOneWidget);
  });
}
