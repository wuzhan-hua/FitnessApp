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
    this.preferActiveSession = false,
    this.readOnly = false,
    this.createOnSaveOnly = false,
  });

  final DateTime date;
  final SessionMode mode;
  final String? sessionId;
  final bool preferActiveSession;
  final bool readOnly;
  final bool createOnSaveOnly;
}

class SessionEditorController extends StateNotifier<SessionEditorState> {
  SessionEditorController(
    this._service,
    this._exerciseCatalogService,
    this.args,
  ) : super(SessionEditorState.initial) {
    load();
  }

  static const double _defaultStrengthWeight = 20;
  static const int _defaultStrengthReps = 8;
  static const int _defaultRestSeconds = 120;

  final WorkoutService _service;
  final ExerciseCatalogService _exerciseCatalogService;
  final SessionEditorArgs args;

  bool get _isReadOnly => args.readOnly;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final session = _shouldCreateLocalDraft
          ? _buildLocalDraftSession()
          : await _service.startOrGetSession(
              args.date,
              mode: args.mode,
              sessionId: args.sessionId,
              preferActiveSession: args.preferActiveSession,
            );
      final normalized = await _normalizeZeroWeightExercises(session);
      state = state.copyWith(
        isLoading: false,
        hasUnsavedChanges: false,
        savingAction: SessionEditorSavingAction.none,
        session: normalized,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: '加载训练记录失败: $error');
    }
  }

  bool get _shouldCreateLocalDraft =>
      args.createOnSaveOnly &&
      (args.sessionId == null || args.sessionId!.isEmpty);

  bool get _isPastBackfill =>
      args.mode == SessionMode.backfill &&
      _day(args.date).isBefore(_day(DateTime.now()));

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  WorkoutSession _buildLocalDraftSession() {
    final normalizedDate = _day(args.date);
    return WorkoutSession(
      id: 'draft-${normalizedDate.millisecondsSinceEpoch}',
      date: normalizedDate,
      title: '新训练日',
      status: SessionStatus.draft,
      durationMinutes: 30,
      exercises: const [],
    );
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
    if (_isReadOnly) {
      return;
    }
    final session = state.session;
    if (session == null) {
      return;
    }

    var changed = false;
    final updatedExercises = session.exercises.map((exercise) {
      if (exercise.id != exerciseId) {
        return exercise;
      }
      final updatedSets = exercise.sets.map((set) {
        if (set.index != setIndex) {
          return set;
        }
        final nextWeight = weight ?? set.weight;
        final nextReps = reps ?? set.reps;
        final nextIsCompleted = isCompleted ?? set.isCompleted;
        final nextDurationMinutes = durationMinutes ?? set.durationMinutes;
        final nextDistanceKm = clearDistanceKm
            ? null
            : (distanceKm ?? set.distanceKm);
        if (nextWeight == set.weight &&
            nextReps == set.reps &&
            nextIsCompleted == set.isCompleted &&
            nextDurationMinutes == set.durationMinutes &&
            nextDistanceKm == set.distanceKm) {
          return set;
        }
        changed = true;
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

    if (!changed) {
      return;
    }

    _updateSession(
      _promoteDraftIfNeeded(session.copyWith(exercises: updatedExercises)),
    );
  }

  void updateDuration(int minutes) {
    if (_isReadOnly) {
      return;
    }
    final session = state.session;
    if (session == null || session.durationMinutes == minutes) {
      return;
    }
    _updateSession(
      _promoteDraftIfNeeded(session.copyWith(durationMinutes: minutes)),
    );
  }

  void updateSessionTitle(String title) {
    if (_isReadOnly) {
      return;
    }
    final session = state.session;
    if (session == null) {
      return;
    }
    final normalized = title.trim();
    if (normalized.isEmpty || normalized == session.title) {
      return;
    }
    _updateSession(_promoteDraftIfNeeded(session.copyWith(title: normalized)));
  }

  void updateNotes(String notes) {
    if (_isReadOnly) {
      return;
    }
    final session = state.session;
    if (session == null || session.notes == notes) {
      return;
    }
    _updateSession(_promoteDraftIfNeeded(session.copyWith(notes: notes)));
  }

  void clearExercises() {
    if (_isReadOnly) {
      return;
    }
    final session = state.session;
    if (session == null || session.exercises.isEmpty) {
      return;
    }
    _updateSession(
      _promoteDraftIfNeeded(session.copyWith(exercises: const [])),
    );
  }

  void addSet({required String exerciseId}) {
    if (_isReadOnly) {
      return;
    }
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

    _updateSession(
      _promoteDraftIfNeeded(session.copyWith(exercises: updatedExercises)),
    );
  }

  bool addExercise({
    required String name,
    String? exerciseId,
    ExerciseSetType setType = ExerciseSetType.strength,
    bool canAdd = true,
    bool defaultsToZeroWeight = false,
  }) {
    if (_isReadOnly) {
      return false;
    }
    if (!canAdd) {
      return false;
    }
    final session = state.session;
    if (session == null) {
      return false;
    }

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
      order: 0,
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
    final reorderedExercises = List<SessionExercise>.generate(
      session.exercises.length + 1,
      (index) => index == 0
          ? newExercise
          : session.exercises[index - 1].copyWith(order: index),
    );

    _updateSession(
      _promoteDraftIfNeeded(session.copyWith(exercises: reorderedExercises)),
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
    if (_isReadOnly) {
      return;
    }
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

    _updateSession(
      _promoteDraftIfNeeded(session.copyWith(exercises: normalized)),
    );
  }

  bool removeSet({required String exerciseId, required int setIndex}) {
    if (_isReadOnly) {
      return false;
    }
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
    _updateSession(
      _promoteDraftIfNeeded(session.copyWith(exercises: updatedExercises)),
    );
    return true;
  }

  List<ExerciseSet> _normalizeSetIndexes(List<ExerciseSet> sets) {
    return List<ExerciseSet>.generate(
      sets.length,
      (index) => sets[index].copyWith(index: index + 1),
    );
  }

  WorkoutSession _promoteDraftIfNeeded(WorkoutSession session) {
    if (session.status != SessionStatus.draft) {
      return session;
    }
    return session.copyWith(status: SessionStatus.inProgress);
  }

  void _updateSession(WorkoutSession session) {
    state = state.copyWith(
      session: session,
      hasUnsavedChanges: true,
      error: null,
    );
  }

  List<SessionExercise> _normalizeExercisesForSave(
    List<SessionExercise> items,
  ) {
    return items.map((exercise) {
      final cardioSets = exercise.sets
          .where((set) => set.setType == ExerciseSetType.cardio)
          .toList();
      if (cardioSets.isEmpty) {
        return exercise;
      }
      final single = cardioSets.first.copyWith(index: 1);
      return exercise.copyWith(sets: [single], targetSets: 1);
    }).toList();
  }

  Future<bool> saveProgress() async {
    if (_isReadOnly) {
      return true;
    }
    return _saveWithStatus(
      SessionStatus.inProgress,
      action: SessionEditorSavingAction.saveProgress,
    );
  }

  Future<bool> completeSession() async {
    if (_isReadOnly) {
      return true;
    }
    return _saveWithStatus(
      SessionStatus.completed,
      action: SessionEditorSavingAction.completeSession,
    );
  }

  Future<bool> autoSaveBeforeExit() async {
    if (_isReadOnly) {
      return true;
    }
    if (!state.hasUnsavedChanges) {
      return true;
    }
    final session = state.session;
    if (session == null) {
      return true;
    }
    final targetStatus =
        session.status == SessionStatus.completed || _isPastBackfill
        ? SessionStatus.completed
        : SessionStatus.inProgress;
    return _saveWithStatus(
      targetStatus,
      action: SessionEditorSavingAction.autoSave,
    );
  }

  Future<bool> _saveWithStatus(
    SessionStatus targetStatus, {
    required SessionEditorSavingAction action,
  }) async {
    final session = state.session;
    if (session == null) {
      return false;
    }

    state = state.copyWith(savingAction: action, error: null);
    try {
      final normalizedExercises = _normalizeExercisesForSave(session.exercises);
      final resolvedStatus = session.status == SessionStatus.completed
          ? SessionStatus.completed
          : targetStatus;
      final saved = session.copyWith(
        status: resolvedStatus,
        exercises: normalizedExercises,
      );
      final persisted = await _service.saveSession(saved);
      state = state.copyWith(
        savingAction: SessionEditorSavingAction.none,
        hasUnsavedChanges: false,
        session: persisted,
        error: null,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        savingAction: SessionEditorSavingAction.none,
        error: '保存失败: $error',
      );
      return false;
    }
  }
}
