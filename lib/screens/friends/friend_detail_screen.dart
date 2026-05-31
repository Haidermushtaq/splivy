import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/friend_model.dart';
import '../../providers/friends_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../services/friends_service.dart';

class FriendDetailScreen extends ConsumerStatefulWidget {
  final Friend friend;

  const FriendDetailScreen({super.key, required this.friend});

  @override
  ConsumerState<FriendDetailScreen> createState() =>
      _FriendDetailScreenState();
}

class _FriendDetailScreenState extends ConsumerState<FriendDetailScreen> {
  static const _accent = Color(0xFF00D4AA);
  static const _red = Color(0xFFFF6B6B);

  late Future<List<String>> _sharedGroupsFuture;

  @override
  void initState() {
    super.initState();
    _sharedGroupsFuture =
        FriendsService().getSharedGroupNames(widget.friend.friendId);
  }

  void _showBreakdown() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BreakdownSheet(friend: widget.friend),
    );
  }

  Future<void> _removeFriend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
            'Remove ${widget.friend.fullName} from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FriendsService().removeFriend(widget.friend.id);
      ref.invalidate(friendsListProvider);
      ref.invalidate(friendRequestsStreamProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to remove friend: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final isOwed = friend.balance > 0;
    final isSettled = friend.balance == 0;
    final balanceColor =
        isSettled ? Colors.grey : (isOwed ? _accent : _red);
    final balanceLabel = isSettled
        ? 'All settled up'
        : isOwed
            ? '${friend.fullName} owes you'
            : 'You owe ${friend.fullName}';
    final balanceText = isSettled
        ? ''
        : 'PKR ${friend.balance.abs().toStringAsFixed(0)}';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(friend.fullName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'remove') _removeFriend();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.person_remove_outlined,
                        color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Remove Friend',
                        style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile card ───────────────────────────────────────────
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: _accent,
                      child: Text(
                        friend.fullName[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(friend.fullName,
                              style: TextStyle(
                                  color: onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          const SizedBox(height: 2),
                          Text('@${friend.username}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                          if (friend.email.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(friend.email,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Balance card ───────────────────────────────────────────
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: isSettled ? null : _showBreakdown,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        isSettled
                            ? Icons.check_circle_outline
                            : isOwed
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                        color: balanceColor,
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(balanceLabel,
                                style: TextStyle(
                                    color: balanceColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            if (balanceText.isNotEmpty)
                              Text(balanceText,
                                  style: TextStyle(
                                      color: balanceColor,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (!isSettled)
                        const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Shared groups ──────────────────────────────────────────
            Text('Shared Groups',
                style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 10),
            FutureBuilder<List<String>>(
              future: _sharedGroupsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                        color: _accent, strokeWidth: 2),
                  ));
                }
                final groups = snap.data ?? [];
                if (groups.isEmpty) {
                  return const Text('No shared groups',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 13));
                }
                return Column(
                  children: groups
                      .map((name) => Card(
                            margin:
                                const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: _accent.withValues(alpha: 0.15),
                                child: const Icon(
                                    Icons.group_outlined,
                                    color: _accent,
                                    size: 18),
                              ),
                              title: Text(name,
                                  style: TextStyle(
                                      color: onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 32),

            // ── Settle up button ───────────────────────────────────────
            if (!isSettled)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed(
                    '/settle-up',
                    arguments: {'groupId': null},
                  ),

                  icon: const Icon(Icons.handshake_outlined,
                      color: Colors.black),
                  label: const Text(
                    'Settle Up',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing every unsettled expense between the user and a friend,
/// split into what they owe and what the user owes, with a net total.
class _BreakdownSheet extends StatelessWidget {
  final Friend friend;
  const _BreakdownSheet({required this.friend});

  static const _accent = Color(0xFF00D4AA);
  static const _red = Color(0xFFFF6B6B);

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return FutureBuilder<List<FriendExpense>>(
          future: FriendsService().getExpensesWithFriend(friend.friendId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(
                    child: CircularProgressIndicator(
                        color: _accent, strokeWidth: 2)),
              );
            }
            final items = snap.data ?? [];
            final outstanding =
                items.where((e) => !e.isSettled).toList();
            final history = items.where((e) => e.isSettled).toList();
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Expenses with ${friend.fullName}',
                  style: TextStyle(
                      color: onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No expenses together yet',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 14)),
                    ),
                  ),
                if (outstanding.isNotEmpty) ...[
                  _sectionLabel(context, 'Outstanding'),
                  ...outstanding.map((e) => _row(context, e)),
                ],
                if (history.isNotEmpty) ...[
                  if (outstanding.isNotEmpty) const SizedBox(height: 12),
                  _sectionLabel(context, 'Offsetting history'),
                  ...history.map((e) => _row(context, e)),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5),
      ),
    );
  }

  Widget _row(BuildContext context, FriendExpense e) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final color = e.isSettled
        ? Colors.grey
        : (e.theyOweMe ? _accent : _red);
    final label = e.isSettled
        ? (e.isNetted ? 'Auto-settled' : 'Settled')
        : (e.theyOweMe ? 'Owes you' : 'You owe');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(
              e.isSettled
                  ? (e.isNetted ? Icons.swap_horiz_rounded : Icons.check_rounded)
                  : (e.theyOweMe
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded),
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: e.isSettled ? Colors.grey : onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: e.isSettled
                            ? TextDecoration.lineThrough
                            : null)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      e.groupName == null
                          ? Icons.receipt_long_outlined
                          : Icons.group_outlined,
                      color: Colors.grey,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${e.source} • ${_formatDate(e.date)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('PKR ${e.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: TextStyle(color: color, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
