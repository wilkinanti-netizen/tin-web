import 'package:cloud_firestore/cloud_firestore.dart';

class PayoutMethod {
  final String id;
  final String userId;
  final String bankName;
  final String accountNumber;
  final String accountHolderName;
  final bool isDefault;
  final DateTime createdAt;

  PayoutMethod({
    required this.id,
    required this.userId,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolderName,
    this.isDefault = false,
    required this.createdAt,
  });

  factory PayoutMethod.fromJson(Map<String, dynamic> json) {
    return PayoutMethod(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      bankName: json['bank_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      accountHolderName: json['account_holder_name'] ?? '',
      isDefault: json['is_default'] ?? false,
      createdAt: json['created_at'] != null
          ? (json['created_at'] is Timestamp
                ? (json['created_at'] as Timestamp).toDate()
                : DateTime.parse(json['created_at']))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_holder_name': accountHolderName,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
