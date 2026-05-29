import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../groups/groups_screen.dart';
import '../friends/friends_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/connection_status_bar.dart';
import '../../providers/realtime_provider.dart';
import '../../services/notification_service.dart';
import '../../services/preferences_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;
  int _prevPendingCount = 0;

  String get _currentRoute {
    const routes = ['/dashboard', '/groups', '/friends', '/profile'];
    return routes[_currentIndex];
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Exit FairShare?',
          style: TextStyle(
              color: Theme.of(ctx).colorScheme.onSurface,
              fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to exit?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Exit',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(friendRequestsStreamProvider);
    final pendingCount = pendingAsync.value?.length ?? 0;

    // Notify when a new friend request arrives.
    ref.listen<AsyncValue<List>>(friendRequestsStreamProvider, (prev, next) {
      next.whenData((requests) {
        final count = requests.length;
        if (count > _prevPendingCount && _prevPendingCount >= 0) {
          final newest = requests.first;
          NotificationService().showFriendRequestNotification(
            (newest as dynamic).username as String,
          );
        }
        _prevPendingCount = count;
      });
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitDialog();
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        drawer: AppDrawer(currentRoute: _currentRoute),
        body: Column(
          children: [
            const ConnectionStatusBar(),
            Expanded(child: _buildBody()),
          ],
        ),
        bottomNavigationBar:
            _buildBottomNav(pendingCount),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final cache = PreferencesService().getUserCache();
    final fullName = cache['fullName'] ?? '';
    final firstName = fullName.split(' ').first;
    final greeting = firstName.isNotEmpty
        ? 'Welcome back, $firstName!'
        : 'Welcome back!';

    return AppBar(
      titleSpacing: 12,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'FairShare',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            greeting,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 4),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).cardColor,
            child: const Icon(Icons.person, color: Colors.grey, size: 20),
          ),
        ),
      ],
    );
  }

  BottomNavigationBar _buildBottomNav(int pendingCount) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      items: [
        const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined), label: 'Home'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined), label: 'Groups'),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.people_outline),
              if (pendingCount > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      pendingCount > 9 ? '9+' : '$pendingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          label: 'Friends',
        ),
        const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), label: 'Profile'),
      ],
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const _HomeTab();
      case 1:
        return const GroupsScreen();
      case 2:
        return const FriendsScreen();
      case 3:
        return const ProfileScreen();
      default:
        return _PlaceholderTab(label: _tabLabel(_currentIndex));
    }
  }

  String _tabLabel(int index) {
    const labels = ['Home', 'Groups', 'Friends', 'Profile'];
    return labels[index];
  }
}

// ── Home tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SummaryCard(),
          const SizedBox(height: 24),
          const _QuickActions(),
          const SizedBox(height: 28),
          Text(
            'Recent Activity',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const _EmptyActivity(),
        ],
      ),
    );
  }
}

class _SummaryCard extends ConsumerStatefulWidget {
  const _SummaryCard();

  @override
  ConsumerState<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends ConsumerState<_SummaryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  String? _prevNetText;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerPulse() {
    _pulseController.forward().then((_) => _pulseController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(userBalanceStreamProvider);

    return balanceAsync.when(
      loading: () =>
          _buildCard(context, netBalance: 0, totalOwed: 0, totalOwing: 0),
      error: (e, st) =>
          _buildCard(context, netBalance: 0, totalOwed: 0, totalOwing: 0),
      data: (balance) {
        final netText = _formatNet(balance.netBalance);
        if (_prevNetText != null && _prevNetText != netText) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _triggerPulse());
        }
        _prevNetText = netText;
        return _buildCard(
          context,
          netBalance: balance.netBalance,
          totalOwed: balance.totalOwed,
          totalOwing: balance.totalOwing,
        );
      },
    );
  }

  String _formatNet(double net) {
    if (net == 0) return 'PKR 0.00';
    return net > 0
        ? '+PKR ${net.toStringAsFixed(2)}'
        : '-PKR ${net.abs().toStringAsFixed(2)}';
  }

  Widget _buildCard(
    BuildContext context, {
    required double netBalance,
    required double totalOwed,
    required double totalOwing,
  }) {
    final netColor = netBalance >= 0
        ? const Color(0xFF00D4AA)
        : const Color(0xFFFF6B6B);
    final netText = _formatNet(netBalance);

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F3460), Color(0xFF1A6B5A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00D4AA).withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Balance',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Text(
                netText,
                key: ValueKey(netText),
                style: TextStyle(
                  color: netColor,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white12, thickness: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _BalanceStat(
                    label: 'You Owe',
                    amount: 'PKR ${totalOwing.toStringAsFixed(2)}',
                    color: const Color(0xFFFF6B6B),
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
                const SizedBox(
                    width: 1,
                    height: 40,
                    child: ColoredBox(color: Colors.white12)),
                Expanded(
                  child: _BalanceStat(
                    label: "You're Owed",
                    amount: 'PKR ${totalOwed.toStringAsFixed(2)}',
                    color: const Color(0xFF00D4AA),
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  const _BalanceStat({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            amount,
            key: ValueKey(amount),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActionButton(
          icon: Icons.add_circle_outline,
          label: 'Add Expense',
          onTap: () => Navigator.of(context).pushNamed('/groups'),
        ),
        _ActionButton(
          icon: Icons.check_circle_outline,
          label: 'Settle Up',
          onTap: () => Navigator.of(context).pushNamed('/settle-up'),
        ),
        _ActionButton(
          icon: Icons.receipt_long_outlined,
          label: 'One-time',
          onTap: () =>
              Navigator.of(context).pushNamed('/custom-expenses'),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  static const _accent = Color(0xFF00D4AA);

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _accent, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.receipt_long_outlined,
              color: Colors.grey, size: 56),
          const SizedBox(height: 16),
          Text(
            'No expenses yet.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your first expense!',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Placeholder tab ───────────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  final String label;
  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction_outlined,
              color: Colors.grey, size: 48),
          const SizedBox(height: 16),
          Text(
            '$label coming soon',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
