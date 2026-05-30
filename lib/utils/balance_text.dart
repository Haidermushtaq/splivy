import 'package:flutter/material.dart';

/// Sign-free phrasing for debts. A positive [amount] means the named person
/// owes the current user; a negative [amount] means the current user owes them.
class BalanceText {
  static const owedColor = Color(0xFF00D4AA);
  static const oweColor = Color(0xFFFF6B6B);

  /// e.g. "Haris owes you PKR 550" or "You owe Haris PKR 550".
  static String sentence(String name, double amount) {
    final abs = amount.abs().toStringAsFixed(0);
    if (amount >= 0) return '$name owes you PKR $abs';
    return 'You owe $name PKR $abs';
  }

  /// Green when the person owes the user, red when the user owes them.
  static Color color(double amount) => amount >= 0 ? owedColor : oweColor;
}
