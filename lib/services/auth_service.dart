import 'package:supabase_flutter/supabase_flutter.dart';
import 'preferences_service.dart';

class AuthService {
  final _client = Supabase.instance.client;

  Future<User?> signUp({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String phone,
  }) async {
    final existing = await _client
        .from('profiles')
        .select('username')
        .eq('username', username)
        .maybeSingle();

    if (existing != null) {
      throw Exception('Username already taken');
    }

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'username': username, 'phone': phone},
    );

    final user = response.user;
    if (user == null) throw Exception('Sign up failed');

    return user;
  }

  Future<Session> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final session = response.session;
    if (session == null) throw Exception('Login failed. Please try again.');
    return session;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Sends a password-reset email to the given address.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  User? getCurrentUser() => _client.auth.currentUser;

  bool get isLoggedIn => getCurrentUser() != null;

  /// Fetches the signed-in user's profile from the database and refreshes the
  /// local cache. This is the source of truth the profile UI should rely on,
  /// since the cache is only populated on some login paths.
  Future<Map<String, dynamic>> getMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final profile = await _client
        .from('profiles')
        .select('full_name, username, email, phone, avatar_url')
        .eq('id', user.id)
        .single();

    await PreferencesService().saveUserCache(
      userId: user.id,
      username: profile['username'] as String? ?? '',
      fullName: profile['full_name'] as String? ?? '',
      email: (profile['email'] as String?) ?? user.email ?? '',
    );
    return profile;
  }

  /// Updates the signed-in user's profile and refreshes the local cache.
  Future<void> updateProfile({
    required String fullName,
    required String username,
    String? phone,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final clash = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .neq('id', user.id)
        .maybeSingle();
    if (clash != null) throw Exception('Username already taken');

    await _client.from('profiles').update({
      'full_name': fullName,
      'username': username,
      'phone': ?phone,
    }).eq('id', user.id);

    await PreferencesService().saveUserCache(
      userId: user.id,
      username: username,
      fullName: fullName,
      email: user.email ?? '',
    );
  }
}
