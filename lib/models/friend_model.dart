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
}
