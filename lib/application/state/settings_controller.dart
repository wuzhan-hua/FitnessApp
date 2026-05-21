import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/auth_service.dart';
import '../../data/services/user_profile_service.dart';
import '../../domain/entities/user_profile.dart';
import '../../utils/app_error.dart';
import '../../utils/app_logger.dart';
import 'app_settings.dart';

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._authService, this._userProfileService)
    : super(AppSettings.defaults) {
    _loadFuture = _load();
    _authSubscription = _authService.onAuthStateChange.listen((event) async {
      final user = event.session?.user;
      if (user == null) {
        _clearPersonalInfoInMemory();
        return;
      }
      if (user.isAnonymous) {
        await _loadCachedPersonalInfoForUser(user.id);
        return;
      }
      try {
        await loadPersonalInfo();
      } catch (error, stackTrace) {
        AppLogger.error(
          '认证状态变更后同步个人资料失败',
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
  }

  final AuthService _authService;
  final UserProfileService _userProfileService;
  late final Future<void> _loadFuture;
  late final StreamSubscription _authSubscription;

  static const _unitKey = 'unit_kg';
  static const _restKey = 'default_rest_seconds';
  static const _focusKey = 'favorite_focus';
  static const _darkModeKey = 'dark_mode_enabled';
  static const _profileNameKey = 'profile_name';
  static const _avatarUrlKey = 'profile_avatar_url';
  static const _genderKey = 'profile_gender';
  static const _birthDateKey = 'profile_birth_date';
  static const _heightCmKey = 'profile_height_cm';
  static const _weightKgKey = 'profile_weight_kg';
  static const _goalKey = 'profile_training_goal';
  static const _trainingYearsKey = 'profile_training_years';
  static const _activityLevelKey = 'profile_activity_level';
  static const _legacyPersonalInfoKeys = [
    _profileNameKey,
    _avatarUrlKey,
    _genderKey,
    _birthDateKey,
    _heightCmKey,
    _weightKgKey,
    _goalKey,
    _trainingYearsKey,
    _activityLevelKey,
  ];

  Future<AppSettings> loadPersonalInfo() async {
    await _loadFuture;
    final user = _authService.currentSession?.user;
    if (user == null || user.isAnonymous) {
      return state;
    }

    final profile = await _userProfileService.fetchCurrentUserProfile();
    if (profile == null) {
      return state;
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = _readCachedPersonalInfo(prefs, user.id);
    final remoteProfileName = profile.profileName.trim();
    await _applyPersonalInfo(
      profileName: remoteProfileName.isNotEmpty
          ? remoteProfileName
          : cached.profileName,
      avatarUrl: _preferNonEmptyString(profile.avatarUrl, cached.avatarUrl),
      gender: profile.gender,
      birthDate: profile.birthDate,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      trainingGoal: profile.trainingGoal,
      trainingYears: profile.trainingYears,
      activityLevel: profile.activityLevel,
    );
    return state;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      useKilogram: prefs.getBool(_unitKey) ?? state.useKilogram,
      defaultRestSeconds: prefs.getInt(_restKey) ?? state.defaultRestSeconds,
      favoriteMuscleFocus:
          prefs.getString(_focusKey) ?? state.favoriteMuscleFocus,
      isDarkMode: prefs.getBool(_darkModeKey) ?? state.isDarkMode,
    );
    _clearPersonalInfoInMemory();

    final user = _authService.currentSession?.user;
    if (user == null) {
      return;
    }
    if (user.isAnonymous) {
      await _loadCachedPersonalInfoForUser(user.id);
      return;
    }

    try {
      final profile = await _userProfileService.fetchCurrentUserProfile();
      if (profile == null) {
        await _loadCachedPersonalInfoForUser(user.id);
        return;
      }

      final cached = _readCachedPersonalInfo(prefs, user.id);
      final remoteProfileName = profile.profileName.trim();
      await _applyPersonalInfo(
        profileName: remoteProfileName.isNotEmpty
            ? remoteProfileName
            : cached.profileName,
        avatarUrl: _preferNonEmptyString(profile.avatarUrl, cached.avatarUrl),
        gender: profile.gender,
        birthDate: profile.birthDate,
        heightCm: profile.heightCm,
        weightKg: profile.weightKg,
        trainingGoal: profile.trainingGoal,
        trainingYears: profile.trainingYears,
        activityLevel: profile.activityLevel,
      );
    } catch (error, stackTrace) {
      AppLogger.warn('初始化个人资料同步失败，保留本地设置继续运行');
      AppLogger.error('初始化个人资料同步失败', error: error, stackTrace: stackTrace);
      await _loadCachedPersonalInfoForUser(user.id);
    }
  }

  Future<void> toggleUnit(bool useKg) async {
    state = state.copyWith(useKilogram: useKg);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_unitKey, useKg);
  }

  Future<void> updateRestSeconds(int seconds) async {
    state = state.copyWith(defaultRestSeconds: seconds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_restKey, seconds);
  }

  Future<void> updateFavoriteFocus(String value) async {
    state = state.copyWith(favoriteMuscleFocus: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_focusKey, value);
  }

  Future<void> toggleDarkMode(bool enabled) async {
    state = state.copyWith(isDarkMode: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, enabled);
  }

  Future<void> updatePersonalInfo({
    required String profileName,
    String? avatarUrl,
    String? gender,
    DateTime? birthDate,
    double? heightCm,
    double? weightKg,
    String? trainingGoal,
    String? trainingYears,
    String? activityLevel,
  }) async {
    await _loadFuture;
    final normalizedName = profileName.trim();
    if (normalizedName.isEmpty) {
      return;
    }
    final user = _authService.currentSession?.user;
    if (user != null && !user.isAnonymous) {
      await _userProfileService.upsertCurrentUserProfile(
        UserProfile(
          userId: user.id,
          profileName: normalizedName,
          avatarUrl: avatarUrl,
          gender: gender,
          birthDate: birthDate,
          heightCm: heightCm,
          weightKg: weightKg,
          trainingGoal: trainingGoal,
          trainingYears: trainingYears,
          activityLevel: activityLevel,
        ),
      );
    }

    await _applyPersonalInfo(
      profileName: normalizedName,
      avatarUrl: avatarUrl,
      gender: gender,
      birthDate: birthDate,
      heightCm: heightCm,
      weightKg: weightKg,
      trainingGoal: trainingGoal,
      trainingYears: trainingYears,
      activityLevel: activityLevel,
    );
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  Future<void> _setOrRemoveString(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, value);
  }

  Future<void> _setOrRemoveDouble(
    SharedPreferences prefs,
    String key,
    double? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setDouble(key, value);
  }

  String _userScopedKey(String userId, String key) => 'user:$userId:$key';

  _CachedPersonalInfo _readCachedPersonalInfo(
    SharedPreferences prefs,
    String userId,
  ) {
    String scoped(String key) => _userScopedKey(userId, key);
    return _CachedPersonalInfo(
      profileName: prefs.getString(scoped(_profileNameKey))?.trim() ?? '',
      avatarUrl: prefs.getString(scoped(_avatarUrlKey)),
      gender: prefs.getString(scoped(_genderKey)),
      birthDate: _parseDate(prefs.getString(scoped(_birthDateKey))),
      heightCm: prefs.getDouble(scoped(_heightCmKey)),
      weightKg: prefs.getDouble(scoped(_weightKgKey)),
      trainingGoal: prefs.getString(scoped(_goalKey)),
      trainingYears: prefs.getString(scoped(_trainingYearsKey)),
      activityLevel: prefs.getString(scoped(_activityLevelKey)),
    );
  }

  Future<void> _loadCachedPersonalInfoForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = _readCachedPersonalInfo(prefs, userId);
    state = state.copyWith(
      profileName: cached.profileName,
      avatarUrl: cached.avatarUrl,
      clearAvatarUrl: cached.avatarUrl == null,
      gender: cached.gender,
      clearGender: cached.gender == null,
      birthDate: cached.birthDate,
      clearBirthDate: cached.birthDate == null,
      heightCm: cached.heightCm,
      clearHeightCm: cached.heightCm == null,
      weightKg: cached.weightKg,
      clearWeightKg: cached.weightKg == null,
      trainingGoal: cached.trainingGoal,
      clearTrainingGoal: cached.trainingGoal == null,
      trainingYears: cached.trainingYears,
      clearTrainingYears: cached.trainingYears == null,
      activityLevel: cached.activityLevel,
      clearActivityLevel: cached.activityLevel == null,
    );
  }

  void _clearPersonalInfoInMemory() {
    state = state.copyWith(
      profileName: AppSettings.defaults.profileName,
      clearAvatarUrl: true,
      clearGender: true,
      clearBirthDate: true,
      clearHeightCm: true,
      clearWeightKg: true,
      clearTrainingGoal: true,
      clearTrainingYears: true,
      clearActivityLevel: true,
    );
  }

  String? _preferNonEmptyString(String? primary, String? fallback) {
    final normalizedPrimary = primary?.trim();
    if (normalizedPrimary != null && normalizedPrimary.isNotEmpty) {
      return normalizedPrimary;
    }

    final normalizedFallback = fallback?.trim();
    if (normalizedFallback != null && normalizedFallback.isNotEmpty) {
      return normalizedFallback;
    }

    return null;
  }

  Future<String> uploadAvatar({
    required List<int> bytes,
    required String fileName,
  }) async {
    await _loadFuture;
    final user = _authService.currentSession?.user;
    if (user == null || user.isAnonymous) {
      throw const AppError(message: '请先登录后再上传头像。', code: 'auth_required');
    }

    final avatarUrl = await _userProfileService.uploadAvatar(
      userId: user.id,
      bytes: bytes,
      fileName: fileName,
    );
    state = state.copyWith(avatarUrl: avatarUrl, clearAvatarUrl: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userScopedKey(user.id, _avatarUrlKey), avatarUrl);
    AppLogger.info('头像上传成功，已同步到本地设置状态');
    return avatarUrl;
  }

  Future<void> _applyPersonalInfo({
    required String profileName,
    String? avatarUrl,
    String? gender,
    DateTime? birthDate,
    double? heightCm,
    double? weightKg,
    String? trainingGoal,
    String? trainingYears,
    String? activityLevel,
  }) async {
    state = state.copyWith(
      profileName: profileName,
      avatarUrl: avatarUrl,
      clearAvatarUrl: avatarUrl == null,
      gender: gender,
      clearGender: gender == null,
      birthDate: birthDate,
      clearBirthDate: birthDate == null,
      heightCm: heightCm,
      clearHeightCm: heightCm == null,
      weightKg: weightKg,
      clearWeightKg: weightKg == null,
      trainingGoal: trainingGoal,
      clearTrainingGoal: trainingGoal == null,
      trainingYears: trainingYears,
      clearTrainingYears: trainingYears == null,
      activityLevel: activityLevel,
      clearActivityLevel: activityLevel == null,
    );

    final userId = _authService.currentSession?.user.id;
    if (userId == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await _clearLegacyPersonalInfoCache(prefs);
    await prefs.setString(_userScopedKey(userId, _profileNameKey), profileName);
    await _setOrRemoveString(
      prefs,
      _userScopedKey(userId, _avatarUrlKey),
      avatarUrl,
    );
    await _setOrRemoveString(prefs, _userScopedKey(userId, _genderKey), gender);
    await _setOrRemoveString(
      prefs,
      _userScopedKey(userId, _birthDateKey),
      birthDate?.toIso8601String(),
    );
    await _setOrRemoveDouble(
      prefs,
      _userScopedKey(userId, _heightCmKey),
      heightCm,
    );
    await _setOrRemoveDouble(
      prefs,
      _userScopedKey(userId, _weightKgKey),
      weightKg,
    );
    await _setOrRemoveString(
      prefs,
      _userScopedKey(userId, _goalKey),
      trainingGoal,
    );
    await _setOrRemoveString(
      prefs,
      _userScopedKey(userId, _trainingYearsKey),
      trainingYears,
    );
    await _setOrRemoveString(
      prefs,
      _userScopedKey(userId, _activityLevelKey),
      activityLevel,
    );
  }

  Future<void> _clearLegacyPersonalInfoCache(SharedPreferences prefs) async {
    for (final key in _legacyPersonalInfoKeys) {
      await prefs.remove(key);
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}

class _CachedPersonalInfo {
  const _CachedPersonalInfo({
    required this.profileName,
    this.avatarUrl,
    this.gender,
    this.birthDate,
    this.heightCm,
    this.weightKg,
    this.trainingGoal,
    this.trainingYears,
    this.activityLevel,
  });

  final String profileName;
  final String? avatarUrl;
  final String? gender;
  final DateTime? birthDate;
  final double? heightCm;
  final double? weightKg;
  final String? trainingGoal;
  final String? trainingYears;
  final String? activityLevel;
}
