import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

const _prefsKey = "app_theme_mode";

final themeProvider =
    AsyncNotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

class ThemeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_prefsKey);
    if (v == "dark") return ThemeMode.dark;
    return ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    final current = state.valueOrNull ?? ThemeMode.light;
    final next = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = AsyncValue.data(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, next == ThemeMode.dark ? "dark" : "light");
  }
}
