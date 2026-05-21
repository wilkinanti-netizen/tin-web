import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTransaction {
  final String id;
  final String userId;
  final String type; // 'topup', 'payment', 'payout', 'refund', 'cancellation_fee', etc.
  final double amount;
  final String description;
  final DateTime timestamp;
  final String? tripId;

  WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
    this.tripId,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final rawDate = json['timestamp'];
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.parse(rawDate);
    } else {
      parsedDate = DateTime.now();
    }

    return WalletTransaction(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      type: json['type'] ?? 'payment',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] ?? '',
      timestamp: parsedDate,
      tripId: json['trip_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'amount': amount,
      'description': description,
      'timestamp': timestamp,
      if (tripId != null) 'trip_id': tripId,
    };
  }
}
