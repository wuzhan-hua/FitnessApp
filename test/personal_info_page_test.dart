import 'package:fitness_client/application/providers/providers.dart';
import 'package:fitness_client/application/state/app_settings.dart';
import 'package:fitness_client/application/state/auth_status.dart';
import 'package:fitness_client/application/state/settings_controller.dart';
import 'package:fitness_client/data/services/auth_service.dart';
import 'package:fitness_client/data/services/user_profile_service.dart';
import 'package:fitness_client/presentation/pages/personal_info_page.dart';
import 'package:fitness_client/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthServiceWithEmail extends AuthService {
  _FakeAuthServiceWithEmail(this._session)
    : super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final Session? _session;

  @override
  Session? get currentSession => _session;
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
  _TestSettingsController(super.authService, super.service) : super() {
    state = AppSettings.defaults.copyWith(profileName: '测试用户');
  }

  @override
  Future<AppSettings> loadPersonalInfo() async => state;
}

void main() {
  testWidgets('个人信息页显示当前账号邮箱', (tester) async {
    final session = Session(
      accessToken: 'access-token',
      tokenType: 'bearer',
      user: User(
        id: 'user-1',
        appMetadata: const {'provider': 'email'},
        userMetadata: const {},
        aud: 'authenticated',
        email: 'tester@example.com',
        createdAt: DateTime(2026, 5, 20).toIso8601String(),
      ),
    );
    final authService = _FakeAuthServiceWithEmail(session);
    final userProfileService = _FakeUserProfileService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          settingsProvider.overrideWith(
            (ref) => _TestSettingsController(authService, userProfileService),
          ),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              const AuthSessionSnapshot(
                status: AuthStatus.authenticated,
                userId: 'user-1',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PersonalInfoPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前账号邮箱'), findsOneWidget);
    expect(find.text('tester@example.com'), findsOneWidget);
  });
}
