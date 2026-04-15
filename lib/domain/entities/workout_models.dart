import 'package:flutter/foundation.dart';

enum SessionStatus { draft, inProgress, completed }

enum SessionMode { newSession, continueSession, backfill }

enum ExerciseSetType { strength, cardio }

extension ExerciseSetTypeX on ExerciseSetType {
  String get value {
    switch (this) {
      case ExerciseSetType.strength:
        return 'strength';
      case ExerciseSetType.cardio:
        return 'cardio';
    }
  }

  static ExerciseSetType from(String? raw) {
    switch (raw) {
      case 'cardio':
        return ExerciseSetType.cardio;
      case 'strength':
      default:
        return ExerciseSetType.strength;
    }
  }
}

extension SessionStatusX on SessionStatus {
  String get value {
    switch (this) {
      case SessionStatus.draft:
        return 'draft';
      case SessionStatus.inProgress:
        return 'in_progress';
      case SessionStatus.completed:
        return 'completed';
    }
  }

  static SessionStatus from(String raw) {
    switch (raw) {
      case 'draft':
        return SessionStatus.draft;
      case 'in_progress':
        return SessionStatus.inProgress;
      case 'completed':
        return SessionStatus.completed;
      default:
        return SessionStatus.draft;
    }
  }
}

@immutable
class ExerciseCatalogItem {
  const ExerciseCatalogItem({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
  });

  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;

  factory ExerciseCatalogItem.fromJson(Map<String, dynamic> json) {
    return ExerciseCatalogItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      muscleGroup: json['muscleGroup'] as String? ?? '',
      equipment: json['equipment'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'muscleGroup': muscleGroup,
      'equipment': equipment,
    };
  }
}

@immutable
class ExerciseSet {
  const ExerciseSet({
    required this.index,
    required this.weight,
    required this.reps,
    required this.restSeconds,
    required this.isCompleted,
    this.setType = ExerciseSetType.strength,
    this.durationMinutes,
    this.distanceKm,
  });

  final int index;
  final double weight;
  final int reps;
  final int restSeconds;
  final bool isCompleted;
  final ExerciseSetType setType;
  final int? durationMinutes;
  final double? distanceKm;

  double get volume => setType == ExerciseSetType.cardio ? 0 : weight * reps;

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    final parsedSetType = ExerciseSetTypeX.from(json['setType'] as String?);
    final inferredSetType =
        json['setType'] == null &&
            (json['durationMinutes'] != null || json['distanceKm'] != null)
        ? ExerciseSetType.cardio
        : parsedSetType;
    return ExerciseSet(
      index: (json['index'] as num? ?? 0).toInt(),
      weight: (json['weight'] as num? ?? 0).toDouble(),
      reps: (json['reps'] as num? ?? 0).toInt(),
      restSeconds: (json['restSeconds'] as num? ?? 0).toInt(),
      isCompleted: json['isCompleted'] as bool? ?? false,
      setType: inferredSetType,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'weight': weight,
      'reps': reps,
      'restSeconds': restSeconds,
      'isCompleted': isCompleted,
      'setType': setType.value,
      'durationMinutes': durationMinutes,
      'distanceKm': distanceKm,
    };
  }

  ExerciseSet copyWith({
    int? index,
    double? weight,
    int? reps,
    int? restSeconds,
    bool? isCompleted,
    ExerciseSetType? setType,
    int? durationMinutes,
    bool clearDurationMinutes = false,
    double? distanceKm,
    bool clearDistanceKm = false,
  }) {
    return ExerciseSet(
      index: index ?? this.index,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      restSeconds: restSeconds ?? this.restSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
      setType: setType ?? this.setType,
      durationMinutes: clearDurationMinutes
          ? null
          : (durationMinutes ?? this.durationMinutes),
      distanceKm: clearDistanceKm ? null : (distanceKm ?? this.distanceKm),
    );
  }
}

@immutable
class SessionExercise {
  const SessionExercise({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.targetSets,
    required this.order,
    required this.sets,
  });

  final String id;
  final String exerciseId;
  final String exerciseName;
  final int targetSets;
  final int order;
  final List<ExerciseSet> sets;

  int get completedSetCount => sets.where((set) => set.isCompleted).length;

  double get totalVolume => sets.fold(0, (sum, set) => sum + set.volume);

  factory SessionExercise.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] as List<dynamic>? ?? const [];
    return SessionExercise(
      id: json['id'] as String? ?? '',
      exerciseId: json['exerciseId'] as String? ?? '',
      exerciseName: json['exerciseName'] as String? ?? '',
      targetSets: (json['targetSets'] as num? ?? 0).toInt(),
      order: (json['order'] as num? ?? 0).toInt(),
      sets: rawSets
          .map((item) => ExerciseSet.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'targetSets': targetSets,
      'order': order,
      'sets': sets.map((item) => item.toJson()).toList(),
    };
  }

  SessionExercise copyWith({
    String? id,
    String? exerciseId,
    String? exerciseName,
    int? targetSets,
    int? order,
    List<ExerciseSet>? sets,
  }) {
    return SessionExercise(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      targetSets: targetSets ?? this.targetSets,
      order: order ?? this.order,
      sets: sets ?? this.sets,
    );
  }
}

@immutable
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.date,
    required this.title,
    required this.status,
    required this.durationMinutes,
    required this.exercises,
    this.notes,
  });

  final String id;
  final DateTime date;
  final String title;
  final SessionStatus status;
  final int durationMinutes;
  final List<SessionExercise> exercises;
  final String? notes;

  int get totalSets =>
      exercises.fold(0, (sum, exercise) => sum + exercise.sets.length);

  int get completedSets =>
      exercises.fold(0, (sum, exercise) => sum + exercise.completedSetCount);

  double get totalVolume =>
      exercises.fold(0, (sum, exercise) => sum + exercise.totalVolume);

  double get maxWeight => exercises
      .expand((exercise) => exercise.sets)
      .map((set) => set.weight)
      .fold(0.0, (previous, next) => previous > next ? previous : next);

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final rawExercises = json['exercises'] as List<dynamic>? ?? const [];
    return WorkoutSession(
      id: json['id'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      title: json['title'] as String? ?? '',
      status: SessionStatusX.from(json['status'] as String? ?? ''),
      durationMinutes: (json['durationMinutes'] as num? ?? 0).toInt(),
      exercises: rawExercises
          .map((item) => SessionExercise.fromJson(item as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'status': status.value,
      'durationMinutes': durationMinutes,
      'exercises': exercises.map((item) => item.toJson()).toList(),
      'notes': notes,
    };
  }

  WorkoutSession copyWith({
    String? id,
    DateTime? date,
    String? title,
    SessionStatus? status,
    int? durationMinutes,
    List<SessionExercise>? exercises,
    String? notes,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      status: status ?? this.status,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      exercises: exercises ?? this.exercises,
      notes: notes ?? this.notes,
    );
  }
}

@immutable
class DailySummary {
  const DailySummary({
    required this.date,
    required this.hasTraining,
    required this.totalSets,
    required this.totalVolume,
    required this.durationMinutes,
  });

  final DateTime date;
  final bool hasTraining;
  final int totalSets;
  final double totalVolume;
  final int durationMinutes;

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      hasTraining: json['hasTraining'] as bool? ?? false,
      totalSets: (json['totalSets'] as num? ?? 0).toInt(),
      totalVolume: (json['totalVolume'] as num? ?? 0).toDouble(),
      durationMinutes: (json['durationMinutes'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'hasTraining': hasTraining,
      'totalSets': totalSets,
      'totalVolume': totalVolume,
      'durationMinutes': durationMinutes,
    };
  }
}

@immutable
class HomeSnapshot {
  const HomeSnapshot({
    required this.date,
    required this.todaySummary,
    required this.inProgressSession,
    required this.quickSuggestions,
    required this.weekTrainingDays,
    required this.weekTotalSets,
    required this.weekTotalVolume,
    required this.weekAverageDuration,
    required this.recentSessions,
    required this.recoveryHint,
  });

  final DateTime date;
  final DailySummary todaySummary;
  final WorkoutSession? inProgressSession;
  final List<String> quickSuggestions;
  final int weekTrainingDays;
  final int weekTotalSets;
  final double weekTotalVolume;
  final int weekAverageDuration;
  final List<WorkoutSession> recentSessions;
  final String recoveryHint;

  factory HomeSnapshot.fromJson(Map<String, dynamic> json) {
    final rawSessions = json['recentSessions'] as List<dynamic>? ?? const [];
    return HomeSnapshot(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      todaySummary: DailySummary.fromJson(
        json['todaySummary'] as Map<String, dynamic>? ?? const {},
      ),
      inProgressSession:
          (json['inProgressSession'] as Map<String, dynamic>?) == null
          ? null
          : WorkoutSession.fromJson(
              json['inProgressSession'] as Map<String, dynamic>,
            ),
      quickSuggestions: (json['quickSuggestions'] as List<dynamic>? ?? const [])
          .map((item) => '$item')
          .toList(),
      weekTrainingDays: (json['weekTrainingDays'] as num? ?? 0).toInt(),
      weekTotalSets: (json['weekTotalSets'] as num? ?? 0).toInt(),
      weekTotalVolume: (json['weekTotalVolume'] as num? ?? 0).toDouble(),
      weekAverageDuration: (json['weekAverageDuration'] as num? ?? 0).toInt(),
      recentSessions: rawSessions
          .map((item) => WorkoutSession.fromJson(item as Map<String, dynamic>))
          .toList(),
      recoveryHint: json['recoveryHint'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'todaySummary': todaySummary.toJson(),
      'inProgressSession': inProgressSession?.toJson(),
      'quickSuggestions': quickSuggestions,
      'weekTrainingDays': weekTrainingDays,
      'weekTotalSets': weekTotalSets,
      'weekTotalVolume': weekTotalVolume,
      'weekAverageDuration': weekAverageDuration,
      'recentSessions': recentSessions.map((item) => item.toJson()).toList(),
      'recoveryHint': recoveryHint,
    };
  }
}

@immutable
class TimeSeriesPoint {
  const TimeSeriesPoint({required this.label, required this.value});

  final String label;
  final double value;

  factory TimeSeriesPoint.fromJson(Map<String, dynamic> json) {
    return TimeSeriesPoint(
      label: json['label'] as String? ?? '',
      value: (json['value'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'label': label, 'value': value};
  }
}

@immutable
class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.weeklyVolume,
    required this.monthlyVolume,
    required this.prTrend,
    required this.trainingFrequency,
  });

  final List<TimeSeriesPoint> weeklyVolume;
  final List<TimeSeriesPoint> monthlyVolume;
  final List<TimeSeriesPoint> prTrend;
  final int trainingFrequency;

  factory AnalyticsSnapshot.fromJson(Map<String, dynamic> json) {
    final weekly = json['weeklyVolume'] as List<dynamic>? ?? const [];
    final monthly = json['monthlyVolume'] as List<dynamic>? ?? const [];
    final pr = json['prTrend'] as List<dynamic>? ?? const [];

    return AnalyticsSnapshot(
      weeklyVolume: weekly
          .map((item) => TimeSeriesPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      monthlyVolume: monthly
          .map((item) => TimeSeriesPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      prTrend: pr
          .map((item) => TimeSeriesPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      trainingFrequency: (json['trainingFrequency'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weeklyVolume': weeklyVolume.map((item) => item.toJson()).toList(),
      'monthlyVolume': monthlyVolume.map((item) => item.toJson()).toList(),
      'prTrend': prTrend.map((item) => item.toJson()).toList(),
      'trainingFrequency': trainingFrequency,
    };
  }
}
