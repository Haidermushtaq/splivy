import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/expense_model.dart';
import '../../providers/expenses_provider.dart';
import '../../utils/balance_text.dart';
import '../../utils/error_handler.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/edit_expense_dialog.dart';
import 'one_time_expense_screen.dart';

/// Breakdown of a single one-time expense: total, who paid, and a per-person
/// owe/owed list using plain wording (no +/- signs). The descriptive fields
/// (title, category, note) can be edited in place.
class OneTimeExpenseDetailScreen extends ConsumerStatefulWidget {
  final CustomExpenseDetail detail;

  const OneTimeExpenseDetailScreen({super.key, required this.detail});

  @override
  ConsumerState<OneTimeExpenseDetailScreen> createState() =>
      _OneTimeExpenseDetailScreenState();
}

class _OneTimeExpenseDetailScreenState
    extends ConsumerState<OneTimeExpenseDetailScreen> {
  static const _accent = Color(0xFF00D4AA);
  static const _red = Color(0xFFFF6B6B);

  late String _title;
  late String _category;
  late String? _note;

  @override
  void initState() {
    super.initState();
    final e = widget.detail.expense;
    _title = e.title;
    _category = e.category;
    _note = e.note;
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDeleteDialog(context, _title);
    if (ok != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(expensesServiceProvider)
          .deleteExpense(widget.detail.expense.id);
      ref.invalidate(recentExpensesProvider);
      ref.invalidate(customExpensesProvider);
      ref.invalidate(archivedExpensesProvider);
      ref.invalidate(userBalanceProvider);
      if (!context.mounted) return;
      ErrorHandler.showSuccess(context, 'Expense deleted');
      navigator.pop();
    } catch (e) {
      if (!context.mounted) return;
      ErrorHandler.showError(context, e);
    }
  }

  Future<void> _editExpense(BuildContext context) async {
    final service = ref.read(expensesServiceProvider);
    final expenseId = widget.detail.expense.id;

    bool canFull = false;
    try {
      canFull = await service.canFullyEdit(expenseId);
    } catch (_) {
      canFull = false;
    }
    if (!context.mounted) return;

    if (canFull) {
      await _editFully(context, service, expenseId);
    } else {
      await _editMetadata(context, service, expenseId);
    }
  }

  /// Full edit (amounts, payers, people) via the prefilled add-expense form.
  /// On success the providers are refreshed and this detail screen is popped,
  /// since its passed-in snapshot is now stale.
  Future<void> _editFully(
      BuildContext context, dynamic service, String expenseId) async {
    final EditableExpense editable;
    try {
      editable = await service.getEditableExpense(expenseId);
    } catch (e) {
      if (context.mounted) ErrorHandler.showError(context, e);
      return;
    }
    if (!context.mounted) return;

    final navigator = Navigator.of(context);
    final changed = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => OneTimeExpenseScreen(editExpense: editable),
      ),
    );
    if (changed == true) {
      ref.invalidate(recentExpensesProvider);
      ref.invalidate(customExpensesProvider);
      ref.invalidate(archivedExpensesProvider);
      ref.invalidate(userBalanceProvider);
      navigator.pop();
    }
  }

  /// Fallback metadata-only edit (title, category, note) when the expense has
  /// settled or offset debts that a full rewrite would clobber.
  Future<void> _editMetadata(
      BuildContext context, dynamic service, String expenseId) async {
    final result = await showEditExpenseDialog(
      context,
      title: _title,
      category: _category,
      note: _note,
    );
    if (result == null || !context.mounted) return;
    try {
      await service.updateExpenseMeta(
        expenseId: expenseId,
        title: result.title,
        category: result.category,
        note: result.note,
      );
      ref.invalidate(recentExpensesProvider);
      ref.invalidate(customExpensesProvider);
      ref.invalidate(archivedExpensesProvider);
      if (!context.mounted) return;
      setState(() {
        _title = result.title;
        _category = result.category;
        _note = result.note;
      });
      ErrorHandler.showSuccess(context, 'Expense updated');
    } catch (e) {
      if (!context.mounted) return;
      ErrorHandler.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
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
      appBar: AppBar(
        elevation: 0,
        title: const Text('Expense Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: _accent),
            tooltip: 'Edit expense',
            onPressed: () => _editExpense(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _red),
            tooltip: 'Delete expense',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
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
            _title,
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
