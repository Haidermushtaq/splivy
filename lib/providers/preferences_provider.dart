import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/preferences_service.dart';

/// Singleton [PreferencesService] — use this instead of calling
/// PreferencesService() directly in widgets so the instance is shared and
/// can be overridden in tests.
final preferencesServiceProvider = Provider<PreferencesService>(
  (ref) => PreferencesService(),
);

/// Reads the currently configured currency symbol (default: 'PKR').
///
/// Used by: expense amounts throughout the app.
/// Updates when: the user changes their currency in settings.
final currencyProvider = Provider<String>(
  (ref) => ref.read(preferencesServiceProvider).getCurrency(),
);
