import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/group_model.dart';
import '../../models/expense_model.dart';
import '../../providers/groups_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../services/groups_service.dart';
import '../../services/notification_service.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupName;
  final String groupId;

  const GroupDetailScreen({
    super.key,
    required this.groupName,
    required this.groupId,
  });

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  static const _accent = Color(0xFF00D4AA);
  static const _red = Color(0xFFFF6B6B);

  final _listKey = GlobalKey<AnimatedListState>();
  List<Expense> _expenses = [];
  bool _listInitialized = false;

  // ── helpers ──────────────────────────────────────────────────────────────────

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  IconData _categoryIcon(String category) {
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

  // ── expense list management ───────────────────────────────────────────────────

  void _handleExpensesUpdate(List<Expense> incoming) {
    if (!_listInitialized) {
      setState(() {
        _expenses = List.from(incoming);
        _listInitialized = true;
      });
      return;
    }

    final oldIds = _expenses.map((e) => e.id).toSet();
    final newIds = incoming.map((e) => e.id).toSet();
    final addedIds = newIds.difference(oldIds);
    final removedIds = oldIds.difference(newIds);

    // Insert new expenses at top with slide animation.
    for (final addedId in addedIds) {
      final expense = incoming.firstWhere((e) => e.id == addedId);
      setState(() => _expenses.insert(0, expense));
      _listKey.currentState?.insertItem(0,
          duration: const Duration(milliseconds: 400));

      if (expense.paidBy != _currentUserId && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New expense added! ${expense.title}'),
            backgroundColor: _accent.withValues(alpha: 0.95),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        NotificationService().showExpenseNotification(
          groupName: widget.groupName,
          expenseTitle: expense.title,
          amount: expense.amount,
        );
      }
    }

    // Remove deleted expenses.
    if (removedIds.isNotEmpty) {
      for (int i = _expenses.length - 1; i >= 0; i--) {
        if (removedIds.contains(_expenses[i].id)) {
          final removed = _expenses[i];
          _listKey.currentState?.removeItem(
            i,
            (ctx, animation) => FadeTransition(
              opacity: animation,
              child: _buildExpenseCard(removed),
            ),
          );
          setState(() => _expenses.removeAt(i));
        }
      }
    }

    // Refresh balance + members when the expense list changes.
    if (addedIds.isNotEmpty || removedIds.isNotEmpty) {
      ref.invalidate(groupDetailProvider(widget.groupId));
      ref.invalidate(userGroupsStreamProvider);
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Expense>>>(
      groupExpensesStreamProvider(widget.groupId),
      (_, next) => next.whenData(_handleExpensesUpdate),
    );

    final detailAsync = ref.watch(groupDetailProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(widget.groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(groupDetailProvider(widget.groupId));
              ref.invalidate(groupExpensesStreamProvider(widget.groupId));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(e),
        data: (detail) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(groupDetailProvider(widget.groupId)),
          child: ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _buildMembersSection(detail.members),
              const SizedBox(height: 20),
              _buildBalanceCard(detail.group.userBalance),
              const SizedBox(height: 20),
              _buildExpensesHeader(),
              const SizedBox(height: 12),
              _buildAnimatedExpenseList(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context)
            .pushNamed(
              '/add-expense',
              arguments: {
                'groupId': widget.groupId,
                'groupName': widget.groupName,
              },
            )
            .then((_) =>
                ref.invalidate(groupDetailProvider(widget.groupId))),
        backgroundColor: _accent,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text(
          'Add Expense',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── section widgets ───────────────────────────────────────────────────────────

  Widget _buildError(Object e) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.grey, size: 48),
          const SizedBox(height: 12),
          Text('Error loading group: $e',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                ref.invalidate(groupDetailProvider(widget.groupId)),
            style:
                ElevatedButton.styleFrom(backgroundColor: _accent),
            child: const Text('Retry',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection(List<GroupMember> members) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Members',
          style: TextStyle(
              color: onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: members.length + 1,
            itemBuilder: (context, index) {
              if (index == members.length) {
                return _buildAddMemberButton();
              }
              return _buildMemberAvatar(members[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMemberAvatar(GroupMember member) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: _accent,
            child: Text(
              member.fullName[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            member.fullName.split(' ').first,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMemberButton() {
    return GestureDetector(
      onTap: _showAddMemberDialog,
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Theme.of(context).cardColor,
            child: const Icon(Icons.add, color: _accent, size: 24),
          ),
          const SizedBox(height: 6),
          const Text('Add',
              style: TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  void _showAddMemberDialog() {
    final controller = TextEditingController();
    final cardColor = Theme.of(context).cardColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    bool adding = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Member',
              style: TextStyle(color: onSurface, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the username of a registered user.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: onSurface),
                decoration: InputDecoration(
                  prefixText: '@',
                  prefixStyle: const TextStyle(color: _accent),
                  hintText: 'username',
                  hintStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _accent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: adding ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: adding
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setDialog(() => adding = true);
                      try {
                        final member = await GroupsService()
                            .addMemberByUsername(
                                widget.groupId, controller.text);
                        ref.invalidate(groupDetailProvider(widget.groupId));
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        messenger.showSnackBar(SnackBar(
                          content: Text('${member.fullName} added to group'),
                          backgroundColor: _accent,
                          behavior: SnackBarBehavior.floating,
                        ));
                      } catch (e) {
                        setDialog(() => adding = false);
                        messenger.showSnackBar(SnackBar(
                          content: Text(
                              e.toString().replaceFirst('Exception: ', '')),
                          backgroundColor: _red,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    },
              child: adding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Add',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(double netBalance) {
    final isSettled = netBalance == 0;
    final isOwed = netBalance > 0;

    final String balanceText;
    final Color balanceColor;

    if (isSettled) {
      balanceText = 'All settled!';
      balanceColor = Theme.of(context).colorScheme.onSurface;
    } else if (isOwed) {
      balanceText =
          'You are owed PKR ${netBalance.toStringAsFixed(0)}';
      balanceColor = _accent;
    } else {
      balanceText =
          'You owe PKR ${netBalance.abs().toStringAsFixed(0)}';
      balanceColor = _red;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Balance',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              balanceText,
              key: ValueKey(balanceText),
              style: TextStyle(
                color: balanceColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pushNamed(
              '/settle-up',
              arguments: {'groupId': widget.groupId},
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _accent),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Settle Up',
                style: TextStyle(
                    color: _accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesHeader() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Text(
      'Expenses (${_expenses.length})',
      style: TextStyle(
          color: onSurface, fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

  Widget _buildAnimatedExpenseList() {
    if (!_listInitialized) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_expenses.isEmpty) return _buildEmptyState();

    return AnimatedList(
      key: _listKey,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      initialItemCount: _expenses.length,
      itemBuilder: (context, index, animation) {
        if (index >= _expenses.length) return const SizedBox.shrink();
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(
              parent: animation, curve: Curves.easeOut)),
          child: FadeTransition(
            opacity: animation,
            child: _buildExpenseCard(_expenses[index]),
          ),
        );
      },
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final youOwe = !expense.isSettled &&
        expense.userOwes &&
        expense.userShare > 0;
    final youAreOwed = !expense.isSettled &&
        !expense.userOwes &&
        expense.userShare > 0;

    final shareColor =
        expense.isSettled ? Colors.grey : (youOwe ? _red : _accent);
    final shareText = expense.isSettled
        ? 'Settled'
        : youOwe
            ? 'You owe PKR ${expense.userShare.toStringAsFixed(0)}'
            : youAreOwed
                ? '+PKR ${expense.userShare.toStringAsFixed(0)}'
                : 'PKR ${expense.amount.toStringAsFixed(0)}';

    final paidByText = expense.paidByName == 'You'
        ? 'Paid by You'
        : 'Paid by ${expense.paidByName}';
    final date = expense.createdAt;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _accent.withValues(alpha: 0.15),
              child: Icon(_categoryIcon(expense.category),
                  color: _accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: TextStyle(
                        color: onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(dateText,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(paidByText,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  shareText,
                  style: TextStyle(
                      color: shareColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'PKR ${expense.amount.toStringAsFixed(0)} total',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                color: Colors.grey, size: 48),
            SizedBox(height: 12),
            Text(
              'No expenses yet in this group',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
