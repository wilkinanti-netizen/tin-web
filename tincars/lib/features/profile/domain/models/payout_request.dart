import 'package:cloud_firestore/cloud_firestore.dart';

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
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.parse(date);
      return DateTime.now();
    }

    return PayoutRequest(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      payoutMethodId: json['payout_method_id'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: PayoutStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PayoutStatus.pending,
      ),
      adminComment: json['admin_comment'],
      createdAt: parseDate(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? parseDate(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'payout_method_id': payoutMethodId,
      'amount': amount,
      'status': status.name,
      'admin_comment': adminComment,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}
