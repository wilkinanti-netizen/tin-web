import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tincars/features/trips/data/rating_repository.dart';

final ratingRepositoryProvider = Provider<RatingRepository>((ref) {
  return RatingRepository();
});

// Estado del controller
class RatingState {
  final bool isSubmitting;
  final bool isSubmitted;
  final String? error;

  const RatingState({
    this.isSubmitting = false,
    this.isSubmitted = false,
    this.error,
  });

  RatingState copyWith({bool? isSubmitting, bool? isSubmitted, String? error}) {
    return RatingState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      error: error,
    );
  }
}

class RatingController extends Notifier<RatingState> {
  late RatingRepository _repository;

  @override
  RatingState build() {
    _repository = ref.read(ratingRepositoryProvider);
    return const RatingState();
  }

  Future<bool> submitRating({
    required String tripId,
    required String ratedId,
    required int stars,
    required List<String> tags,
    String? comment,
    required bool raterIsDriver,
    double? tipAmount,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      state = state.copyWith(error: 'No hay sesión activa');
      return false;
    }

    // Verificar que no haya calificado ya este viaje
    final alreadyRated = await _repository.hasRatedTrip(
      tripId: tripId,
      raterId: currentUser.uid,
    );

    if (alreadyRated) {
      AppLogger.log('[RATING] Ya se calificó el viaje $tripId por ${currentUser.uid}');
      state = state.copyWith(isSubmitted: true);
      return true;
    }

    state = state.copyWith(isSubmitting: true);

    try {
      await _repository.submitRating(
        tripId: tripId,
        raterId: currentUser.uid,
        ratedId: ratedId,
        stars: stars,
        tags: tags,
        comment: comment,
        raterIsDriver: raterIsDriver,
        tipAmount: tipAmount,
      );

      state = state.copyWith(isSubmitting: false, isSubmitted: true);
      AppLogger.log('[RATING] ¡Calificación enviada exitosamente!');
      return true;
    } catch (e) {
      AppLogger.log('[RATING] ERROR al enviar calificación: $e');
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }
}

final ratingControllerProvider =
    NotifierProvider.autoDispose<RatingController, RatingState>(
      RatingController.new,
    );
