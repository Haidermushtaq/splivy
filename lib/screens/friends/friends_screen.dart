import 'package:flutter/material.dart';
import 'friend_detail_screen.dart';

class _Friend {
  final String name;
  final String username;
  final double balance;
  final String lastActivity;

  const _Friend({
    required this.name,
    required this.username,
    required this.balance,
    required this.lastActivity,
  });
}

const _dummyFriends = [
  _Friend(
      name: 'Ali Khan',
      username: 'ali_khan',
      balance: 500,
      lastActivity: '2 days ago'),
  _Friend(
      name: 'Mohsin Ashraf',
      username: 'mohsin_a',
      balance: -300,
      lastActivity: '5 days ago'),
  _Friend(
      name: 'Shumail Khan',
      username: 'shumail_k',
      balance: 0,
      lastActivity: '1 week ago'),
  _Friend(
      name: 'Haider Zahoor',
      username: 'haider_z',
      balance: 1200,
      lastActivity: '3 days ago'),
];

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  static const _accent = Color(0xFF00D4AA);

  final _searchController = TextEditingController();
  List<_Friend> _filtered = List.from(_dummyFriends);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filtered = _dummyFriends
          .where((f) =>
              f.name.toLowerCase().contains(query.toLowerCase()) ||
              f.username.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _showAddFriendSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddFriendSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () =>
                FocusScope.of(context).requestFocus(FocusNode()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _filtered.isEmpty
                ? _buildEmptyState(onSurface)
                : _buildList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFriendSheet,
        backgroundColor: _accent,
        child: const Icon(Icons.person_add_outlined, color: Colors.black),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
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
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final friend = _filtered[index];
        return _FriendCard(
          friend: friend,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FriendDetailScreen(name: friend.name),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(Color onSurface) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, color: Colors.grey, size: 64),
          const SizedBox(height: 16),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
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
  final _Friend friend;
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
    final balanceColor = isSettled ? Colors.grey : (isOwed ? _accent : _red);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _accent,
                child: Text(
                  friend.name[0].toUpperCase(),
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
                      friend.name,
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
                    const SizedBox(height: 2),
                    Text(
                      'Last expense: ${friend.lastActivity}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11),
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
  const _AddFriendSheet();

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  static const _accent = Color(0xFF00D4AA);

  final _controller = TextEditingController();
  bool _searched = false;
  bool _found = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        _searched = false;
        _found = false;
      });
      return;
    }
    setState(() {
      _searched = value.length >= 3;
      _found = value.contains('@test') || value.contains('test@');
    });
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
          const SizedBox(height: 6),
          const Text(
            'Search by email or username',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            style: TextStyle(color: onSurface),
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Enter email or @username',
              prefixIcon: const Icon(Icons.search, size: 20),
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
                borderSide: const BorderSide(color: _accent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
          if (_searched) ...[
            const SizedBox(height: 16),
            _found ? _buildFoundCard(onSurface) : _buildNotFound(),
          ],
          const SizedBox(height: 20),
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

  Widget _buildFoundCard(Color onSurface) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF00D4AA).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFF00D4AA),
            child: Text(
              'T',
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Test User',
                    style: TextStyle(
                        color: onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 2),
                const Text('@test_user',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4AA),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text(
              'Add Friend',
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return const Center(
      child: Text(
        'No user found with that email or username',
        style: TextStyle(color: Colors.grey, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}
