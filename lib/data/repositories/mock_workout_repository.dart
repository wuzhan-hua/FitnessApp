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
    final lastFocus = _sessionFocusLabel(latest);
    if (gap <= 0) {
      return '今天已完成 $lastFocus 训练，建议以拉伸、走路和复盘记录为主。';
    }
    if (gap == 1) {
      return '昨天刚完成 $lastFocus 训练，今天尽量避免连续高强度冲击同类动作。';
    }
    if (gap <= 3) {
      return '距离上次 $lastFocus 训练已 $gap 天，今天可以恢复主要工作组强度。';
    }
    return '最近 $gap 天未训练，建议先用中等强度热身把节奏找回来。';
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

  List<HomeRecommendationItem> _buildRecommendations({
    required DateTime today,
    required WorkoutSession? todaySession,
    required List<WorkoutSession> recentSessions,
    required int weekTrainingDays,
  }) {
    final items = <HomeRecommendationItem>[];
    final latest = recentSessions.firstOrNull;
    final latestGap = latest == null
        ? null
        : _day(today).difference(_day(latest.date)).inDays;

    if (todaySession?.status == SessionStatus.inProgress) {
      final totalSets = todaySession?.totalSets ?? 0;
      items.add(
        HomeRecommendationItem(
          title: '继续今日训练',
          message: totalSets > 0
              ? '当前已安排 $totalSets 组，优先补完主要动作，再检查是否需要追加辅助动作。'
              : '今日训练已创建但还没有组数，先补充动作和组数，再开始正式记录。',
          type: HomeRecommendationType.continueSession,
          priority: 3,
        ),
      );
    } else if (todaySession?.status == SessionStatus.completed) {
      items.add(
        HomeRecommendationItem(
          title: '完成后复盘',
          message: '今天的训练已记录完成，建议补充备注、检查动作质量，再决定是否需要微调下次安排。',
          type: HomeRecommendationType.review,
          priority: 3,
        ),
      );
    } else if (latest == null || (latestGap != null && latestGap >= 3)) {
      final gapText = latestGap == null ? '最近几天' : '最近 $latestGap 天';
      items.add(
        HomeRecommendationItem(
          title: '先找回训练节奏',
          message: '$gapText没有完整训练，今天建议先从中等强度和基础动作开始恢复。',
          type: HomeRecommendationType.recovery,
          priority: 3,
        ),
      );
    } else if (latestGap == 1) {
      items.add(
        HomeRecommendationItem(
          title: '安排互补训练',
          message: '昨天刚完成${_sessionFocusLabel(latest)}训练，今天更适合安排互补部位或中等容量训练。',
          type: HomeRecommendationType.trainingFocus,
          priority: 2,
        ),
      );
    } else {
      items.add(
        HomeRecommendationItem(
          title: '推进主要工作组',
          message: '今天适合把重点放在主要工作组，先完成核心动作，再补充辅助训练。',
          type: HomeRecommendationType.trainingFocus,
          priority: 2,
        ),
      );
    }

    if (todaySession?.status != SessionStatus.inProgress &&
        weekTrainingDays <= 1) {
      items.add(
        HomeRecommendationItem(
          title: '补足本周频率',
          message: weekTrainingDays == 0
              ? '本周还没有完成训练，今天完成一次完整训练更容易把节奏拉回来。'
              : '本周目前只完成了 $weekTrainingDays 次训练，还可以补 1 次容量训练。',
          type: HomeRecommendationType.trainingFocus,
          priority: 1,
        ),
      );
    }

    if (todaySession?.status == SessionStatus.completed) {
      items.add(
        HomeRecommendationItem(
          title: '查看今日记录',
          message: '如果还想补充动作或组数，请直接进入今天这条训练记录继续完善。',
          type: HomeRecommendationType.review,
          priority: 2,
        ),
      );
    } else if (todaySession == null) {
      items.add(
        HomeRecommendationItem(
          title: '开始前先定重点',
          message: '先确定今天的主动作和目标组数，再开练会更顺手，也更方便后续复盘。',
          type: HomeRecommendationType.trainingFocus,
          priority: 1,
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        const HomeRecommendationItem(
          title: '保持今天的节奏',
          message: '按计划完成主要动作和核心组数，结束后记得检查是否需要补充备注。',
          type: HomeRecommendationType.trainingFocus,
          priority: 0,
        ),
      );
    }

    items.sort((a, b) => b.priority.compareTo(a.priority));
    return items.take(3).toList();
  }

  String _sessionFocusLabel(WorkoutSession session) {
    if (session.title.trim().isNotEmpty) {
      return session.title.trim();
    }
    if (session.exercises.isNotEmpty) {
      return session.exercises.first.exerciseName;
    }
    return '训练';
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
      (sum, item) => sum + item.totalSets,
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

    final recommendations = _buildRecommendations(
      today: today,
      todaySession: todaySession,
      recentSessions: recent,
      weekTrainingDays: trainingDays,
    );

    return HomeSnapshot(
      date: date,
      todaySummary: _buildDailySummary(today, todaySession),
      todaySession: todaySession,
      inProgressSession: todaySession?.status == SessionStatus.inProgress
          ? todaySession
          : null,
      recommendations: recommendations,
      quickSuggestions: recommendations.map((item) => item.message).toList(),
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
        ? session.copyWith(
            id: 'session-${DateTime.now().millisecondsSinceEpoch}',
          )
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
