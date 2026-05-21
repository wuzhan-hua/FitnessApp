import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/diet_record_service.dart';
import '../../data/services/food_library_service.dart';
import '../../data/services/workout_service.dart';
import '../../data/services/exercise_catalog_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/user_profile_service.dart';
import '../../data/repositories/supabase_workout_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/entities/diet_models.dart';
import '../../domain/entities/workout_models.dart';
import '../../utils/app_error.dart';
import '../state/auth_status.dart';
import '../state/app_settings.dart';
import '../state/food_entry_controller.dart';
import '../state/food_entry_state.dart';
import '../state/food_selection_controller.dart';
import '../state/food_selection_state.dart';
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

final scopedWorkoutServiceProvider = Provider.family<WorkoutService, String>((
  ref,
  userId,
) {
  final baseRepository = ref.watch(workoutRepositoryProvider);
  if (baseRepository is! SupabaseWorkoutRepository) {
    return WorkoutService(baseRepository);
  }
  final repository = SupabaseWorkoutRepository(
    Supabase.instance.client,
    scopedUserId: userId,
  );
  return WorkoutService(repository);
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(Supabase.instance.client);
});

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService(Supabase.instance.client);
});

final exerciseCatalogServiceProvider = Provider<ExerciseCatalogService>((ref) {
  final resolved = _supabaseClientOrFallback();
  return ExerciseCatalogService(
    resolved.client,
    useRemote: resolved.isInitialized,
  );
});

final foodLibraryServiceProvider = Provider<FoodLibraryService>((ref) {
  final resolved = _supabaseClientOrFallback();
  return FoodLibraryService(resolved.client, useRemote: resolved.isInitialized);
});

final dietRecordServiceProvider = Provider<DietRecordService>((ref) {
  return DietRecordService(_supabaseClientOrFallback().client);
});

({SupabaseClient client, bool isInitialized}) _supabaseClientOrFallback() {
  try {
    return (client: Supabase.instance.client, isInitialized: true);
  } catch (_) {
    return (
      client: SupabaseClient(
        'http://localhost',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
      isInitialized: false,
    );
  }
}

final guestSoftSignedOutProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(authServiceProvider);
  return service.isGuestSoftSignedOut();
});

final authSessionProvider = StreamProvider<AuthSessionSnapshot>((ref) async* {
  final service = ref.watch(authServiceProvider);
  AuthSessionSnapshot fromSession(Session? session) {
    final status = service.resolveStatus(session);
    return AuthSessionSnapshot(status: status, userId: session?.user.id);
  }

  yield fromSession(service.currentSession);
  await for (final event in service.onAuthStateChange) {
    yield fromSession(event.session);
  }
});

final authStatusProvider = Provider<AsyncValue<AuthStatus>>((ref) {
  return ref.watch(authSessionProvider).whenData((snapshot) => snapshot.status);
});

final currentAuthUserIdProvider = FutureProvider<String?>((ref) async {
  return ref.watch(
    authSessionProvider.selectAsync((snapshot) => snapshot.userId),
  );
});

final currentUserIsAdminProvider = FutureProvider<bool>((ref) async {
  final snapshot = await ref.watch(
    authSessionProvider.selectAsync((snapshot) => snapshot),
  );
  final userId = snapshot.userId;
  if (snapshot.status != AuthStatus.authenticated ||
      userId == null ||
      userId.isEmpty) {
    return false;
  }
  final service = ref.watch(userProfileServiceProvider);
  return service.fetchCurrentUserIsAdmin();
});

Future<String> _requireUserIdForWorkoutData(Ref ref) async {
  final snapshot = await ref.watch(
    authSessionProvider.selectAsync((snapshot) => snapshot),
  );
  final userId = snapshot.userId;
  if (!snapshot.status.isSignedIn || userId == null || userId.isEmpty) {
    throw const AppError(message: '未登录，无法访问训练数据。', code: 'auth_required');
  }
  return userId;
}

final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>(
  (ref) {
    final authService = ref.watch(authServiceProvider);
    final userProfileService = ref.watch(userProfileServiceProvider);
    return SettingsController(authService, userProfileService);
  },
);

final homeSnapshotProvider = FutureProvider<HomeSnapshot>((ref) async {
  final userId = await _requireUserIdForWorkoutData(ref);
  final service = ref.watch(scopedWorkoutServiceProvider(userId));
  return service.getHomeSnapshot(DateTime.now());
});

DateTime calendarGridStartDay(DateTime month) {
  final firstDay = DateTime(month.year, month.month, 1);
  final startOffset = firstDay.weekday - 1;
  return firstDay.subtract(Duration(days: startOffset));
}

DateTime dietCalendarGridStartDay(DateTime month) {
  final firstDay = DateTime(month.year, month.month, 1);
  return firstDay.subtract(Duration(days: firstDay.weekday % 7));
}

DateTime monthKey(DateTime date) => DateTime(date.year, date.month, 1);

final workoutSessionByIdProvider =
    FutureProvider.family<WorkoutSession?, String>((ref, sessionId) async {
      final userId = await _requireUserIdForWorkoutData(ref);
      final service = ref.watch(scopedWorkoutServiceProvider(userId));
      return service.getSessionById(sessionId);
    });

final calendarMonthProvider = StateProvider<DateTime>(
  (ref) => monthKey(DateTime.now()),
);

final sessionsByCalendarGridProvider =
    FutureProvider.family<List<WorkoutSession>, DateTime>((ref, month) async {
      final userId = await _requireUserIdForWorkoutData(ref);
      final service = ref.watch(scopedWorkoutServiceProvider(userId));
      final startDay = calendarGridStartDay(month);
      final endExclusive = startDay.add(const Duration(days: 42));
      return service.getSessionsInRange(
        fromInclusive: startDay,
        toExclusive: endExclusive,
      );
    });

final sessionsByMonthProvider =
    FutureProvider.family<List<WorkoutSession>, DateTime>((ref, month) async {
      final userId = await _requireUserIdForWorkoutData(ref);
      final service = ref.watch(scopedWorkoutServiceProvider(userId));
      return service.getSessionsByMonth(month);
    });

final analyticsSnapshotProvider = FutureProvider<AnalyticsSnapshot>((
  ref,
) async {
  final userId = await _requireUserIdForWorkoutData(ref);
  final service = ref.watch(scopedWorkoutServiceProvider(userId));
  final now = DateTime.now();
  return service.getAnalyticsSnapshot(
    from: now.subtract(const Duration(days: 30)),
    to: now,
  );
});

void invalidateUserScopedMainPageProviders(
  WidgetRef ref, {
  required DateTime calendarMonth,
  required DateTime dietDate,
}) {
  final resolvedMonth = monthKey(calendarMonth);
  final resolvedDietDate = DateTime(
    dietDate.year,
    dietDate.month,
    dietDate.day,
  );
  ref.invalidate(authSessionProvider);
  ref.invalidate(authStatusProvider);
  ref.invalidate(currentAuthUserIdProvider);
  ref.invalidate(homeSnapshotProvider);
  ref.invalidate(analyticsSnapshotProvider);
  ref.invalidate(currentUserIsAdminProvider);
  ref.invalidate(settingsProvider);
  ref.invalidate(sessionsByMonthProvider(resolvedMonth));
  ref.invalidate(sessionsByCalendarGridProvider(resolvedMonth));
  ref.invalidate(monthlyDietSummariesProvider(resolvedMonth));
  ref.invalidate(dietRecordsByDateProvider(resolvedDietDate));
  ref.invalidate(dailyDietSummaryProvider(resolvedDietDate));
}

void invalidateUserScopedProvidersAfterSignIn(
  WidgetRef ref, {
  required DateTime calendarMonth,
  required DateTime dietDate,
}) {
  final resolvedMonth = monthKey(calendarMonth);
  final resolvedDietDate = DateTime(
    dietDate.year,
    dietDate.month,
    dietDate.day,
  );
  ref.invalidate(authSessionProvider);
  ref.invalidate(authStatusProvider);
  ref.invalidate(currentAuthUserIdProvider);
  ref.invalidate(currentUserIsAdminProvider);
  ref.invalidate(settingsProvider);
  ref.invalidate(monthlyDietSummariesProvider(resolvedMonth));
  ref.invalidate(dietRecordsByDateProvider(resolvedDietDate));
  ref.invalidate(dailyDietSummaryProvider(resolvedDietDate));
}

Future<void> prewarmWorkoutDataForCurrentUser(
  WidgetRef ref, {
  required DateTime calendarMonth,
}) async {
  final snapshot = await ref.read(authSessionProvider.future);
  final userId = snapshot.userId;
  if (!snapshot.status.isSignedIn || userId == null || userId.isEmpty) {
    return;
  }
  ref.read(scopedWorkoutServiceProvider(userId));
  ref.read(homeSnapshotProvider);
  final resolvedMonth = monthKey(calendarMonth);
  ref.read(sessionsByCalendarGridProvider(resolvedMonth));
  ref.read(analyticsSnapshotProvider);
}

void invalidateAuthScopedProvidersOnSignOut(
  WidgetRef ref, {
  required DateTime dietDate,
}) {
  final resolvedDietDate = DateTime(
    dietDate.year,
    dietDate.month,
    dietDate.day,
  );
  ref.invalidate(authSessionProvider);
  ref.invalidate(currentAuthUserIdProvider);
  ref.invalidate(currentUserIsAdminProvider);
  ref.invalidate(settingsProvider);
  ref.invalidate(dietRecordsByDateProvider(resolvedDietDate));
  ref.invalidate(dailyDietSummaryProvider(resolvedDietDate));
}

final selectedDietDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final foodSearchKeywordProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final selectedFoodCategoryProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final foodLibraryProvider = FutureProvider.autoDispose<List<FoodItem>>((
  ref,
) async {
  final service = ref.watch(foodLibraryServiceProvider);
  final keyword = ref.watch(foodSearchKeywordProvider);
  final categoryId = ref.watch(selectedFoodCategoryProvider);
  return service.searchFoods(keyword: keyword, categoryId: categoryId);
});

final foodCategoriesProvider = FutureProvider.autoDispose<List<FoodCategory>>((
  ref,
) async {
  final service = ref.watch(foodLibraryServiceProvider);
  return service.getFoodCategories();
});

final adminFoodCategoriesProvider =
    FutureProvider.autoDispose<List<FoodCategory>>((ref) async {
      final service = ref.watch(foodLibraryServiceProvider);
      return service.getFoodCategories(activeOnly: false);
    });

final adminFoodCatalogItemsProvider = FutureProvider.autoDispose
    .family<List<FoodItem>, String?>((ref, categoryId) async {
      final service = ref.watch(foodLibraryServiceProvider);
      return service.getAdminFoods(categoryId: categoryId);
    });

final dietRecordsByDateProvider =
    FutureProvider.family<List<DietRecord>, DateTime>((ref, date) async {
      final service = ref.watch(dietRecordServiceProvider);
      return service.getDietRecordsByDate(date);
    });

final dailyDietSummaryProvider =
    FutureProvider.family<DailyDietSummary, DateTime>((ref, date) async {
      final service = ref.watch(dietRecordServiceProvider);
      return service.getDailyDietSummary(date);
    });

final monthlyDietSummariesProvider =
    FutureProvider.family<Map<DateTime, DailyDietSummary>, DateTime>((
      ref,
      month,
    ) async {
      final service = ref.watch(dietRecordServiceProvider);
      final gridStart = dietCalendarGridStartDay(monthKey(month));
      final gridEnd = gridStart.add(const Duration(days: 42));
      final records = await service.getDietRecordsInRange(
        fromInclusive: gridStart,
        toExclusive: gridEnd,
      );
      final recordsByDay = <DateTime, List<DietRecord>>{};
      for (final record in records) {
        final day = DateTime(
          record.consumedAt.year,
          record.consumedAt.month,
          record.consumedAt.day,
        );
        recordsByDay.putIfAbsent(day, () => <DietRecord>[]).add(record);
      }
      return {
        for (final entry in recordsByDay.entries)
          entry.key: DailyDietSummary.fromRecords(entry.key, entry.value),
      };
    });

final foodEntryControllerProvider = StateNotifierProvider.autoDispose
    .family<FoodEntryController, FoodEntryState, FoodItem>((ref, food) {
      final service = ref.watch(dietRecordServiceProvider);
      return FoodEntryController(service, food);
    });

final foodSelectionControllerProvider = StateNotifierProvider.autoDispose
    .family<FoodSelectionController, FoodSelectionState, MealType>((
      ref,
      mealType,
    ) {
      final service = ref.watch(dietRecordServiceProvider);
      return FoodSelectionController(service, mealType);
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

const selectionExerciseLibrarySearchScope = 'selection';
const browseExerciseLibrarySearchScope = 'browse';

final selectedExerciseSearchKeywordProvider = StateProvider.autoDispose
    .family<String, String>((ref, _) => '');

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

final exerciseCatalogItemsProvider = FutureProvider.autoDispose
    .family<List<ExerciseCatalogItem>, String>((ref, searchScope) async {
      final muscleGroup = ref.watch(selectedExerciseMuscleGroupProvider);
      final searchKeyword = ref.watch(
        selectedExerciseSearchKeywordProvider(searchScope),
      );
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
