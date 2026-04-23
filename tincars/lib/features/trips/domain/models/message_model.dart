import 'package:tincars/core/utils/app_logger.dart';

class Message {
  final String id;
  final String tripId;
  final String senderId;
  final String text;
  final String? imageUrl;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.text,
    this.imageUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'sender_id': senderId,
      'text': text,
      'image_url': imageUrl,
      // 'created_at' added by repository as serverTimestamp
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    try {
      DateTime parsedDate;
      final rawDate = json['created_at'];
      if (rawDate is DateTime) {
        parsedDate = rawDate;
      } else if (rawDate is String) {
        parsedDate = DateTime.parse(rawDate);
      } else {
        // Assume it's a Firestore Timestamp or similar
        parsedDate = (rawDate as dynamic)?.toDate() ?? DateTime.now();
      }

      return Message(
        id: json['id'] ?? '',
        tripId: json['trip_id'] ?? '',
        senderId: json['sender_id'] ?? '',
        text: json['text'] ?? '',
        imageUrl: json['imageUrl'] ?? json['image_url'],
        createdAt: parsedDate,
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
