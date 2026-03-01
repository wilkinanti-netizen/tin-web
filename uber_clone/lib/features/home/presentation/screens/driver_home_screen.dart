import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/features/trips/presentation/widgets/trip_request_card.dart';
import 'package:tincars/features/profile/presentation/screens/earnings_screen.dart';
import 'package:tincars/features/profile/presentation/screens/driver_service_settings_screen.dart';
import 'package:tincars/features/trips/presentation/screens/driver_trip_management_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/core/utils/permission_service.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';
import 'package:tincars/features/profile/presentation/screens/driver_registration_screen.dart';
import 'package:tincars/features/profile/presentation/screens/driver_waiting_screen.dart';
import 'package:tincars/core/utils/marker_utils.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  bool _isOnline = true;
  static const LatLng _center = LatLng(4.6097, -74.0817); // Bogotá, Colombia
  final AudioPlayer _audioPlayer = AudioPlayer();
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  GoogleMapController? _mapController;
  bool _isFirstLocationUpdate = true;
  Set<Marker> _markers = {};
  bool _isNavigatingToTrip = false; // Guard contra duplicados

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Solo pedir permiso si no está ya concedido
    final status = await Geolocator.checkPermission();
    if (status == LocationPermission.always ||
        status == LocationPermission.whileInUse) {
      // Ya tiene permiso — solo iniciar tracking
      _startPositionTracking();
      return;
    }
    // Pedir permiso por primera vez
    final locationGranted = await PermissionService.instance
        .handleLocationPermission(context);
    if (locationGranted) {
      await PermissionService.instance.handleBackgroundLocationPermission(
        context,
      );
      // Obtener ubicación inicial rápidamente
      try {
        final pos = await Geolocator.getCurrentPosition();
        if (mounted) setState(() => _currentPosition = pos);
      } catch (e) {
        debugPrint('Error getting initial position: $e');
      }
      _startPositionTracking();
    }
  }

  void _startPositionTracking() {
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) {
          if (mounted) {
            setState(() => _currentPosition = position);
            if (_mapController != null &&
                (_isFirstLocationUpdate || _isOnline)) {
              if (_markers.isEmpty) {
                // Solo auto-centrar si no hay un viaje activo para no arruinar el zoom A-B
                _mapController!.animateCamera(
                  CameraUpdate.newLatLng(
                    LatLng(position.latitude, position.longitude),
                  ),
                );
              }
              _isFirstLocationUpdate = false;
            }
          }
        });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _playNotificationSound() async {
    try {
      if (_audioPlayer.state == PlayerState.playing) return;
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('music/alerta.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void _stopNotificationSound() {
    try {
      _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping sound: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverProfileAsync = ref.watch(driverProfileProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    return userProfileAsync.when(
      data: (user) {
        if (user == null)
          return const Scaffold(
            body: Center(child: Text('Usuario no encontrado')),
          );

        // 1. Si está verificado como conductor, mostrar mapa principal
        if (user.driverStatus == DriverStatus.active) {
          return _buildMainDriverContent(context);
        }

        // 2. Si está en espera o rechazado, mostrar pantalla de espera
        if (user.driverStatus == DriverStatus.pending ||
            user.driverStatus == DriverStatus.rejected) {
          return DriverWaitingScreen(status: user.driverStatus!.name);
        }

        // 3. Si no ha iniciado registro (isDriver es false o driver_data no existe)
        return driverProfileAsync.when(
          data: (profile) {
            if (profile == null) return _buildRegistrationRequiredView();
            // Caso borde: tiene driver_data pero status no es active (posiblemente pending)
            return DriverWaitingScreen(
              status: user.driverStatus?.name ?? 'pending',
            );
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.black)),
          ),
          error: (err, stack) =>
              Scaffold(body: Center(child: Text('Error: $err'))),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      ),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text('Error al cargar perfil: $err'))),
    );
  }

  Widget _buildRegistrationRequiredView() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black, Color(0xFF1A1A1A)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_car_filled_rounded,
              color: Colors.white,
              size: 80,
            ),
            const SizedBox(height: 32),
            const Text(
              'Conviértete en Socio TINS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aún no has completado tu registro como conductor. Únete a nuestra red premium y empieza a ganar hoy mismo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DriverRegistrationScreen(),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'INICIAR REGISTRO',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainDriverContent(BuildContext context) {
    final incomingTripsAsync = ref.watch(requestedTripsProvider);
    final activeTripAsync = ref.watch(activeTripProvider);

    final incomingTripsRaw = incomingTripsAsync.asData?.value ?? [];
    final hasActiveTrip = activeTripAsync.asData?.value != null;

    AppLogger.log('DEBUG DRIVER_HOME:');
    AppLogger.log('   - _isOnline: $_isOnline');
    AppLogger.log('   - incomingTrips: ${incomingTripsRaw.length}');
    AppLogger.log('   - hasActiveTrip: $hasActiveTrip');
    if (incomingTripsRaw.isNotEmpty) {
      AppLogger.log('   - First Trip ID: ${incomingTripsRaw.first.id}');
      AppLogger.log('   - First Trip Status: ${incomingTripsRaw.first.status}');
    }
    AppLogger.log('--------------------');

    if (incomingTripsRaw.isNotEmpty) {
      print(
        'UI: Recibidos ${incomingTripsRaw.length} viajes desde el provider.',
      );
    }

    // ── Filtrar solo viajes razonablemente cercanos (500 km para pruebas) ──
    const double maxDistance = 500000.0; // 500 km en metros
    final incomingTrips = _currentPosition == null
        ? incomingTripsRaw
        : incomingTripsRaw.where((t) {
            final dist = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              t.pickupLocation.latitude,
              t.pickupLocation.longitude,
            );
            final isVisible = dist <= maxDistance;
            print(
              'UI: Viaje ${t.id} está a ${dist.toStringAsFixed(0)}m. ¿Visible (<${maxDistance}m)? $isVisible',
            );
            return isVisible;
          }).toList();

    if (incomingTripsRaw.isNotEmpty && incomingTrips.isEmpty) {
      print(
        'UI: ADVERTENCIA - Hay ${incomingTripsRaw.length} viajes en Raw pero 0 después del filtro de 15km.',
      );
    }

    ref.listen<AsyncValue<Trip?>>(activeTripProvider, (previous, next) {
      final trip = next.asData?.value;
      if (trip != null && trip.driverId != null) {
        if ((trip.status == TripStatus.accepted ||
                trip.status == TripStatus.arrived ||
                trip.status == TripStatus.inProgress) &&
            !_isNavigatingToTrip) {
          _isNavigatingToTrip = true;
          print(
            '[CONDUCTOR] Viaje activo detectado (${trip.status.name}) → navegando a TripManagement',
          );
          _stopNotificationSound();
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'trip_management'),
              builder: (context) => DriverTripManagementScreen(tripId: trip.id),
            ),
          ).then((_) {
            // Cuando el conductor regresa (viaje completado/cancelado), reset guard
            if (mounted) setState(() => _isNavigatingToTrip = false);
          });
        }
      } else {
        // Viaje nulo → resetear el guard
        if (mounted) _isNavigatingToTrip = false;
      }
    });

    ref.listen<AsyncValue<List<Trip>>>(requestedTripsProvider, (
      previous,
      next,
    ) {
      if (!_isOnline) return;

      final activeTrip = ref.read(activeTripProvider).asData?.value;
      if (activeTrip != null) return;

      final prevCount = previous?.asData?.value.length ?? 0;
      final nextCount = next.asData?.value.length ?? 0;

      if (nextCount > prevCount) {
        _playNotificationSound();
        _showTripOnMap(next.asData?.value.first);
      } else if (nextCount == 0 && prevCount > 0) {
        _stopNotificationSound();
        setState(() => _markers = {});
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          GoogleMap(
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    )
                  : _center,
              zoom: 16.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Header
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () async {
                  final newStatus = !_isOnline;
                  setState(() => _isOnline = newStatus);

                  if (newStatus) {
                    final rawTrips =
                        ref.read(requestedTripsProvider).asData?.value ?? [];
                    if (rawTrips.isNotEmpty && _currentPosition != null) {
                      final dist = Geolocator.distanceBetween(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                        rawTrips.first.pickupLocation.latitude,
                        rawTrips.first.pickupLocation.longitude,
                      );
                      if (dist <= 500000.0) {
                        _playNotificationSound();
                        _showTripOnMap(rawTrips.first);
                      }
                    }
                  } else {
                    _stopNotificationSound();
                    setState(() => _markers = {});
                  }

                  // Optimistically sync to database
                  try {
                    final currUser = Supabase.instance.client.auth.currentUser;
                    if (currUser != null) {
                      await Supabase.instance.client
                          .from('driver_data')
                          .update({'is_online': newStatus})
                          .eq('profile_id', currUser.id);
                    }
                  } catch (e) {
                    debugPrint('Error syncing online status: $e');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: _isOnline
                          ? Colors.greenAccent.withValues(alpha: 0.3)
                          : Colors.redAccent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _isOnline
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isOnline ? 'EN LÍNEA' : 'DESCONECTADO',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: _isOnline ? Colors.black87 : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Menu
          Positioned(
            top: 60,
            left: 20,
            child: FloatingActionButton.small(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DriverServiceSettingsScreen(),
                ),
              ),
              backgroundColor: Colors.white,
              child: const Icon(Icons.menu_open_rounded, color: Colors.black),
            ),
          ),

          // ── Earnings bar premium + FAB mi ubicación ──
          if (incomingTrips.isEmpty && !hasActiveTrip)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: ref
                  .watch(todayDriverStatsProvider)
                  .maybeWhen(
                    data: (stats) => GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EarningsScreen(),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.grey.shade100,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        child: Row(
                          children: [
                            // Ganancias
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'HOY',
                                    style: TextStyle(
                                      color: Colors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '\$${(stats['earnings'] ?? 0.0).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Divisor
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.grey.shade200,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                            ),
                            // Viajes del día
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(stats['count'] ?? 0.0).toInt()}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'VIAJES',
                                  style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            // Flecha
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.black26,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
            ),

          // FAB mi ubicación
          if (incomingTrips.isEmpty && !hasActiveTrip)
            Positioned(
              bottom: 140,
              right: 20,
              child: FloatingActionButton.small(
                heroTag: 'my_location_fab',
                onPressed: () {
                  if (_currentPosition != null && _mapController != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        16,
                      ),
                    );
                  }
                },
                backgroundColor: Colors.white,
                elevation: 4,
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Colors.black,
                  size: 18,
                ),
              ),
            ),

          // New Trip Overlay — pantalla completa
          if (_isOnline && incomingTrips.isNotEmpty && !hasActiveTrip)
            Positioned.fill(
              child: TripRequestCard(
                key: ValueKey(
                  '${incomingTrips.first.id}_${incomingTrips.first.price}',
                ),
                trip: incomingTrips.first,
                driverPosition: _currentPosition,
                onReject: () {
                  _stopNotificationSound();
                  ref
                      .read(ignoredTripsProvider.notifier)
                      .ignore(
                        incomingTrips.first.id,
                        incomingTrips.first.price,
                      );
                  setState(() => _markers = {});
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showTripOnMap(Trip? trip) async {
    if (trip == null || _mapController == null) return;

    final markerA = await MarkerUtils.createABMarker(
      letter: 'A',
      backgroundColor: Colors.blueAccent,
      foregroundColor: Colors.white,
      label: 'Recogida',
    );
    final markerB = await MarkerUtils.createABMarker(
      letter: 'B',
      backgroundColor: Colors.redAccent,
      foregroundColor: Colors.white,
      label: 'Destino',
    );

    if (!mounted) return;

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('pickup'),
          position: trip.pickupLocation,
          icon: markerA,
        ),
        Marker(
          markerId: const MarkerId('dropoff'),
          position: trip.dropoffLocation,
          icon: markerB,
        ),
      };
    });
    final bounds = _getBounds([
      trip.pickupLocation,
      trip.dropoffLocation,
      if (_currentPosition != null)
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
    ]);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
