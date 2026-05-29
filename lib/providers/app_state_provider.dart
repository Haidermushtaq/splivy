import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/preferences_service.dart';

// ── AppState ──────────────────────────────────────────────────────────────────

/// Immutable snapshot of the global application state.
/// Combines authenticated user identity, preferences, and app settings
/// so any widget can watch a single provider instead of querying multiple
/// services.
class AppState {
  final String? currentUserId;
  final String? currentUsername;
  final String? currentFullName;
  final String? currentEmail;
  final bool isLoggedIn;
  final ThemeMode themeMode;
  final String currency;
  final bool reminderEnabled;
  final int reminderInterval;

  const AppState({
    this.currentUserId,
    this.currentUsername,
    this.currentFullName,
    this.currentEmail,
    this.isLoggedIn = false,
    this.themeMode = ThemeMode.dark,
    this.currency = 'PKR',
    this.reminderEnabled = true,
    this.reminderInterval = 24,
  });

  AppState copyWith({
    String? currentUserId,
    String? currentUsername,
    String? currentFullName,
    String? currentEmail,
    bool? isLoggedIn,
    ThemeMode? themeMode,
    String? currency,
    bool? reminderEnabled,
    int? reminderInterval,
  }) {
    return AppState(
      currentUserId: currentUserId ?? this.currentUserId,
      currentUsername: currentUsername ?? this.currentUsername,
      currentFullName: currentFullName ?? this.currentFullName,
      currentEmail: currentEmail ?? this.currentEmail,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      themeMode: themeMode ?? this.themeMode,
      currency: currency ?? this.currency,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderInterval: reminderInterval ?? this.reminderInterval,
    );
  }
}

// ── AppStateNotifier ──────────────────────────────────────────────────────────

/// Manages and exposes [AppState] across the app.
///
/// Initialised once at startup from [PreferencesService] (local cache) and
/// the current Supabase auth session.  Call [updateUser] after login and
/// [logout] on sign-out.
class AppStateNotifier extends StateNotifier<AppState> {
  final PreferencesService _prefs;

  AppStateNotifier(this._prefs) : super(const AppState()) {
    _initialize();
  }

  /// Hydrates state from the local cache and the current auth session.
  /// Called automatically on construction.
  void _initialize() {
    final cache = _prefs.getUserCache();
    final user = Supabase.instance.client.auth.currentUser;
    final session = Supabase.instance.client.auth.currentSession;

    state = AppState(
      currentUserId: cache['userId'] ?? user?.id,
      currentUsername: cache['username'],
      currentFullName: cache['fullName'],
      currentEmail: cache['email'] ?? user?.email,
      isLoggedIn: user != null && session != null,
      themeMode: _prefs.getThemeMode(),
      currency: _prefs.getCurrency(),
      reminderEnabled: _prefs.getReminderEnabled(),
      reminderInterval: _prefs.getReminderInterval(),
    );
  }

  /// Call after a successful login to sync user profile data into app state.
  void updateUser({
    required String userId,
    required String username,
    required String fullName,
    required String email,
  }) {
    state = state.copyWith(
      currentUserId: userId,
      currentUsername: username,
      currentFullName: fullName,
      currentEmail: email,
      isLoggedIn: true,
    );
  }

  /// Clears user identity from state, local cache, and signs out from Supabase.
  /// Theme and currency preferences are preserved.
  Future<void> logout() async {
    await _prefs.clearUserCache();
    await Supabase.instance.client.auth.signOut();
    state = AppState(
      themeMode: state.themeMode,
      currency: state.currency,
    );
  }

  /// Refreshes state from local prefs — useful after settings changes.
  void refresh() => _initialize();
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Global app state provider.
///
/// Used by: DashboardScreen (greeting), ProfileScreen (user info),
/// any widget that needs the current user without a Supabase round-trip.
/// Updates when: login, logout, or [AppStateNotifier.refresh] is called.
final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier(PreferencesService());
});
