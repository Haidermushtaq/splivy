import 'package:flutter/material.dart';

class _Debt {
  final String name;
  final String groupName;
  final double amount;
  final String dueSince;

  const _Debt({
    required this.name,
    required this.groupName,
    required this.amount,
    required this.dueSince,
  });
}

const _allYouOwe = <_Debt>[
  _Debt(name: 'Ali Khan', groupName: 'Roommates', amount: 500, dueSince: '3 days ago'),
  _Debt(name: 'Mohsin Ashraf', groupName: 'Office Lunch', amount: 1300, dueSince: '1 week ago'),
];

const _allOwesYou = <_Debt>[
  _Debt(name: 'Shumail Khan', groupName: 'Trip to Murree', amount: 2000, dueSince: '2 days ago'),
  _Debt(name: 'Haider Zahoor', groupName: 'Roommates', amount: 1200, dueSince: '5 days ago'),
];

class SettleUpScreen extends StatefulWidget {
  final String? groupId;

  const SettleUpScreen({super.key, this.groupId});

  @override
  State<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends State<SettleUpScreen> {
  static const _bg = Color(0xFF1A1A2E);
  static const _accent = Color(0xFF00D4AA);
  static const _cardDark = Color(0xFF0F3460);
  static const _red = Color(0xFFFF6B6B);

  late List<_Debt> _youOwe;
  late List<_Debt> _owesYou;

  @override
  void initState() {
    super.initState();
    if (widget.groupId != null) {
      final filter = widget.groupId!.toLowerCase();
      _youOwe = _allYouOwe
          .where((d) => d.groupName.toLowerCase().contains(filter))
          .toList();
      _owesYou = _allOwesYou
          .where((d) => d.groupName.toLowerCase().contains(filter))
          .toList();
    } else {
      _youOwe = [..._allYouOwe];
      _owesYou = [..._allOwesYou];
    }
  }

  double get _totalToSettle =>
      _youOwe.fold(0.0, (sum, d) => sum + d.amount);

  bool get _allSettled => _youOwe.isEmpty && _owesYou.isEmpty;

  void _confirmMarkAsPaid(_Debt debt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Payment',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to mark PKR ${debt.amount.toStringAsFixed(0)} to ${debt.name} as paid?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _youOwe.remove(debt));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      const Text('Payment marked as settled!'),
                  backgroundColor: _accent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text(
              'Confirm',
              style: TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _sendReminder(_Debt debt) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reminder sent to ${debt.name}!'),
        backgroundColor: _accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
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
        title: const Text(
          'Settle Up',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _allSettled ? _buildAllSettled() : _buildContent(),
    );
  }

  // ── Main content ──────────────────────────────────────────────────────────

  Widget _buildContent() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(),
          if (_youOwe.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionHeader('You Owe', _red),
            const SizedBox(height: 10),
            ..._youOwe.map((d) => _buildDebtCard(d, youOwe: true)),
          ],
          if (_owesYou.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionHeader('Owes You', _accent),
            const SizedBox(height: 10),
            ..._owesYou.map((d) => _buildDebtCard(d, youOwe: false)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    final count = _youOwe.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3460), Color(0xFF1A1A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total to Settle',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'PKR ${_totalToSettle.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count == 0
                ? 'Nothing pending — check who owes you below'
                : 'Across $count ${count == 1 ? 'person' : 'people'}',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Debt card (shared for both sections) ─────────────────────────────────

  Widget _buildDebtCard(_Debt debt, {required bool youOwe}) {
    final amountColor = youOwe ? _red : _accent;
    final amountText =
        'PKR ${debt.amount.toStringAsFixed(0)}';

    return Card(
      color: _cardDark,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _accent,
              child: Text(
                debt.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    debt.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${debt.groupName} group',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Due since: ${debt.dueSince}',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                _actionButton(
                  label: youOwe ? 'Mark as Paid' : 'Send Reminder',
                  onTap: youOwe
                      ? () => _confirmMarkAsPaid(debt)
                      : () => _sendReminder(debt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: _accent),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(color: _accent, fontSize: 11),
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // ── All settled empty state ───────────────────────────────────────────────

  Widget _buildAllSettled() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withValues(alpha: 0.15),
              border: Border.all(
                  color: _accent.withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(Icons.check_rounded,
                color: _accent, size: 56),
          ),
          const SizedBox(height: 24),
          const Text(
            'All settled up!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You have no pending payments',
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final isCenter = i == 2;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isCenter ? 14 : 8,
                height: isCenter ? 14 : 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent
                      .withValues(alpha: isCenter ? 1.0 : 0.35),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
