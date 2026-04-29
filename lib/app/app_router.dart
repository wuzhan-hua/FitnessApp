import 'package:flutter/material.dart';

import '../application/state/session_editor_controller.dart';
import '../domain/entities/workout_models.dart';
import '../presentation/pages/auth_page.dart';
import '../presentation/pages/admin_exercise_catalog_page.dart';
import '../presentation/pages/exercise_detail_page.dart';
import '../presentation/pages/exercise_library_page.dart';
import '../presentation/pages/personal_info_page.dart';
import '../presentation/pages/session_editor_page.dart';

class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == SessionEditorPage.routeName) {
      final args = settings.arguments;
      if (args is SessionEditorArgs) {
        return MaterialPageRoute<SessionEditorExitResult?>(
          builder: (_) => SessionEditorPage(args: args),
          settings: settings,
        );
      }

      final fallback = SessionEditorArgs(
        date: DateTime.now(),
        mode: SessionMode.newSession,
      );
      return MaterialPageRoute<SessionEditorExitResult?>(
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
    if (settings.name == ExerciseLibraryPage.routeName) {
      final args = settings.arguments;
      return MaterialPageRoute<ExerciseSelectionResult?>(
        builder: (_) => ExerciseLibraryPage(
          args: args is ExerciseLibraryPageArgs ? args : null,
        ),
        settings: settings,
      );
    }
    if (settings.name == ExerciseDetailPage.routeName) {
      final args = settings.arguments;
      if (args is ExerciseDetailPageArgs) {
        return MaterialPageRoute<void>(
          builder: (_) => ExerciseDetailPage(args: args),
          settings: settings,
        );
      }
    }
    if (settings.name == AdminExerciseCatalogPage.routeName) {
      return MaterialPageRoute<void>(
        builder: (_) => const AdminExerciseCatalogPage(),
        settings: settings,
      );
    }
    if (settings.name == AuthPage.routeName) {
      final args = settings.arguments;
      final preferUpgrade = args is AuthPageArgs ? args.preferUpgrade : false;
      return MaterialPageRoute<void>(
        builder: (_) => AuthPage(preferUpgrade: preferUpgrade),
        settings: settings,
      );
    }
    return null;
  }
}
