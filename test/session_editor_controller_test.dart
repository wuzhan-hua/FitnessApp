import 'package:fitness_client/application/state/session_editor_controller.dart';
import 'package:fitness_client/data/repositories/workout_repository.dart';
import 'package:fitness_client/data/services/exercise_catalog_service.dart';
import 'package:fitness_client/data/services/workout_service.dart';
import 'package:fitness_client/domain/entities/workout_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SessionEditorController createOnSaveOnly', () {
    test('loads local draft without starting repository session', () async {
      final repository = _CountingWorkoutRepository();
      final controller = _buildController(repository);
      addTearDown(controller.dispose);

      await _waitForLoad(controller);

      expect(repository.startOrGetSessionCalls, 0);
      expect(controller.state.isLoading, false);
      expect(controller.state.hasUnsavedChanges, false);
      expect(controller.state.session?.id, startsWith('draft-'));
      expect(controller.state.session?.exercises, isEmpty);
    });

    test('creates completed session only when completed', () async {
      final repository = _CountingWorkoutRepository();
      final controller = _buildController(repository);
      addTearDown(controller.dispose);

      await _waitForLoad(controller);
      final success = await controller.completeSession();

      expect(success, true);
      expect(repository.startOrGetSessionCalls, 0);
      expect(repository.saveSessionCalls, 1);
      expect(repository.savedSession?.id, startsWith('draft-'));
      expect(repository.savedSession?.status, SessionStatus.completed);
    });

    test('autosaves past backfill as completed', () async {
      final repository = _CountingWorkoutRepository();
      final controller = _buildController(repository);
      addTearDown(controller.dispose);

      await _waitForLoad(controller);
      controller.updateDuration(45);
      final success = await controller.autoSaveBeforeExit();

      expect(success, true);
      expect(repository.startOrGetSessionCalls, 0);
      expect(repository.saveSessionCalls, 1);
      expect(repository.savedSession?.status, SessionStatus.completed);
    });
  });
}

SessionEditorController _buildController(
  _CountingWorkoutRepository repository,
) {
  return SessionEditorController(
    WorkoutService(repository),
    ExerciseCatalogService(
      SupabaseClient(
        'http://localhost',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    ),
    SessionEditorArgs(
      date: DateTime(2026, 4, 20),
      mode: SessionMode.backfill,
      createOnSaveOnly: true,
    ),
  );
}

Future<void> _waitForLoad(SessionEditorController controller) async {
  for (var i = 0; i < 10 && controller.state.isLoading; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _CountingWorkoutRepository implements WorkoutRepository {
  int startOrGetSessionCalls = 0;
  int saveSessionCalls = 0;
  WorkoutSession? savedSession;

  @override
  Future<AnalyticsSnapshot> getAnalyticsSnapshot({
    required DateTime from,
    required DateTime to,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WorkoutSession?> getActiveSessionByDate(DateTime date) {
    throw UnimplementedError();
  }

  @override
  Future<HomeSnapshot> getHomeSnapshot(DateTime date) {
    throw UnimplementedError();
  }

  @override
  Future<List<WorkoutSession>> getRecentSessions({int limit = 10}) {
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
  Future<List<WorkoutSession>> getSessionsByMonth(DateTime month) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveSession(WorkoutSession session) async {
    saveSessionCalls += 1;
    savedSession = session;
  }

  @override
  Future<WorkoutSession> startOrGetSession(
    DateTime date, {
    required SessionMode mode,
    String? sessionId,
    bool preferActiveSession = false,
  }) async {
    startOrGetSessionCalls += 1;
    return WorkoutSession(
      id: 'repository-session',
      date: date,
      title: '仓库训练',
      status: SessionStatus.draft,
      durationMinutes: 30,
      exercises: const [],
    );
  }
}
