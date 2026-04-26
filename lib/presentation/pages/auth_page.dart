import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../../application/state/auth_status.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_error.dart';
import '../../utils/snackbar_helper.dart';

enum _AuthMode { signIn, signUp }

class AuthPageArgs {
  const AuthPageArgs({this.preferUpgrade = false});

  final bool preferUpgrade;
}

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, this.preferUpgrade = false});

  static const routeName = '/auth';
  final bool preferUpgrade;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isSubmitting = false;
  bool _isSendingCode = false;
  int _resendSeconds = 0;
  String? _lockedUpgradeEmail;
  Timer? _resendTimer;
  late _AuthMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.preferUpgrade ? _AuthMode.signUp : _AuthMode.signIn;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(email);
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }

  void _setMode(_AuthMode mode) {
    _resendTimer?.cancel();
    setState(() {
      _mode = mode;
      _otpController.clear();
      _passwordController.clear();
      _lockedUpgradeEmail = null;
      _resendSeconds = 0;
    });
    ref.read(emailSignUpPendingProvider.notifier).state = false;
  }

  Future<void> _sendOtp() async {
    if (_isSendingCode || _resendSeconds > 0) {
      return;
    }

    final authService = ref.read(authServiceProvider);
    final authStatus =
        ref.read(authStatusProvider).valueOrNull ?? AuthStatus.signedOut;
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      showLatestSnackBar(context, '请先输入正确邮箱后再发送验证码');
      return;
    }

    setState(() => _isSendingCode = true);
    try {
      if (widget.preferUpgrade && authStatus.isGuest) {
        await authService.sendGuestUpgradeCode(email);
        if (!mounted) {
          return;
        }
        setState(() {
          _lockedUpgradeEmail = email.toLowerCase();
        });
      } else {
        await authService.sendEmailCodeForSignUp(email);
      }
      if (!mounted) {
        return;
      }
      _startResendCountdown();
      showLatestSnackBar(context, '验证码已发送，请检查邮箱。');
    } catch (error) {
      if (!mounted) return;
      final appError = AppError.from(error, fallbackMessage: '验证码发送失败，请稍后重试。');
      showLatestSnackBar(context, appError.message);
    } finally {
      if (mounted) {
        setState(() => _isSendingCode = false);
      }
    }
  }

  Future<void> _submit(AuthStatus status) async {
    if (!_formKey.currentState!.validate() || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    final authService = ref.read(authServiceProvider);
    final emailSignUpPendingNotifier = ref.read(
      emailSignUpPendingProvider.notifier,
    );
    final guestSoftSignedOut = guestSoftSignedOutProvider;
    final homeSnapshot = homeSnapshotProvider;
    final analyticsSnapshot = analyticsSnapshotProvider;
    final calendarMonth = ref.read(calendarMonthProvider);
    final sessionsByMonth = sessionsByMonthProvider(calendarMonth);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final isUpgradeFlow = widget.preferUpgrade && status.isGuest;
    try {
      if (isUpgradeFlow) {
        final lockedUpgradeEmail = _lockedUpgradeEmail;
        if (lockedUpgradeEmail != null &&
            lockedUpgradeEmail != email.toLowerCase()) {
          throw const AppError(message: '发送验证码后的邮箱不能修改，请重新发送验证码。');
        }
        await authService.upgradeGuestToEmail(
          email: email,
          code: _otpController.text.trim(),
          password: password,
        );
        if (!mounted) return;
        showLatestSnackBar(context, '邮箱账号升级成功，已切换为正式账号');
      } else if (_mode == _AuthMode.signIn) {
        await authService.signInWithEmail(email, password);
        emailSignUpPendingNotifier.state = false;
        if (!mounted) return;
        showLatestSnackBar(context, '登录成功');
      } else {
        emailSignUpPendingNotifier.state = true;
        await authService.completeEmailSignUp(
          email: email,
          code: _otpController.text.trim(),
          password: password,
        );
        emailSignUpPendingNotifier.state = false;
        if (!mounted) return;
        showLatestSnackBar(context, '注册成功，已进入系统');
      }

      ref.invalidate(guestSoftSignedOut);
      ref.invalidate(homeSnapshot);
      ref.invalidate(analyticsSnapshot);
      ref.invalidate(sessionsByMonth);

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      emailSignUpPendingNotifier.state = false;
      if (!mounted) return;
      final appError = AppError.from(error, fallbackMessage: '认证失败，请稍后重试。');
      showLatestSnackBar(context, appError.message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _guestSignIn() async {
    if (_isSubmitting) {
      return;
    }

    final authService = ref.read(authServiceProvider);
    setState(() => _isSubmitting = true);
    try {
      await authService.signInAsGuest();
      if (!mounted) return;
      ref.invalidate(guestSoftSignedOutProvider);
      showLatestSnackBar(context, '游客登录成功');
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      final appError = AppError.from(error, fallbackMessage: '游客登录失败，请稍后重试。');
      showLatestSnackBar(context, appError.message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    String? hint,
  }) {
    final colors = AppColors.of(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: colors.panelAlt.withValues(alpha: 0.36),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.textMuted.withValues(alpha: 0.24)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.textMuted.withValues(alpha: 0.24)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.accent, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authStatus =
        ref.watch(authStatusProvider).valueOrNull ?? AuthStatus.signedOut;
    final isGuest = authStatus.isGuest;
    final isUpgradeFlow = widget.preferUpgrade && isGuest;
    final colors = AppColors.of(context);
    final isOtpFlow =
        (_mode == _AuthMode.signUp && !isUpgradeFlow) || isUpgradeFlow;
    final isUpgradeEmailLocked = isUpgradeFlow && _lockedUpgradeEmail != null;

    final title = isUpgradeFlow
        ? '升级为邮箱账号'
        : _mode == _AuthMode.signIn
        ? '邮箱登录'
        : '邮箱注册';
    final sendOtpLabel = _isSendingCode
        ? '发送中'
        : _resendSeconds > 0
        ? '${_resendSeconds}s'
        : '发送验证码';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!isUpgradeFlow)
            TextButton(
              onPressed: _isSubmitting ? null : _guestSignIn,
              child: const Text('游客登录'),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - AppSpacing.md * 2,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'ForgeLog',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '简洁记录每次训练，持续积累你的进步',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!isUpgradeFlow)
                                  SegmentedButton<_AuthMode>(
                                    showSelectedIcon: false,
                                    segments: const [
                                      ButtonSegment<_AuthMode>(
                                        value: _AuthMode.signIn,
                                        label: Text('密码登录'),
                                      ),
                                      ButtonSegment<_AuthMode>(
                                        value: _AuthMode.signUp,
                                        label: Text('邮箱注册'),
                                      ),
                                    ],
                                    selected: {_mode},
                                    onSelectionChanged: _isSubmitting
                                        ? null
                                        : (values) {
                                            if (_mode == values.first) {
                                              return;
                                            }
                                            _setMode(values.first);
                                          },
                                  ),
                                if (!isUpgradeFlow)
                                  const SizedBox(height: AppSpacing.md),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  readOnly: isUpgradeEmailLocked,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: _fieldDecoration(
                                    context,
                                    label: '邮箱',
                                    hint: 'name@example.com',
                                  ),
                                  validator: (value) {
                                    final text = value?.trim() ?? '';
                                    if (text.isEmpty) {
                                      return '请输入邮箱';
                                    }
                                    if (!_isValidEmail(text)) {
                                      return '邮箱格式不正确';
                                    }
                                    return null;
                                  },
                                ),
                                if (isUpgradeEmailLocked) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: _isSubmitting || _isSendingCode
                                          ? null
                                          : () {
                                              _resendTimer?.cancel();
                                              setState(() {
                                                _lockedUpgradeEmail = null;
                                                _otpController.clear();
                                                _resendSeconds = 0;
                                              });
                                            },
                                      child: const Text('修改邮箱并重新发送验证码'),
                                    ),
                                  ),
                                ],
                                if (isOtpFlow) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _otpController,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(6),
                                          ],
                                          decoration: _fieldDecoration(
                                            context,
                                            label: isUpgradeFlow
                                                ? '升级验证码'
                                                : '邮箱验证码',
                                            hint: '请输入 6 位验证码',
                                          ),
                                          validator: (value) {
                                            if (!isOtpFlow) {
                                              return null;
                                            }
                                            final text = value?.trim() ?? '';
                                            if (text.isEmpty) {
                                              return '请输入验证码';
                                            }
                                            if (text.length != 6) {
                                              return '验证码为 6 位数字';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      SizedBox(
                                        height: 52,
                                        child: FilledButton.tonal(
                                          onPressed:
                                              (_isSubmitting ||
                                                  _isSendingCode ||
                                                  _resendSeconds > 0)
                                              ? null
                                              : _sendOtp,
                                          child: Text(sendOtpLabel),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    isUpgradeFlow
                                        ? '发送验证码后，请前往邮箱查收并输入 6 位验证码，再设置密码完成升级。'
                                        : '发送验证码后，请前往邮箱查收并输入 6 位验证码，再设置密码完成注册。',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: colors.textMuted),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.sm),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  autofillHints: const [AutofillHints.password],
                                  decoration: _fieldDecoration(
                                    context,
                                    label: '密码',
                                    hint: '至少 6 位字符',
                                  ),
                                  validator: (value) {
                                    final text = value?.trim() ?? '';
                                    if (text.isEmpty) {
                                      return '请输入密码';
                                    }
                                    if (text.length < 6) {
                                      return '密码至少 6 位';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),
                                FilledButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => _submit(authStatus),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          isUpgradeFlow
                                              ? '升级账号'
                                              : _mode == _AuthMode.signIn
                                              ? '登录'
                                              : '注册并自动登录',
                                        ),
                                ),
                                if (!isUpgradeFlow) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  TextButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _setMode(
                                            _mode == _AuthMode.signIn
                                                ? _AuthMode.signUp
                                                : _AuthMode.signIn,
                                          ),
                                    child: Text(
                                      _mode == _AuthMode.signIn
                                          ? '没有账号？去注册'
                                          : '已有账号？去登录',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '支持游客登录和邮箱密码登录；新用户可通过邮箱验证码注册并自动登录。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
