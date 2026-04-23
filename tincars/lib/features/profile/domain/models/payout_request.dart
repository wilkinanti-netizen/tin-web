enum PayoutStatus { pending, processing, completed, failed }

class PayoutRequest {
  final String id;
  final String userId;
  final String payoutMethodId;
  final double amount;
  final PayoutStatus status;
  final String? adminComment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PayoutRequest({
    required this.id,
    required this.userId,
    required this.payoutMethodId,
    required this.amount,
    this.status = PayoutStatus.pending,
    this.adminComment,
    required this.createdAt,
    this.updatedAt,
  });

  factory PayoutRequest.fromJson(Map<String, dynamic> json) {
    return PayoutRequest(
      id: json['id'],
      userId: json['user_id'],
      payoutMethodId: json['payout_method_id'],
      amount: (json['amount'] as num).toDouble(),
      status: PayoutStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PayoutStatus.pending,
      ),
      adminComment: json['admin_comment'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'payout_method_id': payoutMethodId,
      'amount': amount,
      'status': status.name,
      'admin_comment': adminComment,
    };
  }
}
