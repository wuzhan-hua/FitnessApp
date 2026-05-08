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

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(Supabase.instance.client);
});

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService(Supabase.instance.client);
});

final exerciseCatalogServiceProvider = Provider<ExerciseCatalogService>((ref) {
  return ExerciseCatalogService(Supabase.instance.client);
});

final foodLibraryServiceProvider = Provider<FoodLibraryService>((ref) {
  return FoodLibraryService();
});

final dietRecordServiceProvider = Provider<DietRecordService>((ref) {
  return DietRecordService(Supabase.instance.client);
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

DateTime calendarGridStartDay(DateTime month) {
  final firstDay = DateTime(month.year, month.month, 1);
  final startOffset = firstDay.weekday - 1;
  return firstDay.subtract(Duration(days: startOffset));
}

DateTime dietCalendarGridStartDay(DateTime month) {
  final firstDay = DateTime(month.year, month.month, 1);
  return firstDay.subtract(Duration(days: firstDay.weekday % 7));
}

final workoutSessionByIdProvider =
    FutureProvider.family<WorkoutSession?, String>((ref, sessionId) async {
      final service = ref.watch(workoutServiceProvider);
      return service.getSessionById(sessionId);
    });

final calendarMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final sessionsByCalendarGridProvider =
    FutureProvider.family<List<WorkoutSession>, DateTime>((ref, month) async {
      final service = ref.watch(workoutServiceProvider);
      final startDay = calendarGridStartDay(month);
      final endExclusive = startDay.add(const Duration(days: 42));
      return service.getSessionsInRange(
        fromInclusive: startDay,
        toExclusive: endExclusive,
      );
    });

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
  final category = ref.watch(selectedFoodCategoryProvider);
  return service.searchFoods(keyword: keyword, category: category);
});

final foodCategoriesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final service = ref.watch(foodLibraryServiceProvider);
  return service.getCategories();
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
      final gridStart = dietCalendarGridStartDay(month);
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
