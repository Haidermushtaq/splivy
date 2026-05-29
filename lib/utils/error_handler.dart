import 'package:flutter/material.dart';

/// Centralized error and success feedback for the app.
/// Use instead of raw SnackBar calls throughout all screens.
class ErrorHandler {
  static const _accent = Color(0xFF00D4AA);
  static const _errorColor = Color(0xFFFF6B6B);

  /// Converts a raw exception or error string into a user-friendly message.
  static String getReadableError(dynamic error) {
    final msg = error.toString().toLowerCase();

    if (msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        msg.contains('no internet')) {
      return 'No internet connection. Please check your network.';
    }
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'Wrong email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email before logging in.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already registered')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('username already taken')) {
      return 'This username is not available.';
    }
    if (msg.contains('jwt expired') || msg.contains('session expired')) {
      return 'Your session has expired. Please log in again.';
    }
    if (msg.contains('permission denied') ||
        msg.contains('row level security')) {
      return "You don't have permission to do this.";
    }
    if (msg.contains('violates unique constraint')) {
      return 'This record already exists.';
    }
    if (msg.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (msg.contains('all guests must be settled')) {
      return 'Settle all guests before archiving this expense.';
    }

    final stripped = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Error: ', '');
    if (stripped.length > 120) return 'An unexpected error occurred.';
    return stripped;
  }

  /// Shows a red floating snackbar with an error icon.
  static void showError(BuildContext context, dynamic error) {
    final message = getReadableError(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Shows a teal floating snackbar with a check icon.
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.black, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: Colors.black, fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: _accent,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
