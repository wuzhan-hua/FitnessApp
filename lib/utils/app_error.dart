import 'package:supabase_flutter/supabase_flutter.dart';

class AppError implements Exception {
  const AppError({required this.message, this.code, this.details});

  final String message;
  final String? code;
  final Object? details;

  static const Map<String, String> _codeMessages = {
    'email_exists': '该邮箱已注册，请直接登录。',
    'email_already_registered': '该邮箱已注册，请直接登录。',
    'invalid_credentials': '邮箱或密码错误，请检查后重试。',
    'invalid_login_credentials': '邮箱或密码错误，请检查后重试。',
    'email_not_confirmed': '邮箱尚未完成验证，请先完成验证。',
    'same_password': '新密码不能与当前密码相同。',
    'weak_password': '密码强度不足，请使用至少 6 位字符。',
    'over_email_send_rate_limit': '邮件发送过于频繁，请稍后再试。',
    'otp_expired': '验证码已过期，请重新获取。',
    'code_expired': '验证码已过期，请重新获取。',
    'invalid_otp': '验证码无效，请重新输入。',
    'invalid_code': '验证码无效，请重新输入。',
    'code_not_found': '请先发送验证码。',
    'code_already_used': '验证码已使用，请重新获取。',
    'send_too_frequently': '验证码发送过于频繁，请 60 秒后再试。',
    'send_hourly_limit_reached': '该邮箱当前发送次数已达上限，请稍后再试。',
    'auth_required': '请先登录后再操作。',
    'guest_upgrade_only': '当前账号状态不支持该操作。',
    'email_already_bound': '该邮箱已绑定当前账号，请直接输入验证码完成升级。',
    'guest_upgrade_session_not_synced': '账号已升级成功，但登录状态尚未同步，请重新登录。',
    'guest_upgrade_auto_sign_in_failed': '账号已升级成功，但自动登录失败，请直接用邮箱登录。',
    'duplicate_key': '数据已存在，请勿重复提交。',
    '23505': '数据已存在，请勿重复提交。',
    '23503': '关联数据不存在，无法完成当前操作。',
    '42501': '当前没有权限执行该操作。',
    'PGRST116': '未找到对应数据。',
  };

  factory AppError.from(Object error, {String? fallbackMessage}) {
    if (error is AppError) {
      return error;
    }
    if (error is PostgrestException) {
      final resolvedMessage = _resolveMessage(
        code: error.code,
        rawMessage: error.message,
        fallbackMessage: fallbackMessage,
      );
      return AppError(
        message: resolvedMessage,
        code: error.code,
        details: error.details ?? error.hint,
      );
    }
    if (error is AuthException) {
      final resolvedMessage = _resolveMessage(
        code: error.code ?? error.statusCode,
        rawMessage: error.message,
        fallbackMessage: fallbackMessage,
      );
      return AppError(
        message: resolvedMessage,
        code: error.code ?? error.statusCode,
        details: error,
      );
    }
    if (error is FunctionException) {
      final details = error.details;
      if (details is Map<String, dynamic>) {
        final rawMessage = details['message'] as String?;
        final rawCode = details['code'] as String?;
        return AppError(
          message: _resolveMessage(
            code: rawCode ?? '${error.status}',
            rawMessage: rawMessage,
            fallbackMessage: fallbackMessage,
          ),
          code: rawCode ?? '${error.status}',
          details: details,
        );
      }
      return AppError(
        message: _resolveMessage(
          code: '${error.status}',
          rawMessage: error.reasonPhrase,
          fallbackMessage: fallbackMessage ?? '服务调用失败，请稍后重试。',
        ),
        code: '${error.status}',
        details: details ?? error.reasonPhrase,
      );
    }
    return AppError(
      message: fallbackMessage ?? '发生未知错误，请稍后重试。',
      details: error,
    );
  }

  static String _resolveMessage({
    String? code,
    String? rawMessage,
    String? fallbackMessage,
  }) {
    final normalizedCode = code?.trim();
    if (normalizedCode != null && normalizedCode.isNotEmpty) {
      final matched = _codeMessages[normalizedCode];
      if (matched != null) {
        return matched;
      }
    }

    final normalizedMessage = rawMessage?.trim().toLowerCase() ?? '';
    if (normalizedMessage.isNotEmpty) {
      if (normalizedMessage.contains('already been registered') ||
          normalizedMessage.contains('user with this email') ||
          normalizedMessage.contains('email address is already in use')) {
        return '该邮箱已注册，请直接登录。';
      }
      if (normalizedMessage.contains('invalid login credentials') ||
          normalizedMessage.contains('invalid credentials')) {
        return '邮箱或密码错误，请检查后重试。';
      }
      if (normalizedMessage.contains('email not confirmed')) {
        return '邮箱尚未完成验证，请先完成验证。';
      }
      if (normalizedMessage.contains('otp') &&
          normalizedMessage.contains('expired')) {
        return '验证码已过期，请重新获取。';
      }
      if ((normalizedMessage.contains('otp') ||
              normalizedMessage.contains('code')) &&
          (normalizedMessage.contains('invalid') ||
              normalizedMessage.contains('token has expired'))) {
        return '验证码无效，请重新输入。';
      }
      if (normalizedMessage.contains('duplicate key') ||
          normalizedMessage.contains('unique constraint')) {
        return '数据已存在，请勿重复提交。';
      }
      if (normalizedMessage.contains('row-level security') ||
          normalizedMessage.contains('permission denied')) {
        return '当前没有权限执行该操作。';
      }
      if (normalizedMessage.contains('jwt') &&
          normalizedMessage.contains('expired')) {
        return '登录状态已失效，请重新登录。';
      }
    }

    return fallbackMessage ?? rawMessage ?? '发生未知错误，请稍后重试。';
  }

  @override
  String toString() => message;
}
