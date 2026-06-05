import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/expense_model.dart';
import '../../services/expenses_service.dart';
import '../../utils/balance_text.dart';
import '../../widgets/payment_bottom_sheet.dart';
import 'one_time_expense_detail_screen.dart';

final _customExpensesProvider =
    FutureProvider<List<CustomExpenseDetail>>((ref) {
  return ExpensesService().getCustomExpenses();
});

class CustomExpensesScreen extends ConsumerWidget {
  const CustomExpensesScreen({super.key});

  static const _accent = Color(0xFF00D4AA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(_customExpensesProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('One-time Expenses'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accent,
        onPressed: () async {
          final created = await Navigator.of(context)
              .pushNamed('/add-one-time');
          if (created == true) ref.invalidate(_customExpensesProvider);
        },
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('New',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: asyncData.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: _accent)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.grey, size: 48),
              const SizedBox(height: 12),
              Text('Error: $e',
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(_customExpensesProvider),
                style:
                    ElevatedButton.styleFrom(backgroundColor: _accent),
                child: const Text('Retry',
                    style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
        data: (expenses) {
          if (expenses.isEmpty) {
            return _buildEmpty(context);
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(_customExpensesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              itemCount: expenses.length,
              itemBuilder: (context, i) => _ExpenseCard(
                detail: expenses[i],
                onRefresh: () => ref.invalidate(_customExpensesProvider),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_outlined,
              color: Colors.grey, size: 56),
          const SizedBox(height: 16),
          Text(
            'No one-time expenses',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add a guest when creating an expense to track it here',
            style: TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final CustomExpenseDetail detail;
  final VoidCallback onRefresh;

  static const _accent = Color(0xFF00D4AA);

  const _ExpenseCard({required this.detail, required this.onRefresh});

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  Future<void> _sendWhatsApp(
      BuildContext context, GuestSplit guest, String expenseTitle) async {
    final rawPhone = guest.guestPhone;
    final waPhone = '92${rawPhone.substring(1)}';
    final amt = guest.amount.abs().toStringAsFixed(0);
    final body = guest.amount >= 0
        ? 'Hi ${guest.guestName}, you owe PKR $amt for "$expenseTitle". Please settle up! – Splivy'
        : 'Hi ${guest.guestName}, I owe you PKR $amt for "$expenseTitle". Let me know how to pay you. – Splivy';
    final msg = Uri.encodeComponent(body);
    final url = Uri.parse('https://wa.me/$waPhone?text=$msg');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _payGuest(
      BuildContext context, GuestSplit guest, String expenseTitle) async {
    await showPaymentBottomSheet(
      context,
      splitId: guest.id,
      amount: guest.amount.abs(),
      payerName: 'You',
      receiverName: guest.guestName,
      receiverPhone: guest.guestPhone,
      expenseTitle: expenseTitle,
      isGuest: true,
      isCurrentUserPayer: true,
      onComplete: onRefresh,
    );
  }

  Future<void> _markPaid(BuildContext context, GuestSplit guest) async {
    try {
      await ExpensesService().settleGuestSplit(guest.id);
      onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _markFriendPaid(BuildContext context, FriendDebt debt) async {
    try {
      await ExpensesService().markSplitSettled(debt.splitId);
      onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _archive(BuildContext context) async {
    try {
      await ExpensesService()
          .archiveCustomExpense(detail.expense.id);
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense archived'),
            backgroundColor: _accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = detail.expense;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final allSettled = detail.allSettled;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OneTimeExpenseDetailScreen(detail: detail),
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: TextStyle(
                          color: onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(e.createdAt),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PKR ${e.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (allSettled)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'All settled',
                          style: TextStyle(
                              color: _accent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            if (detail.friendDebts.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 10),
              ...detail.friendDebts.map((d) => _FriendRow(
                    debt: d,
                    onMarkPaid: () => _markFriendPaid(context, d),
                  )),
            ],

            if (detail.guests.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 10),
              ...detail.guests.map((g) => _GuestRow(
                    guest: g,
                    expenseTitle: e.title,
                    onWhatsApp: () =>
                        _sendWhatsApp(context, g, e.title),
                    onMarkPaid: () => _markPaid(context, g),
                    onPay: () => _payGuest(context, g, e.title),
                  )),
            ],

            if (allSettled) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: () => _archive(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.archive_outlined,
                      color: Colors.grey, size: 16),
                  label: const Text('Archive',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

class _GuestRow extends StatelessWidget {
  final GuestSplit guest;
  final String expenseTitle;
  final VoidCallback onWhatsApp;
  final VoidCallback onMarkPaid;
  final VoidCallback onPay;

  static const _accent = Color(0xFF00D4AA);

  const _GuestRow({
    required this.guest,
    required this.expenseTitle,
    required this.onWhatsApp,
    required this.onMarkPaid,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: guest.isSettled
                ? Colors.grey.withValues(alpha: 0.2)
                : _accent.withValues(alpha: 0.15),
            child: Text(
              guest.guestName[0].toUpperCase(),
              style: TextStyle(
                color: guest.isSettled ? Colors.grey : _accent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guest.guestName,
                  style: TextStyle(
                    color: guest.isSettled ? Colors.grey : onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: guest.isSettled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                Text(
                  BalanceText.sentence(guest.guestName, guest.amount),
                  style: TextStyle(
                    color: guest.isSettled
                        ? Colors.grey
                        : BalanceText.color(guest.amount),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!guest.isSettled) ...[
            _SmallButton(
              label: 'WhatsApp',
              icon: Icons.chat_outlined,
              color: const Color(0xFF25D366),
              onTap: onWhatsApp,
            ),
            const SizedBox(width: 6),
            if (guest.amount < 0)
              _SmallButton(
                label: 'Pay',
                icon: Icons.payment,
                color: _accent,
                onTap: onPay,
              )
            else
              _SmallButton(
                label: 'Paid',
                icon: Icons.check,
                color: _accent,
                onTap: onMarkPaid,
              ),
          ] else
            const Icon(Icons.check_circle_outline,
                color: Colors.grey, size: 18),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  final FriendDebt debt;
  final VoidCallback onMarkPaid;

  static const _accent = Color(0xFF00D4AA);

  const _FriendRow({required this.debt, required this.onMarkPaid});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: debt.isSettled
                ? Colors.grey.withValues(alpha: 0.2)
                : _accent.withValues(alpha: 0.15),
            child: Text(
              debt.name[0].toUpperCase(),
              style: TextStyle(
                color: debt.isSettled ? Colors.grey : _accent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  debt.name,
                  style: TextStyle(
                    color: debt.isSettled ? Colors.grey : onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration:
                        debt.isSettled ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  BalanceText.sentence(debt.name, debt.amount),
                  style: TextStyle(
                    color: debt.isSettled
                        ? Colors.grey
                        : BalanceText.color(debt.amount),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!debt.isSettled)
            _SmallButton(
              label: 'Paid',
              icon: Icons.check,
              color: _accent,
              onTap: onMarkPaid,
            )
          else
            const Icon(Icons.check_circle_outline,
                color: Colors.grey, size: 18),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
