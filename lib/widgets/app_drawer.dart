import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';

class AppDrawer extends StatefulWidget {
  final String currentRoute;
  const AppDrawer({super.key, required this.currentRoute});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  static const _accent = Color(0xFF00D4AA);

  int _reminderHours = 24;

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    return Drawer(
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(context),
          const SizedBox(height: 8),
          _navTile(context, icon: Icons.home_outlined, label: 'Home', route: '/dashboard'),
          _navTile(context, icon: Icons.group_outlined, label: 'My Groups', route: '/groups'),
          _navTile(context, icon: Icons.people_outline, label: 'Friends', route: '/friends'),
          _navTile(context, icon: Icons.receipt_long_outlined, label: 'One-time Expenses', route: '/custom-expenses'),
          _navTile(context, icon: Icons.payments_outlined, label: 'Settle Up', route: '/settle-up'),
          _navTile(context, icon: Icons.history, label: 'History', route: '/history'),
          _navTile(context, icon: Icons.person_outline, label: 'Profile', route: '/profile'),
          Divider(color: dividerColor, indent: 16, endIndent: 16, height: 24),
          _actionTile(
            context,
            icon: Icons.notifications_outlined,
            label: 'Reminder Settings',
            onTap: _showReminderDialog,
          ),
          _actionTile(
            context,
            icon: Icons.info_outline,
            label: 'About Splivy',
            onTap: _showAboutDialog,
          ),
          Divider(color: dividerColor, indent: 16, endIndent: 16, height: 24),
          _actionTile(
            context,
            icon: Icons.logout,
            label: 'Logout',
            onTap: _confirmLogout,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00D4AA), Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(topRight: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 20,
      ),
      child: Builder(
        builder: (context) {
          final cache = PreferencesService().getUserCache();
          final fullName = cache['fullName']?.isNotEmpty == true
              ? cache['fullName']!
              : 'User';
          final username = cache['username']?.isNotEmpty == true
              ? '@${cache['username']}'
              : '';
          final email = cache['email'] ?? '';
          final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/splivy_logo.png',
                    width: 36,
                    height: 36,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Splivy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.black45,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                fullName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (username.isNotEmpty)
                Text(
                  username,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              if (email.isNotEmpty)
                Text(
                  email,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    final active = widget.currentRoute == route;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: active ? _accent : onSurface),
        title: Text(
          label,
          style: TextStyle(
            color: active ? _accent : onSurface,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        tileColor: active ? _accent.withValues(alpha: 0.2) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () {
          if (route == '/dashboard') {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context)
              ..pop()
              ..pushNamed(route);
          }
        },
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final tileColor = color ?? Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: tileColor),
        title: Text(label, style: TextStyle(color: tileColor)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
      ),
    );
  }

  void _showReminderDialog() {
    final cardColor = Theme.of(context).cardColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    int tempHours = _reminderHours;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Reminder Settings',
            style: TextStyle(color: onSurface, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Payment reminder frequency',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...[24, 48, 72].map((h) {
                final selected = tempHours == h;
                return InkWell(
                  onTap: () => setDialogState(() => tempHours = h),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? _accent : Colors.grey,
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
                        const SizedBox(width: 12),
                        Text(
                          'Every ${h}hrs',
                          style: TextStyle(color: onSurface, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                setState(() => _reminderHours = tempHours);
                Navigator.of(ctx).pop();
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
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
            Image.asset(
              'assets/images/splivy_logo.png',
              width: 60,
              height: 60,
            ),
            const SizedBox(width: 10),
            Text(
              'Splivy',
              style: TextStyle(color: onSurface, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Version 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const Text(
              'Split smart. Settle easy.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Text(
              'Team',
              style: TextStyle(
                color: onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            ...['Haider Mushtaq', 'Mohsin Ashraf', 'Shumail Khan', 'Haider Zahoor'].map(
              (name) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, color: _accent, size: 14),
                    const SizedBox(width: 6),
                    Text(name, style: TextStyle(color: onSurface, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    final cardColor = Theme.of(context).cardColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout',
          style: TextStyle(color: onSurface, fontWeight: FontWeight.bold),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService().signOut();
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
