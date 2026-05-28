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
                  ],
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
