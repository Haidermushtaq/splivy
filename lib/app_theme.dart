import 'package:flutter/material.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

ThemeData get lightTheme => ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00D4AA),
        brightness: Brightness.light,
      ),
      useMaterial3: false,
    );

ThemeData get darkTheme => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00D4AA),
        brightness: Brightness.dark,
      ),
      useMaterial3: false,
    );
