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

/// A single unsettled expense between the current user and a friend.
/// [theyOweMe] is true when the friend owes the current user for this expense,
/// false when the current user owes the friend.
class FriendExpense {
  final String expenseId;
  final String title;
  final double amount;
  final bool theyOweMe;
  final DateTime date;

  const FriendExpense({
    required this.expenseId,
    required this.title,
    required this.amount,
    required this.theyOweMe,
    required this.date,
  });
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
