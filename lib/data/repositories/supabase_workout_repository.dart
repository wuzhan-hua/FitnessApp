import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/workout_models.dart';
import '../../utils/app_error.dart';
import 'workout_repository.dart';

class SupabaseWorkoutRepository implements WorkoutRepository {
  SupabaseWorkoutRepository(this._client);

  final SupabaseClient _client;

  bool _profileEnsured = false;
  String? _profileEnsuredForUserId;

  @override
  Future<HomeSnapshot> getHomeSnapshot(DateTime date) async {
    final userId = await _requireUserId();
    await _ensureProfile(userId);

    final today = _day(date);
    final todaySession = await getSessionByDate(today);
    final recentSessions = await getRecentSessions(limit: 2);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEndExclusive = today.add(const Duration(days: 1));

    final weekSessions = await _fetchSessionsDetailed(
      userId: userId,
      fromInclusive: weekStart,
      toExclusive: weekEndExclusive,
      descendingByDate: true,
    );

    final weekCompleted = weekSessions
        .where((session) => session.status == SessionStatus.completed)
        .toList();
    final trainingDays = weekCompleted
        .map((session) => _day(session.date))
        .toSet()
        .length;
    final weekTotalSets = weekCompleted.fold<int>(
      0,
      (sum, session) => sum + session.completedSets,
    );
    final weekTotalVolume = weekCompleted.fold<double>(
      0,
      (sum, session) => sum + session.totalVolume,
    );
    final weekAverageDuration = weekCompleted.isEmpty
        ? 0
        : (weekCompleted.fold<int>(
                    0,
                    (sum, session) => sum + session.durationMinutes,
                  ) /
                  weekCompleted.length)
              .round();

    return HomeSnapshot(
      date: date,
      todaySummary: _buildDailySummary(today, todaySession),
      inProgressSession: todaySession?.status == SessionStatus.inProgress
          ? todaySession
          : null,
      quickSuggestions: const [
        '胸推主项已 5 天未做，可安排重组',
        '背部训练密度偏低，建议加 1 个划船动作',
        '今日可尝试工作组 +2.5kg',
      ],
      weekTrainingDays: trainingDays,
      weekTotalSets: weekTotalSets,
      weekTotalVolume: weekTotalVolume,
      weekAverageDuration: weekAverageDuration,
      recentSessions: recentSessions,
      recoveryHint: _buildRecoveryHint(today, recentSessions),
    );
  }

  @override
  Future<List<WorkoutSession>> getSessionsByMonth(DateTime month) async {
    final userId = await _requireUserId();
    await _ensureProfile(userId);
    final monthStart = DateTime(month.year, month.month, 1);
    final nextMonthStart = DateTime(month.year, month.month + 1, 1);
    return _fetchSessionsDetailed(
      userId: userId,
      fromInclusive: monthStart,
      toExclusive: nextMonthStart,
      descendingByDate: false,
    );
  }

  @override
  Future<List<WorkoutSession>> getRecentSessions({int limit = 10}) async {
    final userId = await _requireUserId();
    await _ensureProfile(userId);
    return _fetchSessionsDetailed(
      userId: userId,
      descendingByDate: true,
      limit: limit,
    );
  }

  @override
  Future<WorkoutSession?> getSessionById(String id) async {
    if (!_isUuid(id)) {
      return null;
    }
    final userId = await _requireUserId();
    await _ensureProfile(userId);
    final sessions = await _fetchSessionsDetailed(
      userId: userId,
      sessionId: id,
      descendingByDate: true,
      limit: 1,
    );
    return sessions.isEmpty ? null : sessions.first;
  }

  @override
  Future<WorkoutSession?> getSessionByDate(DateTime date) async {
    final userId = await _requireUserId();
    await _ensureProfile(userId);
    final dayStart = _day(date);
    final nextDayStart = dayStart.add(const Duration(days: 1));
    final sessions = await _fetchSessionsDetailed(
      userId: userId,
      fromInclusive: dayStart,
      toExclusive: nextDayStart,
      descendingByDate: true,
      limit: 1,
    );
    return sessions.isEmpty ? null : sessions.first;
  }

  @override
  Future<WorkoutSession> startOrGetSession(
    DateTime date, {
    required SessionMode mode,
    String? sessionId,
  }) async {
    final userId = await _requireUserId();
    await _ensureProfile(userId);

    if (sessionId != null && sessionId.isNotEmpty) {
      final byId = await getSessionById(sessionId);
      if (byId != null) {
        return byId;
      }
    }

    final existingByDate = await getSessionByDate(date);
    if (existingByDate != null && mode != SessionMode.newSession) {
      return existingByDate;
    }

    return _createSession(
      userId: userId,
      date: date,
      withTemplate: mode != SessionMode.newSession,
    );
  }

  @override
  Future<void> saveSession(WorkoutSession session) async {
    final userId = await _requireUserId();
    await _ensureProfile(userId);

    final existingSession = _isUuid(session.id)
        ? await _client
              .from('workout_sessions')
              .select('id, status')
              .eq('user_id', userId)
              .eq('id', session.id)
              .maybeSingle()
        : null;

    if (existingSession != null &&
        (existingSession['status'] as String?) == 'completed') {
      throw const AppError(
        message: '该训练已完成归档，不能再次覆盖。',
        code: 'session_locked',
      );
    }

    String persistedSessionId = session.id;

    if (existingSession == null) {
      final insertPayload = {
        'user_id': userId,
        'date': session.date.toIso8601String(),
        'title': session.title,
        'status': session.status.value,
        'duration_minutes': session.durationMinutes,
        'notes': session.notes,
      };

      if (_isUuid(session.id)) {
        insertPayload['id'] = session.id;
      }

      final created =
          await _client
              .from('workout_sessions')
              .insert(insertPayload)
              .select('id')
              .single();
      persistedSessionId = '${created['id']}';
    } else {
      await _client
          .from('workout_sessions')
          .update({
            'date': session.date.toIso8601String(),
            'title': session.title,
            'status': session.status.value,
            'duration_minutes': session.durationMinutes,
            'notes': session.notes,
          })
          .eq('user_id', userId)
          .eq('id', session.id);
      persistedSessionId = session.id;
    }

    await _client
        .from('workout_sets')
        .delete()
        .eq('user_id', userId)
        .eq('session_id', persistedSessionId);
    await _client
        .from('workout_exercises')
        .delete()
        .eq('user_id', userId)
        .eq('session_id', persistedSessionId);

    final insertedExerciseRows = <_InsertedExercise>[];
    final orderedExercises = [...session.exercises]
      ..sort((a, b) => a.order.compareTo(b.order));

    for (final exercise in orderedExercises) {
      final createdExercise =
          await _client
              .from('workout_exercises')
              .insert({
                'user_id': userId,
                'session_id': persistedSessionId,
                'exercise_id': exercise.exerciseId,
                'exercise_name': exercise.exerciseName,
                'target_sets': exercise.targetSets,
                'sort_order': exercise.order,
              })
              .select('id')
              .single();
      final exerciseRowId = '${createdExercise['id']}';

      final setPayloads = exercise.sets
          .map(
            (set) => {
              'user_id': userId,
              'session_id': persistedSessionId,
              'exercise_row_id': exerciseRowId,
              'set_index': set.index,
              'weight': set.weight,
              'reps': set.reps,
              'rest_seconds': set.restSeconds,
              'is_completed': set.isCompleted,
              'set_type': set.setType.value,
              'duration_minutes': set.durationMinutes,
              'distance_km': set.distanceKm,
            },
          )
          .toList();

      if (setPayloads.isNotEmpty) {
        await _client.from('workout_sets').insert(setPayloads);
      }

      insertedExerciseRows.add(
        _InsertedExercise(
          rowId: exerciseRowId,
          exerciseName: exercise.exerciseName,
          sets: exercise.sets,
        ),
      );
    }

    if (session.status == SessionStatus.completed) {
      final existingRecords =
          await _client
              .from('workout_records')
              .select('id')
              .eq('user_id', userId)
              .eq('session_id', persistedSessionId)
              .limit(1);

      final existingRecordRows = List<Map<String, dynamic>>.from(
        existingRecords as List<dynamic>,
      );
      if (existingRecordRows.isEmpty) {
        final recordRows = <Map<String, dynamic>>[];
        for (final exercise in insertedExerciseRows) {
          for (final set in exercise.sets) {
            recordRows.add({
              'user_id': userId,
              'session_id': persistedSessionId,
              'exercise_name': exercise.exerciseName,
              'sets': set.index,
              'reps': set.reps,
              'weight': set.weight,
              'exercise_row_id': exercise.rowId,
            });
          }
        }
        if (recordRows.isNotEmpty) {
          await _client.from('workout_records').insert(recordRows);
        }
      }
    }
  }

  @override
  Future<AnalyticsSnapshot> getAnalyticsSnapshot({
    required DateTime from,
    required DateTime to,
  }) async {
    final userId = await _requireUserId();
    await _ensureProfile(userId);

    final normalizedFrom = _day(from);
    final normalizedTo = _day(to).add(const Duration(days: 1));
    final scope = await _fetchSessionsDetailed(
      userId: userId,
      fromInclusive: normalizedFrom,
      toExclusive: normalizedTo,
      descendingByDate: false,
    );

    final completed = scope
        .where((session) => session.status == SessionStatus.completed)
        .toList();

    final weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final now = DateTime.now();
    final thisWeekStart = _day(now).subtract(Duration(days: now.weekday - 1));
    final weeklyVolume = <TimeSeriesPoint>[];

    for (var i = 0; i < 7; i++) {
      final day = thisWeekStart.add(Duration(days: i));
      final volume = completed
          .where((session) => _day(session.date) == day)
          .fold<double>(0, (sum, session) => sum + session.totalVolume);
      weeklyVolume.add(TimeSeriesPoint(label: weekDays[i], value: volume));
    }

    final monthlyVolume = <TimeSeriesPoint>[];
    for (var i = 0; i < 4; i++) {
      final weekEnd = _day(now).subtract(Duration(days: i * 7));
      final weekStart = weekEnd.subtract(const Duration(days: 6));
      final volume = completed
          .where(
            (session) =>
                !_day(session.date).isBefore(weekStart) &&
                !_day(session.date).isAfter(weekEnd),
          )
          .fold<double>(0, (sum, session) => sum + session.totalVolume);
      monthlyVolume.add(TimeSeriesPoint(label: '第${4 - i}周', value: volume));
    }

    final sorted = [...completed]..sort((a, b) => a.date.compareTo(b.date));
    final prTrend = sorted
        .take(max(6, sorted.length))
        .map(
          (session) => TimeSeriesPoint(
            label: '${session.date.month}/${session.date.day}',
            value: session.maxWeight,
          ),
        )
        .toList();

    final trainingFrequency = completed
        .map((session) => _day(session.date))
        .toSet()
        .length;

    return AnalyticsSnapshot(
      weeklyVolume: weeklyVolume,
      monthlyVolume: monthlyVolume.reversed.toList(),
      prTrend: prTrend,
      trainingFrequency: trainingFrequency,
    );
  }

  Future<WorkoutSession> _createSession({
    required String userId,
    required DateTime date,
    required bool withTemplate,
  }) async {
    final normalizedDate = _day(date);
    final created =
        await _client
            .from('workout_sessions')
            .insert({
              'user_id': userId,
              'date': normalizedDate.toIso8601String(),
              'title': withTemplate ? '推训练日' : '新训练日',
              'status': SessionStatus.draft.value,
              'duration_minutes': 0,
              'notes': withTemplate ? '保持肩胛稳定，最后一组可接近力竭。' : null,
            })
            .select()
            .single();

    final sessionId = '${created['id']}';
    if (!withTemplate) {
      return _mapSessionRow(created, const []);
    }

    final templateExercises = _buildTemplateExercises();
    final persistedExercises = <SessionExercise>[];
    for (final exercise in templateExercises) {
      final exerciseRow =
          await _client
              .from('workout_exercises')
              .insert({
                'user_id': userId,
                'session_id': sessionId,
                'exercise_id': exercise.exerciseId,
                'exercise_name': exercise.exerciseName,
                'target_sets': exercise.targetSets,
                'sort_order': exercise.order,
              })
              .select()
              .single();

      final exerciseRowId = '${exerciseRow['id']}';
      final setRows = exercise.sets
          .map(
            (set) => {
              'user_id': userId,
              'session_id': sessionId,
              'exercise_row_id': exerciseRowId,
              'set_index': set.index,
              'weight': set.weight,
              'reps': set.reps,
              'rest_seconds': set.restSeconds,
              'is_completed': set.isCompleted,
              'set_type': set.setType.value,
              'duration_minutes': set.durationMinutes,
              'distance_km': set.distanceKm,
            },
          )
          .toList();

      List<ExerciseSet> persistedSets = const [];
      if (setRows.isNotEmpty) {
        final insertedSetRows =
            await _client
                .from('workout_sets')
                .insert(setRows)
                .select()
                .order('set_index');
        persistedSets = List<Map<String, dynamic>>.from(
          insertedSetRows as List<dynamic>,
        ).map(_mapSetRow).toList();
      }

      persistedExercises.add(_mapExerciseRow(exerciseRow, persistedSets));
    }

    return _mapSessionRow(created, persistedExercises);
  }

  List<SessionExercise> _buildTemplateExercises() {
    return const [
      SessionExercise(
        id: 'template-1',
        exerciseId: 'bench-press',
        exerciseName: '杠铃卧推',
        targetSets: 2,
        order: 0,
        sets: [
          ExerciseSet(
            index: 1,
            weight: 60,
            reps: 8,
            restSeconds: 120,
            isCompleted: false,
          ),
          ExerciseSet(
            index: 2,
            weight: 65,
            reps: 8,
            restSeconds: 120,
            isCompleted: false,
          ),
        ],
      ),
      SessionExercise(
        id: 'template-2',
        exerciseId: 'incline-dumbbell-press',
        exerciseName: '上斜哑铃卧推',
        targetSets: 1,
        order: 1,
        sets: [
          ExerciseSet(
            index: 1,
            weight: 24,
            reps: 10,
            restSeconds: 90,
            isCompleted: false,
          ),
        ],
      ),
    ];
  }

  Future<List<WorkoutSession>> _fetchSessionsDetailed({
    required String userId,
    DateTime? fromInclusive,
    DateTime? toExclusive,
    int? limit,
    String? sessionId,
    required bool descendingByDate,
  }) async {
    dynamic query = _client
        .from('workout_sessions')
        .select()
        .eq('user_id', userId);

    if (sessionId != null && sessionId.isNotEmpty) {
      query = query.eq('id', sessionId);
    }
    if (fromInclusive != null) {
      query = query.gte('date', fromInclusive.toIso8601String());
    }
    if (toExclusive != null) {
      query = query.lt('date', toExclusive.toIso8601String());
    }
    query = query.order('date', ascending: !descendingByDate);
    if (limit != null) {
      query = query.limit(limit);
    }

    final sessionRowsRaw = await query;
    final sessionRows = List<Map<String, dynamic>>.from(
      sessionRowsRaw as List<dynamic>,
    );
    if (sessionRows.isEmpty) {
      return const [];
    }

    final sessionIds = sessionRows.map((row) => '${row['id']}').toList();
    final exerciseRowsRaw =
        await _client
            .from('workout_exercises')
            .select()
            .eq('user_id', userId)
            .inFilter('session_id', sessionIds)
            .order('sort_order');
    final exerciseRows = List<Map<String, dynamic>>.from(
      exerciseRowsRaw as List<dynamic>,
    );

    List<Map<String, dynamic>> setRows = const [];
    if (exerciseRows.isNotEmpty) {
      final exerciseIds = exerciseRows.map((row) => '${row['id']}').toList();
      final setRowsRaw =
          await _client
              .from('workout_sets')
              .select()
              .eq('user_id', userId)
              .inFilter('exercise_row_id', exerciseIds)
              .order('set_index');
      setRows = List<Map<String, dynamic>>.from(setRowsRaw as List<dynamic>);
    }

    final setsByExerciseId = <String, List<ExerciseSet>>{};
    for (final setRow in setRows) {
      final exerciseId = '${setRow['exercise_row_id']}';
      final mapped = _mapSetRow(setRow);
      setsByExerciseId.putIfAbsent(exerciseId, () => []).add(mapped);
    }

    final exercisesBySessionId = <String, List<SessionExercise>>{};
    for (final exerciseRow in exerciseRows) {
      final exerciseId = '${exerciseRow['id']}';
      final mapped = _mapExerciseRow(
        exerciseRow,
        setsByExerciseId[exerciseId] ?? const [],
      );
      final parentSessionId = '${exerciseRow['session_id']}';
      exercisesBySessionId.putIfAbsent(parentSessionId, () => []).add(mapped);
    }

    return sessionRows
        .map(
          (sessionRow) => _mapSessionRow(
            sessionRow,
            exercisesBySessionId['${sessionRow['id']}'] ?? const [],
          ),
        )
        .toList();
  }

  WorkoutSession _mapSessionRow(
    Map<String, dynamic> row,
    List<SessionExercise> exercises,
  ) {
    return WorkoutSession(
      id: '${row['id']}',
      date: DateTime.tryParse('${row['date']}') ?? DateTime.now(),
      title: row['title'] as String? ?? '',
      status: SessionStatusX.from(row['status'] as String? ?? 'draft'),
      durationMinutes: (row['duration_minutes'] as num? ?? 0).toInt(),
      exercises: exercises,
      notes: row['notes'] as String?,
    );
  }

  SessionExercise _mapExerciseRow(
    Map<String, dynamic> row,
    List<ExerciseSet> sets,
  ) {
    final sortedSets = [...sets]..sort((a, b) => a.index.compareTo(b.index));
    return SessionExercise(
      id: '${row['id']}',
      exerciseId: row['exercise_id'] as String? ?? '',
      exerciseName: row['exercise_name'] as String? ?? '',
      targetSets: (row['target_sets'] as num? ?? 0).toInt(),
      order: (row['sort_order'] as num? ?? 0).toInt(),
      sets: sortedSets,
    );
  }

  ExerciseSet _mapSetRow(Map<String, dynamic> row) {
    return ExerciseSet(
      index: (row['set_index'] as num? ?? 0).toInt(),
      weight: (row['weight'] as num? ?? 0).toDouble(),
      reps: (row['reps'] as num? ?? 0).toInt(),
      restSeconds: (row['rest_seconds'] as num? ?? 0).toInt(),
      isCompleted: row['is_completed'] as bool? ?? false,
      setType: ExerciseSetTypeX.from(row['set_type'] as String?),
      durationMinutes: (row['duration_minutes'] as num?)?.toInt(),
      distanceKm: (row['distance_km'] as num?)?.toDouble(),
    );
  }

  Future<String> _requireUserId() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AppError(message: '未登录，无法访问训练数据。', code: 'auth_required');
    }
    return user.id;
  }

  Future<void> _ensureProfile(String userId) async {
    if (_profileEnsured && _profileEnsuredForUserId == userId) {
      return;
    }
    await _client.from('users').upsert({'user_id': userId}, onConflict: 'user_id');
    _profileEnsured = true;
    _profileEnsuredForUserId = userId;
  }

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  String _buildRecoveryHint(DateTime today, List<WorkoutSession> sessions) {
    if (sessions.isEmpty) {
      return '最近 3 天无训练，建议从中等强度热身开始恢复节奏。';
    }
    final latest = sessions.first;
    final gap = _day(today).difference(_day(latest.date)).inDays;
    final lastGroup = latest.exercises.isEmpty
        ? '全身'
        : latest.exercises.first.exerciseName;
    return '距离上次 $lastGroup 训练已 $gap 天，今天可重点冲击主要工作组。';
  }

  DailySummary _buildDailySummary(DateTime date, WorkoutSession? session) {
    if (session == null) {
      return DailySummary(
        date: date,
        hasTraining: false,
        totalSets: 0,
        totalVolume: 0,
        durationMinutes: 0,
      );
    }
    return DailySummary(
      date: date,
      hasTraining: true,
      totalSets: session.completedSets,
      totalVolume: session.totalVolume,
      durationMinutes: session.durationMinutes,
    );
  }

  bool _isUuid(String value) {
    final regex = RegExp(
      r'^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$',
    );
    return regex.hasMatch(value);
  }
}

class _InsertedExercise {
  const _InsertedExercise({
    required this.rowId,
    required this.exerciseName,
    required this.sets,
  });

  final String rowId;
  final String exerciseName;
  final List<ExerciseSet> sets;
}
