import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/preferences_service.dart';

final preferencesServiceProvider = Provider<PreferencesService>(
  (ref) => PreferencesService(),
);

final currencyProvider = Provider<String>(
  (ref) => ref.read(preferencesServiceProvider).getCurrency(),
);
