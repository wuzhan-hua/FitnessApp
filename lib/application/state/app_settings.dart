import 'package:flutter/foundation.dart';

@immutable
class AppSettings {
  const AppSettings({
    required this.useKilogram,
    required this.defaultRestSeconds,
    required this.favoriteMuscleFocus,
    required this.isDarkMode,
  });

  final bool useKilogram;
  final int defaultRestSeconds;
  final String favoriteMuscleFocus;
  final bool isDarkMode;

  AppSettings copyWith({
    bool? useKilogram,
    int? defaultRestSeconds,
    String? favoriteMuscleFocus,
    bool? isDarkMode,
  }) {
    return AppSettings(
      useKilogram: useKilogram ?? this.useKilogram,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      favoriteMuscleFocus: favoriteMuscleFocus ?? this.favoriteMuscleFocus,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  static const defaults = AppSettings(
    useKilogram: true,
    defaultRestSeconds: 120,
    favoriteMuscleFocus: '胸',
    isDarkMode: false,
  );
}
