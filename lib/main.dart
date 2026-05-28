import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'utils/page_transitions.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/groups/group_detail_screen.dart';
import 'screens/expenses/add_expense_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settle/settle_up_screen.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('theme_mode') ?? true;
  runApp(
    ProviderScope(
      overrides: [
        themeProvider.overrideWith(
          (ref) => isDark ? ThemeMode.dark : ThemeMode.light,
        ),
      ],
      child: const FairShareApp(),
    ),
  );
}

class FairShareApp extends ConsumerWidget {
  const FairShareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      next.whenData((state) {
        if (state.event == AuthChangeEvent.signedOut) {
          _navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/login', (r) => false);
        }
      });
    });

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'FairShare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      initialRoute: '/',
      onGenerateRoute: _generateRoute,
    );
  }
}

Route<dynamic> _generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return slideRoute(const SplashScreen(), settings);
    case '/login':
      return slideRoute(const LoginScreen(), settings);
    case '/signup':
      return slideRoute(const SignupScreen(), settings);
    case '/dashboard':
      return slideRoute(const DashboardScreen(), settings);
    case '/groups':
      return slideRoute(const GroupsScreen(), settings);
    case '/friends':
      return slideRoute(const FriendsScreen(), settings);
    case '/profile':
      return slideRoute(const ProfileScreen(), settings);
    case '/group-detail':
      final args = settings.arguments as Map<String, dynamic>;
      return slideRoute(
        GroupDetailScreen(
          groupName: args['groupName'] as String,
          groupId: args['groupId'] as String,
        ),
        settings,
      );
    case '/add-expense':
      final args = settings.arguments as Map<String, dynamic>;
      return slideRoute(
        AddExpenseScreen(
          groupId: args['groupId'] as String,
          groupName: args['groupName'] as String,
        ),
        settings,
      );
    case '/settle-up':
      final args = settings.arguments as Map<String, dynamic>?;
      return slideRoute(
        SettleUpScreen(groupId: args?['groupId'] as String?),
        settings,
      );
    default:
      return slideRoute(const SplashScreen(), settings);
  }
}
