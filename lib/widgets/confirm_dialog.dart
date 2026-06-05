import 'package:flutter/material.dart';

const _accent = Color(0xFF00D4AA);
const _danger = Color(0xFFFF6B6B);
const _dialogBg = Color(0xFF0F3460);
const _amber = Color(0xFFFFB347);

/// Shows a styled confirmation dialog.
///
/// Returns `true` if confirmed, `false` if cancelled, and `null` if the
/// dialog was dismissed (tap outside / back).
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  Color confirmColor = _accent,
  Color confirmTextColor = Colors.black,
  bool isDangerous = false,
  Widget? icon,
}) {
  final effectiveConfirmColor = isDangerous ? _danger : confirmColor;
  final effectiveConfirmTextColor =
      isDangerous ? Colors.white : confirmTextColor;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          if (icon != null) ...[
            IconTheme(
              data: const IconThemeData(size: 28),
              child: icon,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            cancelText,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: effectiveConfirmColor,
            foregroundColor: effectiveConfirmTextColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            confirmText,
            style: TextStyle(
              color: effectiveConfirmTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

Future<bool?> showDeleteDialog(BuildContext context, String itemName) {
  return showConfirmDialog(
    context,
    title: 'Delete $itemName',
    message:
        'Are you sure you want to delete "$itemName"? This action cannot be undone.',
    icon: const Icon(Icons.delete_outline, color: _danger),
    confirmText: 'Delete',
    isDangerous: true,
  );
}

Future<bool?> showSettleDialog(
    BuildContext context, String personName, double amount) {
  return showConfirmDialog(
    context,
    title: 'Settle Up',
    message:
        'Confirm you have settled PKR ${amount.toStringAsFixed(0)} with $personName?',
    icon: const Icon(Icons.check_circle_outline, color: _accent),
    confirmText: 'Yes, Settled',
    isDangerous: false,
  );
}

Future<bool?> showLogoutDialog(BuildContext context) {
  return showConfirmDialog(
    context,
    title: 'Logout',
    message: 'Are you sure you want to logout from Splivy?',
    icon: const Icon(Icons.logout, color: _danger),
    confirmText: 'Logout',
    isDangerous: true,
  );
}

Future<bool?> showArchiveDialog(BuildContext context) {
  return showConfirmDialog(
    context,
    title: 'Archive Expense',
    message:
        'This expense is fully settled. Archive it to keep your list clean? You can view archived expenses anytime.',
    icon: const Icon(Icons.archive_outlined, color: _amber),
    confirmText: 'Archive',
    isDangerous: false,
  );
}

Future<bool?> showRemoveFriendDialog(
    BuildContext context, String friendName) {
  return showConfirmDialog(
    context,
    title: 'Remove Friend',
    message:
        'Remove $friendName from your friends list? Any shared expenses will still be visible.',
    icon: const Icon(Icons.person_remove_outlined, color: _danger),
    confirmText: 'Remove',
    isDangerous: true,
  );
}

Future<bool?> showLeaveGroupDialog(BuildContext context, String groupName) {
  return showConfirmDialog(
    context,
    title: 'Leave Group',
    message:
        'Are you sure you want to leave "$groupName"? You won\'t be able to see group expenses anymore.',
    icon: const Icon(Icons.exit_to_app, color: _danger),
    confirmText: 'Leave',
    isDangerous: true,
  );
}

Future<bool?> showDeleteGroupDialog(BuildContext context, String groupName) {
  return showConfirmDialog(
    context,
    title: 'Delete Group',
    message:
        'Permanently delete "$groupName" and all its expenses? This cannot be undone and all members will lose access.',
    icon: const Icon(Icons.delete_forever_outlined, color: _danger),
    confirmText: 'Delete Forever',
    isDangerous: true,
  );
}

Future<bool?> showMarkReceivedDialog(
  BuildContext context,
  String payerName,
  double amount,
  String method,
) {
  return showConfirmDialog(
    context,
    title: 'Confirm Payment Received',
    message:
        'Confirm that $payerName paid you PKR ${amount.toStringAsFixed(0)} via $method?',
    icon: const Icon(Icons.payments_outlined, color: _accent),
    confirmText: 'Confirm Received',
    isDangerous: false,
  );
}

Future<bool?> showCancelExpenseDialog(
    BuildContext context, String expenseTitle) {
  return showConfirmDialog(
    context,
    title: 'Cancel Expense',
    message:
        'Cancel "$expenseTitle"? All splits will be removed and balances updated.',
    icon: const Icon(Icons.cancel_outlined, color: _danger),
    confirmText: 'Cancel Expense',
    isDangerous: true,
  );
}

Future<bool?> showExitAppDialog(BuildContext context) {
  return showConfirmDialog(
    context,
    title: 'Exit Splivy',
    message: 'Are you sure you want to exit?',
    icon: const Icon(Icons.exit_to_app, color: _danger),
    confirmText: 'Exit',
    isDangerous: true,
  );
}
