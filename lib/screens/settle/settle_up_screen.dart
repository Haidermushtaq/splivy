import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/expense_model.dart';
import '../../services/expenses_service.dart';
import '../../services/payment_service.dart';
import '../../services/reminder_service.dart';
import '../../widgets/lottie_widget.dart';
import '../../widgets/payment_bottom_sheet.dart';
import '../../utils/balance_text.dart';

final _settleUpProvider =
    FutureProvider<List<DebtItem>>((ref) async {
  return ExpensesService().getSettleUpData();
});

final _guestSplitsProvider =
    FutureProvider<List<CustomExpenseDetail>>((ref) async {
  return ExpensesService().getCustomExpenses();
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
  static const _orange = Color(0xFFFF9800);
  static const _cardColor = Color(0xFF0F3460);

  final _paymentService = PaymentService();

  Future<void> _openPaymentSheet(DebtItem debt) async {
    await showPaymentBottomSheet(
      context,
      splitId: debt.splitId,
      amount: debt.amount,
      payerName: 'You',
      receiverName: debt.name,
      receiverPhone: debt.receiverPhone ?? '',
      expenseTitle: debt.expenseTitle,
      isGuest: false,
      isCurrentUserPayer: true,
      onComplete: () {
        ref.invalidate(_settleUpProvider);
        ReminderService().scheduleAllReminders();
      },
    );
  }

  Future<void> _confirmReceived(DebtItem debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Payment Received?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${debt.name} marked PKR ${debt.amount.toStringAsFixed(0)} as paid via ${debt.paymentMethod ?? 'unknown'}.',
              style: const TextStyle(color: Colors.grey),
            ),
            if (debt.paymentProofUrl != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _showProofImage(debt.paymentProofUrl!),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: _accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'View Payment Proof',
                      style: TextStyle(color: _accent, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(false);
              _showDisputeDialog(debt);
            },
            child: const Text('Dispute', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Received', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _paymentService.receiverConfirms(splitId: debt.splitId, isGuest: false);
      ref.invalidate(_settleUpProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment from ${debt.name} confirmed!'),
            backgroundColor: _accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _cancelPaymentClaim(DebtItem debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Payment?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This undoes your "paid" mark for PKR ${debt.amount.toStringAsFixed(0)} '
          'to ${debt.name}. The debt goes back to unpaid. Use this if you '
          'marked it by mistake or haven\'t actually paid yet.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Payment',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _paymentService.cancelPaymentClaim(
          splitId: debt.splitId, isGuest: false);
      ref.invalidate(_settleUpProvider);
      ReminderService().scheduleAllReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment mark cancelled. The debt is unpaid again.'),
            backgroundColor: _orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showDisputeDialog(DebtItem debt) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Dispute Payment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please explain why you are disputing this payment:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g., Payment not received, wrong amount...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Submit Dispute', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || controller.text.trim().isEmpty) return;

    try {
      await _paymentService.disputePayment(
        splitId: debt.splitId,
        message: controller.text.trim(),
        isGuest: false,
      );
      ref.invalidate(_settleUpProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dispute submitted. The payer has been notified.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dispute: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showProofImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(child: CircularProgressIndicator(color: _accent)),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _openGuestPaymentSheet(
      GuestSplit guest, String expenseTitle) async {
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
      onComplete: () => ref.invalidate(_guestSplitsProvider),
    );
  }

  Future<void> _markGuestGuestSettled(GuestGuestDebt debt) async {
    try {
      await ExpensesService().settleGuestGuestDebt(debt.id);
      ref.invalidate(_guestSplitsProvider);
    } catch (e) {
      if (mounted) {
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

  Future<void> _markGuestPaid(GuestSplit guest) async {
    try {
      await ExpensesService().settleGuestSplit(guest.id);
      ref.invalidate(_guestSplitsProvider);
    } catch (e) {
      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final settleAsync = ref.watch(_settleUpProvider);
    final guestAsync = ref.watch(_guestSplitsProvider);

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
          // Both feeds must resolve before deciding "all settled"; otherwise
          // guest debts read as empty on the first pass and flash a false
          // "All settled" state until _guestSplitsProvider catches up.
          if (guestAsync.isLoading) {
            return const Center(
              child: LottieWidget(
                assetPath: 'assets/animations/loading.json',
                width: 100,
                height: 100,
                repeat: true,
              ),
            );
          }

          final debts = widget.groupId != null
              ? allDebts
                  .where((d) =>
                      d.groupName.toLowerCase().contains(
                          widget.groupId!.toLowerCase()))
                  .toList()
              : allDebts;

          final youOwe = debts.where((d) => d.youOwe).toList();
          final owesYou = debts.where((d) => !d.youOwe).toList();

          final pendingGuests = guestAsync.value
                  ?.expand((detail) => detail.guests
                      .where((g) => !g.isSettled && g.amount.abs() > 0.01)
                      .map((g) => (detail: detail, guest: g)))
                  .toList() ??
              [];

          final guestGuestDebts = guestAsync.value
                  ?.expand((detail) => detail.guestGuestDebts
                      .where((d) => !d.isSettled)
                      .map((d) => (detail: detail, debt: d)))
                  .toList() ??
              [];

          final allSettled = youOwe.isEmpty &&
              owesYou.isEmpty &&
              pendingGuests.isEmpty &&
              guestGuestDebts.isEmpty;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_settleUpProvider);
              ref.invalidate(_guestSplitsProvider);
            },
            child: allSettled
                ? _buildAllSettled()
                : _buildContent(
                    youOwe, owesYou, pendingGuests, guestGuestDebts),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    List<DebtItem> youOwe,
    List<DebtItem> owesYou,
    List<({CustomExpenseDetail detail, GuestSplit guest})> pendingGuests,
    List<({CustomExpenseDetail detail, GuestGuestDebt debt})> guestGuestDebts,
  ) {
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
          if (pendingGuests.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionHeader('One-time Expenses', Colors.amber),
            const SizedBox(height: 10),
            ...pendingGuests.map(
              (entry) => _buildGuestDebtCard(entry.guest, entry.detail.expense.title),
            ),
          ],
          if (guestGuestDebts.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionHeader('Between Others (tracking)', Colors.amber),
            const SizedBox(height: 6),
            const Text(
              'Debts between people who aren’t on the app. '
              'You’re keeping the record.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ...guestGuestDebts.map(
              (entry) =>
                  _buildGuestGuestCard(entry.debt, entry.detail.expense.title),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGuestGuestCard(GuestGuestDebt debt, String expenseTitle) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.amber.withValues(alpha: 0.2),
              child: const Icon(Icons.swap_horiz_rounded,
                  color: Colors.amber, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${debt.debtorName} owes ${debt.creditorName}',
                    style: TextStyle(
                      color: onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expenseTitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'PKR ${debt.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                _actionButton(
                  label: 'Mark Settled',
                  onTap: () => _markGuestGuestSettled(debt),
                ),
              ],
            ),
          ],
        ),
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
    final amountText = 'PKR ${debt.amount.toStringAsFixed(0)}';
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _accent,
              backgroundImage:
                  (debt.avatarUrl != null && debt.avatarUrl!.isNotEmpty)
                      ? NetworkImage(debt.avatarUrl!)
                      : null,
              child: (debt.avatarUrl == null || debt.avatarUrl!.isEmpty)
                  ? Text(
                      debt.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          debt.name,
                          style: TextStyle(
                            color: onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildStatusBadge(debt),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    debt.expenseTitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${debt.groupName} • ${debt.dueSince}',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
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
                _buildActionButtons(debt, youOwe: youOwe),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(DebtItem debt) {
    if (debt.isPending) return const SizedBox.shrink();

    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    if (debt.isPayerMarked) {
      bgColor = _orange.withValues(alpha: 0.2);
      textColor = _orange;
      text = 'Awaiting';
      icon = Icons.hourglass_empty;
    } else if (debt.isConfirmed || debt.isCashSettled) {
      bgColor = _accent.withValues(alpha: 0.2);
      textColor = _accent;
      text = 'Settled';
      icon = Icons.check_circle;
    } else if (debt.isDisputed) {
      bgColor = Colors.red.withValues(alpha: 0.2);
      textColor = Colors.red;
      text = 'Disputed';
      icon = Icons.warning;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 10),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(DebtItem debt, {required bool youOwe}) {
    if (youOwe) {
      if (debt.isPending) {
        return _actionButton(label: 'Pay Now', onTap: () => _openPaymentSheet(debt));
      } else if (debt.isPayerMarked) {
        return _actionButton(
            label: 'Cancel',
            onTap: () => _cancelPaymentClaim(debt),
            color: _orange);
      } else if (debt.isDisputed) {
        return _actionButton(label: 'Retry Payment', onTap: () => _openPaymentSheet(debt), color: Colors.red);
      } else {
        return const Icon(Icons.check_circle, color: _accent, size: 20);
      }
    } else {
      if (debt.isPending) {
        return _actionButton(label: 'Send Reminder', onTap: () => _sendReminder(debt));
      } else if (debt.isPayerMarked) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (debt.paymentProofUrl != null) ...[
              GestureDetector(
                onTap: () => _showProofImage(debt.paymentProofUrl!),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.receipt_long, color: Colors.grey, size: 16),
                ),
              ),
              const SizedBox(width: 6),
            ],
            _actionButton(label: 'Confirm', onTap: () => _confirmReceived(debt)),
          ],
        );
      } else if (debt.isDisputed) {
        return _actionButton(label: 'Disputed', onTap: () {}, color: Colors.red);
      } else {
        return const Icon(Icons.check_circle, color: _accent, size: 20);
      }
    }
  }

  Widget _actionButton(
      {required String label,
      required VoidCallback onTap,
      Color color = _accent}) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }

  Widget _buildGuestDebtCard(GuestSplit guest, String expenseTitle) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final iOweGuest = guest.amount < 0;
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
              backgroundColor: Colors.amber.withValues(alpha: 0.2),
              child: Text(
                guest.guestName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.amber,
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
                    guest.guestName,
                    style: TextStyle(
                      color: onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expenseTitle,
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
                  iOweGuest ? 'You owe' : 'Owes you',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
                Text(
                  'PKR ${guest.amount.abs().toStringAsFixed(0)}',
                  style: TextStyle(
                    color: BalanceText.color(guest.amount),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _actionButton(
                      label: 'WhatsApp',
                      onTap: () => _sendWhatsApp(context, guest, expenseTitle),
                      color: const Color(0xFF25D366),
                    ),
                    const SizedBox(width: 6),
                    if (iOweGuest)
                      _actionButton(
                        label: 'Pay Now',
                        onTap: () =>
                            _openGuestPaymentSheet(guest, expenseTitle),
                      )
                    else
                      _actionButton(
                        label: 'Mark Paid',
                        onTap: () => _markGuestPaid(guest),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
