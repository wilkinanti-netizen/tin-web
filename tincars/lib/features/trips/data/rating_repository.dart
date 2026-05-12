import 'package:tincars/core/utils/app_logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tincars/features/trips/domain/models/rating_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RatingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RatingRepository();

  /// Guarda la calificación y actualiza el promedio del usuario calificado
  Future<void> submitRating({
    required String tripId,
    required String raterId,
    required String ratedId,
    required int stars,
    required List<String> tags,
    String? comment,
    required bool raterIsDriver,
    double? tipAmount,
  }) async {
    final ratingRef = _firestore.collection('ratings').doc();
    
    // 1. Insertar la calificación
    await ratingRef.set({
      'id': ratingRef.id,
      'trip_id': tripId,
      'rater_id': raterId,
      'rated_id': ratedId,
      'stars': stars,
      'tags': tags,
      'comment': comment,
      'rater_is_driver': raterIsDriver,
      'tip_amount': tipAmount ?? 0.0,
      'created_at': FieldValue.serverTimestamp(),
    });

    // 2. Si hay propina y el calificador es el pasajero, actualizar el viaje
    if (!raterIsDriver && tipAmount != null && tipAmount > 0) {
      await _firestore.collection('trips').doc(tripId).update({
        'tip_amount': tipAmount,
      });
    }

    // 2. Recalcular el promedio del usuario calificado
    await _updateAverageRating(ratedId);

    AppLogger.log('[RATING] Promedio actualizado para $ratedId');
  }

  Future<void> _updateAverageRating(String userId) async {
    // Obtener todas las calificaciones del usuario
    final query = await _firestore
        .collection('ratings')
        .where('rated_id', isEqualTo: userId)
        .get();

    if (query.docs.isEmpty) return;

    final total = query.docs.fold<int>(0, (sum, doc) => sum + (doc.data()['stars'] as int));
    final average = total / query.docs.length;
    final roundedAverage = double.parse(average.toStringAsFixed(1));

    // Actualizar en la tabla profiles
    await _firestore
        .collection('profiles')
        .doc(userId)
        .update({
          'average_rating': roundedAverage,
          'total_ratings': query.docs.length,
        });
  }

  /// Obtener las calificaciones recibidas por un usuario
  Future<List<Rating>> getRatingsForUser(String userId) async {
    final query = await _firestore
        .collection('ratings')
        .where('rated_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .get();

    return query.docs.map((doc) => Rating.fromJson(doc.data())).toList();
  }

  /// Verificar si ya se calificó este viaje (para no duplicar)
  Future<bool> hasRatedTrip({
    required String tripId,
    required String raterId,
  }) async {
    final query = await _firestore
        .collection('ratings')
        .where('trip_id', isEqualTo: tripId)
        .where('rater_id', isEqualTo: raterId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }
}

final ratingRepositoryProvider = Provider<RatingRepository>((ref) {
  return RatingRepository();
});
