import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/group_model.dart';
import '../../providers/realtime_provider.dart';
import '../../services/groups_service.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  static const _accent = Color(0xFF00D4AA);

  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();
  bool _searching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Group> _filtered(List<Group> groups) {
    if (_searchQuery.isEmpty) return groups;
    return groups
        .where((g) =>
            g.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Future<void> _showCreateGroupDialog() async {
    _groupNameController.clear();
    final cardColor = Theme.of(context).cardColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'New Group',
          style: TextStyle(
              color: Theme.of(ctx).colorScheme.onSurface,
              fontWeight: FontWeight.bold),
        ),
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
            onPressed: () async {
              final name = _groupNameController.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await GroupsService().createGroup(name);
                ref.invalidate(userGroupsStreamProvider);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Failed to create group: $e'),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
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
    // Use real-time stream so the list refreshes when memberships or
    // expenses change without requiring manual pull-to-refresh.
    final groupsAsync = ref.watch(userGroupsStreamProvider);
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
                onChanged: (q) => setState(() => _searchQuery = q),
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
                  _searchQuery = '';
                }
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.grey)),
        ),
        data: (groups) {
          final filtered = _filtered(groups);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(userGroupsStreamProvider),
            child: filtered.isEmpty
                ? _buildEmptyState(onSurface)
                : _buildList(filtered),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupDialog,
        backgroundColor: _accent,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildList(List<Group> groups) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: groups.length,
      itemBuilder: (context, index) => _GroupCard(
        group: groups[index],
        onTap: () => Navigator.of(context).pushNamed(
          '/group-detail',
          arguments: {
            'groupName': groups[index].name,
            'groupId': groups[index].id,
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color onSurface) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.group_outlined, color: Colors.grey, size: 64),
              const SizedBox(height: 16),
              Text(
                'No groups yet.',
                style: TextStyle(
                    color: onSurface,
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create Group',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
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
    final isOwed = group.userBalance > 0;
    final isSettled = group.userBalance == 0;
    final balanceColor =
        isSettled ? Colors.grey : (isOwed ? _accent : _red);
    final balanceText = isSettled
        ? 'Settled'
        : isOwed
            ? '+PKR ${group.userBalance.toStringAsFixed(0)}'
            : '-PKR ${group.userBalance.abs().toStringAsFixed(0)}';
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
