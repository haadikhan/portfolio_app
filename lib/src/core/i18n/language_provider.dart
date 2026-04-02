import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

const _prefsKey = "app_locale_language";

final languageProvider =
    AsyncNotifierProvider<LanguageNotifier, Locale>(LanguageNotifier.new);

class LanguageNotifier extends AsyncNotifier<Locale> {
  @override
  Future<Locale> build() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey) ?? "en";
    return code == "ur" ? const Locale("ur") : const Locale("en");
  }

  Future<void> setLanguage(String code) async {
    final locale = code == "ur" ? const Locale("ur") : const Locale("en");
    state = AsyncValue.data(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }
}
