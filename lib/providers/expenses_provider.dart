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

/// Recent expenses the current user is part of, newest first (max 20).
/// autoDispose: refetches whenever the dashboard is re-entered, so archived
/// /settled expenses drop off the feed without a manual refresh.
final recentExpensesProvider =
    FutureProvider.autoDispose<List<RecentExpense>>((ref) {
  return ref.read(expensesServiceProvider).getRecentExpenses();
});

/// Archived (settled) expenses the current user is part of.
/// autoDispose: refetches each time the archived screen opens.
final archivedExpensesProvider =
    FutureProvider.autoDispose<List<RecentExpense>>((ref) {
  return ref.read(expensesServiceProvider).getArchivedExpenses();
});

/// Full detail of every one-time (custom) expense the user is part of.
/// Cached so tapping a recent-activity row opens instantly instead of
/// re-fetching the whole feed on each tap. autoDispose keeps it fresh on
/// re-entry while still serving repeated taps from the in-flight cache.
final customExpensesProvider =
    FutureProvider.autoDispose<List<CustomExpenseDetail>>((ref) {
  return ref.read(expensesServiceProvider).getCustomExpenses();
});
