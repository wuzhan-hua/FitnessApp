import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController() : super(AppSettings.defaults) {
    _load();
  }

  static const _unitKey = 'unit_kg';
  static const _restKey = 'default_rest_seconds';
  static const _focusKey = 'favorite_focus';
  static const _darkModeKey = 'dark_mode_enabled';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      useKilogram: prefs.getBool(_unitKey) ?? state.useKilogram,
      defaultRestSeconds: prefs.getInt(_restKey) ?? state.defaultRestSeconds,
      favoriteMuscleFocus:
          prefs.getString(_focusKey) ?? state.favoriteMuscleFocus,
      isDarkMode: prefs.getBool(_darkModeKey) ?? state.isDarkMode,
    );
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
}
