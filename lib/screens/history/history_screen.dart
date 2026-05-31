import 'package:flutter/material.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../services/expenses_service.dart';
import '../../services/groups_service.dart';
import '../expenses/one_time_expense_detail_screen.dart';

const _accent = Color(0xFF00D4AA);

/// Entry point for browsing all past activity: one-time expenses and groups,
/// including archived/settled records that the live screens hide.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('History')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          _HubTile(
            icon: Icons.receipt_long_outlined,
            title: 'One-time Expenses',
            subtitle: 'All one-time bills, settled and active',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const _OneTimeHistoryScreen(),
            )),
          ),
          const SizedBox(height: 12),
          _HubTile(
            icon: Icons.group_outlined,
            title: 'Groups',
            subtitle: 'Every group and its full expense history',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const _GroupsHistoryScreen(),
            )),
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

Widget _loading() =>
    const Center(child: CircularProgressIndicator(color: _accent));

Widget _error(Object e) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Error: $e',
          style: const TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ),
    );

Widget _empty(BuildContext context, IconData icon, String text) => Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey, size: 56),
          const SizedBox(height: 14),
          Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

/// All one-time expenses the user created, archived included.
class _OneTimeHistoryScreen extends StatefulWidget {
  const _OneTimeHistoryScreen();

  @override
  State<_OneTimeHistoryScreen> createState() => _OneTimeHistoryScreenState();
}

class _OneTimeHistoryScreenState extends State<_OneTimeHistoryScreen> {
  late Future<List<CustomExpenseDetail>> _future;

  @override
  void initState() {
    super.initState();
    _future = ExpensesService().getCustomExpenses(includeArchived: true);
  }

  void _reload() {
    setState(() {
      _future = ExpensesService().getCustomExpenses(includeArchived: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('One-time Expenses')),
      body: FutureBuilder<List<CustomExpenseDetail>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _loading();
          }
          if (snap.hasError) return _error(snap.error!);
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return _empty(
                context, Icons.receipt_long_outlined, 'No one-time expenses');
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final detail = items[i];
                final e = detail.expense;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          OneTimeExpenseDetailScreen(detail: detail),
                    )),
                    title: Text(
                      e.title,
                      style: TextStyle(
                          color: onSurface, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _formatDate(e.createdAt),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'PKR ${e.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: _accent, fontWeight: FontWeight.bold),
                        ),
                        if (detail.allSettled)
                          const Text('Settled',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Every group the user belongs to, archived included.
class _GroupsHistoryScreen extends StatefulWidget {
  const _GroupsHistoryScreen();

  @override
  State<_GroupsHistoryScreen> createState() => _GroupsHistoryScreenState();
}

class _GroupsHistoryScreenState extends State<_GroupsHistoryScreen> {
  late Future<List<Group>> _future;

  @override
  void initState() {
    super.initState();
    _future = GroupsService().getUserGroups(includeArchived: true);
  }

  void _reload() {
    setState(() {
      _future = GroupsService().getUserGroups(includeArchived: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Groups')),
      body: FutureBuilder<List<Group>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _loading();
          }
          if (snap.hasError) return _error(snap.error!);
          final groups = snap.data ?? [];
          if (groups.isEmpty) {
            return _empty(context, Icons.group_outlined, 'No groups yet');
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final g = groups[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _GroupExpensesHistoryScreen(
                          groupId: g.id, groupName: g.name),
                    )),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.group, color: _accent),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            g.name,
                            style: TextStyle(
                                color: onSurface, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (g.isArchived) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Archived',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 10)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${g.memberCount} member${g.memberCount == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.grey),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Every expense in one group, archived included. Tapping an expense opens the
/// full group expense detail (which shows the in-expense offsetting history).
class _GroupExpensesHistoryScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const _GroupExpensesHistoryScreen({
    required this.groupId,
    required this.groupName,
  });

  @override
  State<_GroupExpensesHistoryScreen> createState() =>
      _GroupExpensesHistoryScreenState();
}

class _GroupExpensesHistoryScreenState
    extends State<_GroupExpensesHistoryScreen> {
  late Future<List<Expense>> _future;

  @override
  void initState() {
    super.initState();
    _future =
        ExpensesService().getGroupExpenses(widget.groupId, includeArchived: true);
  }

  void _reload() {
    setState(() {
      _future = ExpensesService()
          .getGroupExpenses(widget.groupId, includeArchived: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(elevation: 0, title: Text(widget.groupName)),
      body: FutureBuilder<List<Expense>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _loading();
          }
          if (snap.hasError) return _error(snap.error!);
          final expenses = snap.data ?? [];
          if (expenses.isEmpty) {
            return _empty(
                context, Icons.receipt_long_outlined, 'No expenses yet');
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: expenses.length,
              itemBuilder: (context, i) {
                final e = expenses[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    onTap: () => Navigator.of(context).pushNamed(
                      '/group-expense-detail',
                      arguments: {
                        'expenseId': e.id,
                        'groupName': widget.groupName,
                      },
                    ),
                    title: Text(
                      e.title,
                      style: TextStyle(
                          color: onSurface, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${e.paidByName} • ${_formatDate(e.createdAt)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'PKR ${e.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: _accent, fontWeight: FontWeight.bold),
                        ),
                        if (e.isSettled)
                          const Text('Settled',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
