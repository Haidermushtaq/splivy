class Expense {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String paidBy;
  final String paidByName;
  final String category;
  final String? note;
  final double userShare;
  final bool isSettled;
  final bool isCustom;
  final bool isArchived;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.paidByName,
    required this.category,
    this.note,
    required this.userShare,
    required this.isSettled,
    required this.isCustom,
    required this.isArchived,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense.fromMap(json);

  factory Expense.fromMap(
    Map<String, dynamic> map, {
    String paidByName = 'Unknown',
    double userShare = 0,
    bool isSettled = false,
  }) {
    return Expense(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      paidBy: map['paid_by'] as String,
      paidByName: paidByName,
      category: map['category'] as String? ?? 'Other',
      note: map['note'] as String?,
      userShare: userShare,
      isSettled: isSettled,
      isCustom: map['is_custom'] as bool? ?? false,
      isArchived: map['is_archived'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class UserBalance {
  final double totalOwed;
  final double totalOwing;

  const UserBalance({required this.totalOwed, required this.totalOwing});

  double get netBalance => totalOwed - totalOwing;
}

class DebtItem {
  final String expenseId;
  final String name;
  final String groupName;
  final double amount;
  final String dueSince;
  final bool youOwe;

  const DebtItem({
    required this.expenseId,
    required this.name,
    required this.groupName,
    required this.amount,
    required this.dueSince,
    required this.youOwe,
  });
}
