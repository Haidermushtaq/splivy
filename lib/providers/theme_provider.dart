import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/preferences_service.dart';

/// Manages the app's [ThemeMode] and persists the choice to [PreferencesService].
///
/// Used by: SplivyApp (MaterialApp.themeMode), ProfileScreen (toggle switch).
/// Updates when: [toggleTheme] or [setTheme] is called.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final PreferencesService _prefs;

  ThemeModeNotifier(this._prefs) : super(_prefs.getThemeMode());

  void toggleTheme() {
    setTheme(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    _prefs.saveThemeMode(mode);
  }
}

final themeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(PreferencesService());
});
