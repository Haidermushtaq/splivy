import 'package:flutter/material.dart';
import '../../models/expense_model.dart';
import '../../utils/balance_text.dart';

/// Read-only breakdown of a single one-time expense: total, who paid, and a
/// per-person owe/owed list using plain wording (no +/- signs).
class OneTimeExpenseDetailScreen extends StatelessWidget {
  final CustomExpenseDetail detail;

  const OneTimeExpenseDetailScreen({super.key, required this.detail});

  static const _accent = Color(0xFF00D4AA);

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final e = detail.expense;

    // Build a unified list of (name, amount, isSettled). Positive amount means
    // the person owes the current user; negative means the user owes them.
    final entries = <({String name, double amount, bool isSettled})>[
      ...detail.friendDebts.map((d) =>
          (name: d.name, amount: d.amount, isSettled: d.isSettled)),
      ...detail.guests.map((g) =>
          (name: g.guestName, amount: g.amount, isSettled: g.isSettled)),
    ];

    double owedToYou = 0;
    double youOwe = 0;
    for (final entry in entries) {
      if (entry.isSettled) continue;
      if (entry.amount >= 0) {
        owedToYou += entry.amount;
      } else {
        youOwe += -entry.amount;
      }
    }

    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Expense Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(context, e),
          const SizedBox(height: 16),
          if (owedToYou > 0.01 || youOwe > 0.01) ...[
            _buildTotalsCard(owedToYou, youOwe),
            const SizedBox(height: 16),
          ],
          if (detail.payers.length > 1) ...[
            _buildSectionTitle(context, 'Who paid'),
            const SizedBox(height: 8),
            ...detail.payers.map((p) => _buildPayerRow(context, p)),
            const SizedBox(height: 16),
          ],
          _buildSectionTitle(context, 'Breakdown'),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No one is splitting this expense.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...entries.map((entry) => _buildPersonRow(context, entry)),
          if (detail.guestGuestDebts.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionTitle(context, 'Between others'),
            const SizedBox(height: 8),
            ...detail.guestGuestDebts.map((d) => _buildGuestGuestRow(context, d)),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, Expense e) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3460), Color(0xFF1A6B5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.title,
            style: TextStyle(
              color: onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(e.createdAt),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Text('Total', style: TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            'PKR ${e.amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: _accent,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.grey, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Paid by ${e.paidByName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(double owedToYou, double youOwe) {
    return Row(
      children: [
        if (owedToYou > 0.01)
          Expanded(
            child: _statBox(
              "You're owed",
              owedToYou,
              BalanceText.owedColor,
              Icons.arrow_downward_rounded,
            ),
          ),
        if (owedToYou > 0.01 && youOwe > 0.01) const SizedBox(width: 12),
        if (youOwe > 0.01)
          Expanded(
            child: _statBox(
              'You owe',
              youOwe,
              BalanceText.oweColor,
              Icons.arrow_upward_rounded,
            ),
          ),
      ],
    );
  }

  Widget _statBox(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'PKR ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildPayerRow(BuildContext context, PayerContribution p) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _accent.withValues(alpha: 0.15),
            child: Text(
              p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
              style: const TextStyle(
                color: _accent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              p.name,
              style: TextStyle(
                color: onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            'PKR ${p.amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: _accent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestGuestRow(BuildContext context, GuestGuestDebt d) {
    final color = d.isSettled ? Colors.grey : BalanceText.oweColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            d.isSettled ? Icons.check_circle : Icons.swap_horiz_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              d.isSettled
                  ? '${d.debtorName} settled with ${d.creditorName}'
                  : '${d.debtorName} owes ${d.creditorName} '
                      'PKR ${d.amount.toStringAsFixed(0)}',
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonRow(
    BuildContext context,
    ({String name, double amount, bool isSettled}) entry,
  ) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final color = entry.isSettled
        ? Colors.grey
        : BalanceText.color(entry.amount);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              entry.name.isEmpty ? '?' : entry.name[0].toUpperCase(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: TextStyle(
                    color: entry.isSettled ? Colors.grey : onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    decoration:
                        entry.isSettled ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  entry.isSettled
                      ? 'Settled'
                      : BalanceText.sentence(entry.name, entry.amount),
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
          ),
          if (entry.isSettled)
            const Icon(Icons.check_circle, color: Colors.grey, size: 18),
        ],
      ),
    );
  }
}
