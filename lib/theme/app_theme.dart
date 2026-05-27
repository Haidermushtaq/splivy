import 'package:flutter/material.dart';

abstract class AppTheme {
  static const _accent = Color(0xFF00D4AA);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        cardColor: const Color(0xFF0F3460),
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          secondary: _accent,
          error: Color(0xFFFF6B6B),
          surface: Color(0xFF0F3460),
          onSurface: Colors.white,
          onPrimary: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0F3460),
          selectedItemColor: _accent,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0F3460),
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIconColor: Colors.grey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        dividerColor: Colors.white12,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.grey),
          bodySmall: TextStyle(color: Colors.grey),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Colors.white),
        ),
      );

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        cardColor: const Color(0xFFFFFFFF),
        colorScheme: const ColorScheme.light(
          primary: _accent,
          secondary: _accent,
          error: Color(0xFFE53935),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF1A1A2E),
          onPrimary: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          elevation: 1,
          shadowColor: Colors.black26,
          iconTheme: IconThemeData(color: Color(0xFF1A1A2E)),
          actionsIconTheme: IconThemeData(color: Color(0xFF1A1A2E)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          selectedItemColor: _accent,
          unselectedItemColor: Color(0xFF666666),
          type: BottomNavigationBarType.fixed,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF0F0F0),
          hintStyle: const TextStyle(color: Color(0xFF666666)),
          prefixIconColor: const Color(0xFF666666),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        dividerColor: Colors.black12,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF1A1A2E)),
          bodyMedium: TextStyle(color: Color(0xFF666666)),
          bodySmall: TextStyle(color: Color(0xFF666666)),
          titleLarge: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Color(0xFF1A1A2E)),
        ),
      );
}
