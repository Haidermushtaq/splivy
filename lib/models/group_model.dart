import 'expense_model.dart';

class Group {
  final String id;
  final String name;
  final String createdBy;
  final int memberCount;
  final String lastExpense;
  final double userBalance;
  final bool isArchived;
  final DateTime createdAt;

  const Group({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberCount,
    required this.lastExpense,
    required this.userBalance,
    required this.isArchived,
    required this.createdAt,
  });

  factory Group.fromMap(
    Map<String, dynamic> map, {
    int memberCount = 0,
    String lastExpense = 'No expenses yet',
    double userBalance = 0,
  }) {
    return Group(
      id: map['id'] as String,
      name: map['name'] as String,
      createdBy: map['created_by'] as String,
      memberCount: memberCount,
      lastExpense: lastExpense,
      userBalance: userBalance,
      isArchived: map['is_archived'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class GroupMember {
  final String id;
  final String fullName;
  final String username;

  const GroupMember({
    required this.id,
    required this.fullName,
    required this.username,
  });
}

class GroupDetail {
  final Group group;
  final List<GroupMember> members;
  final List<Expense> expenses;

  const GroupDetail({
    required this.group,
    required this.members,
    required this.expenses,
  });
}
