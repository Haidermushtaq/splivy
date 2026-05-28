import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _client = Supabase.instance.client;

  Future<User?> signUp({
    required String fullName,
    required String username,
    required String email,
    required String password,
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
      data: {'full_name': fullName, 'username': username},
    );

    final user = response.user;
    if (user == null) throw Exception('Sign up failed');

    await _client.from('profiles').insert({
      'id': user.id,
      'full_name': fullName,
      'username': username,
      'email': email,
      'created_at': DateTime.now().toIso8601String(),
    });

    return user;
  }

  Future<Session?> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.session;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? getCurrentUser() => _client.auth.currentUser;

  bool get isLoggedIn => getCurrentUser() != null;
}
