import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/friend_model.dart';
import '../../providers/friends_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../services/friends_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/lottie_widget.dart';
import '../../widgets/skeleton_loader.dart';
import 'friend_detail_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  static const _accent = Color(0xFF00D4AA);

  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Friend> _filtered(List<Friend> friends) {
    if (_searchQuery.isEmpty) return friends;
    final q = _searchQuery.toLowerCase();
    return friends
        .where((f) =>
            f.fullName.toLowerCase().contains(q) ||
            f.username.toLowerCase().contains(q))
        .toList();
  }

  void _showAddFriendSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddFriendSheet(
        onSent: () {
          ref.invalidate(pendingRequestsProvider);
          ref.invalidate(friendRequestsStreamProvider);
          ref.invalidate(friendsListProvider);
        },
      ),
    );
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      await FriendsService().acceptFriendRequest(requestId);
      ref.invalidate(pendingRequestsProvider);
      ref.invalidate(friendRequestsStreamProvider);
      ref.invalidate(friendsListProvider);
      if (mounted) ErrorHandler.showSuccess(context, 'Friend request accepted!');
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      await FriendsService().rejectFriendRequest(requestId);
      ref.invalidate(pendingRequestsProvider);
      ref.invalidate(friendRequestsStreamProvider);
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsListProvider);
    // Use real-time stream for pending requests so the badge in DashboardScreen
    // and the list here both stay in sync without manual refresh.
    final pendingAsync = ref.watch(friendRequestsStreamProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(friendsListProvider);
              ref.invalidate(pendingRequestsProvider);
              ref.invalidate(friendRequestsStreamProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(friendsListProvider);
          ref.invalidate(pendingRequestsProvider);
          ref.invalidate(friendRequestsStreamProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildSearchBar()),
            pendingAsync.when(
              loading: () => const SliverToBoxAdapter(
                  child: SizedBox.shrink()),
              error: (_, _) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (pending) {
                if (pending.isEmpty) {
                  return const SliverToBoxAdapter(
                      child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                    child: _buildPendingSection(pending, onSurface));
              },
            ),
            friendsAsync.when(
              loading: () => const FriendListSkeleton(),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.grey, size: 48),
                      const SizedBox(height: 12),
                      Text(ErrorHandler.getReadableError(e),
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(friendsListProvider),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _accent),
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),
                ),
              ),
              data: (friends) {
                final filtered = _filtered(friends);
                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                      child: _buildEmptyState(onSurface));
                }
                return SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final friend = filtered[index];
                        return _FriendCard(
                          friend: friend,
                          onTap: () =>
                              Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  FriendDetailScreen(friend: friend),
                            ),
                          ).then((_) {
                            ref.invalidate(friendsListProvider);
                          }),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFriendSheet,
        backgroundColor: _accent,
        child: const Icon(Icons.person_add_outlined,
            color: Colors.black),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (q) => setState(() => _searchQuery = q),
        decoration: InputDecoration(
          hintText: 'Search friends...',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: _accent, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPendingSection(
      List<PendingRequest> pending, Color onSurface) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Friend Requests (${pending.length})',
            style: TextStyle(
                color: onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...pending.map((req) => _buildRequestCard(req, onSurface)),
          const SizedBox(height: 8),
          const Divider(color: Colors.white12),
        ],
      ),
    );
  }

  Widget _buildRequestCard(
      PendingRequest req, Color onSurface) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _accent,
              child: Text(
                req.fullName[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(req.fullName,
                      style: TextStyle(
                          color: onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text('@${req.username}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _acceptRequest(req.id),
              child: const Text(
                'Accept',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _rejectRequest(req.id),
              child: const Text(
                'Decline',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color onSurface) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LottieWidget(
            assetPath: 'assets/animations/empty.json',
            width: 200,
            height: 200,
            repeat: true,
          ),
          Text(
            'No friends yet.',
            style: TextStyle(
                color: onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Connect with friends to split expenses!',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _showAddFriendSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Add your first friend',
              style: TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Friend card ───────────────────────────────────────────────────────────────

class _FriendCard extends StatelessWidget {
  final Friend friend;
  final VoidCallback onTap;

  static const _accent = Color(0xFF00D4AA);
  static const _red = Color(0xFFFF6B6B);

  const _FriendCard({required this.friend, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOwed = friend.balance > 0;
    final isSettled = friend.balance == 0;
    final balanceText = isSettled
        ? 'Settled'
        : isOwed
            ? '+PKR ${friend.balance.toStringAsFixed(0)}'
            : '-PKR ${friend.balance.abs().toStringAsFixed(0)}';
    final balanceColor =
        isSettled ? Colors.grey : (isOwed ? _accent : _red);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _accent,
                child: Text(
                  friend.fullName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.fullName,
                      style: TextStyle(
                          color: onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${friend.username}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    balanceText,
                    style: TextStyle(
                      color: balanceColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right,
                      color: Colors.grey, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add friend bottom sheet ───────────────────────────────────────────────────

class _AddFriendSheet extends StatefulWidget {
  final VoidCallback onSent;
  const _AddFriendSheet({required this.onSent});

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  static const _accent = Color(0xFF00D4AA);

  final _controller = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  bool _hasSearched = false;
  Profile? _foundUser;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _hasSearched = false;
        _foundUser = null;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce =
        Timer(const Duration(milliseconds: 500), () => _search(q));
  }

  Future<void> _search(String query) async {
    try {
      final user = await FriendsService().searchUser(query);
      if (mounted) {
        setState(() {
          _foundUser = user;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _foundUser = null;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    }
  }

  Future<void> _sendRequest(Profile user) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FriendsService().sendFriendRequest(user.id);
      widget.onSent();
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Text('Friend request sent to @${user.username}!'),
        backgroundColor: _accent,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      messenger.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 24,
      ),
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
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Add Friend',
            style: TextStyle(
                color: onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 20),
          ),
          const SizedBox(height: 4),
          const Text(
            'Search by @username or email address',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            style: TextStyle(color: onSurface),
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: '@username or email',
              prefixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _accent),
                      ),
                    )
                  : const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: scaffoldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: _accent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          if (_hasSearched && _foundUser != null)
            _UserResultCard(
                user: _foundUser!, onAdd: () => _sendRequest(_foundUser!))
          else if (_hasSearched && _foundUser == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.search_off, color: Colors.grey, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'No user found with that email or @username',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _UserResultCard extends StatelessWidget {
  final Profile user;
  final VoidCallback onAdd;

  static const _accent = Color(0xFF00D4AA);

  const _UserResultCard({required this.user, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _accent,
              child: Text(
                user.fullName[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName,
                      style: TextStyle(
                          color: onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text('@${user.username}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Add Friend',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
