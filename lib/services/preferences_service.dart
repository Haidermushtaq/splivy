import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  late SharedPreferences _prefs;

  // ── Keys ────────────────────────────────────────────────────────────────────
  static const String keyThemeMode = 'theme_mode';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyLastUserId = 'last_user_id';
  static const String keyReminderEnabled = 'reminder_enabled';
  static const String keyReminderInterval = 'reminder_interval_hours';
  static const String keyLastSync = 'last_sync_timestamp';
  static const String keyCachedUsername = 'cached_username';
  static const String keyCachedFullName = 'cached_full_name';
  static const String keyCachedEmail = 'cached_email';
  static const String keyCachedAvatar = 'cached_avatar_url';
  static const String keyCurrency = 'currency';
  static const String keyNotificationSound = 'notification_sound';

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Theme ────────────────────────────────────────────────────────────────────
  void saveThemeMode(ThemeMode mode) {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
    _prefs.setString(keyThemeMode, value);
  }

  ThemeMode getThemeMode() {
    return switch (_prefs.getString(keyThemeMode)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  // ── User cache ───────────────────────────────────────────────────────────────
  Future<void> saveUserCache({
    required String userId,
    required String username,
    required String fullName,
    required String email,
  }) async {
    await _prefs.setString(keyLastUserId, userId);
    await _prefs.setString(keyCachedUsername, username);
    await _prefs.setString(keyCachedFullName, fullName);
    await _prefs.setString(keyCachedEmail, email);
  }

  Map<String, String?> getUserCache() => {
        'userId': _prefs.getString(keyLastUserId),
        'username': _prefs.getString(keyCachedUsername),
        'fullName': _prefs.getString(keyCachedFullName),
        'email': _prefs.getString(keyCachedEmail),
      };

  String? getLastUserId() => _prefs.getString(keyLastUserId);

  Future<void> clearUserCache() async {
    await _prefs.remove(keyLastUserId);
    await _prefs.remove(keyCachedUsername);
    await _prefs.remove(keyCachedFullName);
    await _prefs.remove(keyCachedEmail);
    await _prefs.remove(keyCachedAvatar);
  }

  // ── Reminders ────────────────────────────────────────────────────────────────
  bool getReminderEnabled() => _prefs.getBool(keyReminderEnabled) ?? true;
  Future<void> saveReminderEnabled(bool enabled) =>
      _prefs.setBool(keyReminderEnabled, enabled);

  int getReminderInterval() => _prefs.getInt(keyReminderInterval) ?? 24;
  Future<void> saveReminderInterval(int hours) =>
      _prefs.setInt(keyReminderInterval, hours);

  // ── App Settings ─────────────────────────────────────────────────────────────
  String getCurrency() => _prefs.getString(keyCurrency) ?? 'PKR';
  Future<void> saveCurrency(String currency) =>
      _prefs.setString(keyCurrency, currency);

  bool getNotificationSound() => _prefs.getBool(keyNotificationSound) ?? true;
  Future<void> saveNotificationSound(bool enabled) =>
      _prefs.setBool(keyNotificationSound, enabled);

  // ── Onboarding ───────────────────────────────────────────────────────────────
  bool isOnboardingDone() => _prefs.getBool(keyOnboardingDone) ?? false;
  Future<void> setOnboardingDone() => _prefs.setBool(keyOnboardingDone, true);

  // ── Last sync ────────────────────────────────────────────────────────────────
  Future<void> saveLastSync() =>
      _prefs.setInt(keyLastSync, DateTime.now().millisecondsSinceEpoch);

  DateTime? getLastSync() {
    final ms = _prefs.getInt(keyLastSync);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> clearAll() => _prefs.clear();
}
