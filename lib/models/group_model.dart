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

  Map<String, dynamic> toCache() => {
        'id': id,
        'name': name,
        'created_by': createdBy,
        'member_count': memberCount,
        'last_expense': lastExpense,
        'user_balance': userBalance,
        'is_archived': isArchived,
        'created_at': createdAt.toIso8601String(),
      };

  factory Group.fromCache(Map<String, dynamic> j) => Group(
        id: j['id'] as String,
        name: j['name'] as String,
        createdBy: j['created_by'] as String,
        memberCount: j['member_count'] as int? ?? 0,
        lastExpense: j['last_expense'] as String? ?? 'No expenses yet',
        userBalance: (j['user_balance'] as num?)?.toDouble() ?? 0,
        isArchived: j['is_archived'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class GroupMember {
  final String id;
  final String fullName;
  final String username;
  final String? avatarUrl;

  const GroupMember({
    required this.id,
    required this.fullName,
    required this.username,
    this.avatarUrl,
  });

  Map<String, dynamic> toCache() => {
        'id': id,
        'full_name': fullName,
        'username': username,
        'avatar_url': avatarUrl,
      };

  factory GroupMember.fromCache(Map<String, dynamic> j) => GroupMember(
        id: j['id'] as String,
        fullName: j['full_name'] as String,
        username: j['username'] as String,
        avatarUrl: j['avatar_url'] as String?,
      );
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

  Map<String, dynamic> toCache() => {
        'group': group.toCache(),
        'members': members.map((m) => m.toCache()).toList(),
        'expenses': expenses.map((e) => e.toCache()).toList(),
      };

  factory GroupDetail.fromCache(Map<String, dynamic> j) => GroupDetail(
        group: Group.fromCache((j['group'] as Map).cast<String, dynamic>()),
        members: (j['members'] as List)
            .map((m) => GroupMember.fromCache((m as Map).cast<String, dynamic>()))
            .toList(),
        expenses: (j['expenses'] as List)
            .map((e) => Expense.fromCache((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
