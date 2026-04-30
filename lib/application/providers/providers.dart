import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/workout_service.dart';
import '../../data/services/exercise_catalog_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/user_profile_service.dart';
import '../../data/repositories/supabase_workout_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/entities/workout_models.dart';
import '../state/auth_status.dart';
import '../state/app_settings.dart';
import '../state/session_editor_controller.dart';
import '../state/session_editor_state.dart';
import '../state/settings_controller.dart';

final emailSignUpPendingProvider = StateProvider<bool>((ref) => false);

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return SupabaseWorkoutRepository(Supabase.instance.client);
});

final workoutServiceProvider = Provider<WorkoutService>((ref) {
  final repository = ref.watch(workoutRepositoryProvider);
  return WorkoutService(repository);
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(Supabase.instance.client);
});

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService(Supabase.instance.client);
});

final exerciseCatalogServiceProvider = Provider<ExerciseCatalogService>((ref) {
  return ExerciseCatalogService(Supabase.instance.client);
});

final currentUserIsAdminProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(userProfileServiceProvider);
  return service.fetchCurrentUserIsAdmin();
});

final guestSoftSignedOutProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(authServiceProvider);
  return service.isGuestSoftSignedOut();
});

final authStatusProvider = StreamProvider<AuthStatus>((ref) async* {
  final service = ref.watch(authServiceProvider);
  yield service.resolveStatus(service.currentSession);
  await for (final event in service.onAuthStateChange) {
    yield service.resolveStatus(event.session);
  }
});

final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>(
  (ref) {
    final authService = ref.watch(authServiceProvider);
    final userProfileService = ref.watch(userProfileServiceProvider);
    return SettingsController(authService, userProfileService);
  },
);

final homeSnapshotProvider = FutureProvider<HomeSnapshot>((ref) async {
  final service = ref.watch(workoutServiceProvider);
  return service.getHomeSnapshot(DateTime.now());
});

final workoutSessionByIdProvider =
    FutureProvider.family<WorkoutSession?, String>((ref, sessionId) async {
      final service = ref.watch(workoutServiceProvider);
      return service.getSessionById(sessionId);
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
      final exerciseCatalogService = ref.watch(exerciseCatalogServiceProvider);
      return SessionEditorController(service, exerciseCatalogService, args);
    });

final selectedExerciseMuscleGroupProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final selectedExerciseEquipmentProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final selectedExerciseSearchKeywordProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final exerciseMuscleGroupsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final service = ref.watch(exerciseCatalogServiceProvider);
  return service.getPrimaryMuscleGroups();
});

final exerciseEquipmentsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final muscleGroup = ref.watch(selectedExerciseMuscleGroupProvider);
  if (muscleGroup == null || muscleGroup.isEmpty) {
    return const [];
  }
  final service = ref.watch(exerciseCatalogServiceProvider);
  return service.getEquipmentsByMuscleGroup(muscleGroup);
});

final exerciseCatalogItemsProvider =
    FutureProvider.autoDispose<List<ExerciseCatalogItem>>((ref) async {
      final muscleGroup = ref.watch(selectedExerciseMuscleGroupProvider);
      final searchKeyword = ref.watch(selectedExerciseSearchKeywordProvider);
      final normalizedKeyword = searchKeyword.trim();
      final service = ref.watch(exerciseCatalogServiceProvider);
      if (normalizedKeyword.isNotEmpty) {
        return service.searchExercises(keyword: normalizedKeyword);
      }
      if (muscleGroup == null || muscleGroup.isEmpty) {
        return const [];
      }
      final equipment = ref.watch(selectedExerciseEquipmentProvider);
      return service.getExercises(
        muscleGroup: muscleGroup,
        equipment: equipment,
      );
    });

final adminExerciseCatalogItemsProvider = FutureProvider.autoDispose
    .family<List<AdminExerciseCatalogItem>, String>((ref, muscleGroup) async {
      final service = ref.watch(exerciseCatalogServiceProvider);
      return service.getAdminExercises(muscleGroup: muscleGroup);
    });
