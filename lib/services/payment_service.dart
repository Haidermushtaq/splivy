import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_model.dart';
import 'notification_service.dart';

class PaymentService {
  final _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  List<PaymentMethod> getPaymentMethods({
    required String receiverPhone,
    required String receiverName,
    required double amount,
    required String expenseTitle,
  }) {
    return [
      PaymentMethod(
        id: 'jazzcash',
        name: 'JazzCash',
        icon: Icons.phone_android,
        color: const Color(0xFFE91E63),
        urlBuilder: () => 'https://www.jazzcash.com.pk',
        androidPackage: 'com.techlogix.mobilinkcustomer',
        isOnline: true,
      ),
      PaymentMethod(
        id: 'easypaisa',
        name: 'Easypaisa',
        icon: Icons.phone_android,
        color: const Color(0xFF4CAF50),
        urlBuilder: () => 'https://www.easypaisa.com.pk',
        androidPackage: 'pk.com.telenor.phoenix',
        isOnline: true,
      ),
      PaymentMethod(
        id: 'sadapay',
        name: 'SadaPay',
        icon: Icons.account_balance_wallet,
        color: const Color(0xFF9C27B0),
        urlBuilder: () => 'https://sadapay.pk',
        androidPackage: 'com.sadapay.app',
        isOnline: true,
      ),
      PaymentMethod(
        id: 'nayapay',
        name: 'NayaPay',
        icon: Icons.account_balance_wallet,
        color: const Color(0xFF2196F3),
        urlBuilder: () => 'https://nayapay.com',
        androidPackage: 'com.nayapay.app',
        isOnline: true,
      ),
      PaymentMethod(
        id: 'whatsapp',
        name: 'WhatsApp',
        icon: Icons.message,
        color: const Color(0xFF25D366),
        urlBuilder: () {
          final phone = '92${receiverPhone.substring(1)}';
          final msg = 'Hi $receiverName, sending PKR ${amount.toStringAsFixed(0)} '
              'for "$expenseTitle" via Splivy app. '
              'Please confirm once received.';
          return 'https://wa.me/$phone?text=${Uri.encodeComponent(msg)}';
        },
        isOnline: true,
      ),
      const PaymentMethod(
        id: 'cash',
        name: 'Cash',
        icon: Icons.money,
        color: Color(0xFF00D4AA),
        isOnline: false,
      ),
    ];
  }

  Future<String?> uploadProof(File imageFile, String splitId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'proof_${splitId}_$timestamp.jpg';
    final bytes = await imageFile.readAsBytes();

    await _client.storage.from('payment-proofs').uploadBinary(
          filename,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    return _client.storage.from('payment-proofs').getPublicUrl(filename);
  }

  Future<void> payerMarksPaid({
    required String splitId,
    required String paymentMethod,
    required double amountPaid,
    String? proofUrl,
    required bool isGuest,
  }) async {
    final table = isGuest ? 'guest_splits' : 'expense_splits';

    await _client.from(table).update({
      'amount_paid': amountPaid,
      'payment_method': paymentMethod,
      'payment_proof_url': ?proofUrl,
      'payment_status': PaymentStatus.payerMarked,
      if (!isGuest) 'paid_by_user': _userId,
      'is_settled': false,
    }).eq('id', splitId);

    if (!isGuest) {
      final payerProfile = await _client
          .from('profiles')
          .select('full_name')
          .eq('id', _userId)
          .single();

      final payerName = payerProfile['full_name'] as String;

      await NotificationService().showPaymentReceivedNotification(
        payerName: payerName,
        amount: amountPaid,
        method: paymentMethod,
        splitId: splitId,
      );
    }
  }

  /// Reverts a "payer marked as paid" claim back to unpaid. Only valid before
  /// the receiver confirms — used when the payer marked paid by mistake or
  /// uploaded the wrong proof. Clears the amount paid, method, proof and payer.
  Future<void> cancelPaymentClaim({
    required String splitId,
    required bool isGuest,
  }) async {
    final table = isGuest ? 'guest_splits' : 'expense_splits';

    await _client.from(table).update({
      'payment_status': PaymentStatus.pending,
      'amount_paid': 0,
      'payment_method': null,
      'payment_proof_url': null,
      'is_settled': false,
      'settled_at': null,
      if (!isGuest) 'paid_by_user': null,
    }).eq('id', splitId);
  }

  Future<void> receiverConfirms({
    required String splitId,
    required bool isGuest,
  }) async {
    final table = isGuest ? 'guest_splits' : 'expense_splits';
    final now = DateTime.now().toIso8601String();

    await _client.from(table).update({
      if (!isGuest) 'confirmed_by': _userId,
      'payment_status': PaymentStatus.confirmed,
      'is_settled': true,
      'settled_at': now,
    }).eq('id', splitId);

    if (!isGuest) {
      final split = await _client
          .from('expense_splits')
          .select('paid_by_user, amount_paid')
          .eq('id', splitId)
          .single();

      final payerId = split['paid_by_user'] as String?;
      final amount = (split['amount_paid'] as num?)?.toDouble() ?? 0;

      if (payerId != null) {
        final receiverProfile = await _client
            .from('profiles')
            .select('full_name')
            .eq('id', _userId)
            .single();

        final receiverName = receiverProfile['full_name'] as String;

        await NotificationService().showPaymentConfirmedNotification(
          receiverName: receiverName,
          amount: amount,
        );
      }
    }
  }

  Future<void> cashSettlement({
    required String splitId,
    required bool payerIsMarking,
    required bool isGuest,
    required double amount,
  }) async {
    final table = isGuest ? 'guest_splits' : 'expense_splits';
    final now = DateTime.now().toIso8601String();

    final updateData = <String, dynamic>{
      'payment_method': 'cash',
      'payment_status': PaymentStatus.cashSettled,
      'is_settled': true,
      'settled_at': now,
      'amount_paid': amount,
    };

    if (!isGuest) {
      if (payerIsMarking) {
        updateData['paid_by_user'] = _userId;
      } else {
        updateData['confirmed_by'] = _userId;
      }
    }

    await _client.from(table).update(updateData).eq('id', splitId);

    if (!isGuest) {
      final currentUserProfile = await _client
          .from('profiles')
          .select('full_name')
          .eq('id', _userId)
          .single();

      final currentUserName = currentUserProfile['full_name'] as String;

      if (payerIsMarking) {
        await NotificationService().showCashPaymentNotification(
          payerName: currentUserName,
          amount: amount,
          isPayer: true,
        );
      } else {
        await NotificationService().showCashPaymentNotification(
          payerName: currentUserName,
          amount: amount,
          isPayer: false,
        );
      }
    }
  }

  Future<void> disputePayment({
    required String splitId,
    required String message,
    required bool isGuest,
  }) async {
    final table = isGuest ? 'guest_splits' : 'expense_splits';

    await _client.from(table).update({
      'payment_status': PaymentStatus.disputed,
      'dispute_message': message,
    }).eq('id', splitId);

    if (!isGuest) {
      final split = await _client
          .from('expense_splits')
          .select('paid_by_user, amount_paid')
          .eq('id', splitId)
          .single();

      final payerId = split['paid_by_user'] as String?;

      if (payerId != null) {
        final receiverProfile = await _client
            .from('profiles')
            .select('full_name')
            .eq('id', _userId)
            .single();

        final receiverName = receiverProfile['full_name'] as String;

        await NotificationService().showDisputeNotification(
          disputerName: receiverName,
          message: message,
        );
      }
    }
  }

  Future<Map<String, dynamic>?> getSplitPaymentInfo(
    String splitId, {
    required bool isGuest,
  }) async {
    final table = isGuest ? 'guest_splits' : 'expense_splits';
    return await _client.from(table).select().eq('id', splitId).maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getPendingConfirmations() async {
    final splits = await _client
        .from('expense_splits')
        .select(
            'id, expense_id, amount, payment_status, paid_by_user, payment_method, expenses!inner(title)')
        .eq('owed_to', _userId)
        .eq('payment_status', PaymentStatus.payerMarked);

    return (splits as List).map((split) {
      final expense = split['expenses'] as Map;
      return {
        ...split as Map<String, dynamic>,
        'expense_title': expense['title'],
      };
    }).toList();
  }
}
