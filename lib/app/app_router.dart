import 'package:flutter/material.dart';

import '../application/state/session_editor_controller.dart';
import '../domain/entities/workout_models.dart';
import '../presentation/pages/personal_info_page.dart';
import '../presentation/pages/session_editor_page.dart';

class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == SessionEditorPage.routeName) {
      final args = settings.arguments;
      if (args is SessionEditorArgs) {
        return MaterialPageRoute<void>(
          builder: (_) => SessionEditorPage(args: args),
          settings: settings,
        );
      }

      final fallback = SessionEditorArgs(
        date: DateTime.now(),
        mode: SessionMode.newSession,
      );
      return MaterialPageRoute<void>(
        builder: (_) => SessionEditorPage(args: fallback),
        settings: settings,
      );
    }
    if (settings.name == PersonalInfoPage.routeName) {
      return MaterialPageRoute<void>(
        builder: (_) => const PersonalInfoPage(),
        settings: settings,
      );
    }
    return null;
  }
}
