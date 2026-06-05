import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/preferences_service.dart';
import '../utils/responsive.dart';
import '../widgets/lottie_widget.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    Future.delayed(const Duration(milliseconds: 2500), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final prefs = PreferencesService();

    if (!prefs.isOnboardingDone()) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    final session = Supabase.instance.client.auth.currentSession;

    if (user != null && session != null) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else if (prefs.getLastUserId() != null) {
      // Had a session before — show expired message then go to login.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please log in again.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Image.asset(
                  'assets/images/splivy_logo.png',
                  width: 150,
                  height: 150,
                ),
                const SizedBox(height: 24),
                Text(
                  'Splivy',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: Responsive.fontSize(context, 36),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Split smart. Settle easy.',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: Responsive.fontSize(context, 16)),
                ),
                const Spacer(),
                const LottieWidget(
                  assetPath: 'assets/animations/loading.json',
                  width: 100,
                  height: 100,
                  repeat: true,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
