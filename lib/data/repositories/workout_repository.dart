import '../../domain/entities/workout_models.dart';

abstract class WorkoutRepository {
  Future<HomeSnapshot> getHomeSnapshot(DateTime date);

  Future<List<WorkoutSession>> getSessionsByMonth(DateTime month);

  Future<List<WorkoutSession>> getRecentSessions({int limit = 10});

  Future<WorkoutSession?> getSessionById(String id);

  Future<WorkoutSession?> getSessionByDate(DateTime date);

  Future<WorkoutSession?> getActiveSessionByDate(DateTime date);

  Future<WorkoutSession> startOrGetSession(
    DateTime date, {
    required SessionMode mode,
    String? sessionId,
    bool preferActiveSession = false,
  });

  Future<WorkoutSession> saveSession(WorkoutSession session);

  Future<AnalyticsSnapshot> getAnalyticsSnapshot({
    required DateTime from,
    required DateTime to,
  });
}
