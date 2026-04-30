import 'dart:math';

import '../../domain/entities/workout_models.dart';
import 'workout_repository.dart';

class MockWorkoutRepository implements WorkoutRepository {
  MockWorkoutRepository() {
    _seedData();
  }

  final List<WorkoutSession> _sessions = [];

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
      totalSets: session.totalSets,
      totalVolume: session.totalVolume,
      durationMinutes: session.durationMinutes,
    );
  }

  WorkoutSession _defaultSession(DateTime date) {
    return WorkoutSession(
      id: 'session-${date.millisecondsSinceEpoch}',
      date: date,
      title: '推训练日',
      status: SessionStatus.draft,
      durationMinutes: 30,
      exercises: const [
        SessionExercise(
          id: 'sq-1',
          exerciseId: 'bench-press',
          exerciseName: '杠铃卧推',
          targetSets: 4,
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
          id: 'sq-2',
          exerciseId: 'incline-dumbbell-press',
          exerciseName: '上斜哑铃卧推',
          targetSets: 3,
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
      ],
      notes: '保持肩胛稳定，最后一组可接近力竭。',
    );
  }

  @override
  Future<AnalyticsSnapshot> getAnalyticsSnapshot({
    required DateTime from,
    required DateTime to,
  }) async {
    final normalizedFrom = _day(from);
    final normalizedTo = _day(to);
    final scope = _sessions
        .where(
          (session) =>
              !_day(session.date).isBefore(normalizedFrom) &&
              !_day(session.date).isAfter(normalizedTo) &&
              session.status == SessionStatus.completed,
        )
        .toList();

    final weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final now = DateTime.now();
    final thisWeekStart = _day(now).subtract(Duration(days: now.weekday - 1));
    final weeklyVolume = <TimeSeriesPoint>[];

    for (var i = 0; i < 7; i++) {
      final day = thisWeekStart.add(Duration(days: i));
      final volume = scope
          .where((session) => _day(session.date) == day)
          .fold<double>(0, (sum, item) => sum + item.totalVolume);
      weeklyVolume.add(TimeSeriesPoint(label: weekDays[i], value: volume));
    }

    final monthlyVolume = <TimeSeriesPoint>[];
    for (var i = 0; i < 4; i++) {
      final weekStart = _day(now).subtract(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final volume = scope
          .where(
            (session) =>
                !_day(
                  session.date,
                ).isBefore(weekEnd.subtract(const Duration(days: 6))) &&
                !_day(session.date).isAfter(weekEnd),
          )
          .fold<double>(0, (sum, item) => sum + item.totalVolume);
      monthlyVolume.add(TimeSeriesPoint(label: '第${4 - i}周', value: volume));
    }

    final sorted = scope..sort((a, b) => a.date.compareTo(b.date));
    final prTrend = sorted
        .take(max(6, sorted.length))
        .map(
          (session) => TimeSeriesPoint(
            label: '${session.date.month}/${session.date.day}',
            value: session.maxWeight,
          ),
        )
        .toList();

    final trainingFrequency = scope
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

  @override
  Future<HomeSnapshot> getHomeSnapshot(DateTime date) async {
    final today = _day(date);
    final todaySession = _sessions
        .where((session) => _day(session.date) == today)
        .firstOrNull;
    final recent = await getRecentSessions(limit: 2);

    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekItems = _sessions.where((session) {
      final d = _day(session.date);
      return !d.isBefore(weekStart) && !d.isAfter(today);
    });

    final weekCompleted = weekItems
        .where((session) => session.status == SessionStatus.completed)
        .toList();
    final trainingDays = weekCompleted
        .map((item) => _day(item.date))
        .toSet()
        .length;
    final totalSets = weekCompleted.fold<int>(
      0,
      (sum, item) => sum + item.completedSets,
    );
    final totalVolume = weekCompleted.fold<double>(
      0,
      (sum, item) => sum + item.totalVolume,
    );
    final averageDuration = weekCompleted.isEmpty
        ? 0
        : (weekCompleted.fold<int>(
                    0,
                    (sum, item) => sum + item.durationMinutes,
                  ) /
                  weekCompleted.length)
              .round();

    return HomeSnapshot(
      date: date,
      todaySummary: _buildDailySummary(today, todaySession),
      todaySession: todaySession,
      inProgressSession: todaySession?.status == SessionStatus.inProgress
          ? todaySession
          : null,
      quickSuggestions: const [
        '胸推主项已 5 天未做，可安排重组',
        '背部训练密度偏低，建议加 1 个划船动作',
        '今日可尝试工作组 +2.5kg',
      ],
      weekTrainingDays: trainingDays,
      weekTotalSets: totalSets,
      weekTotalVolume: totalVolume,
      weekAverageDuration: averageDuration,
      recentSessions: recent,
      recoveryHint: _buildRecoveryHint(today, recent),
    );
  }

  @override
  Future<WorkoutSession?> getSessionByDate(DateTime date) async {
    final target = _day(date);
    return _sessions
        .where((session) => _day(session.date) == target)
        .firstOrNull;
  }

  @override
  Future<WorkoutSession?> getActiveSessionByDate(DateTime date) async {
    final target = _day(date);
    final candidates = _sessions
        .where(
          (session) =>
              _day(session.date) == target &&
              (session.status == SessionStatus.draft ||
                  session.status == SessionStatus.inProgress),
        )
        .toList();
    return candidates.isEmpty ? null : candidates.last;
  }

  @override
  Future<WorkoutSession?> getSessionById(String id) async {
    return _sessions.where((session) => session.id == id).firstOrNull;
  }

  @override
  Future<List<WorkoutSession>> getSessionsByMonth(DateTime month) async {
    return _sessions
        .where(
          (session) =>
              session.date.year == month.year &&
              session.date.month == month.month,
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<List<WorkoutSession>> getRecentSessions({int limit = 10}) async {
    final copied = [..._sessions]..sort((a, b) => b.date.compareTo(a.date));
    return copied.take(limit).toList();
  }

  @override
  Future<WorkoutSession> saveSession(WorkoutSession session) async {
    final persisted = session.id.startsWith('draft-')
        ? session.copyWith(id: 'session-${DateTime.now().millisecondsSinceEpoch}')
        : session;
    final index = _sessions.indexWhere((item) => item.id == persisted.id);
    if (index == -1) {
      _sessions.add(persisted);
    } else {
      _sessions[index] = persisted;
    }
    return persisted;
  }

  @override
  Future<WorkoutSession> startOrGetSession(
    DateTime date, {
    required SessionMode mode,
    String? sessionId,
    bool preferActiveSession = false,
  }) async {
    if (sessionId != null) {
      final session = await getSessionById(sessionId);
      if (session != null) {
        return session;
      }
    }

    if (preferActiveSession) {
      final active = await getActiveSessionByDate(date);
      if (active != null) {
        return active;
      }
    }

    final existing = await getSessionByDate(date);
    if (existing != null && mode != SessionMode.newSession) {
      return existing;
    }

    final created = mode == SessionMode.newSession
        ? _defaultSession(_day(date)).copyWith(exercises: const [])
        : _defaultSession(_day(date));
    _sessions.add(created);
    return created;
  }

  void _seedData() {
    final now = _day(DateTime.now());

    _sessions
      ..clear()
      ..addAll([
        WorkoutSession(
          id: 'session-ongoing',
          date: now,
          title: '推训练日 · 力量',
          status: SessionStatus.inProgress,
          durationMinutes: 38,
          exercises: const [
            SessionExercise(
              id: 'ex1',
              exerciseId: 'bench-press',
              exerciseName: '杠铃卧推',
              targetSets: 4,
              order: 0,
              sets: [
                ExerciseSet(
                  index: 1,
                  weight: 75,
                  reps: 6,
                  restSeconds: 150,
                  isCompleted: true,
                ),
                ExerciseSet(
                  index: 2,
                  weight: 77.5,
                  reps: 5,
                  restSeconds: 180,
                  isCompleted: true,
                ),
                ExerciseSet(
                  index: 3,
                  weight: 80,
                  reps: 4,
                  restSeconds: 180,
                  isCompleted: false,
                ),
              ],
            ),
            SessionExercise(
              id: 'ex2',
              exerciseId: 'dips',
              exerciseName: '负重双杠臂屈伸',
              targetSets: 3,
              order: 1,
              sets: [
                ExerciseSet(
                  index: 1,
                  weight: 25,
                  reps: 8,
                  restSeconds: 120,
                  isCompleted: false,
                ),
              ],
            ),
          ],
          notes: '第 3 组前休息 3 分钟。',
        ),
        WorkoutSession(
          id: 'session-1',
          date: now.subtract(const Duration(days: 1)),
          title: '下肢增肌',
          status: SessionStatus.completed,
          durationMinutes: 74,
          exercises: const [
            SessionExercise(
              id: 'ex3',
              exerciseId: 'back-squat',
              exerciseName: '深蹲',
              targetSets: 5,
              order: 0,
              sets: [
                ExerciseSet(
                  index: 1,
                  weight: 100,
                  reps: 5,
                  restSeconds: 180,
                  isCompleted: true,
                ),
                ExerciseSet(
                  index: 2,
                  weight: 105,
                  reps: 5,
                  restSeconds: 180,
                  isCompleted: true,
                ),
                ExerciseSet(
                  index: 3,
                  weight: 110,
                  reps: 4,
                  restSeconds: 180,
                  isCompleted: true,
                ),
              ],
            ),
          ],
        ),
        WorkoutSession(
          id: 'session-2',
          date: now.subtract(const Duration(days: 3)),
          title: '拉训练日 · 容量',
          status: SessionStatus.completed,
          durationMinutes: 68,
          exercises: const [
            SessionExercise(
              id: 'ex4',
              exerciseId: 'barbell-row',
              exerciseName: '杠铃划船',
              targetSets: 4,
              order: 0,
              sets: [
                ExerciseSet(
                  index: 1,
                  weight: 70,
                  reps: 8,
                  restSeconds: 120,
                  isCompleted: true,
                ),
                ExerciseSet(
                  index: 2,
                  weight: 72.5,
                  reps: 8,
                  restSeconds: 120,
                  isCompleted: true,
                ),
                ExerciseSet(
                  index: 3,
                  weight: 75,
                  reps: 7,
                  restSeconds: 120,
                  isCompleted: true,
                ),
              ],
            ),
          ],
        ),
        WorkoutSession(
          id: 'session-backfill',
          date: now.subtract(const Duration(days: 9)),
          title: '补录 · 推训练日',
          status: SessionStatus.completed,
          durationMinutes: 61,
          exercises: const [
            SessionExercise(
              id: 'ex5',
              exerciseId: 'overhead-press',
              exerciseName: '站姿推举',
              targetSets: 4,
              order: 0,
              sets: [
                ExerciseSet(
                  index: 1,
                  weight: 45,
                  reps: 8,
                  restSeconds: 120,
                  isCompleted: true,
                ),
                ExerciseSet(
                  index: 2,
                  weight: 47.5,
                  reps: 7,
                  restSeconds: 120,
                  isCompleted: true,
                ),
              ],
            ),
          ],
        ),
      ]);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
