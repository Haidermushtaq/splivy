import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';
import 'lottie_widget.dart';

Future<void> showPaymentBottomSheet(
  BuildContext context, {
  required String splitId,
  required double amount,
  required String payerName,
  required String receiverName,
  required String receiverPhone,
  required String expenseTitle,
  required bool isGuest,
  required bool isCurrentUserPayer,
  required VoidCallback onComplete,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PaymentBottomSheet(
      splitId: splitId,
      amount: amount,
      payerName: payerName,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      expenseTitle: expenseTitle,
      isGuest: isGuest,
      isCurrentUserPayer: isCurrentUserPayer,
      onComplete: onComplete,
    ),
  );
}

class _PaymentBottomSheet extends StatefulWidget {
  final String splitId;
  final double amount;
  final String payerName;
  final String receiverName;
  final String receiverPhone;
  final String expenseTitle;
  final bool isGuest;
  final bool isCurrentUserPayer;
  final VoidCallback onComplete;

  const _PaymentBottomSheet({
    required this.splitId,
    required this.amount,
    required this.payerName,
    required this.receiverName,
    required this.receiverPhone,
    required this.expenseTitle,
    required this.isGuest,
    required this.isCurrentUserPayer,
    required this.onComplete,
  });

  @override
  State<_PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<_PaymentBottomSheet> {
  static const _accent = Color(0xFF00D4AA);
  static const _cardColor = Color(0xFF0F3460);

  final _paymentService = PaymentService();
  final _imagePicker = ImagePicker();
  static const _appLauncher = MethodChannel('splivy/app_launcher');

  PaymentMethod? _selectedMethod;
  File? _proofImage;
  bool _hasOpenedPaymentApp = false;
  bool _isLoading = false;
  bool _showSuccess = false;

  late List<PaymentMethod> _methods;

  @override
  void initState() {
    super.initState();
    _methods = _paymentService.getPaymentMethods(
      receiverPhone: widget.receiverPhone,
      receiverName: widget.receiverName,
      amount: widget.amount,
      expenseTitle: widget.expenseTitle,
    );
  }

  Future<void> _openPaymentApp() async {
    if (_selectedMethod?.urlBuilder == null) return;

    // Prefer opening the installed wallet app over its website. The wallet
    // apps expose no payment deep link, so we just bring the app to the
    // foreground; the user then enters the recipient and amount manually.
    final pkg = _selectedMethod!.androidPackage;
    if (!kIsWeb && Platform.isAndroid && pkg != null) {
      // Use the platform's getLaunchIntentForPackage (via MainActivity) to open
      // the app the same way the home screen does. A raw MAIN/LAUNCHER intent
      // fails for apps whose launcher entry is an activity-alias, leaking to the
      // website fallback and a confusing "open with" browser chooser.
      try {
        final opened = await _appLauncher.invokeMethod<bool>(
          'launchApp',
          {'package': pkg},
        );
        if (opened == true) {
          setState(() => _hasOpenedPaymentApp = true);
          return;
        }
      } catch (_) {
        // Channel error; fall through to the Play Store / website.
      }

      // App not installed: open its Play Store page directly (no chooser).
      try {
        final store = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: 'market://details?id=$pkg',
          flags: const [268435456], // FLAG_ACTIVITY_NEW_TASK
        );
        await store.launch();
        setState(() => _hasOpenedPaymentApp = true);
        return;
      } catch (_) {
        // Play Store app missing; fall through to the website.
      }
    }

    // Non-Android, no package, or Play Store unavailable: fall back to the web.
    final fallback = !kIsWeb && Platform.isAndroid && pkg != null
        ? 'https://play.google.com/store/apps/details?id=$pkg'
        : _selectedMethod!.urlBuilder!();
    final url = Uri.parse(fallback);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      setState(() => _hasOpenedPaymentApp = true);
    }
  }

  Future<void> _pickProofImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _proofImage = File(picked.path));
    }
  }

  Future<void> _confirmPayment() async {
    if (_selectedMethod == null) return;

    if (_selectedMethod!.isOnline && _proofImage == null) {
      final proceed = await _showNoProofDialog();
      if (!proceed) return;
    }

    final confirmed = await _showConfirmDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      String? proofUrl;
      if (_proofImage != null) {
        proofUrl = await _paymentService.uploadProof(_proofImage!, widget.splitId);
      }

      if (_selectedMethod!.id == 'cash') {
        await _paymentService.cashSettlement(
          splitId: widget.splitId,
          payerIsMarking: true,
          isGuest: widget.isGuest,
          amount: widget.amount,
        );
      } else {
        await _paymentService.payerMarksPaid(
          splitId: widget.splitId,
          paymentMethod: _selectedMethod!.name,
          amountPaid: widget.amount,
          proofUrl: proofUrl,
          isGuest: widget.isGuest,
        );
      }

      setState(() {
        _isLoading = false;
        _showSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.of(context).pop();
        widget.onComplete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedMethod!.id == 'cash'
                ? 'Cash payment marked as settled!'
                : 'Payment marked! Waiting for ${widget.receiverName} to confirm.'),
            backgroundColor: _accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark payment: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _showNoProofDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'No proof uploaded',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Upload proof so ${widget.receiverName} can verify your payment.',
              style: const TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Confirm Without Proof', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop(false);
                  _pickProofImage();
                },
                child: const Text('Upload Proof', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Confirm Payment?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Mark PKR ${widget.amount.toStringAsFixed(0)} as paid to ${widget.receiverName} via ${_selectedMethod!.name}?',
              style: const TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Confirm ✅', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            const Text(
              'Payment Marked!',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _accent),
            SizedBox(height: 16),
            Text('Processing...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Pay PKR ${widget.amount.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('To: ${widget.receiverName}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text('For: ${widget.expenseTitle}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          const Text('Select Payment Method', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _methods.length,
            itemBuilder: (ctx, index) {
              final method = _methods[index];
              final selected = _selectedMethod?.id == method.id;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedMethod = method;
                  _hasOpenedPaymentApp = false;
                  _proofImage = null;
                }),
                child: Container(
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: selected ? Border.all(color: _accent, width: 2) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(method.icon, color: method.color, size: 28),
                      const SizedBox(height: 6),
                      Text(
                        method.name,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_selectedMethod != null) ...[
            const SizedBox(height: 20),
            if (_selectedMethod!.isOnline && _selectedMethod!.id != 'whatsapp') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openPaymentApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedMethod!.color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.open_in_new, color: Colors.white),
                  label: Text(
                    'Open ${_selectedMethod!.name}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            if (_selectedMethod!.id == 'whatsapp') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openPaymentApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedMethod!.color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.message, color: Colors.white),
                  label: const Text(
                    'Send via WhatsApp',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            if (_selectedMethod!.isOnline && _hasOpenedPaymentApp) ...[
              const SizedBox(height: 16),
              const Text('Upload Payment Screenshot', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const Text('Upload proof of payment (recommended)', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickProofImage,
                child: Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade700, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _proofImage == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined, color: Colors.grey, size: 32),
                            SizedBox(height: 6),
                            Text('Tap to upload receipt', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        )
                      : Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_proofImage!, width: double.infinity, height: 100, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => _proofImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
            if (_selectedMethod!.id == 'cash') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.money, color: _accent, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cash Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text(
                            'PKR ${widget.amount.toStringAsFixed(0)} to ${widget.receiverName}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_selectedMethod!.isOnline && !_hasOpenedPaymentApp && _selectedMethod!.id != 'cash')
                    ? null
                    : _confirmPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  disabledBackgroundColor: Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _selectedMethod!.id == 'cash' ? 'Mark as Paid - Cash' : 'Confirm Payment',
                  style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
