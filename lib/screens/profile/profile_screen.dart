import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/groups_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../services/preferences_service.dart';
import '../../services/reminder_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/confirm_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _accent = Color(0xFF00D4AA);

  bool isUploadingAvatar = false;

  void _toggleTheme(bool isDark) {
    ref.read(themeProvider.notifier).setTheme(
        isDark ? ThemeMode.dark : ThemeMode.light);
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
    final profileAsync = ref.watch(myProfileProvider);
    final cache = PreferencesService().getUserCache();

    // Prefer fresh DB values; fall back to the local cache while loading.
    final dbProfile = profileAsync.valueOrNull;
    final fullNameRaw = (dbProfile?['full_name'] as String?)?.isNotEmpty == true
        ? dbProfile!['full_name'] as String
        : (cache['fullName'] ?? '');
    final usernameRaw = (dbProfile?['username'] as String?)?.isNotEmpty == true
        ? dbProfile!['username'] as String
        : (cache['username'] ?? '');
    final emailRaw = (dbProfile?['email'] as String?)?.isNotEmpty == true
        ? dbProfile!['email'] as String
        : (cache['email'] ?? '');

    final fullName = fullNameRaw.isNotEmpty ? fullNameRaw : 'User';
    final username = usernameRaw.isNotEmpty ? '@$usernameRaw' : '';
    final email = emailRaw;
    final avatarUrl = (dbProfile?['avatar_url'] as String?);

    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF0F3460),
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? NetworkImage(avatarUrl)
                  : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white, size: 56)
                  : null,
            ),
            if (isUploadingAvatar)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: _accent),
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: isUploadingAvatar ? null : _pickAndUploadAvatar,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF1A1A2E), width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.black, size: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          fullName,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (username.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            username,
            style: const TextStyle(
              color: _accent,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsRow(Color cardColor) {
    final groupsAsync = ref.watch(userGroupsProvider);
    final friendsAsync = ref.watch(friendsListProvider);

    final groupCount = groupsAsync.valueOrNull?.length ?? 0;
    final friendCount = friendsAsync.valueOrNull?.length ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _StatItem(label: 'Groups', value: '$groupCount'),
          _vDivider(),
          _StatItem(label: 'Friends', value: '$friendCount'),
          _vDivider(),
          const _StatItem(label: 'Version', value: '1.0'),
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
            icon: Icons.edit_outlined,
            label: 'Edit Profile',
            onTap: _showEditProfile,
          ),
          const Divider(color: Colors.white12, height: 1, indent: 56, endIndent: 16),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Reminder Settings',
            onTap: _showReminderSheet,
          ),
          const Divider(color: Colors.white12, height: 1, indent: 56, endIndent: 16),
          _SettingsTile(
            icon: Icons.lock_outline,
            label: 'Change Password',
            onTap: _handleChangePassword,
          ),
          const Divider(color: Colors.white12, height: 1, indent: 56, endIndent: 16),
          _SettingsTile(
            icon: Icons.archive_outlined,
            label: 'Archived Expenses',
            onTap: () =>
                Navigator.of(context).pushNamed('/archived-expenses'),
          ),
          const Divider(color: Colors.white12, height: 1, indent: 56, endIndent: 16),
          _SettingsTile(
            icon: Icons.info_outline,
            label: 'About Splivy',
            onTap: _showAboutDialog,
          ),
          const Divider(color: Colors.white12, height: 1, indent: 56, endIndent: 16),
          _SettingsTile(
            icon: Icons.help_outline,
            label: 'Help & Support',
            onTap: _showHelpDialog,
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

  Future<void> _pickAndUploadAvatar() async {
    // Capture the messenger up front: launching the gallery deactivates this
    // widget, so resolving ScaffoldMessenger.of(context) after the await would
    // throw "deactivated widget's ancestor".
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null) return;
      if (mounted) setState(() => isUploadingAvatar = true);

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      final path = 'avatar_$userId.jpg';
      final bytes = await File(picked.path).readAsBytes();

      await supabase.storage.from('payment-proofs').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final baseUrl =
          supabase.storage.from('payment-proofs').getPublicUrl(path);
      // The path is stable (avatar_<id>.jpg), so the URL never changes and
      // NetworkImage would keep serving the cached old photo. A version query
      // param busts both the CDN and the in-memory image cache.
      final publicUrl =
          '$baseUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      await supabase
          .from('profiles')
          .update({'avatar_url': publicUrl}).eq('id', userId);

      ref.invalidate(myProfileProvider);
      if (mounted) setState(() => isUploadingAvatar = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile picture updated! ✅')),
      );
    } catch (_) {
      if (mounted) setState(() => isUploadingAvatar = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to upload photo. Try again.')),
      );
    }
  }

  Future<void> _showEditProfile() async {
    final profile = ref.read(myProfileProvider).valueOrNull;
    final cache = PreferencesService().getUserCache();
    final nameCtrl = TextEditingController(
        text: (profile?['full_name'] as String?) ?? cache['fullName'] ?? '');
    final userCtrl = TextEditingController(
        text: (profile?['username'] as String?) ?? cache['username'] ?? '');

    final cardColor = Theme.of(context).cardColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          InputDecoration field(String label) => InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _accent),
                ),
              );

          return AlertDialog(
            backgroundColor: cardColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Edit Profile',
                style:
                    TextStyle(color: onSurface, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: onSurface),
                  decoration: field('Full Name'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: userCtrl,
                  style: TextStyle(color: onSurface),
                  decoration: field('Username'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final uname = userCtrl.text.trim();
                        final messenger = ScaffoldMessenger.of(context);
                        if (name.isEmpty || uname.isEmpty) {
                          messenger.showSnackBar(const SnackBar(
                            content: Text('Name and username are required'),
                            backgroundColor: Colors.redAccent,
                          ));
                          return;
                        }
                        setDialog(() => saving = true);
                        try {
                          await AuthService()
                              .updateProfile(fullName: name, username: uname);
                          ref.invalidate(myProfileProvider);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          messenger.showSnackBar(const SnackBar(
                            content: Text('Profile updated!'),
                            backgroundColor: _accent,
                            behavior: SnackBarBehavior.floating,
                          ));
                        } catch (e) {
                          setDialog(() => saving = false);
                          final msg = e.toString().contains('already taken')
                              ? 'Username already taken'
                              : 'Could not update profile';
                          messenger.showSnackBar(SnackBar(
                            content: Text(msg),
                            backgroundColor: Colors.redAccent,
                          ));
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Save',
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAboutDialog() {
    final cardColor = Theme.of(context).cardColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'About Splivy',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet,
                color: _accent, size: 48),
            const SizedBox(height: 8),
            const Text(
              'Splivy',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const Text('v1.0.0',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            const Text(
              'Split smart. Settle easy.',
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontStyle: FontStyle.italic),
            ),
            const Divider(color: Colors.white12, height: 24),
            const Text(
              'Built with ❤️ in Pakistan 🇵🇰',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Developed by:',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ),
            ...['Haider Mushtaq', 'Mohsin Ashraf', 'Shumail Khan', 'Haider Zahoor']
                .map((name) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '• $name',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleChangePassword() async {
    final email =
        AuthService().getCurrentUser()?.email ?? PreferencesService().getUserCache()['email'];
    final messenger = ScaffoldMessenger.of(context);
    if (email == null || email.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No email on file for this account'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }
    try {
      await AuthService().resetPassword(email);
      messenger.showSnackBar(SnackBar(
        content: Text('Password reset link sent to $email'),
        backgroundColor: _accent,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not send reset email. Try again.'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  void _showHelpDialog() {
    final cardColor = Theme.of(context).cardColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: _accent, size: 24),
            const SizedBox(width: 10),
            Text('Help & Support',
                style:
                    TextStyle(color: onSurface, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.email_outlined, color: _accent, size: 18),
                SizedBox(width: 8),
                Text('Email Us',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: GestureDetector(
                onTap: () => launchUrl(
                    Uri.parse('mailto:splivy.support@gmail.com')),
                child: const Text('splivy.support@gmail.com',
                    style: TextStyle(color: _accent, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: const [
                Icon(Icons.bug_report_outlined, color: _accent, size: 18),
                SizedBox(width: 8),
                Text('Report a Bug',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: GestureDetector(
                onTap: () => launchUrl(
                    Uri.parse('https://github.com/Haidermushtaq/splivy/issues')),
                child: const Text('github.com/Haidermushtaq/splivy',
                    style: TextStyle(color: _accent, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: const [
                Icon(Icons.schedule_outlined, color: _accent, size: 18),
                SizedBox(width: 8),
                Text('Response Time',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 26),
              child: Text('We typically respond within 24 hours.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showLogoutDialog(context);
    if (confirmed != true || !mounted) return;
    // Capture before the next await: signing out tears down this screen, so
    // resolving these from context afterwards throws "deactivated widget's
    // ancestor".
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService().signOut();
      await PreferencesService().clearAll();
      await NotificationService().cancelAllNotifications();
      rootNavigator.pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Logout failed. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
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
