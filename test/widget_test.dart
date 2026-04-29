import 'package:fitness_client/application/providers/providers.dart';
import 'package:fitness_client/application/state/app_settings.dart';
import 'package:fitness_client/application/state/settings_controller.dart';
import 'package:fitness_client/application/state/auth_status.dart';
import 'package:fitness_client/data/services/auth_service.dart';
import 'package:fitness_client/data/services/user_profile_service.dart';
import 'package:fitness_client/data/repositories/mock_workout_repository.dart';
import 'package:fitness_client/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService()
    : super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Session? get currentSession => null;
}

class _FakeUserProfileService extends UserProfileService {
  _FakeUserProfileService()
    : super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
}

class _TestSettingsController extends SettingsController {
  _TestSettingsController()
    : super(_FakeAuthService(), _FakeUserProfileService()) {
    state = AppSettings.defaults;
  }
}

void main() {
  testWidgets('renders 4 tabs and switches to calendar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsController()),
          workoutRepositoryProvider.overrideWithValue(MockWorkoutRepository()),
          currentUserIsAdminProvider.overrideWith((ref) async => false),
          guestSoftSignedOutProvider.overrideWith((ref) async => false),
          authStatusProvider.overrideWith((ref) {
            return Stream.value(AuthStatus.authenticated);
          }),
        ],
        child: const FitnessApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();

    expect(find.textContaining('年'), findsWidgets);
  });

  testWidgets('home page key sections are visible', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsController()),
          workoutRepositoryProvider.overrideWithValue(MockWorkoutRepository()),
          currentUserIsAdminProvider.overrideWith((ref) async => false),
          guestSoftSignedOutProvider.overrideWith((ref) async => false),
          authStatusProvider.overrideWith((ref) {
            return Stream.value(AuthStatus.authenticated);
          }),
        ],
        child: const FitnessApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日状态'), findsOneWidget);
    expect(find.text('主操作区'), findsOneWidget);
    expect(find.text('近7天概览'), findsOneWidget);
  });

  testWidgets('auth page defaults to password login and toggles to sign up', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsController()),
          currentUserIsAdminProvider.overrideWith((ref) async => false),
          guestSoftSignedOutProvider.overrideWith((ref) async => false),
          authStatusProvider.overrideWith((ref) {
            return Stream.value(AuthStatus.signedOut);
          }),
        ],
        child: const FitnessApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('密码登录'), findsAtLeastNWidgets(1));
    expect(find.text('邮箱注册'), findsAtLeastNWidgets(1));
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('注册并自动登录'), findsNothing);
    expect(find.text('邮箱验证码'), findsNothing);

    await tester.tap(find.text('邮箱注册').first);
    await tester.pumpAndSettle();

    expect(find.text('注册并自动登录'), findsOneWidget);
    expect(find.text('邮箱验证码'), findsOneWidget);
  });
}
