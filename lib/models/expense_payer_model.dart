class ExpensePayer {
  final String id;
  final String expenseId;
  final String userId;
  final String? userName;
  final double amountPaid;
  final DateTime createdAt;

  const ExpensePayer({
    required this.id,
    required this.expenseId,
    required this.userId,
    this.userName,
    required this.amountPaid,
    required this.createdAt,
  });

  factory ExpensePayer.fromJson(Map<String, dynamic> json, {String? userName}) {
    return ExpensePayer(
      id: json['id'] as String,
      expenseId: json['expense_id'] as String,
      userId: json['user_id'] as String,
      userName: userName,
      amountPaid: (json['amount_paid'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'expense_id': expenseId,
        'user_id': userId,
        'amount_paid': amountPaid,
        'created_at': createdAt.toIso8601String(),
      };
}
