import '../../domain/entities/workout_models.dart';
import '../../utils/app_error.dart';
import '../../utils/app_logger.dart';
import '../repositories/workout_repository.dart';

class WorkoutService {
  const WorkoutService(this._repository);

  final WorkoutRepository _repository;

  Future<HomeSnapshot> getHomeSnapshot(DateTime date) async {
    try {
      return await _repository.getHomeSnapshot(date);
    } catch (error, stackTrace) {
      AppLogger.error('加载首页数据失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '加载首页数据失败，请稍后重试。');
    }
  }

  Future<List<WorkoutSession>> getSessionsByMonth(DateTime month) async {
    try {
      return await _repository.getSessionsByMonth(month);
    } catch (error, stackTrace) {
      AppLogger.error('加载日历数据失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '加载日历数据失败，请稍后重试。');
    }
  }

  Future<AnalyticsSnapshot> getAnalyticsSnapshot({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      return await _repository.getAnalyticsSnapshot(from: from, to: to);
    } catch (error, stackTrace) {
      AppLogger.error('加载统计数据失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '加载统计数据失败，请稍后重试。');
    }
  }

  Future<WorkoutSession> startOrGetSession(
    DateTime date, {
    required SessionMode mode,
    String? sessionId,
    bool preferActiveSession = false,
  }) async {
    try {
      return await _repository.startOrGetSession(
        date,
        mode: mode,
        sessionId: sessionId,
        preferActiveSession: preferActiveSession,
      );
    } catch (error, stackTrace) {
      AppLogger.error('加载训练会话失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '加载训练会话失败，请稍后重试。');
    }
  }

  Future<WorkoutSession> saveSession(WorkoutSession session) async {
    try {
      return await _repository.saveSession(session);
    } catch (error, stackTrace) {
      AppLogger.error('保存训练记录失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '保存训练记录失败，请稍后重试。');
    }
  }
}
