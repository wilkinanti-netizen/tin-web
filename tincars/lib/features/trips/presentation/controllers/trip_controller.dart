import 'package:tincars/core/utils/app_logger.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/core/services/notification_service.dart';
import 'package:tincars/features/trips/data/trip_repository.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';

class TripController extends AsyncNotifier<void> {
  late TripRepository _repository;

  static String statusToDbString(TripStatus status) {
    switch (status) {
      case TripStatus.requested: return 'requested';
      case TripStatus.accepted: return 'accepted';
      case TripStatus.arrived: return 'arrived';
      case TripStatus.inProgress: return 'in_progress';
      case TripStatus.completed: return 'completed';
      case TripStatus.cancelled: return 'cancelled';
    }
  }

  @override
  FutureOr<void> build() {
    _repository = ref.read(tripRepositoryProvider);
    return null;
  }

  Future<void> createTrip(Trip trip) async {
    AppLogger.log('TripController: Iniciando createTrip para el viaje ${trip.id}...');
    state = const AsyncValue.loading();
    try {
      await _repository.createTrip(trip);
      AppLogger.log('TripController: Viaje creado exitosamente');
      state = const AsyncValue.data(null);
    } catch (e, s) {
      AppLogger.log('TripController: ERROR en createTrip: $e');
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> acceptTrip(String tripId, String driverId) async {
    AppLogger.log('TripController: Aceptando viaje $tripId por conductor $driverId');
    state = const AsyncValue.loading();
    try {
      await _repository.acceptTrip(tripId, driverId);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      AppLogger.log('TripController: ERROR al aceptar viaje: $e');
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }

  Future<void> updateStatus(String tripId, TripStatus status, {String? cancellationReason}) async {
    final currentTrip = await _repository.getTripById(tripId);
    if (currentTrip != null && currentTrip.status == status) return;

    try {
      await _repository.updateTripStatus(tripId, statusToDbString(status), cancellationReason: cancellationReason);
      
      if (status == TripStatus.completed) {
        final trip = await _repository.getTripById(tripId);
        if (trip != null && trip.driverId != null) {
          final profileRepo = ref.read(profileRepositoryProvider);
          await profileRepo.addToEarnings(trip.driverId!, trip.price);
          if (trip.paymentMethod == 'Wallet') {
            await profileRepo.updateWalletBalance(trip.passengerId, trip.price, isIncrement: false);
          }
          ref.invalidate(driverProfileProvider);
          ref.invalidate(todayDriverStatsProvider);
          ref.invalidate(userProfileProvider);
          await _handleReferralBonus(trip.passengerId, trip.driverId);
        }
      }
    } catch (e, s) {
      AppLogger.log('TripController: Error al actualizar estado: $e');
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> completeStop(String tripId, int stopIndex) async {
    try {
      await _repository.updateIntermediateStopStatus(tripId, stopIndex, true);
    } catch (e, s) {
      AppLogger.log('TripController: Error al completar parada: $e');
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> updatePrice(String tripId, double newPrice) async {
    try {
      await _repository.updateTripPrice(tripId, newPrice);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> updateLocation(String tripId, double lat, double lng, {double? heading}) async {
    await _repository.updateDriverLocation(tripId, lat, lng, heading: heading);
  }

  Future<void> modifyTrip({
    required String tripId,
    required List<TripStop> newStops,
    required double newPrice,
    required double newDistance,
    required LatLng newDropoff,
    required String newDropoffAddress,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.modifyTrip(
        tripId: tripId,
        newStops: newStops,
        newPrice: newPrice,
        newDistance: newDistance,
        newDropoff: newDropoff,
        newDropoffAddress: newDropoffAddress,
      );
      state = const AsyncValue.data(null);
    } catch (e, s) {
      AppLogger.log('TripController: Error al modificar viaje: $e');
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> updatePassengerLocation(String tripId, double lat, double lng) async {
    await _repository.updatePassengerLocation(tripId, lat, lng);
  }

  Future<void> updatePassengerEmoji(String tripId, String emoji) async {
    await _repository.updatePassengerEmoji(tripId, emoji);
  }

  Future<void> updateTip(String tripId, double tipAmount) async {
    try {
      final trip = await _repository.getTripById(tripId);
      if (trip == null) return;
      await _repository.updateTripTip(tripId, tipAmount);
      if (trip.paymentMethod == 'Wallet' && tipAmount > 0) {
        final profileRepo = ref.read(profileRepositoryProvider);
        await profileRepo.updateWalletBalance(trip.passengerId, tipAmount, isIncrement: false);
        if (trip.driverId != null) {
          await profileRepo.addToEarnings(trip.driverId!, tipAmount);
        }
      }
      ref.invalidate(userProfileProvider);
      ref.invalidate(driverProfileProvider);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> _handleReferralBonus(String passengerId, String? driverId) async {
    try {
      final repo = ref.read(profileRepositoryProvider);
      final profile = await repo.getUserProfile(passengerId);
      if (profile == null || profile.referredById == null) return;

      await repo.ensureReferralCode(passengerId);
      final history = await _repository.getTripHistory(passengerId);
      final count = history.where((t) => t.status == TripStatus.completed).length;

      if (count == 100) {
        await repo.updateWalletBalance(profile.referredById!, 100.0, isIncrement: true);
        if (driverId != null) await repo.addToEarnings(driverId, 200.0);
        ref.invalidate(userProfileProvider);
        ref.invalidate(driverProfileProvider);
      } else if (count == 1) {
        await repo.updateWalletBalance(passengerId, 5.0, isIncrement: true);
        await repo.updateWalletBalance(profile.referredById!, 5.0, isIncrement: true);
        ref.invalidate(userProfileProvider);
      }
    } catch (e) {
      AppLogger.log('[REFERRAL] Error: $e');
    }
  }
}

final tripControllerProvider = AsyncNotifierProvider<TripController, void>(TripController.new);

final requestedTripsProvider = StreamProvider<List<Trip>>((ref) {
  final activeTripAsync = ref.watch(activeTripProvider);
  if (activeTripAsync.value != null) return Stream.value([]);

  final profileAsync = ref.watch(driverProfileProvider);
  return profileAsync.when(
    data: (profile) {
      if (profile == null || profile.activeServices.isEmpty) return Stream.value([]);
      final ignored = ref.watch(ignoredTripsProvider);

      return ref.read(tripRepositoryProvider).streamRequestedTrips(allowedServices: profile.activeServices).map((trips) {
        if (trips.isEmpty) return <Trip>[];
        return trips.where((t) => !(ignored[t.id] != null && t.price <= ignored[t.id]!)).toList();
      });
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

final allRequestedTripsProvider = StreamProvider<List<Trip>>((ref) {
  final profileAsync = ref.watch(driverProfileProvider);
  return profileAsync.when(
    data: (profile) {
      if (profile == null) return Stream.value([]);
      return ref.read(tripRepositoryProvider).streamRequestedTrips(allowedServices: profile.activeServices);
    },
    loading: () => Stream.value([]),
    error: (e, s) => Stream.value([]),
  );
});

final tripStreamProvider = StreamProvider.family<Trip, String>((ref, tripId) {
  return ref.read(tripRepositoryProvider).streamTrip(tripId);
});

final activeTripProvider = StreamProvider<Trip?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);

  final repository = ref.read(tripRepositoryProvider);
  final controller = StreamController<Trip?>();
  Trip? lastPTrip;
  Trip? lastDTrip;

  void emit() { if (!controller.isClosed) controller.add(lastDTrip ?? lastPTrip); }

  final pStream = repository.streamActiveTrip(user.uid).listen((t) { lastPTrip = t; emit(); });
  final dStream = repository.streamActiveTripForDriver(user.uid).listen((t) { lastDTrip = t; emit(); });

  ref.onDispose(() { pStream.cancel(); dStream.cancel(); controller.close(); });
  return controller.stream;
});

final tripHistoryProvider = StreamProvider.autoDispose<List<Trip>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);
  return ref.read(tripRepositoryProvider).streamTripHistory(user.uid);
});

final driverTripHistoryProvider = StreamProvider.autoDispose<List<Trip>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);
  return ref.read(tripRepositoryProvider).streamTripHistoryForDriver(user.uid);
});

final todayDriverStatsProvider = StreamProvider<Map<String, double>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value({'earnings': 0.0, 'count': 0.0});

  return ref.watch(tripRepositoryProvider).streamTripHistoryForDriver(user.uid).map((trips) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayTrips = trips.where((t) => t.status == TripStatus.completed && t.createdAt.isAfter(today)).toList();
    double earnings = todayTrips.fold(0.0, (sum, t) => sum + t.price);
    return {'earnings': earnings, 'count': todayTrips.length.toDouble()};
  });
});

final ignoredTripsProvider = NotifierProvider<IgnoredTripsNotifier, Map<String, double>>(IgnoredTripsNotifier.new);

class IgnoredTripsNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => {};
  void ignore(String tripId, double currentPrice) => state = {...state, tripId: currentPrice};
  void unignore(String tripId) {
    final newState = Map<String, double>.from(state);
    newState.remove(tripId);
    state = newState;
  }
}

final tripNotificationProvider = Provider<void>((ref) {
  TripStatus? lastStatus;
  String? lastTripId;

  ref.listen<AsyncValue<Trip?>>(activeTripProvider, (previous, next) {
    final trip = next.value;
    if (trip == null) {
      lastStatus = null;
      lastTripId = null;
      return;
    }
    if (trip.id != lastTripId || trip.status != lastStatus) {
      final isPassenger = FirebaseAuth.instance.currentUser?.uid == trip.passengerId;
      if (isPassenger && trip.status != lastStatus) _handlePassengerNotification(trip);
      lastStatus = trip.status;
      lastTripId = trip.id;
    }
  });
});

void _handlePassengerNotification(Trip trip) {
  String? title;
  String? body;
  switch (trip.status) {
    case TripStatus.accepted: title = '¡Viaje Aceptado!'; body = 'Un conductor va en camino a recogerte.'; break;
    case TripStatus.arrived: title = '¡El conductor llegó!'; body = 'Tu conductor está afuera esperándote.'; break;
    case TripStatus.completed: title = 'Viaje Finalizado'; body = 'Esperamos que hayas tenido un excelente viaje.'; break;
    default: return;
  }
  NotificationService.instance.showTripStatusNotification(title: title, body: body, payload: trip.id);
}
