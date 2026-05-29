import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../services/reminder_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _accent = Color(0xFF00D4AA);

  void _toggleTheme(bool isDark) {
    ref.read(themeProvider.notifier).state =
        isDark ? ThemeMode.dark : ThemeMode.light;
    saveThemePreference(isDark);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final cs = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 28),
              _buildAvatarSection(cs),
              const SizedBox(height: 24),
              _buildStatsRow(cardColor),
              const SizedBox(height: 28),
              _buildThemeToggle(isDark, cardColor),
              const SizedBox(height: 16),
              _buildSettingsList(cardColor),
              const SizedBox(height: 28),
              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(ColorScheme cs) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 52,
              backgroundColor: _accent,
              child: const Icon(Icons.person, color: Colors.black, size: 56),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2),
                ),
                child: Icon(Icons.edit_outlined, color: cs.onSurface, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Haider Mushtaq',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '@haider_mushtaq',
          style: TextStyle(
            color: _accent,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'haider@example.com',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildStatsRow(Color cardColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _StatItem(label: 'Groups', value: '3'),
          _vDivider(),
          _StatItem(label: 'Friends', value: '4'),
          _vDivider(),
          _StatItem(label: 'Expenses', value: '12'),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 36, color: Colors.white12);

  Widget _buildThemeToggle(bool isDark, Color cardColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        value: isDark,
        onChanged: _toggleTheme,
        activeThumbColor: _accent,
        secondary: Icon(
          isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        title: Text(
          'Dark Mode',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          isDark ? 'Switch to light theme' : 'Switch to dark theme',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildSettingsList(Color cardColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Reminder Settings',
            onTap: _showReminderSheet,
          ),
          const Divider(color: Colors.white12, height: 1, indent: 56, endIndent: 16),
          _SettingsTile(
            icon: Icons.lock_outline,
            label: 'Change Password',
            onTap: () => _showComingSoon('Change Password'),
          ),
          const Divider(color: Colors.white12, height: 1, indent: 56, endIndent: 16),
          _SettingsTile(
            icon: Icons.info_outline,
            label: 'About FairShare',
            onTap: _showAboutDialog,
          ),
          const Divider(color: Colors.white12, height: 1, indent: 56, endIndent: 16),
          _SettingsTile(
            icon: Icons.help_outline,
            label: 'Help & Support',
            onTap: () => _showComingSoon('Help & Support'),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton(
        onPressed: _confirmLogout,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'Logout',
          style: TextStyle(
              color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _showReminderSheet() async {
    final svc = ReminderService();
    final settings = await svc.getReminderSettings();

    if (!mounted) return;

    bool enabled = settings.enabled;
    int selectedHours = settings.intervalHours;

    const intervals = [
      (hours: 12, label: 'Every 12 hours'),
      (hours: 24, label: 'Every 24 hours'),
      (hours: 48, label: 'Every 48 hours'),
      (hours: 72, label: 'Every 72 hours'),
      (hours: 168, label: 'Every week'),
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final onSurface = Theme.of(ctx).colorScheme.onSurface;
          final cardColor = Theme.of(ctx).cardColor;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  Text(
                    'Reminder Settings',
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Enable toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: _accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_outlined,
                            color: _accent, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Payment Reminders',
                            style: TextStyle(
                                color: onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        CupertinoSwitch(
                          value: enabled,
                          activeTrackColor: _accent,
                          onChanged: (val) => setSheet(() => enabled = val),
                        ),
                      ],
                    ),
                  ),

                  if (enabled) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Remind me every:',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    ...intervals.map((opt) {
                      final selected = selectedHours == opt.hours;
                      return GestureDetector(
                        onTap: () =>
                            setSheet(() => selectedHours = opt.hours),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? _accent.withValues(alpha: 0.12)
                                : cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? _accent
                                  : Colors.white12,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        selected ? _accent : Colors.grey,
                                    width: 2,
                                  ),
                                ),
                                child: selected
                                    ? Center(
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _accent,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Text(
                                opt.label,
                                style: TextStyle(
                                  color: selected ? _accent : onSurface,
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Text(
                      'Next reminder in: $selectedHours hours',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await svc.saveReminderSettings(
                            selectedHours, enabled);
                        await svc.scheduleAllReminders();
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Reminder settings saved!'),
                              backgroundColor: _accent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Save Settings',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAboutDialog() {
    final cardColor = Theme.of(context).cardColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded,
                color: _accent, size: 24),
            const SizedBox(width: 10),
            Text('FairShare',
                style: TextStyle(color: onSurface, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Version 1.0.0',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            Text('Built by',
                style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: 8),
            ...['Haider Mushtaq', 'Mohsin Ashraf', 'Shumail Khan', 'Haider Zahoor']
                .map((name) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline,
                              color: _accent, size: 14),
                          const SizedBox(width: 6),
                          Text(name,
                              style: TextStyle(color: onSurface, fontSize: 13)),
                        ],
                      ),
                    )),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close',
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    final cardColor = Theme.of(context).cardColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(feature,
            style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface,
                fontWeight: FontWeight.bold)),
        content: const Text(
          'This feature is coming soon!',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK',
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    final cardColor = Theme.of(context).cardColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout',
          style: TextStyle(
              color: Theme.of(ctx).colorScheme.onSurface,
              fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await AuthService().signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login', (route) => false);
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logout failed. Please try again.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Logout',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  static const _accent = Color(0xFF00D4AA);

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: Radius.zero,
        bottom: isLast ? const Radius.circular(14) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    color: onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
