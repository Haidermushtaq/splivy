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

  Map<String, dynamic> toCache() => {
        'id': id,
        'group_id': groupId,
        'title': title,
        'amount': amount,
        'paid_by': paidBy,
        'paid_by_name': paidByName,
        'category': category,
        'note': note,
        'user_share': userShare,
        'user_owes': userOwes,
        'is_settled': isSettled,
        'is_custom': isCustom,
        'is_archived': isArchived,
        'is_multi_payer': isMultiPayer,
        'created_at': createdAt.toIso8601String(),
      };

  factory Expense.fromCache(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        groupId: j['group_id'] as String?,
        title: j['title'] as String,
        amount: (j['amount'] as num).toDouble(),
        paidBy: j['paid_by'] as String?,
        paidByName: j['paid_by_name'] as String? ?? 'Unknown',
        category: j['category'] as String? ?? 'Other',
        note: j['note'] as String?,
        userShare: (j['user_share'] as num?)?.toDouble() ?? 0,
        userOwes: j['user_owes'] as bool? ?? false,
        isSettled: j['is_settled'] as bool? ?? false,
        isCustom: j['is_custom'] as bool? ?? false,
        isArchived: j['is_archived'] as bool? ?? false,
        isMultiPayer: j['is_multi_payer'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class UserBalance {
  final double totalOwed;
  final double totalOwing;

  const UserBalance({required this.totalOwed, required this.totalOwing});

  double get netBalance => totalOwed - totalOwing;

  Map<String, dynamic> toCache() =>
      {'total_owed': totalOwed, 'total_owing': totalOwing};

  factory UserBalance.fromCache(Map<String, dynamic> j) => UserBalance(
        totalOwed: (j['total_owed'] as num).toDouble(),
        totalOwing: (j['total_owing'] as num).toDouble(),
      );
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

  Map<String, dynamic> toCache() => {
        'expense_id': expenseId,
        'split_id': splitId,
        'name': name,
        'group_name': groupName,
        'amount': amount,
        'due_since': dueSince,
        'you_owe': youOwe,
        'expense_title': expenseTitle,
        'receiver_phone': receiverPhone,
        'payment_status': paymentStatus,
        'payment_proof_url': paymentProofUrl,
        'payment_method': paymentMethod,
        'avatar_url': avatarUrl,
      };

  factory DebtItem.fromCache(Map<String, dynamic> j) => DebtItem(
        expenseId: j['expense_id'] as String,
        splitId: j['split_id'] as String,
        name: j['name'] as String,
        groupName: j['group_name'] as String,
        amount: (j['amount'] as num).toDouble(),
        dueSince: j['due_since'] as String,
        youOwe: j['you_owe'] as bool,
        expenseTitle: j['expense_title'] as String,
        receiverPhone: j['receiver_phone'] as String?,
        paymentStatus: j['payment_status'] as String? ?? 'pending',
        paymentProofUrl: j['payment_proof_url'] as String?,
        paymentMethod: j['payment_method'] as String?,
        avatarUrl: j['avatar_url'] as String?,
      );
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

  Map<String, dynamic> toCache() => {
        'id': id,
        'expense_id': expenseId,
        'guest_name': guestName,
        'guest_phone': guestPhone,
        'amount': amount,
        'share': share,
        'amount_paid': amountPaid,
        'is_settled': isSettled,
        'created_at': createdAt.toIso8601String(),
      };

  factory GuestSplit.fromCache(Map<String, dynamic> j) => GuestSplit(
        id: j['id'] as String,
        expenseId: j['expense_id'] as String,
        guestName: j['guest_name'] as String,
        guestPhone: j['guest_phone'] as String,
        amount: (j['amount'] as num).toDouble(),
        share: (j['share'] as num?)?.toDouble() ?? 0,
        amountPaid: (j['amount_paid'] as num?)?.toDouble() ?? 0,
        isSettled: j['is_settled'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
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

  Map<String, dynamic> toCache() => {
        'id': id,
        'expense_id': expenseId,
        'debtor_name': debtorName,
        'debtor_phone': debtorPhone,
        'creditor_name': creditorName,
        'creditor_phone': creditorPhone,
        'amount': amount,
        'is_settled': isSettled,
      };

  factory GuestGuestDebt.fromCache(Map<String, dynamic> j) =>
      GuestGuestDebt.fromJson(j);
}

/// A registered participant reconstructed from a stored expense so it can be
/// prefilled into the add/edit form. [owed] is recovered as `paid - net`, where
/// net comes from the minimized settlement edges; [includedInSplit] is true when
/// the person carries any share of the bill.
class EditableParticipant {
  final String userId;
  final String name;
  final bool isYou;
  final double paid;
  final double owed;
  final bool includedInSplit;

  const EditableParticipant({
    required this.userId,
    required this.name,
    required this.isYou,
    required this.paid,
    required this.owed,
    required this.includedInSplit,
  });
}

/// A guest reconstructed from a stored expense for prefilling the edit form.
/// Guests store their share and paid amount directly, so they're always exact.
class EditableGuest {
  final String name;
  final String phone;
  final double owed;
  final double paid;

  const EditableGuest({
    required this.name,
    required this.phone,
    required this.owed,
    required this.paid,
  });
}

/// A whole expense reconstructed into the shape the add/edit form needs:
/// header fields plus per-person paid/owed amounts. Used only by the guarded
/// full-edit flow; never cached (editing requires connectivity).
class EditableExpense {
  final String expenseId;
  final String? groupId;
  final String title;
  final double totalAmount;
  final String category;
  final String? note;
  final bool isMultiPayer;
  final bool isCustomSplit;
  final String? singlePayerId;
  final List<EditableParticipant> participants;
  final List<EditableGuest> guests;

  const EditableExpense({
    required this.expenseId,
    required this.groupId,
    required this.title,
    required this.totalAmount,
    required this.category,
    required this.note,
    required this.isMultiPayer,
    required this.isCustomSplit,
    required this.singlePayerId,
    required this.participants,
    required this.guests,
  });

  bool get isOneTime => groupId == null;
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

  Map<String, dynamic> toCache() => {
        'split_id': splitId,
        'user_id': userId,
        'name': name,
        'phone': phone,
        'amount': amount,
        'is_settled': isSettled,
      };

  factory FriendDebt.fromCache(Map<String, dynamic> j) => FriendDebt(
        splitId: j['split_id'] as String,
        userId: j['user_id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
        amount: (j['amount'] as num).toDouble(),
        isSettled: j['is_settled'] as bool? ?? false,
      );
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

  Map<String, dynamic> toCache() =>
      {'name': name, 'amount': amount, 'is_you': isYou};

  factory PayerContribution.fromCache(Map<String, dynamic> j) =>
      PayerContribution(
        name: j['name'] as String,
        amount: (j['amount'] as num).toDouble(),
        isYou: j['is_you'] as bool? ?? false,
      );
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

  Map<String, dynamic> toCache() => {
        'split_id': splitId,
        'debtor_id': debtorId,
        'debtor_name': debtorName,
        'creditor_id': creditorId,
        'creditor_name': creditorName,
        'amount': amount,
        'is_settled': isSettled,
        'payment_status': paymentStatus,
        'amount_paid': amountPaid,
      };

  factory ExpenseSplitEdge.fromCache(Map<String, dynamic> j) =>
      ExpenseSplitEdge(
        splitId: j['split_id'] as String,
        debtorId: j['debtor_id'] as String,
        debtorName: j['debtor_name'] as String,
        creditorId: j['creditor_id'] as String,
        creditorName: j['creditor_name'] as String,
        amount: (j['amount'] as num).toDouble(),
        isSettled: j['is_settled'] as bool? ?? false,
        paymentStatus: j['payment_status'] as String? ?? 'pending',
        amountPaid: (j['amount_paid'] as num?)?.toDouble() ?? 0,
      );
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

  Map<String, dynamic> toCache() => {
        'expense': expense.toCache(),
        'group_name': groupName,
        'payers': payers.map((p) => p.toCache()).toList(),
        'edges': edges.map((e) => e.toCache()).toList(),
      };

  factory GroupExpenseDetail.fromCache(Map<String, dynamic> j) =>
      GroupExpenseDetail(
        expense: Expense.fromCache((j['expense'] as Map).cast<String, dynamic>()),
        groupName: j['group_name'] as String,
        payers: (j['payers'] as List)
            .map((p) =>
                PayerContribution.fromCache((p as Map).cast<String, dynamic>()))
            .toList(),
        edges: (j['edges'] as List)
            .map((e) =>
                ExpenseSplitEdge.fromCache((e as Map).cast<String, dynamic>()))
            .toList(),
      );
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

  Map<String, dynamic> toCache() => {
        'id': id,
        'expense_id': expenseId,
        'expense_title': expenseTitle,
        'group_name': groupName,
        'counterpart_name': counterpartName,
        'you_paid': youPaid,
        'amount': amount,
        'payment_method': paymentMethod,
        'payment_proof_url': paymentProofUrl,
        'payment_status': paymentStatus,
        'is_offset': isOffset,
        'is_guest': isGuest,
        'settled_at': settledAt.toIso8601String(),
      };

  factory SettlementRecord.fromCache(Map<String, dynamic> j) =>
      SettlementRecord(
        id: j['id'] as String,
        expenseId: j['expense_id'] as String,
        expenseTitle: j['expense_title'] as String,
        groupName: j['group_name'] as String,
        counterpartName: j['counterpart_name'] as String,
        youPaid: j['you_paid'] as bool,
        amount: (j['amount'] as num).toDouble(),
        paymentMethod: j['payment_method'] as String?,
        paymentProofUrl: j['payment_proof_url'] as String?,
        paymentStatus: j['payment_status'] as String? ?? 'confirmed',
        isOffset: j['is_offset'] as bool? ?? false,
        isGuest: j['is_guest'] as bool? ?? false,
        settledAt: DateTime.parse(j['settled_at'] as String),
      );
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

  Map<String, dynamic> toCache() => {
        'expense': expense.toCache(),
        'guests': guests.map((g) => g.toCache()).toList(),
        'friend_debts': friendDebts.map((f) => f.toCache()).toList(),
        'guest_guest_debts':
            guestGuestDebts.map((d) => d.toCache()).toList(),
        'payers': payers.map((p) => p.toCache()).toList(),
      };

  factory CustomExpenseDetail.fromCache(Map<String, dynamic> j) =>
      CustomExpenseDetail(
        expense:
            Expense.fromCache((j['expense'] as Map).cast<String, dynamic>()),
        guests: (j['guests'] as List)
            .map((g) => GuestSplit.fromCache((g as Map).cast<String, dynamic>()))
            .toList(),
        friendDebts: (j['friend_debts'] as List)
            .map((f) => FriendDebt.fromCache((f as Map).cast<String, dynamic>()))
            .toList(),
        guestGuestDebts: (j['guest_guest_debts'] as List)
            .map((d) =>
                GuestGuestDebt.fromCache((d as Map).cast<String, dynamic>()))
            .toList(),
        payers: (j['payers'] as List)
            .map((p) =>
                PayerContribution.fromCache((p as Map).cast<String, dynamic>()))
            .toList(),
      );
}
