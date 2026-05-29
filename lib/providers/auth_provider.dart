import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

/// Singleton [AuthService] instance shared across the widget tree.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Stream of Supabase [AuthState] events (signedIn, signedOut, tokenRefreshed…).
///
/// Used by: main.dart — listens for signedOut to redirect to /login and
/// signedIn to schedule payment reminders.
/// Updates when: any Supabase auth event fires.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Derives the currently signed-in [User] from [authStateProvider].
///
/// Returns null when loading or unauthenticated. Falls back to the synchronous
/// [Supabase.instance.client.auth.currentUser] while the stream hasn't emitted
/// yet, preventing a flash of logged-out state on hot restart.
///
/// Used by: any screen that needs to gate UI on auth status.
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) => state.session?.user,
    loading: () => Supabase.instance.client.auth.currentUser,
    error: (_, _) => null,
  );
});

/// Fetches the signed-in user's profile (full name, username, email…) from the
/// database, refreshing the local cache as a side effect.
///
/// Used by: ProfileScreen, app drawer header.
/// Updates when: invalidated after editing the profile.
final myProfileProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.read(authServiceProvider).getMyProfile();
});
