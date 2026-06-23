import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tincars/core/utils/app_logger.dart';

/// Service that handles real-time GPS tracking via Firebase Realtime Database.
/// This is significantly cheaper than Firestore for high-frequency location updates.
/// Firestore charges per read/write, while RTDB charges per bandwidth.
class RealtimeLocationService {
  RealtimeLocationService._();
  static final RealtimeLocationService instance = RealtimeLocationService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Update driver location in RTDB (used when driver is idle/waiting for trips)
  Future<void> updateDriverLocation(
    String driverId,
    double lat,
    double lng, {
    double? heading,
    bool isOnline = true,
  }) async {
    try {
      final ref = _db.ref('driver_locations/$driverId');
      
      // Manejo de Conductores Fantasmas: si se pierde la conexión, bórralo de la lista
      if (isOnline) {
        await ref.onDisconnect().remove();
      } else {
        await ref.onDisconnect().cancel();
      }
      
      await ref.set({
        'lat': lat,
        'lng': lng,
        if (heading != null) 'heading': heading,
        'is_online': isOnline,
        'updated_at': ServerValue.timestamp,
      });
    } catch (e) {
      AppLogger.error('Error updating driver location in RTDB', error: e);
    }
  }

  /// Update driver location during an active trip
  Future<void> updateTripDriverLocation(
    String tripId,
    double lat,
    double lng, {
    double? heading,
  }) async {
    try {
      final ref = _db.ref('trip_locations/$tripId/driver');
      await ref.set({
        'lat': lat,
        'lng': lng,
        if (heading != null) 'heading': heading,
        'updated_at': ServerValue.timestamp,
      });
    } catch (e) {
      AppLogger.error('Error updating trip driver location in RTDB', error: e);
    }
  }

  /// Stream driver location during a trip (for passenger to see driver moving)
  Stream<LatLng?> streamTripDriverLocation(String tripId) {
    final ref = _db.ref('trip_locations/$tripId/driver');
    return ref.onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return null;
      return LatLng(
        (data['lat'] as num).toDouble(),
        (data['lng'] as num).toDouble(),
      );
    });
  }

  /// Stream all online driver locations (for demand heatmap calculation)
  Stream<Map<String, Map<String, dynamic>>> streamAllOnlineDrivers() {
    final ref = _db.ref('driver_locations');
    return ref.onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return {};

      final result = <String, Map<String, dynamic>>{};
      data.forEach((key, value) {
        if (value is Map && value['is_online'] == true) {
          result[key.toString()] = Map<String, dynamic>.from(value as Map);
        }
      });
      return result;
    });
  }

  /// Remove driver location when they go offline
  Future<void> removeDriverLocation(String driverId) async {
    try {
      await _db.ref('driver_locations/$driverId').remove();
    } catch (e) {
      AppLogger.error('Error removing driver location from RTDB', error: e);
    }
  }

  /// Clean up trip location data after trip completes
  Future<void> removeTripLocation(String tripId) async {
    try {
      await _db.ref('trip_locations/$tripId').remove();
    } catch (e) {
      AppLogger.error('Error removing trip location from RTDB', error: e);
    }
  }

  /// Record a trip request location for demand heatmap
  Future<void> recordTripDemand(double lat, double lng) async {
    try {
      final ref = _db.ref('demand_heatmap').push();
      await ref.set({
        'lat': lat,
        'lng': lng,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      AppLogger.error('Error recording trip demand', error: e);
    }
  }

  /// Stream demand heatmap data (trip requests in the last 30 minutes)
  Stream<List<LatLng>> streamDemandHeatmap() {
    final ref = _db.ref('demand_heatmap');
    return ref.onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <LatLng>[];

      final now = DateTime.now().millisecondsSinceEpoch;
      final thirtyMinAgo = now - (30 * 60 * 1000);
      final points = <LatLng>[];

      data.forEach((key, value) {
        if (value is Map) {
          final timestamp = value['timestamp'] as int?;
          if (timestamp != null && timestamp > thirtyMinAgo) {
            points.add(LatLng(
              (value['lat'] as num).toDouble(),
              (value['lng'] as num).toDouble(),
            ));
          }
        }
      });

      return points;
    });
  }
}
