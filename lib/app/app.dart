import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers/providers.dart';
import '../theme/app_theme.dart';
import 'auth_gate.dart';
import 'app_router.dart';

class FitnessApp extends ConsumerWidget {
  const FitnessApp({super.key});

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
      home: const AuthGate(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
