import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initSupabaseAndAnonymousAuth();
  runApp(const ProviderScope(child: FitnessApp()));
}

Future<void> _initSupabaseAndAnonymousAuth() async {
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError('缺少 SUPABASE_URL 或 SUPABASE_ANON_KEY');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final client = Supabase.instance.client;
  if (client.auth.currentSession == null) {
    final result = await client.auth.signInAnonymously();
    AppLogger.info('匿名登录成功: ${result.user?.id}');
  }
}
