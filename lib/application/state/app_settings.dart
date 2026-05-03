import 'package:flutter/foundation.dart';

@immutable
class AppSettings {
  const AppSettings({
    required this.useKilogram,
    required this.defaultRestSeconds,
    required this.favoriteMuscleFocus,
    required this.isDarkMode,
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

  final bool useKilogram;
  final int defaultRestSeconds;
  final String favoriteMuscleFocus;
  final bool isDarkMode;
  final String profileName;
  final String? avatarUrl;
  final String? gender;
  final DateTime? birthDate;
  final double? heightCm;
  final double? weightKg;
  final String? trainingGoal;
  final String? trainingYears;
  final String? activityLevel;

  AppSettings copyWith({
    bool? useKilogram,
    int? defaultRestSeconds,
    String? favoriteMuscleFocus,
    bool? isDarkMode,
    String? profileName,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    String? gender,
    bool clearGender = false,
    DateTime? birthDate,
    bool clearBirthDate = false,
    double? heightCm,
    bool clearHeightCm = false,
    double? weightKg,
    bool clearWeightKg = false,
    String? trainingGoal,
    bool clearTrainingGoal = false,
    String? trainingYears,
    bool clearTrainingYears = false,
    String? activityLevel,
    bool clearActivityLevel = false,
  }) {
    return AppSettings(
      useKilogram: useKilogram ?? this.useKilogram,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      favoriteMuscleFocus: favoriteMuscleFocus ?? this.favoriteMuscleFocus,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      profileName: profileName ?? this.profileName,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      gender: clearGender ? null : (gender ?? this.gender),
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      heightCm: clearHeightCm ? null : (heightCm ?? this.heightCm),
      weightKg: clearWeightKg ? null : (weightKg ?? this.weightKg),
      trainingGoal: clearTrainingGoal
          ? null
          : (trainingGoal ?? this.trainingGoal),
      trainingYears: clearTrainingYears
          ? null
          : (trainingYears ?? this.trainingYears),
      activityLevel: clearActivityLevel
          ? null
          : (activityLevel ?? this.activityLevel),
    );
  }

  static const defaults = AppSettings(
    useKilogram: true,
    defaultRestSeconds: 120,
    favoriteMuscleFocus: '胸',
    isDarkMode: false,
    profileName: '林泽宇',
  );
}
