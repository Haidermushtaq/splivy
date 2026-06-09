import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/expense_model.dart';
import '../../providers/expenses_provider.dart';
import '../../services/expenses_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/confirm_dialog.dart';

/// Read-only full detail of a single group expense: header (title, group, date,
/// total, who paid, note) plus the per-person owe/owed breakdown split into
/// outstanding and settled (offsetting) history.
class GroupExpenseDetailScreen extends ConsumerStatefulWidget {
  final String expenseId;
  final String? groupName;

  const GroupExpenseDetailScreen({
    super.key,
    required this.expenseId,
    this.groupName,
  });

  @override
  ConsumerState<GroupExpenseDetailScreen> createState() =>
      _GroupExpenseDetailScreenState();
}

class _GroupExpenseDetailScreenState
    extends ConsumerState<GroupExpenseDetailScreen> {
  static const _accent = Color(0xFF00D4AA);
  static const _red = Color(0xFFFF6B6B);

  late Future<GroupExpenseDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = ExpensesService().getGroupExpenseDetail(widget.expenseId);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDeleteDialog(context, 'this expense');
    if (ok != true || !mounted) return;
    final navigator = Navigator.of(context);
    try {
      await ref.read(expensesServiceProvider).deleteExpense(widget.expenseId);
      ref.invalidate(recentExpensesProvider);
      ref.invalidate(customExpensesProvider);
      ref.invalidate(archivedExpensesProvider);
      ref.invalidate(userBalanceProvider);
      if (!mounted) return;
      ErrorHandler.showSuccess(context, 'Expense deleted');
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, e);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Expense Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _red),
            tooltip: 'Delete expense',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: FutureBuilder<GroupExpenseDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _accent));
          }
          if (snap.hasError || !snap.hasData) {
            return _buildError();
          }
          return _buildContent(snap.data!);
        },
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.grey, size: 48),
          const SizedBox(height: 12),
          const Text('Could not load this expense.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {
              _future =
                  ExpensesService().getGroupExpenseDetail(widget.expenseId);
            }),
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            child: const Text('Retry', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(GroupExpenseDetail detail) {
    final outstanding =
        detail.edges.where((edge) => !edge.isSettled).toList();
    final settled = detail.edges.where((edge) => edge.isSettled).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(detail),
        const SizedBox(height: 16),
        if (detail.payers.length > 1) ...[
          _sectionTitle('Who paid'),
          const SizedBox(height: 8),
          ...detail.payers.map(_buildPayerRow),
          const SizedBox(height: 16),
        ],
        _sectionTitle('Breakdown'),
        const SizedBox(height: 8),
        if (outstanding.isEmpty && settled.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No splits on this expense.',
                style: TextStyle(color: Colors.grey)),
          ),
        ...outstanding.map(_buildEdgeRow),
        if (settled.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle('Offsetting history'),
          const SizedBox(height: 8),
          ...settled.map(_buildEdgeRow),
        ],
      ],
    );
  }

  Widget _buildHeaderCard(GroupExpenseDetail detail) {
    final e = detail.expense;
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
          Row(
            children: [
              Expanded(
                child: Text(
                  e.title,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  detail.groupName,
                  style: const TextStyle(
                      color: _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_formatDate(e.createdAt),
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          const Text('Total',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            'PKR ${e.amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: _accent,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      color: Colors.grey, size: 16),
                  const SizedBox(width: 6),
                  Text('Paid by ${e.paidByName}',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.category_outlined,
                      color: Colors.grey, size: 16),
                  const SizedBox(width: 6),
                  Text(e.category,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ],
          ),
          if (e.note != null && e.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(e.note!,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildPayerRow(PayerContribution p) {
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
                  color: _accent, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(p.name,
                style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
          Text('PKR ${p.amount.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: _accent, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildEdgeRow(ExpenseSplitEdge edge) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // Phrase from the current user's perspective when they're involved.
    final String sentence;
    final Color color;
    if (edge.isSettled) {
      color = Colors.grey;
      sentence = '${edge.debtorName} settled with ${edge.creditorName}';
    } else if (edge.creditorIsYou) {
      color = _accent;
      sentence = '${edge.debtorName} owes you';
    } else if (edge.debtorIsYou) {
      color = _red;
      sentence = 'You owe ${edge.creditorName}';
    } else {
      color = onSurface;
      sentence = '${edge.debtorName} owes ${edge.creditorName}';
    }

    final avatarName = edge.creditorIsYou ? edge.debtorName : edge.creditorName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color == onSurface
                ? _accent.withValues(alpha: 0.15)
                : color.withValues(alpha: 0.15),
            child: Text(
              avatarName.isEmpty ? '?' : avatarName[0].toUpperCase(),
              style: TextStyle(
                color: color == onSurface ? _accent : color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sentence,
              style: TextStyle(
                color: edge.isSettled ? Colors.grey : onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 14,
                decoration:
                    edge.isSettled ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('PKR ${edge.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                      color: edge.isSettled ? Colors.grey : color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              if (edge.isSettled)
                Text(
                  edge.paymentStatus == 'netted' ? 'Auto-settled' : 'Settled',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              if (!edge.isSettled && edge.wasOffset)
                Text(
                  'PKR ${edge.amountPaid.toStringAsFixed(0)} offset from PKR ${edge.originalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
