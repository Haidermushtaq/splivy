class Profile {
  final String id;
  final String fullName;
  final String username;
  final String email;
  final String? avatarUrl;

  const Profile({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    this.avatarUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        username: json['username'] as String,
        email: json['email'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
      );
}

class Friend {
  final String id;
  final String userId;
  final String friendId;
  final String fullName;
  final String username;
  final String email;
  final double balance;
  final String status;
  final String? avatarUrl;

  const Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.fullName,
    required this.username,
    required this.email,
    required this.balance,
    required this.status,
    this.avatarUrl,
  });

  Map<String, dynamic> toCache() => {
        'id': id,
        'user_id': userId,
        'friend_id': friendId,
        'full_name': fullName,
        'username': username,
        'email': email,
        'balance': balance,
        'status': status,
        'avatar_url': avatarUrl,
      };

  factory Friend.fromCache(Map<String, dynamic> j) => Friend(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        friendId: j['friend_id'] as String,
        fullName: j['full_name'] as String,
        username: j['username'] as String,
        email: j['email'] as String? ?? '',
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String,
        avatarUrl: j['avatar_url'] as String?,
      );
}

/// A single expense between the current user and a friend.
/// [theyOweMe] is true when the friend owes the current user for this expense,
/// false when the current user owes the friend. [groupName] is the group this
/// debt came from, or null for a one-time expense. [isSettled] marks debts that
/// have been paid or auto-offset (history); [paymentStatus] distinguishes how.
class FriendExpense {
  final String expenseId;
  final String title;
  final double amount;
  final bool theyOweMe;
  final DateTime date;
  final String? groupName;
  final bool isSettled;
  final String paymentStatus;

  /// Portion of the original debt cancelled by auto-netting. For a still-pending
  /// debt the original was `amount + amountPaid`; for a netted debt `amount`
  /// already equals the original and this is what was offset.
  final double amountPaid;

  const FriendExpense({
    required this.expenseId,
    required this.title,
    required this.amount,
    required this.theyOweMe,
    required this.date,
    this.groupName,
    this.isSettled = false,
    this.paymentStatus = 'pending',
    this.amountPaid = 0,
  });

  /// Where this debt originates: the group name, or "One-time".
  String get source => groupName ?? 'One-time';

  /// True when this debt was cleared by auto-netting against an offsetting debt.
  bool get isNetted => paymentStatus == 'netted';

  /// True when part of this debt was cancelled against an offsetting debt.
  bool get wasOffset => amountPaid > 0.01;

  /// The original debt before any offsetting was applied.
  double get originalAmount =>
      paymentStatus == 'netted' ? amount : amount + amountPaid;

  Map<String, dynamic> toCache() => {
        'expense_id': expenseId,
        'title': title,
        'amount': amount,
        'they_owe_me': theyOweMe,
        'date': date.toIso8601String(),
        'group_name': groupName,
        'is_settled': isSettled,
        'payment_status': paymentStatus,
        'amount_paid': amountPaid,
      };

  factory FriendExpense.fromCache(Map<String, dynamic> j) => FriendExpense(
        expenseId: j['expense_id'] as String,
        title: j['title'] as String,
        amount: (j['amount'] as num).toDouble(),
        theyOweMe: j['they_owe_me'] as bool,
        date: DateTime.parse(j['date'] as String),
        groupName: j['group_name'] as String?,
        isSettled: j['is_settled'] as bool? ?? false,
        paymentStatus: j['payment_status'] as String? ?? 'pending',
        amountPaid: (j['amount_paid'] as num?)?.toDouble() ?? 0,
      );
}

class PendingRequest {
  final String id;
  final String fromUserId;
  final String fullName;
  final String username;
  final String? avatarUrl;

  const PendingRequest({
    required this.id,
    required this.fromUserId,
    required this.fullName,
    required this.username,
    this.avatarUrl,
  });

  Map<String, dynamic> toCache() => {
        'id': id,
        'from_user_id': fromUserId,
        'full_name': fullName,
        'username': username,
        'avatar_url': avatarUrl,
      };

  factory PendingRequest.fromCache(Map<String, dynamic> j) => PendingRequest(
        id: j['id'] as String,
        fromUserId: j['from_user_id'] as String,
        fullName: j['full_name'] as String,
        username: j['username'] as String,
        avatarUrl: j['avatar_url'] as String?,
      );
}
