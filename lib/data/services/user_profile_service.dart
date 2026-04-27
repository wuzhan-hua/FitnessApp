import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user_profile.dart';
import '../../utils/app_error.dart';
import '../../utils/app_logger.dart';

class UserProfileService {
  const UserProfileService(this._client);

  final SupabaseClient _client;

  Future<UserProfile?> fetchCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const AppError(message: '请先登录后再操作。', code: 'auth_required');
    }

    try {
      final row = await _client
          .from('user_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return UserProfile.fromJson(row);
    } catch (error, stackTrace) {
      AppLogger.error('加载个人资料失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '加载个人资料失败，请稍后重试。');
    }
  }

  Future<void> upsertCurrentUserProfile(UserProfile profile) async {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const AppError(message: '请先登录后再操作。', code: 'auth_required');
    }

    try {
      await _client
          .from('user_profiles')
          .upsert(profile.toJson(), onConflict: 'user_id');
    } catch (error, stackTrace) {
      AppLogger.error('保存个人资料失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '保存个人资料失败，请稍后重试。');
    }
  }
}
