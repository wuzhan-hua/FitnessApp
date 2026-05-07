import 'package:flutter/foundation.dart';

/// 训练会话状态。
enum SessionStatus { draft, inProgress, completed }

/// 训练会话创建模式。
enum SessionMode { newSession, continueSession, backfill }

/// 训练组类型（力量/有氧）。
enum ExerciseSetType { strength, cardio }

/// 训练组类型与字符串值的映射扩展。
extension ExerciseSetTypeX on ExerciseSetType {
  String get value {
    switch (this) {
      case ExerciseSetType.strength:
        return 'strength';
      case ExerciseSetType.cardio:
        return 'cardio';
    }
  }

  /// 从持久化字符串恢复训练组类型，未知值默认返回力量组。
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

/// 会话状态与字符串值的映射扩展。
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

  /// 从持久化字符串恢复会话状态，未知值默认返回草稿态。
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
/// 动作目录项实体，用于选择训练动作基础信息。
class ExerciseCatalogItem {
  const ExerciseCatalogItem({
    required this.id,
    required this.nameEn,
    this.nameZh,
    this.customNameZh,
    required this.primaryMusclesEn,
    this.primaryMusclesZh = const [],
    this.secondaryMusclesEn = const [],
    this.secondaryMusclesZh = const [],
    this.equipmentEn,
    this.equipmentZh,
    this.categoryEn,
    this.categoryZh,
    this.instructionsEn = const [],
    this.instructionsZh = const [],
    this.coverImagePath,
    this.coverImageUrl,
    this.imageUrls = const [],
  });

  /// 动作唯一标识。
  final String id;

  /// 动作英文名称。
  final String nameEn;

  /// 动作中文名称。
  final String? nameZh;

  /// 管理员自定义中文展示名。
  final String? customNameZh;

  /// 主要目标肌群（英文）。
  final List<String> primaryMusclesEn;

  /// 主要目标肌群（中文）。
  final List<String> primaryMusclesZh;

  /// 次要目标肌群（英文）。
  final List<String> secondaryMusclesEn;

  /// 次要目标肌群（中文）。
  final List<String> secondaryMusclesZh;

  /// 所需器械（英文）。
  final String? equipmentEn;

  /// 所需器械（中文）。
  final String? equipmentZh;

  /// 动作分类（英文）。
  final String? categoryEn;

  /// 动作分类（中文）。
  final String? categoryZh;

  /// 动作说明（英文）。
  final List<String> instructionsEn;

  /// 动作说明（中文）。
  final List<String> instructionsZh;

  /// 列表封面图存储路径。
  final String? coverImagePath;

  /// 列表缩略图地址。
  final String? coverImageUrl;

  /// 动作参考图地址列表。
  final List<String> imageUrls;

  /// 兼容旧代码的展示名称优先级：管理员自定义中文 > 中文 > 英文。
  String get displayName {
    final custom = customNameZh?.trim();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    final zh = nameZh?.trim();
    if (zh != null && zh.isNotEmpty) {
      return zh;
    }
    return nameEn;
  }

  /// 兼容旧代码的展示名称优先级：管理员自定义中文 > 中文 > 英文。
  String get name => displayName;

  /// 兼容旧代码的主要肌群展示值。
  String get muscleGroup {
    final muscles = primaryMusclesZh.isNotEmpty
        ? primaryMusclesZh
        : primaryMusclesEn;
    return muscles.isEmpty ? '' : muscles.first;
  }

  /// 兼容旧代码的器械展示值。
  String get equipment {
    if (equipmentZh != null && equipmentZh!.trim().isNotEmpty) {
      return equipmentZh!;
    }
    return equipmentEn ?? '';
  }

  /// 是否属于默认负重应归零的徒手/拉伸动作。
  bool get defaultsToZeroWeight {
    final normalizedEquipmentEn = equipmentEn?.trim().toLowerCase();
    final normalizedEquipmentZh = equipmentZh?.trim();
    final normalizedCategoryEn = categoryEn?.trim().toLowerCase();
    final normalizedCategoryZh = categoryZh?.trim();
    return normalizedEquipmentEn == 'body only' ||
        normalizedEquipmentZh == '徒手' ||
        normalizedCategoryEn == 'stretching' ||
        normalizedCategoryZh == '拉伸';
  }

  /// 是否属于有氧动作。
  bool get isCardio {
    final normalizedCategoryEn = categoryEn?.trim().toLowerCase();
    final normalizedCategoryZh = categoryZh?.trim();
    return normalizedCategoryEn == 'cardio' || normalizedCategoryZh == '有氧';
  }

  static List<String> _readStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// 从 JSON 构建动作目录项，缺失字段使用空字符串兜底。
  factory ExerciseCatalogItem.fromJson(Map<String, dynamic> json) {
    final fallbackMuscle = json['muscleGroup']?.toString().trim();
    return ExerciseCatalogItem(
      id: json['id'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? json['name'] as String? ?? '',
      nameZh: json['name_zh'] as String?,
      customNameZh: json['custom_name_zh'] as String?,
      primaryMusclesEn: _readStringList(json['primary_muscles_en']).isNotEmpty
          ? _readStringList(json['primary_muscles_en'])
          : (fallbackMuscle == null || fallbackMuscle.isEmpty
                ? const []
                : [fallbackMuscle]),
      primaryMusclesZh: _readStringList(json['primary_muscles_zh']),
      secondaryMusclesEn: _readStringList(json['secondary_muscles_en']),
      secondaryMusclesZh: _readStringList(json['secondary_muscles_zh']),
      equipmentEn:
          json['equipment_en'] as String? ?? json['equipment'] as String?,
      equipmentZh: json['equipment_zh'] as String?,
      categoryEn: json['category_en'] as String?,
      categoryZh: json['category_zh'] as String?,
      instructionsEn: _readStringList(json['instructions_en']),
      instructionsZh: _readStringList(json['instructions_zh']),
      coverImagePath: json['cover_image_path'] as String?,
      coverImageUrl:
          json['cover_image_url'] as String? ??
          json['cover_image_path'] as String?,
      imageUrls: _readStringList(json['image_urls']).isNotEmpty
          ? _readStringList(json['image_urls'])
          : _readStringList(json['image_paths']),
    );
  }

  /// 序列化为 JSON，保持与数据层约定键名一致。
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_en': nameEn,
      'name_zh': nameZh,
      'custom_name_zh': customNameZh,
      'primary_muscles_en': primaryMusclesEn,
      'primary_muscles_zh': primaryMusclesZh,
      'secondary_muscles_en': secondaryMusclesEn,
      'secondary_muscles_zh': secondaryMusclesZh,
      'equipment_en': equipmentEn,
      'equipment_zh': equipmentZh,
      'category_en': categoryEn,
      'category_zh': categoryZh,
      'instructions_en': instructionsEn,
      'instructions_zh': instructionsZh,
      'cover_image_path': coverImagePath,
      'cover_image_url': coverImageUrl,
      'image_urls': imageUrls,
      'name': name,
      'muscleGroup': muscleGroup,
      'equipment': equipment,
    };
  }
}

@immutable
/// 管理后台动作目录项实体，包含可编辑展示名和排序信息。
class AdminExerciseCatalogItem {
  const AdminExerciseCatalogItem({
    required this.exerciseId,
    required this.displayName,
    this.originalNameZh,
    required this.nameEn,
    required this.muscleGroup,
    required this.sortOrder,
    this.customNameZh,
    this.coverImagePath,
    this.coverImageUrl,
  });

  final String exerciseId;
  final String displayName;
  final String? originalNameZh;
  final String nameEn;
  final String muscleGroup;
  final int sortOrder;
  final String? customNameZh;
  final String? coverImagePath;
  final String? coverImageUrl;

  AdminExerciseCatalogItem copyWith({
    String? exerciseId,
    String? displayName,
    String? originalNameZh,
    String? nameEn,
    String? muscleGroup,
    int? sortOrder,
    String? customNameZh,
    String? coverImagePath,
    String? coverImageUrl,
    bool clearOriginalNameZh = false,
    bool clearCustomNameZh = false,
  }) {
    return AdminExerciseCatalogItem(
      exerciseId: exerciseId ?? this.exerciseId,
      displayName: displayName ?? this.displayName,
      originalNameZh: clearOriginalNameZh
          ? null
          : (originalNameZh ?? this.originalNameZh),
      nameEn: nameEn ?? this.nameEn,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      sortOrder: sortOrder ?? this.sortOrder,
      customNameZh: clearCustomNameZh
          ? null
          : (customNameZh ?? this.customNameZh),
      coverImagePath: coverImagePath ?? this.coverImagePath,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    );
  }
}

@immutable
/// 单组训练数据实体，兼容力量与有氧两种记录方式。
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

  /// 当前组序号（从 0 或 1 开始由上层决定）。
  final int index;

  /// 重量（kg），有氧组通常为 0。
  final double weight;

  /// 次数，有氧组可为 0。
  final int reps;

  /// 组间休息时长（秒）。
  final int restSeconds;

  /// 当前组是否已完成。
  final bool isCompleted;

  /// 训练组类型（力量/有氧）。
  final ExerciseSetType setType;

  /// 有氧时长（分钟），力量组通常为空。
  final int? durationMinutes;

  /// 有氧距离（公里），力量组通常为空。
  final double? distanceKm;

  /// 训练容量（力量组=重量*次数；有氧组固定为 0）。
  double get volume => setType == ExerciseSetType.cardio ? 0 : weight * reps;

  /// 从 JSON 构建训练组，兼容旧数据并在必要时推断有氧类型。
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

  /// 序列化为 JSON，保留可选字段以支持完整回写。
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
/// 会话中的单个训练动作，包含目标组数与实际组列表。
class SessionExercise {
  const SessionExercise({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.targetSets,
    required this.order,
    required this.sets,
  });

  /// 会话内动作记录唯一标识。
  final String id;

  /// 对应动作目录 ID。
  final String exerciseId;

  /// 动作展示名称。
  final String exerciseName;

  /// 目标组数。
  final int targetSets;

  /// 在会话中的排序序号。
  final int order;

  /// 当前动作下的训练组明细。
  final List<ExerciseSet> sets;

  /// 已完成训练组数量。
  int get completedSetCount => sets.where((set) => set.isCompleted).length;

  /// 当前动作总训练容量（仅累计力量组容量）。
  double get totalVolume => sets.fold(0, (sum, set) => sum + set.volume);

  /// 从 JSON 构建会话动作，缺失组数据时返回空列表。
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

  /// 序列化为 JSON，包含动作基础信息与组明细。
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
/// 单次训练会话实体，聚合当天训练动作与统计信息。
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

  /// 会话唯一标识。
  final String id;

  /// 会话日期时间。
  final DateTime date;

  /// 会话标题。
  final String title;

  /// 会话状态。
  final SessionStatus status;

  /// 会话总时长（分钟）。
  final int durationMinutes;

  /// 会话中的动作列表。
  final List<SessionExercise> exercises;

  /// 可选备注。
  final String? notes;

  /// 会话总组数。
  int get totalSets =>
      exercises.fold(0, (sum, exercise) => sum + exercise.sets.length);

  /// 会话已完成组数。
  int get completedSets =>
      exercises.fold(0, (sum, exercise) => sum + exercise.completedSetCount);

  /// 会话总训练容量（仅累计力量组容量）。
  double get totalVolume =>
      exercises.fold(0, (sum, exercise) => sum + exercise.totalVolume);

  /// 会话最大重量（无数据时为 0）。
  double get maxWeight => exercises
      .expand((exercise) => exercise.sets)
      .map((set) => set.weight)
      .fold(0.0, (previous, next) => previous > next ? previous : next);

  /// 从 JSON 构建训练会话，异常或缺失日期时回退为当前时间。
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

  /// 序列化为 JSON，日期使用 ISO8601 字符串。
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
/// 日维度训练摘要，用于首页与日历概览展示。
class DailySummary {
  const DailySummary({
    required this.date,
    required this.hasTraining,
    required this.totalSets,
    required this.totalVolume,
    required this.durationMinutes,
  });

  /// 摘要对应日期。
  final DateTime date;

  /// 当日是否有训练。
  final bool hasTraining;

  /// 当日总组数。
  final int totalSets;

  /// 当日总容量（仅力量组）。
  final double totalVolume;

  /// 当日总时长（分钟）。
  final int durationMinutes;

  /// 从 JSON 构建日摘要，缺失字段使用默认值兜底。
  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      hasTraining: json['hasTraining'] as bool? ?? false,
      totalSets: (json['totalSets'] as num? ?? 0).toInt(),
      totalVolume: (json['totalVolume'] as num? ?? 0).toDouble(),
      durationMinutes: (json['durationMinutes'] as num? ?? 0).toInt(),
    );
  }

  /// 序列化为 JSON，日期使用 ISO8601 字符串。
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

/// 首页推荐卡片类型。
enum HomeRecommendationType { recovery, trainingFocus, continueSession, review }

@immutable
/// 首页推荐项，用于今日计划与建议展示。
class HomeRecommendationItem {
  const HomeRecommendationItem({
    required this.title,
    required this.message,
    required this.type,
    this.priority = 0,
  });

  final String title;
  final String message;
  final HomeRecommendationType type;
  final int priority;

  factory HomeRecommendationItem.fromJson(Map<String, dynamic> json) {
    return HomeRecommendationItem(
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: HomeRecommendationType.values.firstWhere(
        (item) => item.name == json['type'],
        orElse: () => HomeRecommendationType.trainingFocus,
      ),
      priority: (json['priority'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'message': message,
      'type': type.name,
      'priority': priority,
    };
  }
}

@immutable
/// 首页快照数据，聚合今日状态、周统计与近期训练信息。
class HomeSnapshot {
  const HomeSnapshot({
    required this.date,
    required this.todaySummary,
    required this.todaySession,
    required this.inProgressSession,
    required this.recommendations,
    required this.quickSuggestions,
    required this.weekTrainingDays,
    required this.weekTotalSets,
    required this.weekTotalVolume,
    required this.weekAverageDuration,
    required this.recentSessions,
    required this.recoveryHint,
  });

  /// 快照生成日期时间。
  final DateTime date;

  /// 今日训练摘要。
  final DailySummary todaySummary;

  /// 当天训练会话（若存在）。
  final WorkoutSession? todaySession;

  /// 当前进行中的训练会话（若存在）。
  final WorkoutSession? inProgressSession;

  /// 首页推荐卡片列表。
  final List<HomeRecommendationItem> recommendations;

  /// 首页快捷建议文案列表。
  final List<String> quickSuggestions;

  /// 本周训练天数。
  final int weekTrainingDays;

  /// 本周总组数。
  final int weekTotalSets;

  /// 本周总容量（仅力量组）。
  final double weekTotalVolume;

  /// 本周平均时长（分钟）。
  final int weekAverageDuration;

  /// 近期训练会话列表。
  final List<WorkoutSession> recentSessions;

  /// 恢复建议文案。
  final String recoveryHint;

  /// 从 JSON 构建首页快照，缺失嵌套对象时使用默认空对象/空列表。
  factory HomeSnapshot.fromJson(Map<String, dynamic> json) {
    final rawSessions = json['recentSessions'] as List<dynamic>? ?? const [];
    final rawRecommendations =
        json['recommendations'] as List<dynamic>? ?? const [];
    return HomeSnapshot(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      todaySummary: DailySummary.fromJson(
        json['todaySummary'] as Map<String, dynamic>? ?? const {},
      ),
      todaySession: (json['todaySession'] as Map<String, dynamic>?) == null
          ? null
          : WorkoutSession.fromJson(
              json['todaySession'] as Map<String, dynamic>,
            ),
      inProgressSession:
          (json['inProgressSession'] as Map<String, dynamic>?) == null
          ? null
          : WorkoutSession.fromJson(
              json['inProgressSession'] as Map<String, dynamic>,
            ),
      recommendations: rawRecommendations
          .map(
            (item) =>
                HomeRecommendationItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
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

  /// 序列化为 JSON，保持首页所需字段结构不变。
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'todaySummary': todaySummary.toJson(),
      'todaySession': todaySession?.toJson(),
      'inProgressSession': inProgressSession?.toJson(),
      'recommendations': recommendations.map((item) => item.toJson()).toList(),
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
/// 时序图表数据点。
class TimeSeriesPoint {
  const TimeSeriesPoint({required this.label, required this.value});

  /// 横轴标签（如日期、周次）。
  final String label;

  /// 对应数值。
  final double value;

  /// 从 JSON 构建时序点，缺失字段使用默认值。
  factory TimeSeriesPoint.fromJson(Map<String, dynamic> json) {
    return TimeSeriesPoint(
      label: json['label'] as String? ?? '',
      value: (json['value'] as num? ?? 0).toDouble(),
    );
  }

  /// 序列化为 JSON，输出 label/value 键对。
  Map<String, dynamic> toJson() {
    return {'label': label, 'value': value};
  }
}

@immutable
/// 训练分析快照，提供周/月容量、PR 趋势与训练频率。
class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.weeklyVolume,
    required this.monthlyVolume,
    required this.prTrend,
    required this.trainingFrequency,
  });

  /// 周维度容量时序。
  final List<TimeSeriesPoint> weeklyVolume;

  /// 月维度容量时序。
  final List<TimeSeriesPoint> monthlyVolume;

  /// PR 趋势时序。
  final List<TimeSeriesPoint> prTrend;

  /// 训练频率（如每周次数）。
  final int trainingFrequency;

  /// 从 JSON 构建分析快照，缺失序列时回退为空列表。
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

  /// 序列化为 JSON，输出各统计序列与频率字段。
  Map<String, dynamic> toJson() {
    return {
      'weeklyVolume': weeklyVolume.map((item) => item.toJson()).toList(),
      'monthlyVolume': monthlyVolume.map((item) => item.toJson()).toList(),
      'prTrend': prTrend.map((item) => item.toJson()).toList(),
      'trainingFrequency': trainingFrequency,
    };
  }
}
