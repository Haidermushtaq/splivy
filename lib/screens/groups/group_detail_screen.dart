import 'package:flutter/material.dart';
import 'groups_screen.dart';
import '../expenses/add_expense_screen.dart';

class _Member {
  final String name;
  const _Member(this.name);
}

class _ExpenseItem {
  final String title;
  final double totalAmount;
  final String paidBy;
  final bool paidByYou;
  final double shareAmount;
  final bool youOwe;
  final DateTime date;
  final IconData icon;

  _ExpenseItem({
    required this.title,
    required this.totalAmount,
    required this.paidBy,
    required this.paidByYou,
    required this.shareAmount,
    required this.youOwe,
    required this.date,
    required this.icon,
  });
}

final _dummyMembers = const [
  _Member('Ali'),
  _Member('Mohsin'),
  _Member('You'),
];

final _dummyExpenses = [
  _ExpenseItem(
    title: 'Groceries',
    totalAmount: 1500,
    paidBy: 'Ali',
    paidByYou: false,
    shareAmount: 500,
    youOwe: true,
    date: DateTime(2026, 5, 24),
    icon: Icons.shopping_cart_outlined,
  ),
  _ExpenseItem(
    title: 'Electricity Bill',
    totalAmount: 2400,
    paidBy: 'You',
    paidByYou: true,
    shareAmount: 1600,
    youOwe: false,
    date: DateTime(2026, 5, 22),
    icon: Icons.bolt_outlined,
  ),
  _ExpenseItem(
    title: 'Internet',
    totalAmount: 1200,
    paidBy: 'Mohsin',
    paidByYou: false,
    shareAmount: 400,
    youOwe: true,
    date: DateTime(2026, 5, 20),
    icon: Icons.wifi,
  ),
];

class GroupDetailScreen extends StatefulWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  static const _bg = Color(0xFF1A1A2E);
  static const _accent = Color(0xFF00D4AA);
  static const _cardDark = Color(0xFF0F3460);
  static const _red = Color(0xFFFF6B6B);

  final List<_ExpenseItem> _expenses = List.from(_dummyExpenses);

  double get _netBalance {
    double net = 0;
    for (final e in _expenses) {
      net += e.youOwe ? -e.shareAmount : e.shareAmount;
    }
    return net;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          widget.group.name,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildMembersSection(),
          const SizedBox(height: 20),
          _buildBalanceCard(),
          const SizedBox(height: 20),
          _buildExpensesSection(),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
        ),
        backgroundColor: _accent,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text(
          'Add Expense',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Members',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _dummyMembers.length + 1,
            itemBuilder: (context, index) {
              if (index == _dummyMembers.length) {
                return _buildAddMemberButton();
              }
              return _buildMemberAvatar(_dummyMembers[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMemberAvatar(_Member member) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: _accent,
            child: Text(
              member.name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            member.name,
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
          backgroundColor: _cardDark,
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

  Widget _buildBalanceCard() {
    final net = _netBalance;
    final isSettled = net == 0;
    final isOwed = net > 0;

    final String balanceText;
    final Color balanceColor;

    if (isSettled) {
      balanceText = 'All settled!';
      balanceColor = Colors.white;
    } else if (isOwed) {
      balanceText = 'You are owed PKR ${net.toStringAsFixed(0)}';
      balanceColor = _accent;
    } else {
      balanceText = 'You owe PKR ${net.abs().toStringAsFixed(0)}';
      balanceColor = _red;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
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
            onPressed: () {},
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

  Widget _buildExpensesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Expenses (${_expenses.length})',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        if (_expenses.isEmpty)
          _buildEmptyState()
        else
          ..._expenses.map(_buildExpenseCard),
      ],
    );
  }

  Widget _buildExpenseCard(_ExpenseItem expense) {
    final shareColor = expense.youOwe ? _red : _accent;
    final shareText = expense.youOwe
        ? 'You owe PKR ${expense.shareAmount.toStringAsFixed(0)}'
        : '+PKR ${expense.shareAmount.toStringAsFixed(0)}';
    final paidByText =
        expense.paidByYou ? 'Paid by You' : 'Paid by ${expense.paidBy}';
    final date = expense.date;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Card(
      color: _cardDark,
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
              child: Icon(expense.icon, color: _accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dateText,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    paidByText,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
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
                  'PKR ${expense.totalAmount.toStringAsFixed(0)} total',
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
            Icon(Icons.receipt_long_outlined, color: Colors.grey, size: 48),
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
