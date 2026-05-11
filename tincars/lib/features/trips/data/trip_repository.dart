import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:cloud_functions/cloud_functions.dart';

class TripRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  TripRepository();

  // Create a new trip request
  Future<void> createTrip(Trip trip) async {
    AppLogger.log(
      'TripRepository: Intentando insertar viaje ${trip.id} en Firestore...',
    );
    try {
      final data = trip.toJson();
      data['created_at'] = FieldValue.serverTimestamp();
      await _firestore.collection('trips').doc(trip.id).set(data);
      AppLogger.log('TripRepository: Viaje insertado correctamente');
    } catch (e) {
      AppLogger.log('TripRepository: ERROR en insert: $e');
      rethrow;
    }
  }

  // Stream listening for requested trips (for drivers)
  Stream<List<Trip>> streamRequestedTrips({
    LatLng? driverLocation,
    double radiusInKm = 500,
    List<VehicleType>? allowedServices,
  }) {
    // Firestore streams are reliable. We filter status=requested.
    Query query = _firestore
        .collection('trips')
        .where('status', isEqualTo: 'requested');

    return query.snapshots().map((snapshot) {
      var trips = snapshot.docs
          .map((doc) {
            try {
              return Trip.fromJson(doc.data() as Map<String, dynamic>);
            } catch (e) {
              AppLogger.log('TripRepository: ERROR parseando viaje: $e');
              return null;
            }
          })
          .whereType<Trip>()
          .toList();

      // Filter by allowed services
      if (allowedServices != null) {
        final allowedNames = allowedServices
            .map(_mapVehicleTypeToDbString)
            .toList();
        trips = trips
            .where((trip) => allowedNames.contains(trip.vehicleType))
            .toList();
      }

      // Geospatial filtering client-side
      if (driverLocation != null) {
        trips = trips.where((trip) {
          final distance =
              Geolocator.distanceBetween(
                driverLocation.latitude,
                driverLocation.longitude,
                trip.pickupLocation.latitude,
                trip.pickupLocation.longitude,
              ) /
              1000;
          return distance <= radiusInKm;
        }).toList();
      }

      // Filter out trips already rejected by this driver (if driverId is known)
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        trips = trips.where((t) => !t.rejectedBy.contains(currentUserId)).toList();
      }

      return trips;
    });
  }

  String _mapVehicleTypeToDbString(VehicleType type) {
    switch (type) {
      case VehicleType.essentials:
        return 'essentials';
      case VehicleType.essentialXL:
        return 'essentials_xl';
      case VehicleType.executive:
        return 'executive';
      case VehicleType.signature:
        return 'signature_lux';
    }
  }

  // Stream listening for specific trip updates (for passenger)
  Stream<Trip> streamTrip(String tripId) {
    return _firestore.collection('trips').doc(tripId).snapshots().map((doc) {
      if (!doc.exists) throw Exception('Viaje no encontrado');
      return Trip.fromJson(doc.data() as Map<String, dynamic>);
    });
  }

  // Stream listening for any active trip of a passenger
  Stream<Trip?> streamActiveTrip(String passengerId) {
    return _firestore
        .collection('trips')
        .where('passenger_id', isEqualTo: passengerId)
        .where(
          'status',
          whereIn: ['requested', 'accepted', 'arrived', 'in_progress'],
        )
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          // Sort by creation time if multiple (standard Firestore doesn't allow order by if whereIn is used on same field as status, but here it's fine)
          final trips = snapshot.docs
              .map((doc) => Trip.fromJson(doc.data() as Map<String, dynamic>))
              .toList();
          trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return trips.first;
        });
  }

  // Stream listening for any active trip of a driver
  Stream<Trip?> streamActiveTripForDriver(String driverId) {
    return _firestore
        .collection('trips')
        .where('driver_id', isEqualTo: driverId)
        .where('status', whereIn: ['accepted', 'arrived', 'in_progress'])
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final trips = snapshot.docs
              .map((doc) => Trip.fromJson(doc.data() as Map<String, dynamic>))
              .toList();
          trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return trips.first;
        });
  }

  // Stream listening for trip history of a passenger (completed or cancelled)
  Stream<List<Trip>> streamTripHistory(String passengerId) {
    return _firestore
        .collection('trips')
        .where('passenger_id', isEqualTo: passengerId)
        .where('status', whereIn: ['completed', 'cancelled'])
        .snapshots()
        .map((snapshot) {
          final trips = snapshot.docs
              .map((doc) {
                try {
                  return Trip.fromJson(doc.data() as Map<String, dynamic>);
                } catch (e) {
                  return null;
                }
              })
              .whereType<Trip>()
              .toList();
          trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return trips;
        });
  }

  // Stream listening for trip history of a driver
  Stream<List<Trip>> streamTripHistoryForDriver(String driverId) {
    return _firestore
        .collection('trips')
        .where('driver_id', isEqualTo: driverId)
        .where('status', whereIn: ['completed', 'cancelled'])
        .snapshots()
        .map((snapshot) {
          final trips = snapshot.docs
              .map((doc) {
                try {
                  return Trip.fromJson(doc.data() as Map<String, dynamic>);
                } catch (e) {
                  return null;
                }
              })
              .whereType<Trip>()
              .toList();
          trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return trips;
        });
  }

  // Driver accepts a trip using a Cloud Function for atomicity
  Future<void> acceptTrip(String tripId, String driverId) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('acceptTrip');
      final result = await callable.call({
        'tripId': tripId,
        'driverId': driverId,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == false) {
        if (data['error'] == 'TRIP_ALREADY_ACCEPTED') {
          throw Exception('TripAlreadyAccepted');
        }
        throw Exception(data['error'] ?? 'Error desconocido al aceptar viaje');
      }
    } catch (e) {
      AppLogger.log('TripRepository: Error calling acceptTrip function: $e');
      rethrow;
    }
  }

  // Driver rejects a trip
  Future<void> rejectTrip(String tripId, String driverId) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('rejectTrip');
      final result = await callable.call({
        'tripId': tripId,
        'driverId': driverId,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] == false) {
        throw Exception(data['error'] ?? 'Error desconocido al rechazar viaje');
      }
    } catch (e) {
      AppLogger.log('TripRepository: Error calling rejectTrip function: $e');
      rethrow;
    }
  }

  // Update trip status (arrived, in_progress, completed)
  Future<void> updateTripStatus(
    String tripId,
    dynamic status, {
    String? cancellationReason,
  }) async {
    String statusStr;
    if (status is TripStatus) {
      statusStr = (status == TripStatus.inProgress)
          ? 'in_progress'
          : status.name;
    } else {
      statusStr = status.toString();
    }

    final Map<String, dynamic> updateData = {
      'status': statusStr,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (cancellationReason != null) {
      updateData['cancellation_reason'] = cancellationReason;
    }

    await _firestore.collection('trips').doc(tripId).update(updateData);
  }

  // Update intermediate stop status
  Future<void> updateIntermediateStopStatus(
    String tripId,
    int stopIndex,
    bool isCompleted,
  ) async {
    final docRef = _firestore.collection('trips').doc(tripId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final List<dynamic> stops = List.from(data['intermediate_stops'] ?? []);
    if (stopIndex < stops.length) {
      stops[stopIndex]['is_completed'] = isCompleted;
      await docRef.update({'intermediate_stops': stops});
    }
  }

  // Cancel a trip
  Future<void> cancelTrip(String tripId) async {
    await updateTripStatus(tripId, 'cancelled');
  }

  // Update driver location for a trip
  Future<void> updateDriverLocation(
    String tripId,
    double lat,
    double lng, {
    double? heading,
  }) async {
    await _firestore.collection('trips').doc(tripId).update({
      'driver_lat': lat,
      'driver_lng': lng,
      if (heading != null) 'driver_heading': heading,
      'last_location_update': FieldValue.serverTimestamp(),
    });
  }

  // Update passenger location for a trip
  Future<void> updatePassengerLocation(
    String tripId,
    double lat,
    double lng,
  ) async {
    await _firestore.collection('trips').doc(tripId).update({
      'passenger_lat': lat,
      'passenger_lng': lng,
    });
  }

  // Update passenger emoji for a trip
  Future<void> updatePassengerEmoji(String tripId, String emoji) async {
    await _firestore.collection('trips').doc(tripId).update({
      'passenger_emoji': emoji,
    });
  }

  // Update trip price
  Future<void> updateTripPrice(String tripId, double newPrice, {double? waitFee}) async {
    await _firestore.collection('trips').doc(tripId).update({
      'price': newPrice,
      if (waitFee != null) 'wait_fee': waitFee,
    });
  }

  // Modify trip during active status
  Future<void> modifyTrip({
    required String tripId,
    required List<TripStop> newStops,
    required double newPrice,
    required double newDistance,
    required LatLng newDropoff,
    required String newDropoffAddress,
  }) async {
    await _firestore.collection('trips').doc(tripId).update({
      'intermediate_stops': newStops.map((s) => s.toJson()).toList(),
      'price': newPrice,
      'distance': newDistance,
      'dropoff_lat': newDropoff.latitude,
      'dropoff_lng': newDropoff.longitude,
      'dropoff_address': newDropoffAddress,
      'is_modified': true,
      'modified_at': FieldValue.serverTimestamp(),
    });
  }

  // Get trip history (not a stream)
  Future<List<Trip>> getTripHistory(String userId) async {
    final pQuery = await _firestore
        .collection('trips')
        .where('passenger_id', isEqualTo: userId)
        .get();
    final dQuery = await _firestore
        .collection('trips')
        .where('driver_id', isEqualTo: userId)
        .get();

    final trips = [
      ...pQuery.docs,
      ...dQuery.docs,
    ].map((doc) => Trip.fromJson(doc.data() as Map<String, dynamic>)).toList();
    trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return trips;
  }

  // Get a single trip by ID
  Future<Trip?> getTripById(String tripId) async {
    final doc = await _firestore.collection('trips').doc(tripId).get();
    if (!doc.exists) return null;
    return Trip.fromJson(doc.data() as Map<String, dynamic>);
  }

  // Update trip tip
  Future<void> updateTripTip(String tripId, double tipAmount) async {
    await _firestore.collection('trips').doc(tripId).update({
      'tip_amount': tipAmount,
    });
  }
}

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository();
});
