import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_model.dart';
import '../services/expenses_service.dart';

final expensesServiceProvider =
    Provider<ExpensesService>((ref) => ExpensesService());

final groupExpensesProvider =
    FutureProvider.family<List<Expense>, String>((ref, groupId) {
  return ref.read(expensesServiceProvider).getGroupExpenses(groupId);
});

final userBalanceProvider = FutureProvider<UserBalance>((ref) {
  return ref.read(expensesServiceProvider).getUserTotalBalance();
});
