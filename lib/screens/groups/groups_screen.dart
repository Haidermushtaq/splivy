import 'package:flutter/material.dart';

class Group {
  final String id;
  final String name;
  final int memberCount;
  final String lastExpense;
  final double balance;

  const Group({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.lastExpense,
    required this.balance,
  });
}

final _dummyGroups = [
  const Group(
    id: 'roommates',
    name: 'Roommates',
    memberCount: 3,
    lastExpense: 'Electricity Bill - PKR 2000',
    balance: -1500,
  ),
  const Group(
    id: 'trip_to_murree',
    name: 'Trip to Murree',
    memberCount: 5,
    lastExpense: 'Hotel Stay - PKR 8000',
    balance: 3200,
  ),
  const Group(
    id: 'office_lunch',
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
  static const _accent = Color(0xFF00D4AA);

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
    final cardColor = Theme.of(context).cardColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Group',
            style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface,
                fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _groupNameController,
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Group name',
            filled: true,
            fillColor: scaffoldBg,
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
                id: name.toLowerCase().replaceAll(' ', '_'),
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 20,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: onSurface),
                decoration: const InputDecoration(
                  hintText: 'Search groups...',
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : const Text('My Groups'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
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
        onTap: () => Navigator.of(context).pushNamed(
          '/group-detail',
          arguments: {
            'groupName': _filtered[index].name,
            'groupId': _filtered[index].id,
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_outlined, color: Colors.grey, size: 64),
          const SizedBox(height: 16),
          Text(
            'No groups yet.',
            style: TextStyle(
                color: onSurface, fontSize: 16, fontWeight: FontWeight.w600),
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
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
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

  static const _accent = Color(0xFF00D4AA);
  static const _red = Color(0xFFFF6B6B);

  const _GroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOwed = group.balance > 0;
    final isSettled = group.balance == 0;
    final balanceColor = isSettled ? Colors.grey : (isOwed ? _accent : _red);
    final balanceText = isSettled
        ? 'Settled'
        : isOwed
            ? '+PKR ${group.balance.toStringAsFixed(0)}'
            : '-PKR ${group.balance.abs().toStringAsFixed(0)}';
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        color: onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${group.memberCount} members',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Last: ${group.lastExpense}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
