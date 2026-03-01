import 'package:tincars/core/utils/app_logger.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/features/trips/data/trip_repository.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';

class TripController extends AsyncNotifier<void> {
  late TripRepository _repository;

  static String statusToDbString(TripStatus status) {
    switch (status) {
      case TripStatus.requested:
        return 'requested';
      case TripStatus.accepted:
        return 'accepted';
      case TripStatus.arrived:
        return 'arrived';
      case TripStatus.inProgress:
        return 'in_progress';
      case TripStatus.completed:
        return 'completed';
      case TripStatus.cancelled:
        return 'cancelled';
    }
  }

  @override
  FutureOr<void> build() {
    _repository = ref.read(tripRepositoryProvider);
    return null;
  }

  Future<void> createTrip(Trip trip) async {
    AppLogger.log(
      'TripController: Iniciando createTrip para el viaje ${trip.id}...',
    );
    state = const AsyncValue.loading();
    try {
      await _repository.createTrip(trip);
      AppLogger.log(
        'TripController: Viaje creado exitosamente en el repositorio',
      );
      state = const AsyncValue.data(null);
    } catch (e, s) {
      AppLogger.log('TripController: ERROR fatal en createTrip: $e');
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> acceptTrip(String tripId, String driverId) async {
    AppLogger.log(
      'TripController: Aceptando viaje $tripId por el conductor $driverId',
    );
    state = const AsyncValue.loading();
    try {
      await _repository.acceptTrip(tripId, driverId);
      AppLogger.log('TripController: Viaje aceptado exitosamente');
      state = const AsyncValue.data(null);
    } catch (e, s) {
      AppLogger.log('TripController: ERROR al aceptar viaje: $e');
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }

  Future<void> _updateTripStatusInRepo(
    String tripId,
    TripStatus status,
    String? cancellationReason,
  ) async {
    try {
      final statusStr = statusToDbString(status);
      await _repository.updateTripStatus(
        tripId,
        statusStr, // Esto ahora es un String
        cancellationReason: cancellationReason,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateStatus(
    String tripId,
    TripStatus status, {
    String? cancellationReason,
  }) async {
    // 1. Obtener el estado actual antes de intentar actualizar
    final currentTrip = await _repository.getTripById(tripId);
    if (currentTrip != null && currentTrip.status == status) {
      AppLogger.log(
        'TripController: El viaje $tripId ya tiene el estado $status. Omitiendo actualización redundante.',
      );
      return;
    }

    print(
      'TripController: Solicitando cambio de estado a $status para el viaje $tripId (Razon: $cancellationReason)',
    );
    // No ponemos estado de carga global para evitar bloqueos en la UI,
    // confiamos en los streams de tiempo real para actualizar la vista.
    try {
      await _updateTripStatusInRepo(tripId, status, cancellationReason);
      AppLogger.log(
        'TripController: Estado actualizado con éxito en el repositorio',
      );

      if (status == TripStatus.completed) {
        final trip = await _repository.getTripById(tripId);
        if (trip != null && trip.driverId != null) {
          await ref
              .read(profileRepositoryProvider)
              .addToEarnings(trip.driverId!, trip.price);
          ref.invalidate(driverProfileProvider);
          ref.invalidate(todayDriverStatsProvider);
        }
      }
    } catch (e, s) {
      AppLogger.log('TripController: Error al actualizar estado: $e');
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> updatePrice(String tripId, double newPrice) async {
    print(
      'TripController: Actualizando precio a $newPrice para el viaje $tripId',
    );
    // No ponemos estado de carga global para evitar parpadeos molestos en la UI de búsqueda
    // state = const AsyncValue.loading();
    try {
      await _repository.updateTripPrice(tripId, newPrice);
      AppLogger.log(
        'TripController: Precio actualizado con éxito en el repositorio',
      );
    } catch (e, s) {
      AppLogger.log('TripController: Error al actualizar precio: $e');
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> updateLocation(String tripId, double lat, double lng) async {
    // We don't necessarily need to set global loading state for location updates to avoid UI flickering
    await _repository.updateDriverLocation(tripId, lat, lng);
  }
}

final tripControllerProvider = AsyncNotifierProvider<TripController, void>(
  TripController.new,
);

final requestedTripsProvider = StreamProvider<List<Trip>>((ref) {
  AppLogger.log('Provider: requestedTripsProvider escuchando cambios...');

  // Si hay un viaje activo, NO buscamos nuevos viajes
  final activeTripAsync = ref.watch(activeTripProvider);
  if (activeTripAsync.value != null) {
    AppLogger.log(
      'Provider: Conductor en flujo de viaje activo, bloqueando nuevas ofertas.',
    );
    return Stream.value([]);
  }

  // Watch driver profile to get active services
  final profileAsync = ref.watch(driverProfileProvider);

  return profileAsync.when(
    data: (profile) {
      if (profile == null) {
        AppLogger.log(
          'Provider: Conductor sin perfil activo, no se buscan viajes.',
        );
        return Stream.value([]);
      }
      if (profile.activeServices.isEmpty) {
        print(
          'Provider: Conductor sin servicios activos (ej: Moto/Carro), no se buscan viajes.',
        );
        return Stream.value([]);
      }

      final activeServices = profile.activeServices;
      final ignored = ref.watch(ignoredTripsProvider);

      AppLogger.log(
        'Provider: Buscando viajes para servicios: $activeServices',
      );

      // PRUEBA DE DIAGNÓSTICO: Intento de lectura única para descartar RLS
      Supabase.instance.client.from('trips').select().eq('status', 'requested').then((
        data,
      ) {
        AppLogger.log('===================================================');
        AppLogger.log('🧪 PRUEBA DE DIAGNÓSTICO (One-time Fetch) 🧪');
        print(
          '👉 Se encontraron ${data.length} viajes "requested" vía SELECT normal.',
        );
        if (data.isNotEmpty) {
          AppLogger.log(
            '👉 IDs encontrados: ${data.map((e) => e['id']).toList()}',
          );
        } else {
          print(
            '🚨 RLS/PERMISOS: El select normal también devolvió 0. Es un problema de POLITICAS en Supabase.',
          );
        }
        AppLogger.log('===================================================');
      });

      return ref
          .read(tripRepositoryProvider)
          .streamRequestedTrips(allowedServices: activeServices)
          .asyncMap((trips) async {
            if (trips.isEmpty) {
              AppLogger.log('Provider: No hay viajes "requested" en la BD.');
              return [];
            }
            try {
              Position? position;
              try {
                position = await Geolocator.getLastKnownPosition();
                position ??= await Geolocator.getCurrentPosition(
                  timeLimit: const Duration(seconds: 3),
                );
              } catch (e) {
                AppLogger.log(
                  'Provider: Error obteniendo ubicación del conductor: $e',
                );
                // Si no hay ubicación, no filtramos por distancia, simplemente permitimos que vea los viajes para que no se quede ciego.
                // En producción podrías querer ocultarlos, pero para asegurar, usaremos una dummy latlng o saltamos.
              }

              if (position == null) {
                print(
                  'Provider: ⚠️ No se pudo obtener la ubicación. MOSTRANDO TODOS LOS VIAJES SIN FILTRO DE DISTANCIA.',
                );
                return trips.where((t) {
                  final ignoredPrice = ignored[t.id];
                  if (ignoredPrice != null && t.price <= ignoredPrice)
                    return false;
                  return true;
                }).toList();
              }

              final driverLoc = LatLng(position.latitude, position.longitude);

              final result = trips.where((trip) {
                final ignoredPrice = ignored[trip.id];
                if (ignoredPrice != null && trip.price <= ignoredPrice) {
                  AppLogger.log(
                    '⏭️ Omitiendo ${trip.id} (Ignorado con precio \$${ignoredPrice})',
                  );
                  return false;
                }

                final distance =
                    Geolocator.distanceBetween(
                      driverLoc.latitude,
                      driverLoc.longitude,
                      trip.pickupLocation.latitude,
                      trip.pickupLocation.longitude,
                    ) /
                    1000;

                // Importante: Usar la misma lógica de mapeo que el Repo para evitar desajustes como "essentialXL" vs "essentials_xl"
                String mapType(String t) {
                  if (t == 'essentialXL') return 'essentials_xl';
                  if (t == 'signature') return 'signature_lux';
                  return t.toLowerCase();
                }

                final isNear = distance <= 500.0;
                final driverServices = activeServices
                    .map((s) => mapType(s.name))
                    .toList();
                final tripType = trip.vehicleType.toLowerCase();
                final serviceMatches = driverServices.contains(tripType);

                return isNear && serviceMatches;
              }).toList();
              AppLogger.log('🎯 Viajes finales en pantalla: ${result.length}');
              return result;
            } catch (e) {
              print(
                'Provider: Error en filtro: $e. Retornando viajes con filtro simple de ignorados.',
              );
              return trips.where((t) => !ignored.containsKey(t.id)).toList();
            }
          });
    },
    loading: () {
      AppLogger.log('Provider: Cargando perfil del conductor...');
      return Stream.value([]);
    },
    error: (e, s) {
      AppLogger.log('Provider: ERROR cargando perfil del conductor: $e');
      return Stream.value([]);
    },
  );
});

final tripStreamProvider = StreamProvider.family<Trip, String>((ref, tripId) {
  return ref.read(tripRepositoryProvider).streamTrip(tripId);
});

final activeTripProvider = StreamProvider<Trip?>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return Stream.value(null);

  final repository = ref.read(tripRepositoryProvider);

  // Manual merge of streams to avoid extra dependencies
  final controller = StreamController<Trip?>();

  final pStream = repository
      .streamActiveTrip(user.id)
      .listen((t) => controller.add(t));
  final dStream = repository
      .streamActiveTripForDriver(user.id)
      .listen((t) => controller.add(t));

  ref.onDispose(() {
    pStream.cancel();
    dStream.cancel();
    controller.close();
  });

  return controller.stream;
});

final tripHistoryProvider = StreamProvider.autoDispose<List<Trip>>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return Stream.value([]);
  return ref.read(tripRepositoryProvider).streamTripHistory(user.id);
});

final driverTripHistoryProvider = StreamProvider.autoDispose<List<Trip>>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return Stream.value([]);
  return ref.read(tripRepositoryProvider).streamTripHistoryForDriver(user.id);
});

final todayDriverStatsProvider = StreamProvider<Map<String, double>>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    return Stream.value({'earnings': 0.0, 'count': 0.0});
  }

  return ref
      .watch(tripRepositoryProvider)
      .streamTripHistoryForDriver(user.id)
      .map((trips) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final todayTrips = trips
            .where(
              (t) =>
                  t.status == TripStatus.completed &&
                  t.createdAt.isAfter(today),
            )
            .toList();

        double earnings = 0;
        for (var t in todayTrips) {
          earnings += t.price;
        }

        return {'earnings': earnings, 'count': todayTrips.length.toDouble()};
      });
});

final ignoredTripsProvider =
    NotifierProvider<IgnoredTripsNotifier, Map<String, double>>(
      IgnoredTripsNotifier.new,
    );

class IgnoredTripsNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => {};

  void ignore(String tripId, double currentPrice) {
    state = {...state, tripId: currentPrice};
  }

  void unignore(String tripId) {
    final newState = Map<String, double>.from(state);
    newState.remove(tripId);
    state = newState;
  }
}
