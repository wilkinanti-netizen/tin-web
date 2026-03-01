import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tincars/features/trips/domain/models/message_model.dart';

class ChatRepository {
  final SupabaseClient _supabase;

  ChatRepository(this._supabase);

  // Stream of messages for a specific trip
  Stream<List<Message>> streamMessages(String tripId) {
    AppLogger.log(
      'ChatRepository: Iniciando stream de mensajes para el viaje $tripId',
    );
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .order('created_at', ascending: true)
        .map((data) {
          return data.map((json) => Message.fromJson(json)).toList();
        });
  }

  // Send a message
  Future<void> sendMessage(Message message) async {
    AppLogger.log(
      'ChatRepository: Enviando mensaje para el viaje ${message.tripId}',
    );
    try {
      await _supabase.from('messages').insert(message.toJson());
      AppLogger.log('ChatRepository: Mensaje enviado exitosamente');
    } catch (e) {
      AppLogger.log('ChatRepository: ERROR al enviar mensaje: $e');
      rethrow;
    }
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(Supabase.instance.client);
});
