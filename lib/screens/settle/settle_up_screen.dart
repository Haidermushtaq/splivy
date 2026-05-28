import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/expense_model.dart';
import '../../services/expenses_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/lottie_widget.dart';

final _settleUpProvider =
    FutureProvider<List<DebtItem>>((ref) async {
  return ExpensesService().getSettleUpData();
});

class SettleUpScreen extends ConsumerStatefulWidget {
  final String? groupId;

  const SettleUpScreen({super.key, this.groupId});

  @override
  ConsumerState<SettleUpScreen> createState() =>
      _SettleUpScreenState();
}

class _SettleUpScreenState extends ConsumerState<SettleUpScreen> {
  static const _accent = Color(0xFF00D4AA);
  static const _red = Color(0xFFFF6B6B);

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  Future<void> _confirmMarkAsPaid(DebtItem debt) async {
    final cardColor = Theme.of(context).cardColor;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Payment',
          style: TextStyle(
              color: Theme.of(ctx).colorScheme.onSurface,
              fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Mark PKR ${debt.amount.toStringAsFixed(0)} to ${debt.name} as paid?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Confirm',
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ExpensesService()
          .settleExpense(debt.expenseId, _currentUserId);
      ref.invalidate(_settleUpProvider);
      if (mounted) {
        await _showPaymentSuccessSheet(debt);
        NotificationService().showSettlementNotification(
          name: debt.name,
          amount: debt.amount,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to settle: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showPaymentSuccessSheet(DebtItem debt) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LottieWidget(
              assetPath: 'assets/animations/payment_success.json',
              width: 150,
              height: 150,
              repeat: false,
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Settled!',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'PKR ${debt.amount.toStringAsFixed(0)} to ${debt.name} is marked as paid.',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) Navigator.of(context).pop();
  }

  void _sendReminder(DebtItem debt) {
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
    final settleAsync = ref.watch(_settleUpProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Settle Up'),
      ),
      body: settleAsync.when(
        loading: () => const Center(
        child: LottieWidget(
          assetPath: 'assets/animations/loading.json',
          width: 100,
          height: 100,
          repeat: true,
        ),
      ),
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
                onPressed: () => ref.invalidate(_settleUpProvider),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _accent),
                child: const Text('Retry',
                    style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
        data: (allDebts) {
          final debts = widget.groupId != null
              ? allDebts
                  .where((d) =>
                      d.groupName.toLowerCase().contains(
                          widget.groupId!.toLowerCase()))
                  .toList()
              : allDebts;

          final youOwe =
              debts.where((d) => d.youOwe).toList();
          final owesYou =
              debts.where((d) => !d.youOwe).toList();
          final allSettled = youOwe.isEmpty && owesYou.isEmpty;

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(_settleUpProvider),
            child: allSettled
                ? _buildAllSettled()
                : _buildContent(youOwe, owesYou),
          );
        },
      ),
    );
  }

  Widget _buildContent(
      List<DebtItem> youOwe, List<DebtItem> owesYou) {
    final totalToSettle =
        youOwe.fold(0.0, (sum, d) => sum + d.amount);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(youOwe.length, totalToSettle),
          if (youOwe.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionHeader('You Owe', _red),
            const SizedBox(height: 10),
            ...youOwe.map(
                (d) => _buildDebtCard(d, youOwe: true)),
          ],
          if (owesYou.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionHeader('Owes You', _accent),
            const SizedBox(height: 10),
            ...owesYou.map(
                (d) => _buildDebtCard(d, youOwe: false)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int count, double totalToSettle) {
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
            'PKR ${totalToSettle.toStringAsFixed(0)}',
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
            style: const TextStyle(
                color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(DebtItem debt, {required bool youOwe}) {
    final amountColor = youOwe ? _red : _accent;
    final amountText =
        'PKR ${debt.amount.toStringAsFixed(0)}';
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
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
                    style: TextStyle(
                      color: onSurface,
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
                  label: youOwe
                      ? 'Mark as Paid'
                      : 'Send Reminder',
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

  Widget _actionButton(
      {required String label, required VoidCallback onTap}) {
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

  Widget _buildAllSettled() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LottieWidget(
                  assetPath: 'assets/animations/celebration.json',
                  width: 250,
                  height: 250,
                  repeat: false,
                ),
                const SizedBox(height: 8),
                Text(
                  'All Settled Up!',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You have no pending payments',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
