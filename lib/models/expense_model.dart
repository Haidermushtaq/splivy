import 'expense_payer_model.dart';

class ExpenseSplit {
  final String id;
  final String expenseId;
  final String userId;
  final String? userName;
  final double amount;
  final bool isSettled;
  final String paymentStatus;

  const ExpenseSplit({
    required this.id,
    required this.expenseId,
    required this.userId,
    this.userName,
    required this.amount,
    required this.isSettled,
    this.paymentStatus = 'pending',
  });

  factory ExpenseSplit.fromJson(Map<String, dynamic> json, {String? userName}) {
    return ExpenseSplit(
      id: json['id'] as String,
      expenseId: json['expense_id'] as String,
      userId: json['user_id'] as String,
      userName: userName,
      amount: (json['amount'] as num).toDouble(),
      isSettled: json['is_settled'] as bool? ?? false,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
    );
  }
}

class Expense {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String? paidBy;
  final String paidByName;
  final String category;
  final String? note;
  final double userShare;
  final bool isSettled;
  final bool isCustom;
  final bool isArchived;
  final bool isMultiPayer;
  final List<ExpensePayer> payers;
  final List<ExpenseSplit> splits;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    this.paidBy,
    required this.paidByName,
    required this.category,
    this.note,
    required this.userShare,
    required this.isSettled,
    required this.isCustom,
    required this.isArchived,
    this.isMultiPayer = false,
    this.payers = const [],
    this.splits = const [],
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense.fromMap(json);

  factory Expense.fromMap(
    Map<String, dynamic> map, {
    String paidByName = 'Unknown',
    double userShare = 0,
    bool isSettled = false,
    List<ExpensePayer> payers = const [],
    List<ExpenseSplit> splits = const [],
  }) {
    return Expense(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      paidBy: map['paid_by'] as String?,
      paidByName: paidByName,
      category: map['category'] as String? ?? 'Other',
      note: map['note'] as String?,
      userShare: userShare,
      isSettled: isSettled,
      isCustom: map['is_custom'] as bool? ?? false,
      isArchived: map['is_archived'] as bool? ?? false,
      isMultiPayer: map['is_multi_payer'] as bool? ?? false,
      payers: payers,
      splits: splits,
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
  final String splitId;
  final String name;
  final String groupName;
  final double amount;
  final String dueSince;
  final bool youOwe;
  final String expenseTitle;
  final String? receiverPhone;
  final String paymentStatus;
  final String? paymentProofUrl;
  final String? paymentMethod;

  const DebtItem({
    required this.expenseId,
    required this.splitId,
    required this.name,
    required this.groupName,
    required this.amount,
    required this.dueSince,
    required this.youOwe,
    required this.expenseTitle,
    this.receiverPhone,
    this.paymentStatus = 'pending',
    this.paymentProofUrl,
    this.paymentMethod,
  });

  bool get isPending => paymentStatus == 'pending';
  bool get isPayerMarked => paymentStatus == 'payer_marked';
  bool get isConfirmed => paymentStatus == 'confirmed';
  bool get isCashSettled => paymentStatus == 'cash_settled';
  bool get isDisputed => paymentStatus == 'disputed';
  bool get isSettled => isConfirmed || isCashSettled;
}

class GuestSplit {
  final String id;
  final String expenseId;
  final String guestName;
  final String guestPhone;
  final double amount;
  final bool isSettled;
  final DateTime createdAt;

  const GuestSplit({
    required this.id,
    required this.expenseId,
    required this.guestName,
    required this.guestPhone,
    required this.amount,
    required this.isSettled,
    required this.createdAt,
  });
}

class GuestSplitInput {
  final String guestName;
  final String guestPhone;
  final double amount;

  const GuestSplitInput({
    required this.guestName,
    required this.guestPhone,
    required this.amount,
  });
}

class CustomExpenseDetail {
  final Expense expense;
  final List<GuestSplit> guests;

  const CustomExpenseDetail({required this.expense, required this.guests});

  bool get allSettled => guests.every((g) => g.isSettled);
}
