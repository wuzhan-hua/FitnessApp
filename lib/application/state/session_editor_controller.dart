import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/exercise_catalog_service.dart';
import '../../data/services/workout_service.dart';
import '../../domain/entities/workout_models.dart';
import 'session_editor_state.dart';

class SessionEditorArgs {
  const SessionEditorArgs({
    required this.date,
    required this.mode,
    this.sessionId,
  });

  final DateTime date;
  final SessionMode mode;
  final String? sessionId;
}

class SessionEditorController extends StateNotifier<SessionEditorState> {
  SessionEditorController(this._service, this._exerciseCatalogService, this.args)
    : super(SessionEditorState.initial) {
    load();
  }

  static const double _defaultStrengthWeight = 20;
  static const int _defaultStrengthReps = 8;
  static const int _defaultRestSeconds = 120;

  final WorkoutService _service;
  final ExerciseCatalogService _exerciseCatalogService;
  final SessionEditorArgs args;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final session = await _service.startOrGetSession(
        args.date,
        mode: args.mode,
        sessionId: args.sessionId,
      );
      final normalized = await _normalizeZeroWeightExercises(session);
      state = state.copyWith(isLoading: false, session: normalized, error: null);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: '加载训练记录失败: $error');
    }
  }

  void updateSet({
    required String exerciseId,
    required int setIndex,
    double? weight,
    int? reps,
    bool? isCompleted,
    int? durationMinutes,
    double? distanceKm,
    bool clearDistanceKm = false,
  }) {
    final session = state.session;
    if (session == null) {
      return;
    }

    final updatedExercises = session.exercises.map((exercise) {
      if (exercise.id != exerciseId) {
        return exercise;
      }
      final updatedSets = exercise.sets.map((set) {
        if (set.index != setIndex) {
          return set;
        }
        return set.copyWith(
          weight: weight,
          reps: reps,
          isCompleted: isCompleted,
          durationMinutes: durationMinutes,
          distanceKm: distanceKm,
          clearDistanceKm: clearDistanceKm,
        );
      }).toList();
      return exercise.copyWith(sets: updatedSets);
    }).toList();

    state = state.copyWith(
      session: session.copyWith(exercises: updatedExercises),
    );
  }

  void updateDuration(int minutes) {
    final session = state.session;
    if (session == null) {
      return;
    }
    state = state.copyWith(session: session.copyWith(durationMinutes: minutes));
  }

  void updateSessionTitle(String title) {
    final session = state.session;
    if (session == null) {
      return;
    }
    final normalized = title.trim();
    if (normalized.isEmpty) {
      return;
    }
    state = state.copyWith(session: session.copyWith(title: normalized));
  }

  void updateNotes(String notes) {
    final session = state.session;
    if (session == null) {
      return;
    }
    state = state.copyWith(session: session.copyWith(notes: notes));
  }

  void clearExercises() {
    final session = state.session;
    if (session == null) {
      return;
    }
    state = state.copyWith(session: session.copyWith(exercises: const []));
  }

  void addSet({required String exerciseId}) {
    final session = state.session;
    if (session == null) {
      return;
    }

    final updatedExercises = session.exercises.map((exercise) {
      if (exercise.id != exerciseId) {
        return exercise;
      }

      final lastSet = exercise.sets.isNotEmpty
          ? exercise.sets.last
          : const ExerciseSet(
              index: 0,
              weight: _defaultStrengthWeight,
              reps: _defaultStrengthReps,
              restSeconds: _defaultRestSeconds,
              isCompleted: false,
            );
      final nextIndex = exercise.sets.length + 1;
      final nextSetType = lastSet.setType;
      final newSet = ExerciseSet(
        index: nextIndex,
        weight: nextSetType == ExerciseSetType.cardio ? 0 : lastSet.weight,
        reps: nextSetType == ExerciseSetType.cardio ? 0 : lastSet.reps,
        restSeconds: lastSet.restSeconds,
        isCompleted: false,
        setType: nextSetType,
        durationMinutes: nextSetType == ExerciseSetType.cardio
            ? (lastSet.durationMinutes ?? 20)
            : null,
        distanceKm: nextSetType == ExerciseSetType.cardio
            ? lastSet.distanceKm
            : null,
      );
      final updatedSets = [...exercise.sets, newSet];
      return exercise.copyWith(
        sets: _normalizeSetIndexes(updatedSets),
        targetSets: exercise.targetSets + 1,
      );
    }).toList();

    state = state.copyWith(
      session: session.copyWith(exercises: updatedExercises),
    );
  }

  bool addExercise({
    required String name,
    String? exerciseId,
    ExerciseSetType setType = ExerciseSetType.strength,
    bool canAdd = true,
    bool defaultsToZeroWeight = false,
  }) {
    if (!canAdd) {
      return false;
    }
    final session = state.session;
    if (session == null) {
      return false;
    }

    final nextOrder = session.exercises.length;
    final normalized = name.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final newExercise = SessionExercise(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      exerciseId:
          exerciseId ?? 'custom-${normalized.replaceAll(RegExp(r'\s+'), '-')}',
      exerciseName: normalized,
      targetSets: 1,
      order: nextOrder,
      sets: [
        ExerciseSet(
          index: 1,
          weight: setType == ExerciseSetType.cardio
              ? 0
              : (defaultsToZeroWeight ? 0 : _defaultStrengthWeight),
          reps: setType == ExerciseSetType.cardio ? 0 : _defaultStrengthReps,
          restSeconds: _defaultRestSeconds,
          isCompleted: false,
          setType: setType,
          durationMinutes: setType == ExerciseSetType.cardio ? 20 : null,
        ),
      ],
    );

    state = state.copyWith(
      session: session.copyWith(exercises: [...session.exercises, newExercise]),
    );
    return true;
  }

  Future<WorkoutSession> _normalizeZeroWeightExercises(
    WorkoutSession session,
  ) async {
    if (session.exercises.isEmpty) {
      return session;
    }
    final exerciseIds = session.exercises
        .map((exercise) => exercise.exerciseId.trim())
        .where((id) => id.isNotEmpty && !id.startsWith('custom-'))
        .toSet();
    if (exerciseIds.isEmpty) {
      return session;
    }

    final zeroWeightIds = await _exerciseCatalogService
        .getDefaultZeroWeightExerciseIds(exerciseIds);
    if (zeroWeightIds.isEmpty) {
      return session;
    }

    var changed = false;
    final updatedExercises = session.exercises.map((exercise) {
      if (!zeroWeightIds.contains(exercise.exerciseId) ||
          !_shouldNormalizeZeroWeightExercise(exercise)) {
        return exercise;
      }
      changed = true;
      return exercise.copyWith(
        sets: exercise.sets
            .map(
              (set) => set.setType == ExerciseSetType.cardio
                  ? set
                  : set.copyWith(weight: 0),
            )
            .toList(),
      );
    }).toList();

    return changed ? session.copyWith(exercises: updatedExercises) : session;
  }

  bool _shouldNormalizeZeroWeightExercise(SessionExercise exercise) {
    final strengthSets = exercise.sets
        .where((set) => set.setType == ExerciseSetType.strength)
        .toList();
    if (strengthSets.isEmpty) {
      return false;
    }
    return strengthSets.every((set) => set.weight == _defaultStrengthWeight);
  }

  void removeExercise({required String exerciseId}) {
    final session = state.session;
    if (session == null) {
      return;
    }

    final remained = session.exercises
        .where((exercise) => exercise.id != exerciseId)
        .toList();
    final normalized = List<SessionExercise>.generate(
      remained.length,
      (index) => remained[index].copyWith(order: index),
    );

    state = state.copyWith(session: session.copyWith(exercises: normalized));
  }

  bool removeSet({required String exerciseId, required int setIndex}) {
    final session = state.session;
    if (session == null) {
      return false;
    }

    var blockedByMinSet = false;
    final updatedExercises = session.exercises.map((exercise) {
      if (exercise.id != exerciseId) {
        return exercise;
      }
      if (exercise.sets.length <= 1) {
        blockedByMinSet = true;
        return exercise;
      }

      final updatedSets = exercise.sets
          .where((set) => set.index != setIndex)
          .toList();
      return exercise.copyWith(
        sets: _normalizeSetIndexes(updatedSets),
        targetSets: updatedSets.length,
      );
    }).toList();

    if (blockedByMinSet) {
      return false;
    }
    state = state.copyWith(
      session: session.copyWith(exercises: updatedExercises),
    );
    return true;
  }

  List<ExerciseSet> _normalizeSetIndexes(List<ExerciseSet> sets) {
    return List<ExerciseSet>.generate(
      sets.length,
      (index) => sets[index].copyWith(index: index + 1),
    );
  }

  Future<bool> save() async {
    final session = state.session;
    if (session == null) {
      return false;
    }

    state = state.copyWith(isSaving: true, error: null);
    try {
      final normalizedExercises = session.exercises.map((exercise) {
        final cardioSets = exercise.sets
            .where((set) => set.setType == ExerciseSetType.cardio)
            .toList();
        if (cardioSets.isEmpty) {
          return exercise;
        }
        final single = cardioSets.first.copyWith(index: 1);
        return exercise.copyWith(sets: [single], targetSets: 1);
      }).toList();
      final saved = session.copyWith(
        status: SessionStatus.completed,
        exercises: normalizedExercises,
      );
      await _service.saveSession(saved);
      state = state.copyWith(isSaving: false, session: saved);
      return true;
    } catch (error) {
      state = state.copyWith(isSaving: false, error: '保存失败: $error');
      return false;
    }
  }
}
