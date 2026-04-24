import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers/providers.dart';
import '../application/state/auth_status.dart';
import '../presentation/pages/auth_page.dart';
import '../presentation/shell/main_shell.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(authStatusProvider);
    final guestSoftSignedOutAsync = ref.watch(guestSoftSignedOutProvider);
    final emailSignUpPending = ref.watch(emailSignUpPendingProvider);
    return guestSoftSignedOutAsync.when(
      data: (guestSoftSignedOut) {
        return statusAsync.when(
          data: (status) {
            if (status == AuthStatus.signedOut) {
              return const AuthPage();
            }
            if (status == AuthStatus.guest && guestSoftSignedOut) {
              return const AuthPage();
            }
            if (status == AuthStatus.authenticated && emailSignUpPending) {
              return const AuthPage();
            }
            return const MainShell();
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) =>
              const Scaffold(body: Center(child: Text('认证状态加载失败，请重启应用重试。'))),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          const Scaffold(body: Center(child: Text('游客状态加载失败，请重启应用重试。'))),
    );
  }
}
