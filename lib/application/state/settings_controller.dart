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
      if (user == null || user.isAnonymous) {
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
    final hasSavedProfileName = prefs.containsKey(_profileNameKey);
    final savedProfileName = prefs.getString(_profileNameKey)?.trim() ?? '';
    final remoteProfileName = profile.profileName.trim();
    final shouldUseRemoteProfileName = _shouldUseRemoteProfileName(
      hasSavedProfileName: hasSavedProfileName,
      savedProfileName: savedProfileName,
      remoteProfileName: remoteProfileName,
    );
    await _applyPersonalInfo(
      profileName: shouldUseRemoteProfileName
          ? remoteProfileName
          : savedProfileName,
      avatarUrl: _preferNonEmptyString(state.avatarUrl, profile.avatarUrl),
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
    final savedProfileName = prefs.getString(_profileNameKey);
    state = state.copyWith(
      useKilogram: prefs.getBool(_unitKey) ?? state.useKilogram,
      defaultRestSeconds: prefs.getInt(_restKey) ?? state.defaultRestSeconds,
      favoriteMuscleFocus:
          prefs.getString(_focusKey) ?? state.favoriteMuscleFocus,
      isDarkMode: prefs.getBool(_darkModeKey) ?? state.isDarkMode,
      profileName: savedProfileName ?? '',
      avatarUrl: prefs.getString(_avatarUrlKey),
      clearAvatarUrl: prefs.getString(_avatarUrlKey) == null,
      gender: prefs.getString(_genderKey),
      clearGender: prefs.getString(_genderKey) == null,
      birthDate: _parseDate(prefs.getString(_birthDateKey)),
      clearBirthDate: _parseDate(prefs.getString(_birthDateKey)) == null,
      heightCm: prefs.getDouble(_heightCmKey),
      clearHeightCm: prefs.getDouble(_heightCmKey) == null,
      weightKg: prefs.getDouble(_weightKgKey),
      clearWeightKg: prefs.getDouble(_weightKgKey) == null,
      trainingGoal: prefs.getString(_goalKey),
      clearTrainingGoal: prefs.getString(_goalKey) == null,
      trainingYears: prefs.getString(_trainingYearsKey),
      clearTrainingYears: prefs.getString(_trainingYearsKey) == null,
      activityLevel: prefs.getString(_activityLevelKey),
      clearActivityLevel: prefs.getString(_activityLevelKey) == null,
    );

    final user = _authService.currentSession?.user;
    if (user == null || user.isAnonymous) {
      if (!prefs.containsKey(_profileNameKey) &&
          state.profileName.trim().isEmpty) {
        state = state.copyWith(profileName: AppSettings.defaults.profileName);
      }
      return;
    }

    try {
      final profile = await _userProfileService.fetchCurrentUserProfile();
      if (profile == null) {
        if (!prefs.containsKey(_profileNameKey) &&
            state.profileName.trim().isEmpty) {
          state = state.copyWith(profileName: AppSettings.defaults.profileName);
        }
        return;
      }

      final remoteProfileName = profile.profileName.trim();
      final shouldUseRemoteProfileName = _shouldUseRemoteProfileName(
        hasSavedProfileName: savedProfileName != null,
        savedProfileName: savedProfileName?.trim() ?? '',
        remoteProfileName: remoteProfileName,
      );
      final resolvedProfileName = shouldUseRemoteProfileName
          ? remoteProfileName
          : savedProfileName!.trim();
      await _applyPersonalInfo(
        profileName: resolvedProfileName.isEmpty
            ? AppSettings.defaults.profileName
            : resolvedProfileName,
        avatarUrl: _preferNonEmptyString(
          prefs.getString(_avatarUrlKey),
          profile.avatarUrl,
        ),
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
      if (!prefs.containsKey(_profileNameKey) &&
          state.profileName.trim().isEmpty) {
        state = state.copyWith(profileName: AppSettings.defaults.profileName);
      }
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

  bool _shouldUseRemoteProfileName({
    required bool hasSavedProfileName,
    required String savedProfileName,
    required String remoteProfileName,
  }) {
    if (remoteProfileName.isEmpty) {
      return false;
    }
    if (!hasSavedProfileName || savedProfileName.isEmpty) {
      return true;
    }
    if (savedProfileName == AppSettings.defaults.profileName &&
        remoteProfileName != savedProfileName) {
      return true;
    }
    return false;
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
    await prefs.setString(_avatarUrlKey, avatarUrl);
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileNameKey, profileName);
    await _setOrRemoveString(prefs, _avatarUrlKey, avatarUrl);
    await _setOrRemoveString(prefs, _genderKey, gender);
    await _setOrRemoveString(
      prefs,
      _birthDateKey,
      birthDate?.toIso8601String(),
    );
    await _setOrRemoveDouble(prefs, _heightCmKey, heightCm);
    await _setOrRemoveDouble(prefs, _weightKgKey, weightKg);
    await _setOrRemoveString(prefs, _goalKey, trainingGoal);
    await _setOrRemoveString(prefs, _trainingYearsKey, trainingYears);
    await _setOrRemoveString(prefs, _activityLevelKey, activityLevel);
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
