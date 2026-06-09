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
  final String? groupId;
  final String title;
  final double amount;
  final String? paidBy;
  final String paidByName;
  final String category;
  final String? note;
  final double userShare;
  final bool userOwes;
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
    this.userOwes = false,
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
    bool userOwes = false,
    bool isSettled = false,
    List<ExpensePayer> payers = const [],
    List<ExpenseSplit> splits = const [],
  }) {
    return Expense(
      id: map['id'] as String,
      groupId: map['group_id'] as String?,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      paidBy: map['paid_by'] as String?,
      paidByName: paidByName,
      category: map['category'] as String? ?? 'Other',
      note: map['note'] as String?,
      userShare: userShare,
      userOwes: userOwes,
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
  final String? avatarUrl;

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
    this.avatarUrl,
  });

  bool get isPending => paymentStatus == 'pending';
  bool get isPayerMarked => paymentStatus == 'payer_marked';
  bool get isConfirmed => paymentStatus == 'confirmed';
  bool get isCashSettled => paymentStatus == 'cash_settled';
  bool get isNetted => paymentStatus == 'netted';
  bool get isDisputed => paymentStatus == 'disputed';
  bool get isSettled => isConfirmed || isCashSettled || isNetted;
}

class GuestSplit {
  final String id;
  final String expenseId;
  final String guestName;
  final String guestPhone;

  /// Net amount between the guest and the creator (current user). Positive =
  /// the guest owes you; negative = you owe the guest.
  final double amount;

  /// The guest's full share of the bill (before counting what they paid).
  final double share;

  /// How much the guest actually paid toward the bill.
  final double amountPaid;
  final bool isSettled;
  final DateTime createdAt;

  const GuestSplit({
    required this.id,
    required this.expenseId,
    required this.guestName,
    required this.guestPhone,
    required this.amount,
    this.share = 0,
    this.amountPaid = 0,
    required this.isSettled,
    required this.createdAt,
  });
}

/// An informational debt between two guests within a single expense, derived
/// from the minimal-transfer settlement (neither party is a registered user).
class GuestGuestDebt {
  final String id;
  final String expenseId;
  final String debtorName;
  final String? debtorPhone;
  final String creditorName;
  final String? creditorPhone;
  final double amount;
  final bool isSettled;

  const GuestGuestDebt({
    required this.id,
    required this.expenseId,
    required this.debtorName,
    this.debtorPhone,
    required this.creditorName,
    this.creditorPhone,
    required this.amount,
    required this.isSettled,
  });

  factory GuestGuestDebt.fromJson(Map<String, dynamic> json) {
    return GuestGuestDebt(
      id: json['id'] as String,
      expenseId: json['expense_id'] as String,
      debtorName: json['debtor_name'] as String? ?? '',
      debtorPhone: json['debtor_phone'] as String?,
      creditorName: json['creditor_name'] as String? ?? '',
      creditorPhone: json['creditor_phone'] as String?,
      amount: (json['amount'] as num).toDouble(),
      isSettled: json['is_settled'] as bool? ?? false,
    );
  }
}

class GuestSplitInput {
  final String guestName;
  final String guestPhone;

  /// The guest's share of the bill (what they owe before counting what they
  /// already paid).
  final double amount;

  /// How much this guest actually paid toward the bill.
  final double amountPaid;

  const GuestSplitInput({
    required this.guestName,
    required this.guestPhone,
    required this.amount,
    this.amountPaid = 0,
  });

  /// Net amount the guest still owes the expense owner (share minus paid).
  double get netOwed => amount - amountPaid;
}

/// A registered-user debt within a one-time expense: a friend who owes the
/// creator. Mirrors a single `expense_splits` edge (debtor -> me).
class FriendDebt {
  final String splitId;
  final String userId;
  final String name;
  final String? phone;
  final double amount;
  final bool isSettled;

  const FriendDebt({
    required this.splitId,
    required this.userId,
    required this.name,
    this.phone,
    required this.amount,
    required this.isSettled,
  });
}

/// A single contributor's payment toward an expense, for display in the
/// "who paid what" breakdown (covers both registered users and guests).
class PayerContribution {
  final String name;
  final double amount;
  final bool isYou;

  const PayerContribution({
    required this.name,
    required this.amount,
    this.isYou = false,
  });
}

/// A single settlement edge within a group expense: [debtorName] owes
/// [creditorName] [amount]. Either party may be the current user, in which case
/// their name is rendered as "You".
class ExpenseSplitEdge {
  final String splitId;
  final String debtorId;
  final String debtorName;
  final String creditorId;
  final String creditorName;
  final double amount;
  final bool isSettled;
  final String paymentStatus;

  /// Portion of the original debt that was cancelled by auto-netting. For a
  /// still-pending split the original debt was `amount + amountPaid`; for a
  /// fully-netted split `amount` already equals the original and this is the
  /// amount that was offset.
  final double amountPaid;

  const ExpenseSplitEdge({
    required this.splitId,
    required this.debtorId,
    required this.debtorName,
    required this.creditorId,
    required this.creditorName,
    required this.amount,
    required this.isSettled,
    this.paymentStatus = 'pending',
    this.amountPaid = 0,
  });

  bool get debtorIsYou => debtorName == 'You';
  bool get creditorIsYou => creditorName == 'You';
  bool get involvesYou => debtorIsYou || creditorIsYou;

  /// True when part of this debt was cancelled against an offsetting debt.
  bool get wasOffset => amountPaid > 0.01;

  /// The original debt before any offsetting was applied.
  double get originalAmount =>
      paymentStatus == 'netted' ? amount : amount + amountPaid;
}

/// Full detail of a single group expense: the expense, its group name, the
/// "who paid what" breakdown, and every debtor -> creditor settlement edge.
class GroupExpenseDetail {
  final Expense expense;
  final String groupName;
  final List<PayerContribution> payers;
  final List<ExpenseSplitEdge> edges;

  const GroupExpenseDetail({
    required this.expense,
    required this.groupName,
    this.payers = const [],
    this.edges = const [],
  });
}

/// A single settled debt between the current user and one counterpart, used by
/// the Settlement History screen. Covers registered-user splits (either
/// direction) and guest splits, and both ordinary payments and auto-net
/// offsets ([isOffset] true when the debt was cancelled rather than paid).
class SettlementRecord {
  final String id;
  final String expenseId;
  final String expenseTitle;
  final String groupName;
  final String counterpartName;

  /// True when the current user was the debtor (you paid the counterpart).
  final bool youPaid;
  final double amount;
  final String? paymentMethod;
  final String? paymentProofUrl;
  final String paymentStatus;

  /// True when this debt was cancelled by auto-netting rather than a payment.
  final bool isOffset;
  final bool isGuest;
  final DateTime settledAt;

  const SettlementRecord({
    required this.id,
    required this.expenseId,
    required this.expenseTitle,
    required this.groupName,
    required this.counterpartName,
    required this.youPaid,
    required this.amount,
    this.paymentMethod,
    this.paymentProofUrl,
    this.paymentStatus = 'confirmed',
    this.isOffset = false,
    this.isGuest = false,
    required this.settledAt,
  });

  bool get isCash =>
      paymentStatus == 'cash_settled' || paymentMethod == 'cash';
}

class CustomExpenseDetail {
  final Expense expense;
  final List<GuestSplit> guests;
  final List<FriendDebt> friendDebts;
  final List<GuestGuestDebt> guestGuestDebts;
  final List<PayerContribution> payers;

  const CustomExpenseDetail({
    required this.expense,
    required this.guests,
    this.friendDebts = const [],
    this.guestGuestDebts = const [],
    this.payers = const [],
  });

  bool get allSettled =>
      guests.every((g) => g.isSettled) &&
      friendDebts.every((f) => f.isSettled) &&
      guestGuestDebts.every((d) => d.isSettled);
}
