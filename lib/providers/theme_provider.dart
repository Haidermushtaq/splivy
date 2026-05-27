import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

Future<void> saveThemePreference(bool isDark) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('theme_mode', isDark);
}
