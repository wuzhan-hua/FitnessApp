import 'package:fitness_client/data/repositories/mock_workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockWorkoutRepository aggregation', () {
    test('home snapshot and analytics are internally consistent', () async {
      final repo = MockWorkoutRepository();
      final home = await repo.getHomeSnapshot(DateTime.now());
      final analytics = await repo.getAnalyticsSnapshot(
        from: DateTime.now().subtract(const Duration(days: 30)),
        to: DateTime.now(),
      );

      expect(home.weekTrainingDays, greaterThanOrEqualTo(0));
      expect(home.weekTotalSets, greaterThanOrEqualTo(0));
      expect(home.recentSessions.length, lessThanOrEqualTo(2));
      expect(analytics.weeklyVolume.length, 7);
      expect(analytics.monthlyVolume.length, 4);
    });
  });
}
