import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A small JSON cache over shared_preferences used as an offline read fallback.
///
/// Every entry is namespaced by the current user id, so switching accounts
/// never serves one user's data to another. Values are any json-encodable
/// structure (maps/lists of primitives) and are stored as JSON strings.
///
/// Caching is strictly best-effort: a failure to read or write the cache must
/// never surface to the caller or break a live request.
class LocalCache {
  LocalCache._();
  static final LocalCache instance = LocalCache._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sp async =>
      _prefs ??= await SharedPreferences.getInstance();

  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? 'anon';

  String _fullKey(String key) => 'cache:$_userId:$key';

  Future<void> write(String key, Object? value) async {
    try {
      final sp = await _sp;
      await sp.setString(_fullKey(key), jsonEncode(value));
    } catch (_) {
      // Best-effort: ignore cache write failures.
    }
  }

  Future<dynamic> read(String key) async {
    try {
      final sp = await _sp;
      final raw = sp.getString(_fullKey(key));
      if (raw == null) return null;
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}

/// True when [e] looks like a loss of connectivity rather than a real backend
/// error (auth failure, constraint violation, etc.). Kept web-safe by matching
/// on the string form instead of importing `dart:io` (SocketException).
bool isOfflineError(Object e) {
  if (e is TimeoutException) return true;
  final s = e.toString().toLowerCase();
  return s.contains('socketexception') ||
      s.contains('failed host lookup') ||
      s.contains('network is unreachable') ||
      s.contains('connection closed') ||
      s.contains('connection refused') ||
      s.contains('connection reset') ||
      s.contains('clientexception') ||
      s.contains('xmlhttprequest') ||
      s.contains('timed out') ||
      s.contains('timeout');
}

/// Runs [live]; on success caches its serialized form under [key] and returns
/// it. If [live] fails with a connectivity error, returns the last cached value
/// decoded via [fromCache]. Any non-network error (or a cache miss while
/// offline) rethrows so real failures still surface.
Future<T> cachedRead<T>({
  required String key,
  required Future<T> Function() live,
  required Object? Function(T value) toCache,
  required T Function(dynamic cached) fromCache,
}) async {
  try {
    final result = await live();
    await LocalCache.instance.write(key, toCache(result));
    return result;
  } catch (e) {
    if (!isOfflineError(e)) rethrow;
    final cached = await LocalCache.instance.read(key);
    if (cached == null) rethrow;
    return fromCache(cached);
  }
}
