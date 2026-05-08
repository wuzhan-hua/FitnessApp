import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers/providers.dart';
import '../theme/app_theme.dart';
import 'auth_gate.dart';
import 'app_router.dart';

class FitnessApp extends ConsumerWidget {
  const FitnessApp({super.key});

  List<Route<dynamic>> _handleInitialRoutes(String initialRoute) {
    debugPrint('[INFO] App initialRoute=$initialRoute');
    final defaultRoute = MaterialPageRoute<void>(
      builder: (_) => const AuthGate(),
      settings: const RouteSettings(name: Navigator.defaultRouteName),
    );
    if (initialRoute == Navigator.defaultRouteName) {
      return [defaultRoute];
    }

    if (initialRoute == '/meal-analysis') {
      debugPrint('[INFO] meal-analysis 初始直达已回退到根页');
      return [defaultRoute];
    }

    final generatedRoute = AppRouter.onGenerateRoute(
      RouteSettings(name: initialRoute),
    );
    if (generatedRoute != null) {
      return [defaultRoute];
    }

    return [defaultRoute];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'ForgeLog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      routes: {
        Navigator.defaultRouteName: (_) => const AuthGate(),
      },
      onGenerateRoute: AppRouter.onGenerateRoute,
      onGenerateInitialRoutes: _handleInitialRoutes,
    );
  }
}
