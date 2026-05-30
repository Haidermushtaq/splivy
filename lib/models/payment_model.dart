import 'package:flutter/material.dart';

class PaymentMethod {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String Function()? urlBuilder;
  final bool isOnline;

  const PaymentMethod({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.urlBuilder,
    required this.isOnline,
  });
}

class PaymentStatus {
  static const String pending = 'pending';
  static const String payerMarked = 'payer_marked';
  static const String confirmed = 'confirmed';
  static const String cashSettled = 'cash_settled';
  static const String disputed = 'disputed';

  /// Auto-cancelled against an offsetting debt with the same person.
  static const String netted = 'netted';

  static bool isSettled(String status) =>
      status == confirmed || status == cashSettled || status == netted;

  static String getDisplayText(String status) {
    switch (status) {
      case pending:
        return 'Pending';
      case payerMarked:
        return 'Awaiting Confirmation';
      case confirmed:
        return 'Confirmed';
      case cashSettled:
        return 'Cash Settled';
      case netted:
        return 'Auto-settled';
      case disputed:
        return 'Disputed';
      default:
        return 'Unknown';
    }
  }

  static Color getColor(String status) {
    switch (status) {
      case pending:
        return Colors.grey;
      case payerMarked:
        return Colors.orange;
      case confirmed:
      case cashSettled:
      case netted:
        return const Color(0xFF00D4AA);
      case disputed:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class SplitPaymentInfo {
  final String splitId;
  final String expenseId;
  final double amount;
  final double amountPaid;
  final String? paymentMethod;
  final String? paymentProofUrl;
  final DateTime? settledAt;
  final String? paidByUser;
  final String? confirmedBy;
  final String paymentStatus;
  final String? disputeMessage;
  final bool isGuest;
  final String? guestName;
  final String? guestPhone;

  const SplitPaymentInfo({
    required this.splitId,
    required this.expenseId,
    required this.amount,
    required this.amountPaid,
    this.paymentMethod,
    this.paymentProofUrl,
    this.settledAt,
    this.paidByUser,
    this.confirmedBy,
    required this.paymentStatus,
    this.disputeMessage,
    required this.isGuest,
    this.guestName,
    this.guestPhone,
  });

  bool get isSettled => PaymentStatus.isSettled(paymentStatus);
  bool get needsConfirmation => paymentStatus == PaymentStatus.payerMarked;
  bool get isDisputed => paymentStatus == PaymentStatus.disputed;
}
