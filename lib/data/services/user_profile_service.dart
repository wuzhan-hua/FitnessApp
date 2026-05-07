import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user_profile.dart';
import '../../utils/app_error.dart';
import '../../utils/app_logger.dart';

class UserProfileService {
  const UserProfileService(this._client);

  static const _avatarBucketName = 'user-avatars';
  static const supportedAvatarExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const unsupportedAvatarExtensions = {'heic', 'heif'};

  final SupabaseClient _client;

  Future<bool> fetchCurrentUserIsAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      return false;
    }

    try {
      final row = await _client
          .from('users')
          .select('is_admin')
          .eq('user_id', user.id)
          .maybeSingle();
      if (row == null) {
        return false;
      }
      return row['is_admin'] == true;
    } catch (error, stackTrace) {
      AppLogger.error('加载管理员权限失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '加载权限失败，请稍后重试。');
    }
  }

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

  Future<String> uploadAvatar({
    required String userId,
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      final extension = _resolveExtension(fileName);
      final objectPath =
          '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
      await _client.storage
          .from(_avatarBucketName)
          .uploadBinary(
            objectPath,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: _resolveContentType(extension),
            ),
          );
      return _client.storage.from(_avatarBucketName).getPublicUrl(objectPath);
    } catch (error, stackTrace) {
      AppLogger.error('上传头像失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '上传头像失败，请稍后重试。');
    }
  }

  String _resolveExtension(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex >= normalized.length - 1) {
      throw const AppError(
        message: '当前仅支持 JPG、PNG、WebP，请先转换后再上传。',
        code: 'unsupported_avatar_format',
      );
    }
    final extension = normalized.substring(dotIndex + 1);
    if (supportedAvatarExtensions.contains(extension)) {
      return extension;
    }
    if (unsupportedAvatarExtensions.contains(extension)) {
      throw const AppError(
        message: '当前仅支持 JPG、PNG、WebP，请先转换后再上传。',
        code: 'unsupported_avatar_format',
      );
    }
    throw const AppError(
      message: '当前仅支持 JPG、PNG、WebP，请先转换后再上传。',
      code: 'unsupported_avatar_format',
    );
  }

  String _resolveContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}
