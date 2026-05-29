import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_model.dart';
import '../services/expenses_service.dart';

/// Singleton [ExpensesService] instance.
final expensesServiceProvider =
    Provider<ExpensesService>((ref) => ExpensesService());

/// One-shot fetch of all expenses for a given group.
///
/// Prefer [groupExpensesStreamProvider] in GroupDetailScreen for live updates.
/// Updates when: manually invalidated.
final groupExpensesProvider =
    FutureProvider.family<List<Expense>, String>((ref, groupId) {
  return ref.read(expensesServiceProvider).getGroupExpenses(groupId);
});

/// One-shot fetch of the current user's total balance (what they owe vs. are owed).
///
/// Prefer [userBalanceStreamProvider] in DashboardScreen for live updates.
/// Updates when: manually invalidated.
final userBalanceProvider = FutureProvider<UserBalance>((ref) {
  return ref.read(expensesServiceProvider).getUserTotalBalance();
});
