import 'dart:typed_data';
import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tincars/features/trips/domain/models/message_model.dart';
import 'package:uuid/uuid.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  ChatRepository();

  // Stream of messages for a specific trip
  Stream<List<Message>> streamMessages(String tripId) {
    AppLogger.log('ChatRepository: Iniciando stream de mensajes para el viaje $tripId');
    return _firestore
        .collection('messages')
        .where('trip_id', isEqualTo: tripId)
        // Eliminamos el orderBy temporalmente para evitar bloqueos por falta de índices
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs.map((doc) => Message.fromJson(doc.data())).toList();
          // Ordenamos manualmente en memoria para asegurar el orden sin requerir índice de Firestore
          messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return messages;
        });
  }

  // Send a message
  Future<void> sendMessage(Message message) async {
    AppLogger.log('ChatRepository: Enviando mensaje para el viaje ${message.tripId}');
    try {
      final data = message.toJson();
      data['created_at'] = FieldValue.serverTimestamp();
      await _firestore.collection('messages').doc(message.id).set(data);
      AppLogger.log('ChatRepository: Mensaje enviado exitosamente');
    } catch (e) {
      AppLogger.log('ChatRepository: ERROR al enviar mensaje: $e');
      rethrow;
    }
  }

  // Upload an image and return the download URL
  Future<String> uploadMessageImage(
    String tripId,
    Uint8List fileBytes,
    String fileName,
  ) async {
    AppLogger.log('ChatRepository: Subiendo imagen para el viaje $tripId');
    try {
      final fileExt = fileName.split('.').last;
      final uniqueFileName = '${const Uuid().v4()}.$fileExt';
      final path = 'chat_images/$tripId/$uniqueFileName';

      final ref = _storage.ref().child(path);
      await ref.putData(fileBytes, SettableMetadata(contentType: 'image/$fileExt'));

      final String url = await ref.getDownloadURL();
      AppLogger.log('ChatRepository: Imagen subida con éxito: $url');
      return url;
    } catch (e) {
      AppLogger.log('ChatRepository: ERROR al subir imagen: $e');
      rethrow;
    }
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});
