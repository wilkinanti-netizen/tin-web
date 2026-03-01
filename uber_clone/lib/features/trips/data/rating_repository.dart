import 'package:tincars/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tincars/features/trips/domain/models/rating_model.dart';

class RatingRepository {
  final _client = Supabase.instance.client;

  /// Guarda la calificación y actualiza el promedio del usuario calificado
  Future<void> submitRating({
    required String tripId,
    required String raterId,
    required String ratedId,
    required int stars,
    required List<String> tags,
    String? comment,
    required bool raterIsDriver,
  }) async {
    print(
      '[RATING] Guardando calificación: $stars estrellas para $ratedId en viaje $tripId',
    );

    // 1. Insertar la calificación
    await _client.from('ratings').insert({
      'trip_id': tripId,
      'rater_id': raterId,
      'rated_id': ratedId,
      'stars': stars,
      'tags': tags,
      'comment': comment,
      'rater_is_driver': raterIsDriver,
      'created_at': DateTime.now().toIso8601String(),
    });

    print(
      '[RATING] Calificación guardada. Actualizando promedio de $ratedId...',
    );

    // 2. Recalcular el promedio del usuario calificado
    await _updateAverageRating(ratedId);

    AppLogger.log('[RATING] Promedio actualizado para $ratedId');
  }

  Future<void> _updateAverageRating(String userId) async {
    // Obtener todas las calificaciones del usuario
    final response = await _client
        .from('ratings')
        .select('stars')
        .eq('rated_id', userId);

    if (response.isEmpty) return;

    final ratings = List<Map<String, dynamic>>.from(response);
    final total = ratings.fold<int>(0, (sum, r) => sum + (r['stars'] as int));
    final average = total / ratings.length;
    final roundedAverage = double.parse(average.toStringAsFixed(1));

    print(
      '[RATING] Nuevo promedio para $userId: $roundedAverage (${ratings.length} calificaciones)',
    );

    // Actualizar en la tabla profiles
    await _client
        .from('profiles')
        .update({
          'average_rating': roundedAverage,
          'total_ratings': ratings.length,
        })
        .eq('id', userId);
  }

  /// Obtener las calificaciones recibidas por un usuario
  Future<List<Rating>> getRatingsForUser(String userId) async {
    final response = await _client
        .from('ratings')
        .select()
        .eq('rated_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(
      response,
    ).map((r) => Rating.fromJson(r)).toList();
  }

  /// Verificar si ya se calificó este viaje (para no duplicar)
  Future<bool> hasRatedTrip({
    required String tripId,
    required String raterId,
  }) async {
    final response = await _client
        .from('ratings')
        .select('id')
        .eq('trip_id', tripId)
        .eq('rater_id', raterId);

    return response.isNotEmpty;
  }
}
