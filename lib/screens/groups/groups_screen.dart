import 'package:flutter/material.dart';
import 'group_detail_screen.dart';

class Group {
  final String name;
  final int memberCount;
  final String lastExpense;
  final double balance;

  const Group({
    required this.name,
    required this.memberCount,
    required this.lastExpense,
    required this.balance,
  });
}

final _dummyGroups = [
  const Group(
    name: 'Roommates',
    memberCount: 3,
    lastExpense: 'Electricity Bill - PKR 2000',
    balance: -1500,
  ),
  const Group(
    name: 'Trip to Murree',
    memberCount: 5,
    lastExpense: 'Hotel Stay - PKR 8000',
    balance: 3200,
  ),
  const Group(
    name: 'Office Lunch',
    memberCount: 4,
    lastExpense: 'Dinner - PKR 500',
    balance: 0,
  ),
];

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  static const _bg = Color(0xFF1A1A2E);
  static const _accent = Color(0xFF00D4AA);
  static const _cardDark = Color(0xFF0F3460);
  static const _red = Color(0xFFFF6B6B);

  final _groupNameController = TextEditingController();
  List<Group> _groups = List.from(_dummyGroups);
  List<Group> _filtered = List.from(_dummyGroups);
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filtered = _groups
          .where((g) => g.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _showCreateGroupDialog() {
    _groupNameController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Group',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _groupNameController,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Group name',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF1A1A2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _accent, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final name = _groupNameController.text.trim();
              if (name.isEmpty) return;
              final newGroup = Group(
                name: name,
                memberCount: 1,
                lastExpense: 'No expenses yet',
                balance: 0,
              );
              setState(() {
                _groups = [newGroup, ..._groups];
                _filtered = [newGroup, ..._filtered];
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Create',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        titleSpacing: 20,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search groups...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : const Text(
                'My Groups',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _searching ? Icons.close : Icons.search,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchController.clear();
                  _filtered = List.from(_groups);
                }
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _filtered.isEmpty ? _buildEmptyState() : _buildList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupDialog,
        backgroundColor: _accent,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _filtered.length,
      itemBuilder: (context, index) => _GroupCard(
        group: _filtered[index],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => GroupDetailScreen(group: _filtered[index])),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_outlined, color: Colors.grey, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No groups yet.',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your first group!',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _showCreateGroupDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create Group',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;

  static const _cardDark = Color(0xFF0F3460);
  static const _accent = Color(0xFF00D4AA);
  static const _red = Color(0xFFFF6B6B);

  const _GroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOwed = group.balance > 0;
    final isSettled = group.balance == 0;
    final balanceColor =
        isSettled ? Colors.grey : (isOwed ? _accent : _red);
    final balanceText = isSettled
        ? 'Settled'
        : isOwed
            ? '+PKR ${group.balance.toStringAsFixed(0)}'
            : '-PKR ${group.balance.abs().toStringAsFixed(0)}';

    return Card(
      color: _cardDark,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: _accent,
                child: Text(
                  group.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${group.memberCount} members',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Last: ${group.lastExpense}',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Balance + arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    balanceText,
                    style: TextStyle(
                      color: balanceColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right,
                      color: Colors.grey, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
