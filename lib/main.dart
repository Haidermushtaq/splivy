import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'config/supabase_config.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/realtime_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/preferences_provider.dart';
import 'providers/app_state_provider.dart';
import 'providers/expenses_provider.dart';
import 'providers/groups_provider.dart';
import 'providers/friends_provider.dart';
import 'services/notification_service.dart';
import 'services/preferences_service.dart';
import 'services/reminder_service.dart';
import 'utils/page_transitions.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/groups/group_detail_screen.dart';
import 'screens/groups/group_expense_detail_screen.dart';
import 'screens/expenses/add_expense_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/expenses/custom_expenses_screen.dart';
import 'screens/expenses/one_time_expense_screen.dart';
import 'screens/expenses/archived_expenses_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/history/settlement_history_screen.dart';
import 'screens/settle/settle_up_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

/// Drops every cached, user-specific provider so a fresh sign-in (possibly a
/// different account) never sees the previous user's profile, balance, groups,
/// friends, or expense feed. The stream providers re-read currentUser on
/// rebuild, so this also re-points realtime subscriptions at the new user.
void _resetUserScopedState(WidgetRef ref) {
  ref.invalidate(myProfileProvider);
  ref.invalidate(userBalanceProvider);
  ref.invalidate(recentExpensesProvider);
  ref.invalidate(archivedExpensesProvider);
  ref.invalidate(customExpensesProvider);
  ref.invalidate(userGroupsProvider);
  ref.invalidate(userGroupsStreamProvider);
  ref.invalidate(selectedGroupProvider);
  ref.invalidate(friendsListProvider);
  ref.invalidate(pendingRequestsProvider);
  ref.invalidate(friendRequestsStreamProvider);
  ref.invalidate(friendRequestNotificationProvider);
}

void _handleNotificationTap(String? payload) {
  final nav = _navigatorKey.currentState;
  if (nav == null || payload == null) return;

  if (payload == 'settle_up' ||
      payload.startsWith('confirm_payment_') ||
      payload == 'payment_confirmed') {
    nav.pushNamed('/settle-up');
  } else if (payload.startsWith('group_')) {
    nav.pushNamed('/groups');
  } else if (payload == 'friends') {
    nav.pushNamed('/friends');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final prefsService = PreferencesService();
  await prefsService.initialize();

  await NotificationService().initialize(onTap: _handleNotificationTap);

  // Deep link handling for email verification callback
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    if (uri.host == 'login-callback') {
      final accessToken = uri.queryParameters['access_token'];
      if (accessToken != null) {
        _navigatorKey.currentState?.pushReplacementNamed('/dashboard');
      }
    }
  });

  runApp(
    ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(prefsService),
      ],
      child: const SplivyApp(),
    ),
  );
}

class SplivyApp extends ConsumerWidget {
  const SplivyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      next.whenData((state) {
        if (state.event == AuthChangeEvent.signedOut) {
          PreferencesService().clearUserCache();
          _resetUserScopedState(ref);
          ref.read(appStateProvider.notifier).refresh();
          _navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/login', (r) => false);
        }
        if (state.event == AuthChangeEvent.signedIn) {
          // A different account may have signed in; drop every cached,
          // user-scoped value so nothing from the previous session leaks through.
          _resetUserScopedState(ref);
          ReminderService().scheduleAllReminders();
        }
      });
    });

    // Keep friend-request notification listener alive for the app lifetime.
    ref.watch(friendRequestNotificationProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Splivy',
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
    case '/onboarding':
      return slideRoute(const OnboardingScreen(), settings);
    case '/login':
      return slideRoute(const LoginScreen(), settings);
    case '/signup':
      return slideRoute(const SignupScreen(), settings);
    case '/email-verification':
      final args = settings.arguments as Map<String, dynamic>;
      return slideRoute(
        EmailVerificationScreen(email: args['email'] as String),
        settings,
      );
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
    case '/group-expense-detail':
      final args = settings.arguments as Map<String, dynamic>;
      return slideRoute(
        GroupExpenseDetailScreen(
          expenseId: args['expenseId'] as String,
          groupName: args['groupName'] as String?,
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
    case '/custom-expenses':
      return slideRoute(const CustomExpensesScreen(), settings);
    case '/add-one-time':
      return slideRoute(const OneTimeExpenseScreen(), settings);
    case '/archived-expenses':
      return slideRoute(const ArchivedExpensesScreen(), settings);
    case '/history':
      return slideRoute(const HistoryScreen(), settings);
    case '/settlement-history':
      return slideRoute(const SettlementHistoryScreen(), settings);
    default:
      return slideRoute(const SplashScreen(), settings);
  }
}
