import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';

class TripRepository {
  final SupabaseClient _supabase;

  TripRepository(this._supabase);

  // Create a new trip request
  Future<void> createTrip(Trip trip) async {
    print(
      'TripRepository: Intentando insertar viaje ${trip.id} en Supabase...',
    );
    try {
      await _supabase.from('trips').insert(trip.toJson());
      AppLogger.log('TripRepository: Viaje insertado correctamente');
    } catch (e) {
      AppLogger.log('TripRepository: ERROR en insert: $e');
      rethrow;
    }
  }

  // Stream listening for requested trips (for drivers)
  // Implemented geospatial filtering using a bounding box approach
  Stream<List<Trip>> streamRequestedTrips({
    LatLng? driverLocation,
    double radiusInKm = 500,
    List<VehicleType>? allowedServices,
  }) {
    final myId = _supabase.auth.currentUser?.id;
    print(
      'TripRepository: streamRequestedTrips iniciado para conductor: $myId',
    );

    // Diagnóstico extra en el repositorio
    _supabase.from('trips').select('id, status').limit(5).then((data) {
      print(
        'TripRepository: DIAGNÓSTICO SELECT (Cualquier status): Recibidos ${data.length} filas.',
      );
    });

    var query = _supabase.from('trips').stream(primaryKey: ['id']);

    return query.map((data) {
      print(
        'TripRepository: REALTIME - Recibidos ${data.length} viajes TOTALES desde Supabase (antes de filtrar status)',
      );

      // Filtrar por status 'requested' en el cliente para mayor fiabilidad
      final requestedData = data
          .where((doc) => doc['status'] == 'requested')
          .toList();

      print(
        'TripRepository: REALTIME - ${requestedData.length} de ${data.length} son "requested"',
      );

      if (requestedData.isNotEmpty) {
        print(
          'TripRepository: IDs de viajes requested: ${requestedData.map((e) => e['id']).toList()}',
        );
      }

      var trips = requestedData
          .map((json) {
            try {
              final t = Trip.fromJson(json);
              return t;
            } catch (e) {
              AppLogger.log('TripRepository: ERROR parseando viaje: $e . JSON: $json');
              return null; // Será filtrado
            }
          })
          .whereType<Trip>()
          .toList();

      // Filter by allowed services (Essentials, XL, etc.)
      if (allowedServices != null) {
        final allowedNames = allowedServices
            .map(_mapVehicleTypeToDbString)
            .toList();
        final countBefore = trips.length;
        trips = trips
            .where((trip) => allowedNames.contains(trip.vehicleType))
            .toList();
        print(
          'TripRepository: Filtro Servicio ($allowedNames): ${trips.length} de $countBefore viajes pasaron.',
        );
      }

      // Perform final precise filtering client-side for better accuracy
      if (driverLocation != null) {
        final countBefore = trips.length;
        trips = trips.where((trip) {
          final distance = _calculateDistance(
            driverLocation.latitude,
            driverLocation.longitude,
            trip.pickupLocation.latitude,
            trip.pickupLocation.longitude,
          );
          final isNear = distance <= radiusInKm;
          print(
            'TripRepository: Distancia a ${trip.id}: ${distance.toStringAsFixed(2)}km. ¿Está en radio de $radiusInKm km? $isNear',
          );
          return isNear;
        }).toList();
        print(
          'TripRepository: Filtro Distancia: ${trips.length} de $countBefore viajes pasaron.',
        );
      }

      print(
        'TripRepository: streamRequestedTrips retorna ${trips.length} viajes finales.',
      );
      return trips;
    });
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Basic Haversine formula
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
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
    AppLogger.log('TripRepository: Iniciando streamTrip para el viaje $tripId');
    return _supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', tripId)
        .where((data) => data.isNotEmpty)
        .map((data) {
          final trip = Trip.fromJson(data.first);
          print(
            'TripRepository: streamTrip actualizó para $tripId. Status: ${trip.status.name}',
          );
          return trip;
        });
  }

  // Stream listening for any active trip of a passenger
  Stream<Trip?> streamActiveTrip(String passengerId) {
    print(
      'TripRepository: Iniciando streamActiveTrip para pasajero $passengerId',
    );
    return _supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('passenger_id', passengerId)
        .map((data) {
          if (data.isEmpty) {
            print(
              'TripRepository: streamActiveTrip(P) vacío para $passengerId',
            );
            return null;
          }
          final trips = data.map((json) => Trip.fromJson(json)).toList();
          print(
            'TripRepository: streamActiveTrip(P) recibió ${trips.length} viajes para $passengerId',
          );
          try {
            final active = trips.firstWhere(
              (t) =>
                  t.status == TripStatus.requested ||
                  t.status == TripStatus.accepted ||
                  t.status == TripStatus.arrived ||
                  t.status == TripStatus.inProgress,
            );
            print(
              'TripRepository: streamActiveTrip(P) encontró viaje activo: ${active.id} (Status: ${active.status.name})',
            );
            return active;
          } catch (e) {
            print(
              'TripRepository: streamActiveTrip(P) no encontró viajes con status activo',
            );
            return null;
          }
        });
  }

  // Stream listening for any active trip of a driver
  Stream<Trip?> streamActiveTripForDriver(String driverId) {
    print(
      'TripRepository: Iniciando streamActiveTripForDriver para conductor $driverId',
    );
    return _supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .map((data) {
          if (data.isEmpty) {
            AppLogger.log('TripRepository: streamActiveTrip(D) vacío para $driverId');
            return null;
          }
          final trips = data.map((json) => Trip.fromJson(json)).toList();
          print(
            'TripRepository: streamActiveTrip(D) recibió ${trips.length} viajes para $driverId',
          );
          try {
            final active = trips.firstWhere(
              (t) =>
                  t.status == TripStatus.accepted ||
                  t.status == TripStatus.arrived ||
                  t.status == TripStatus.inProgress,
            );
            print(
              'TripRepository: streamActiveTrip(D) encontró viaje activo: ${active.id} (Status: ${active.status.name})',
            );
            return active;
          } catch (e) {
            print(
              'TripRepository: streamActiveTrip(D) no encontró viajes con status activo',
            );
            return null;
          }
        });
  }

  // Stream listening for trip history of a passenger (completed or cancelled)
  Stream<List<Trip>> streamTripHistory(String passengerId) {
    return _supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('passenger_id', passengerId)
        .order('created_at', ascending: false) // Newest first
        .map((data) {
          if (data.isEmpty) return [];
          final List<Trip> trips = [];
          for (var json in data) {
            try {
              trips.add(Trip.fromJson(json));
            } catch (e) {
              print(
                'TripRepository: Error parseando viaje historico: $e \n JSON: $json',
              );
            }
          }

          try {
            return trips
                .where(
                  (t) =>
                      t.status == TripStatus.completed ||
                      t.status == TripStatus.cancelled,
                )
                .toList();
          } catch (e) {
            return [];
          }
        });
  }

  // Stream listening for trip history of a driver (completed or cancelled)
  Stream<List<Trip>> streamTripHistoryForDriver(String driverId) {
    debugPrint('DEBUG: Iniciando streamTripHistoryForDriver para $driverId');
    return _supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .map((data) {
          debugPrint(
            'DEBUG: Cargando ${data.length} viajes crudos para conductor $driverId',
          );
          final List<Trip> trips = [];
          for (var json in data) {
            try {
              trips.add(Trip.fromJson(json));
            } catch (e) {
              debugPrint(
                'TripRepository: Error parseando viaje de conductor: $e',
              );
            }
          }

          final filtered = trips
              .where(
                (t) =>
                    t.status == TripStatus.completed ||
                    t.status == TripStatus.cancelled,
              )
              .toList();

          debugPrint(
            'DEBUG: Filtrados ${filtered.length} viajes (completados/cancelados) para historial',
          );
          return filtered;
        });
  }

  // Driver accepts a trip
  Future<void> acceptTrip(String tripId, String driverId) async {
    final response = await _supabase
        .from('trips')
        .update({'driver_id': driverId, 'status': 'accepted'})
        .eq('id', tripId)
        .eq('status', 'requested')
        .select();

    if (response.isEmpty) {
      throw Exception('TripAlreadyAccepted');
    }
  }

  // Update trip status (arrived, in_progress, completed)
  Future<void> updateTripStatus(
    String tripId,
    TripStatus status, {
    String? cancellationReason,
  }) async {
    final Map<String, dynamic> data = {'status': status.name};
    if (cancellationReason != null) {
      data['cancellation_reason'] = cancellationReason;
    }

    await _supabase.from('trips').update(data).eq('id', tripId);
  }

  // Cancel a trip (delete or update status)
  Future<void> cancelTrip(String tripId) async {
    // We can either delete the row or set status to cancelled.
    // Setting to cancelled is better for history.
    await updateTripStatus(tripId, TripStatus.cancelled);
  }

  // Update driver location for a trip
  Future<void> updateDriverLocation(
    String tripId,
    double lat,
    double lng,
  ) async {
    await _supabase
        .from('trips')
        .update({'driver_lat': lat, 'driver_lng': lng})
        .eq('id', tripId);
  }

  // Update trip price (increase offer)
  Future<void> updateTripPrice(String tripId, double newPrice) async {
    try {
      await _supabase
          .from('trips')
          .update({'price': newPrice})
          .eq('id', tripId);
      AppLogger.log('TripRepository: Update exitoso para $tripId a precio $newPrice');
    } catch (e) {
      AppLogger.log('TripRepository: Error en updateTripPrice para $tripId: $e');
      rethrow;
    }
  }

  // Get a single trip by ID
  Future<Trip?> getTripById(String tripId) async {
    try {
      final data = await _supabase
          .from('trips')
          .select()
          .eq('id', tripId)
          .single();
      return Trip.fromJson(data);
    } catch (e) {
      AppLogger.log('Error al obtener viaje por ID: $e');
      return null;
    }
  }
}

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(Supabase.instance.client);
});
