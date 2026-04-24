import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/state/auth_status.dart';
import '../../utils/app_error.dart';
import '../../utils/app_logger.dart';

class _UserTypes {
  const _UserTypes._();

  static const int guest = 0;
  static const int email = 1;
}

class AuthService {
  const AuthService(this._client);

  final SupabaseClient _client;
  static const _guestSoftSignedOutKey = 'guest_soft_signed_out';

  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  AuthStatus resolveStatus(Session? session) {
    final user = session?.user;
    if (user == null) {
      return AuthStatus.signedOut;
    }
    return user.isAnonymous ? AuthStatus.guest : AuthStatus.authenticated;
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      await setGuestSoftSignedOut(false);
      await _syncPublicUserProfileFromAuth(userType: _UserTypes.email);
    } catch (error, stackTrace) {
      AppLogger.error('邮箱登录失败', error: error, stackTrace: stackTrace);
      if (error is AppError) {
        rethrow;
      }
      throw AppError.from(error, fallbackMessage: '邮箱登录失败，请检查账号或稍后重试。');
    }
  }

  Future<void> completeEmailSignUp({
    required String email,
    required String code,
    required String password,
  }) async {
    try {
      await _client.functions.invoke(
        'complete-signup',
        body: {'email': email, 'code': code, 'password': password},
      );
      await signInWithEmail(email, password);
    } catch (error, stackTrace) {
      AppLogger.error('完成邮箱注册失败', error: error, stackTrace: stackTrace);
      if (error is AppError) {
        rethrow;
      }
      throw AppError.from(error, fallbackMessage: '注册失败，请稍后重试。');
    }
  }

  Future<void> sendEmailCodeForSignUp(String email) async {
    try {
      await _client.functions.invoke(
        'send-signup-code',
        body: {'email': email},
      );
    } catch (error, stackTrace) {
      AppLogger.error('发送邮箱验证码失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '验证码发送失败，请稍后重试。');
    }
  }

  Future<void> signInAsGuest() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        if (user.isAnonymous) {
          await setGuestSoftSignedOut(false);
          return;
        }
        throw const AppError(message: '当前已登录邮箱账号，无需游客登录。');
      }

      await _client.auth.signInAnonymously();
      await setGuestSoftSignedOut(false);
      await _syncPublicUserProfileFromAuth(
        includeEmailFields: false,
        userType: _UserTypes.guest,
      );
    } catch (error, stackTrace) {
      AppLogger.error('游客登录失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '游客登录失败，请稍后重试。');
    }
  }

  Future<void> sendGuestUpgradeCode(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final user = _client.auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw const AppError(message: '当前不是游客账号，无法发送升级验证码。');
    }

    try {
      await _client.functions.invoke(
        'send-guest-upgrade-code',
        body: {'email': normalizedEmail},
      );
    } catch (error, stackTrace) {
      AppLogger.error('发送游客升级验证码失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '发送升级验证码失败，请稍后重试。');
    }
  }

  Future<void> upgradeGuestToEmail({
    required String email,
    required String code,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final user = _client.auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw const AppError(message: '当前不是游客账号，无法升级为邮箱账号。');
    }

    try {
      await _client.functions.invoke(
        'complete-guest-upgrade',
        body: {
          'email': normalizedEmail,
          'code': code.trim(),
          'password': password,
        },
      );
      await _client.auth.refreshSession();
      await setGuestSoftSignedOut(false);
    } catch (error, stackTrace) {
      AppLogger.error('游客升级邮箱账号失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '游客升级失败，请稍后重试。');
    }
  }

  Future<void> signOut() async {
    try {
      final user = _client.auth.currentUser;
      if (user?.isAnonymous ?? false) {
        await setGuestSoftSignedOut(true);
        return;
      }

      await setGuestSoftSignedOut(false);
      await _client.auth.signOut();
    } catch (error, stackTrace) {
      AppLogger.error('退出登录失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '退出失败，请稍后重试。');
    }
  }

  Future<bool> isGuestSoftSignedOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestSoftSignedOutKey) ?? false;
  }

  Future<void> setGuestSoftSignedOut(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestSoftSignedOutKey, value);
  }

  Future<void> _syncPublicUserProfileFromAuth({
    bool includeEmailFields = true,
    required int userType,
  }) async {
    final user = _client.auth.currentUser;
    await _syncPublicUserProfile(
      userType: userType,
      includeEmailFields: includeEmailFields,
      email: includeEmailFields ? user?.email : null,
      emailVerifiedAt: includeEmailFields ? user?.emailConfirmedAt : null,
      phone: includeEmailFields ? user?.phone : null,
    );
  }

  Future<void> _syncPublicUserProfile({
    required int userType,
    bool includeEmailFields = true,
    String? email,
    String? emailVerifiedAt,
    String? phone,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AppError(message: '当前未登录，无法同步用户资料。');
    }

    final payload = <String, dynamic>{
      'user_id': user.id,
      'last_sign_in_at': user.lastSignInAt,
      'user_type': userType,
    };

    if (includeEmailFields) {
      payload['email'] = email;
      payload['email_verified_at'] = emailVerifiedAt;
      payload['phone'] = phone;
    }

    try {
      await _client.from('users').upsert(payload, onConflict: 'user_id');
    } catch (error, stackTrace) {
      AppLogger.error('同步业务用户资料失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '同步用户资料失败，请稍后重试。');
    }
  }
}
