class EmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String phoneNumber;
  final DateTime createdAt;

  EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    required this.createdAt,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      phoneNumber: json['phone_number'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone_number': phoneNumber,
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
    };
  }
}
