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
