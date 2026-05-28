import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/group_model.dart';
import '../../models/expense_model.dart';
import '../../providers/groups_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(groupDetailProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(widget.groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(groupDetailProvider(widget.groupId)),
          ),
          IconButton(
              icon: const Icon(Icons.settings_outlined), onPressed: () {}),
        ],
      ),
      body: detailAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
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
                style: ElevatedButton.styleFrom(
                    backgroundColor: _accent),
                child: const Text('Retry',
                    style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
        data: (detail) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(groupDetailProvider(widget.groupId)),
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            children: [
              _buildMembersSection(detail.members),
              const SizedBox(height: 20),
              _buildBalanceCard(detail.group.userBalance),
              const SizedBox(height: 20),
              _buildExpensesSection(detail.expenses),
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
    return Column(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Theme.of(context).cardColor,
          child: const Icon(Icons.add, color: _accent, size: 24),
        ),
        const SizedBox(height: 6),
        const Text(
          'Add',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
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
      balanceText = 'You are owed PKR ${netBalance.toStringAsFixed(0)}';
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
          const Text(
            'Your Balance',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            balanceText,
            style: TextStyle(
              color: balanceColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
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
            child: const Text(
              'Settle Up',
              style: TextStyle(
                  color: _accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesSection(List<Expense> expenses) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Expenses (${expenses.length})',
          style: TextStyle(
              color: onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
        const SizedBox(height: 12),
        if (expenses.isEmpty)
          _buildEmptyState()
        else
          ...expenses.map(_buildExpenseCard),
      ],
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final youOwe = !expense.isSettled &&
        expense.paidByName != 'You' &&
        expense.userShare > 0;
    final youAreOwed = !expense.isSettled &&
        expense.paidByName == 'You' &&
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
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
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 10),
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
