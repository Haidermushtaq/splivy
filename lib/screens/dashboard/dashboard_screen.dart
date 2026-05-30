import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../groups/groups_screen.dart';
import '../friends/friends_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/connection_status_bar.dart';
import '../../providers/realtime_provider.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/groups_provider.dart';
import '../../providers/friends_provider.dart';
import '../../services/expenses_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/skeleton_loader.dart';

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
    final appState = ref.watch(appStateProvider);
    final firstName = appState.currentFullName?.split(' ').first ?? '';
    final greeting =
        firstName.isNotEmpty ? 'Welcome back, $firstName!' : 'Welcome back!';

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
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(userBalanceStreamProvider);
            ref.invalidate(userGroupsProvider);
            ref.invalidate(recentExpensesProvider);
            ref.invalidate(friendsListProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Dashboard refreshed!'),
                  ],
                ),
                backgroundColor: Color(0xFF00D4AA),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 4),
          child: GestureDetector(
            onTap: () => setState(() => _currentIndex = 3),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).cardColor,
              child: const Icon(Icons.person, color: Colors.grey, size: 20),
            ),
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
          const _RecentActivityList(),
        ],
      ),
    );
  }
}

class _RecentActivityList extends ConsumerWidget {
  const _RecentActivityList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentExpensesProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF00D4AA))),
      ),
      error: (_, _) => const _EmptyActivity(),
      data: (items) {
        if (items.isEmpty) return const _EmptyActivity();
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _RecentExpenseCard(expense: items[i]),
        );
      },
    );
  }
}

class _RecentExpenseCard extends StatelessWidget {
  final RecentExpense expense;
  const _RecentExpenseCard({required this.expense});

  static IconData _categoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant_outlined;
      case 'Transport':
        return Icons.directions_car_outlined;
      case 'Shopping':
        return Icons.shopping_bag_outlined;
      case 'Utilities':
        return Icons.bolt_outlined;
      case 'Entertainment':
        return Icons.movie_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isGroup = expense.groupId != null && !expense.isCustom;
    final Color chipColor =
        isGroup ? const Color(0xFF00D4AA) : const Color(0xFFFF6B6B);
    final String chipLabel = isGroup ? 'Group' : 'One-time';

    final subtitleParts = <String>[
      if (expense.groupName != null && expense.groupName!.isNotEmpty)
        expense.groupName!,
      expense.paidByName,
      _formatDate(expense.createdAt),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1A1A2E),
          child: Icon(_categoryIcon(expense.category),
              color: const Color(0xFF00D4AA)),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                expense.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                chipLabel,
                style: TextStyle(
                    color: chipColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitleParts.join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'PKR ${expense.amount.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              expense.isPayer
                  ? 'You paid'
                  : 'Your share: PKR ${expense.userShare.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Color(0xFFFF6B6B), fontSize: 11),
            ),
          ],
        ),
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
      loading: () => const BalanceCardSkeleton(),
      error: (e, _) =>
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
    return 'PKR ${net.abs().toStringAsFixed(2)}';
  }

  String _netLabel(double net) {
    if (net.abs() < 0.01) return 'All settled up';
    return net > 0 ? "You're owed overall" : 'You owe overall';
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
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/settle-up'),
        borderRadius: BorderRadius.circular(20),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    _netLabel(netBalance),
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
                const Text(
                  'View details',
                  style: TextStyle(color: Color(0xFF00D4AA), fontSize: 12),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF00D4AA), size: 16),
              ],
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

void _showAddExpenseChooser(BuildContext context) {
  final onSurface = Theme.of(context).colorScheme.onSurface;
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text('Add Expense',
                style: TextStyle(
                    color: onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _ChooserTile(
              icon: Icons.group_outlined,
              title: 'Add to a group',
              subtitle: 'Split with members of one of your groups',
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushNamed('/groups');
              },
            ),
            const SizedBox(height: 12),
            _ChooserTile(
              icon: Icons.receipt_long_outlined,
              title: 'One-time expense',
              subtitle: 'Split once with friends or guests — no group needed',
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushNamed('/add-one-time');
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChooserTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  static const _accent = Color(0xFF00D4AA);

  const _ChooserTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final fillColor =
        Theme.of(context).inputDecorationTheme.fillColor ??
            Theme.of(context).scaffoldBackgroundColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
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
          onTap: () => _showAddExpenseChooser(context),
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
