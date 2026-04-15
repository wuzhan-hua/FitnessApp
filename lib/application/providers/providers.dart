import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/workout_service.dart';
import '../../data/repositories/mock_workout_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/entities/workout_models.dart';
import '../state/app_settings.dart';
import '../state/session_editor_controller.dart';
import '../state/session_editor_state.dart';
import '../state/settings_controller.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return MockWorkoutRepository();
});

final workoutServiceProvider = Provider<WorkoutService>((ref) {
  final repository = ref.watch(workoutRepositoryProvider);
  return WorkoutService(repository);
});

final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>(
  (ref) {
    return SettingsController();
  },
);

final homeSnapshotProvider = FutureProvider<HomeSnapshot>((ref) async {
  final service = ref.watch(workoutServiceProvider);
  return service.getHomeSnapshot(DateTime.now());
});

final calendarMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final sessionsByMonthProvider =
    FutureProvider.family<List<WorkoutSession>, DateTime>((ref, month) async {
      final service = ref.watch(workoutServiceProvider);
      return service.getSessionsByMonth(month);
    });

final analyticsSnapshotProvider = FutureProvider<AnalyticsSnapshot>((
  ref,
) async {
  final service = ref.watch(workoutServiceProvider);
  final now = DateTime.now();
  return service.getAnalyticsSnapshot(
    from: now.subtract(const Duration(days: 30)),
    to: now,
  );
});

final sessionEditorProvider = StateNotifierProvider.autoDispose
    .family<SessionEditorController, SessionEditorState, SessionEditorArgs>((
      ref,
      args,
    ) {
      final service = ref.watch(workoutServiceProvider);
      return SessionEditorController(service, args);
    });
