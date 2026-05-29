import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  static const _accent = Color(0xFF00D4AA);
  static const _bg = Color(0xFF1A1A2E);

  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
        if (mounted) setState(() => _cooldown = 0);
      } else {
        if (mounted) setState(() => _cooldown--);
      }
    });
  }

  Future<void> _resendVerificationEmail() async {
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verification email resent!'),
            backgroundColor: _accent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 48),

              Lottie.asset(
                'assets/animations/success.json',
                width: 150,
                height: 150,
                repeat: false,
              ),

              const SizedBox(height: 32),

              const Text(
                'Check Your Email!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'We sent a verification link to:',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),

              const SizedBox(height: 6),

              Text(
                widget.email,
                style: const TextStyle(
                  color: _accent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  'Click the link in the email to verify your account. Check your spam folder if you don\'t see it.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _openUrl('https://mail.google.com'),
                  icon: const Icon(Icons.email, color: Colors.black),
                  label: const Text(
                    'Open Gmail',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _openUrl('https://outlook.live.com'),
                  icon: const Icon(Icons.mail_outline, color: _accent),
                  label: const Text(
                    'Open Outlook',
                    style: TextStyle(color: _accent, fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider(color: Colors.grey)),
                ],
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed('/login'),
                child: const Text(
                  'Already verified? Login',
                  style: TextStyle(color: _accent, fontSize: 15),
                ),
              ),

              _cooldown > 0
                  ? Text(
                      'Resend in ${_cooldown}s',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 14),
                    )
                  : TextButton(
                      onPressed: _resendVerificationEmail,
                      child: const Text(
                        'Didn\'t receive email? Resend',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
