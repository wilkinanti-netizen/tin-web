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
      id: json['id'],
      userId: json['user_id'],
      bankName: json['bank_name'],
      accountNumber: json['account_number'],
      accountHolderName: json['account_holder_name'],
      isDefault: json['is_default'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_holder_name': accountHolderName,
      'is_default': isDefault,
    };
  }
}
