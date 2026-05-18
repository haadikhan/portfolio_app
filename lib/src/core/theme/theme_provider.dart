import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

const _prefsKey = "app_theme_mode";

final themeProvider = AsyncNotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

class ThemeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    return switch (stored) {
      "dark" => ThemeMode.dark,
      "light" => ThemeMode.light,
      "auto" => ThemeMode.system,
      _ => ThemeMode.system,
    };
  }

  bool get isAutoMode => state.valueOrNull == ThemeMode.system;

  /// Returns the effective [ThemeMode] for display when auto mode is active.
  /// Uses local device time: 07:00–21:00 → light; 21:00–07:00 → dark.
  static ThemeMode resolveAutoTheme() {
    final hour = DateTime.now().hour;
    return (hour >= 7 && hour < 21) ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = switch (mode) {
      ThemeMode.dark => "dark",
      ThemeMode.light => "light",
      ThemeMode.system => "auto",
    };
    await prefs.setString(_prefsKey, stored);
    state = AsyncData(mode);
  }

  Future<void> toggleTheme() async {
    final current = state.valueOrNull ?? ThemeMode.light;
    final next = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = AsyncValue.data(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, next == ThemeMode.dark ? "dark" : "light");
  }
}
