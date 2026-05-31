class Profile {
  final String id;
  final String fullName;
  final String username;
  final String email;

  const Profile({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        username: json['username'] as String,
        email: json['email'] as String? ?? '',
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

  const Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.fullName,
    required this.username,
    required this.email,
    required this.balance,
    required this.status,
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

  const FriendExpense({
    required this.expenseId,
    required this.title,
    required this.amount,
    required this.theyOweMe,
    required this.date,
    this.groupName,
    this.isSettled = false,
    this.paymentStatus = 'pending',
  });

  /// Where this debt originates: the group name, or "One-time".
  String get source => groupName ?? 'One-time';

  /// True when this debt was cleared by auto-netting against an offsetting debt.
  bool get isNetted => paymentStatus == 'netted';
}

class PendingRequest {
  final String id;
  final String fromUserId;
  final String fullName;
  final String username;

  const PendingRequest({
    required this.id,
    required this.fromUserId,
    required this.fullName,
    required this.username,
  });
}
