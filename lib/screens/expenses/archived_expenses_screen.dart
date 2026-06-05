import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/expenses_provider.dart';
import '../../services/expenses_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/lottie_widget.dart';

class ArchivedExpensesScreen extends ConsumerWidget {
  const ArchivedExpensesScreen({super.key});

  static const _accent = Color(0xFF00D4AA);

  static IconData _categoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant_outlined;
      case 'Transport':
        return Icons.directions_car_outlined;
      case 'Shopping':
        return Icons.shopping_bag_outlined;
      case 'Utilities':
        return Icons.bolt_outlined;
      case 'Entertainment':
        return Icons.movie_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  Future<void> _confirmUnarchive(
      BuildContext context, WidgetRef ref, RecentExpense expense) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Unarchive Expense',
      message: 'Move this expense back to active?',
      confirmText: 'Unarchive',
      icon: const Icon(Icons.unarchive_outlined, color: _accent),
    );

    if (ok != true) return;
    try {
      await ref.read(expensesServiceProvider).unarchiveExpense(expense.id);
      ref.invalidate(archivedExpensesProvider);
      ref.invalidate(recentExpensesProvider);
      if (!context.mounted) return;
      ErrorHandler.showSuccess(context, 'Expense unarchived');
    } catch (e) {
      if (!context.mounted) return;
      ErrorHandler.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(archivedExpensesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Expenses'),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _accent)),
        error: (e, _) => Center(
          child: Text('Failed to load: $e',
              style: const TextStyle(color: Colors.grey)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LottieWidget(
                    assetPath: 'assets/animations/empty.json',
                    width: 180,
                    height: 180,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No archived expenses yet.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Settled expenses will appear here.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _buildCard(context, ref, items[i]),
          );
        },
      ),
    );
  }

  Widget _buildCard(
      BuildContext context, WidgetRef ref, RecentExpense expense) {
    final subtitleParts = <String>[
      if (expense.groupName != null && expense.groupName!.isNotEmpty)
        expense.groupName!,
      expense.paidByName,
      _formatDate(expense.createdAt),
    ];

    return GestureDetector(
      onLongPress: () => _confirmUnarchive(context, ref, expense),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF1A1A2E),
            child: Icon(_categoryIcon(expense.category),
                color: Colors.grey),
          ),
          title: Text(
            expense.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitleParts.join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PKR ${expense.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              const Text(
                'Settled ✅',
                style: TextStyle(color: _accent, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
