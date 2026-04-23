import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tincars/features/trips/data/chat_repository.dart';
import 'package:tincars/features/trips/domain/models/message_model.dart';

class ChatController extends AsyncNotifier<void> {
  late ChatRepository _repository;

  @override
  Future<void> build() async {
    _repository = ref.read(chatRepositoryProvider);
  }

  Future<void> sendMessage(String tripId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final message = Message(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      tripId: tripId,
      senderId: user.uid,
      text: text.trim(),
      createdAt: DateTime.now(),
    );

    // Optimistic update
    ref.read(optimisticChatProvider.notifier).addMessage(tripId, message);

    final result = await AsyncValue.guard(
      () => _repository.sendMessage(message),
    );

    if (result.hasError) {
      // Remove optimistic message on error
      ref.read(optimisticChatProvider.notifier).removeMessage(tripId, message.id);
    }
  }

  Future<void> sendImage(
    String tripId,
    Uint8List bytes,
    String fileName,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      // 1. Upload image
      final imageUrl = await _repository.uploadMessageImage(
        tripId,
        bytes,
        fileName,
      );

      // 2. Send message with imageUrl
      final message = Message(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        tripId: tripId,
        senderId: user.uid,
        text: '📷 Foto', // Default text for images
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
      );

      await _repository.sendMessage(message);
    });

    if (result.hasError) {
      state = AsyncValue.error(result.error!, result.stackTrace!);
    } else {
      state = const AsyncValue.data(null);
    }
  }
}

class OptimisticChatNotifier extends Notifier<Map<String, List<Message>>> {
  @override
  Map<String, List<Message>> build() => {};

  void addMessage(String tripId, Message message) {
    final current = state[tripId] ?? [];
    state = {
      ...state,
      tripId: [...current, message],
    };
  }

  void removeMessage(String tripId, String messageId) {
    final current = state[tripId] ?? [];
    state = {
      ...state,
      tripId: current.where((m) => m.id != messageId).toList(),
    };
  }
}

final optimisticChatProvider =
    NotifierProvider<OptimisticChatNotifier, Map<String, List<Message>>>(
      OptimisticChatNotifier.new,
    );

final chatControllerProvider = AsyncNotifierProvider<ChatController, void>(
  () => ChatController(),
);

final tripMessagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  tripId,
) {
  return ref.read(chatRepositoryProvider).streamMessages(tripId);
});
