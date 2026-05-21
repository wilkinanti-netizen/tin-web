import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tincars/core/utils/app_logger.dart';

/// Service that queues Firestore operations when offline and replays them
/// when connectivity is restored. Prevents data loss in areas with poor signal.
class OfflineQueueService {
  OfflineQueueService._();
  static final OfflineQueueService instance = OfflineQueueService._();

  static const String _queueKey = 'offline_queue';
  StreamSubscription? _connectivitySubscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  /// Initialize connectivity monitoring
  Future<void> init() async {
    final result = await Connectivity().checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);
    AppLogger.log('[OFFLINE] Initial connectivity: $_isOnline');

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (results) {
        final wasOffline = !_isOnline;
        _isOnline = !results.contains(ConnectivityResult.none);
        AppLogger.log('[OFFLINE] Connectivity changed: $_isOnline');

        if (wasOffline && _isOnline) {
          AppLogger.log('[OFFLINE] Back online - replaying queued operations');
          _replayQueue();
        }
      },
    );
  }

  /// Dispose connectivity listener
  void dispose() {
    _connectivitySubscription?.cancel();
  }

  /// Queue a Firestore update operation for later execution
  Future<void> queueOperation({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    String type = 'update', // 'update' or 'set'
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_queueKey) ?? [];

      final operation = jsonEncode({
        'collection': collection,
        'doc_id': docId,
        'data': data,
        'type': type,
        'queued_at': DateTime.now().toIso8601String(),
      });

      queue.add(operation);
      await prefs.setStringList(_queueKey, queue);
      AppLogger.log('[OFFLINE] Queued operation: $collection/$docId ($type)');
    } catch (e) {
      AppLogger.error('[OFFLINE] Error queueing operation', error: e);
    }
  }

  /// Execute an operation with automatic offline queueing
  Future<bool> executeOrQueue({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    String type = 'update',
  }) async {
    if (_isOnline) {
      try {
        final firestore = FirebaseFirestore.instance;
        final ref = firestore.collection(collection).doc(docId);

        if (type == 'set') {
          await ref.set(data, SetOptions(merge: true));
        } else {
          await ref.update(data);
        }
        return true;
      } catch (e) {
        // If it fails even when "online", queue it
        AppLogger.log('[OFFLINE] Operation failed while online, queueing: $e');
        await queueOperation(
          collection: collection,
          docId: docId,
          data: data,
          type: type,
        );
        return false;
      }
    } else {
      await queueOperation(
        collection: collection,
        docId: docId,
        data: data,
        type: type,
      );
      return false;
    }
  }

  /// Replay all queued operations
  Future<void> _replayQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_queueKey) ?? [];

      if (queue.isEmpty) {
        AppLogger.log('[OFFLINE] No queued operations to replay');
        return;
      }

      AppLogger.log('[OFFLINE] Replaying ${queue.length} queued operations');
      final firestore = FirebaseFirestore.instance;
      final failedOps = <String>[];

      for (final opStr in queue) {
        try {
          final op = jsonDecode(opStr) as Map<String, dynamic>;
          final ref = firestore.collection(op['collection']).doc(op['doc_id']);
          final data = Map<String, dynamic>.from(op['data'] as Map);

          // Remove server timestamp placeholders and replace with actual values
          data.removeWhere((key, value) => value == '__SERVER_TIMESTAMP__');
          data['synced_at'] = FieldValue.serverTimestamp();

          if (op['type'] == 'set') {
            await ref.set(data, SetOptions(merge: true));
          } else {
            await ref.update(data);
          }

          AppLogger.log(
            '[OFFLINE] Replayed: ${op['collection']}/${op['doc_id']}',
          );
        } catch (e) {
          AppLogger.error('[OFFLINE] Failed to replay operation', error: e);
          failedOps.add(opStr);
        }
      }

      // Keep only failed operations in the queue
      await prefs.setStringList(_queueKey, failedOps);

      if (failedOps.isEmpty) {
        AppLogger.log('[OFFLINE] All queued operations replayed successfully');
      } else {
        AppLogger.log(
          '[OFFLINE] ${failedOps.length} operations still queued after replay',
        );
      }
    } catch (e) {
      AppLogger.error('[OFFLINE] Error replaying queue', error: e);
    }
  }

  /// Get the number of pending operations
  Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_queueKey) ?? []).length;
  }
}
