import 'package:tincars/core/utils/app_logger.dart';
class Message {
  final String id;
  final String tripId;
  final String senderId;
  final String text;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {'trip_id': tripId, 'sender_id': senderId, 'text': text};
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    try {
      return Message(
        id: json['id'] ?? '',
        tripId: json['trip_id'] ?? '',
        senderId: json['sender_id'] ?? '',
        text: json['text'] ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
      );
    } catch (e) {
      AppLogger.log('Error parsing message: $e . JSON: $json');
      return Message(
        id: '',
        tripId: '',
        senderId: '',
        text: 'Error al cargar mensaje',
        createdAt: DateTime.now(),
      );
    }
  }
}
