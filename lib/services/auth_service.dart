import 'package:supabase_flutter/supabase_flutter.dart';

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

  User? getCurrentUser() => _client.auth.currentUser;

  bool get isLoggedIn => getCurrentUser() != null;
}
