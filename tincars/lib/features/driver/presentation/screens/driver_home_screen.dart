import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/features/driver/presentation/widgets/trip_request_card.dart';
import 'package:tincars/features/driver/presentation/screens/earnings_screen.dart';
import 'package:tincars/features/driver/presentation/screens/driver_service_settings_screen.dart';
import 'package:tincars/features/driver/presentation/screens/driver_trip_management_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/core/utils/permission_service.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';
import 'package:tincars/features/driver/presentation/screens/driver_registration_screen.dart';
import 'package:tincars/features/driver/presentation/screens/driver_waiting_screen.dart';
import 'package:tincars/features/home/presentation/providers/user_mode_provider.dart';
import 'package:tincars/core/utils/marker_utils.dart';
import 'package:tincars/core/services/maps_service.dart';
import 'package:tincars/core/services/notification_service.dart';
import 'package:tincars/features/trips/domain/services/pricing_service.dart';
import 'package:tincars/core/services/realtime_location_service.dart';
import 'package:tincars/core/services/surge_pricing_service.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  bool _isOnline = true;
  static const LatLng _center = LatLng(
    25.7617,
    -80.1918,
  ); // Miami, USA (Updated for US support)
  final AudioPlayer _audioPlayer = AudioPlayer();
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  GoogleMapController? _mapController;
  bool _isFirstLocationUpdate = true;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _heatmapCircles = {};
  bool _isNavigatingToTrip = false; // Guard contra duplicados
  final MapsService _mapsService = MapsService();
  String? _currentShowingTripId;

  // Trip Distance and Time Cache
  double? _pickupDistance;
  int? _pickupTime;
  double? _tripDistance;
  int? _tripTime;

  void _resetTripMetrics() {
    _pickupDistance = null;
    _pickupTime = null;
    _tripDistance = null;
    _tripTime = null;
    _currentShowingTripId = null;
  }

  StreamSubscription? _heatmapSubscription;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _startHeatmapUpdates();
  }

  void _startHeatmapUpdates() {
    // Update heatmap every 30 seconds
    _heatmapSubscription = Stream.periodic(
      const Duration(seconds: 30),
    ).listen((_) async {
      if (!_isOnline || !mounted) return;
      try {
        final circles = await SurgePricingService.instance.generateHeatmapCircles();
        if (mounted) setState(() => _heatmapCircles = circles);
      } catch (e) {
        debugPrint('Error updating heatmap: $e');
      }
    });
    // Initial load
    SurgePricingService.instance.generateHeatmapCircles().then((circles) {
      if (mounted) setState(() => _heatmapCircles = circles);
    }).catchError((_) {});
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

  void _centerCamera(Position position) {
    if (_mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
    );
  }

  void _startPositionTracking() {
    LocationSettings locationSettings;

    if (Theme.of(context).platform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText:
              "TinCars está rastreando tu ubicación para recibir viajes.",
          notificationTitle: "Modo Conductor Activo",
          enableWakeLock: true,
        ),
      );
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            if (mounted) {
              setState(() {
                _currentPosition = position;
                if (_isFirstLocationUpdate) {
                  _centerCamera(position);
                  _isFirstLocationUpdate = false;
                }
              });

              if (_isOnline) {
                final userId = FirebaseAuth.instance.currentUser?.uid;
                if (userId != null) {
                  // Use RTDB for real-time GPS (cheaper than Firestore)
                  RealtimeLocationService.instance.updateDriverLocation(
                    userId,
                    position.latitude,
                    position.longitude,
                    heading: position.heading,
                  );
                }
              }
            }
          },
          onError: (error) {
            AppLogger.error('Error en el stream de ubicación: $error');
          },
        );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _positionSubscription?.cancel();
    _heatmapSubscription?.cancel();
    // Set driver offline in RTDB when leaving
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      RealtimeLocationService.instance.removeDriverLocation(userId);
    }
    super.dispose();
  }

  Future<void> _playNotificationSound(Trip trip) async {
    try {
      if (_audioPlayer.state == PlayerState.playing) return;
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('music/alerta.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
    // Also show a system notification so the alert fires when the app
    // is in the background or the driver is using another app.
    try {
      await NotificationService.instance.showIncomingTripNotification(
        tripId: trip.id,
        pickupAddress: trip.pickupAddress,
        price: trip.price.toStringAsFixed(2),
      );
    } catch (e) {
      debugPrint('Error showing trip notification: $e');
    }
  }

  void _stopNotificationSound() {
    try {
      _audioPlayer.stop();
      NotificationService.instance.cancelIncomingTripNotification();
      _resetTripMetrics();
      if (mounted) {
        setState(() {
          _markers = {};
          _polylines = {};
        });
      }
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
          final profile = driverProfileAsync.asData?.value;
          return DriverWaitingScreen(
            status: user.driverStatus!.name,
            rejectionReason: profile?.rejectionReason,
            driverId: user.id,
            rejectedPhotos: profile?.rejectedPhotos,
          );
        }

        // 3. Si no ha iniciado registro (isDriver es false o driver_data no existe)
        return driverProfileAsync.when(
          data: (profile) {
            if (profile == null) return _buildRegistrationRequiredView();
            // Caso borde: tiene driver_data pero status no es active (posiblemente pending)
            return DriverWaitingScreen(
              status: user.driverStatus?.name ?? 'pending',
              rejectionReason: profile.rejectionReason,
              driverId: user.id,
              rejectedPhotos: profile.rejectedPhotos,
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
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                ref.read(isModeTransitioningProvider.notifier).start();
                Future.delayed(const Duration(milliseconds: 300), () {
                  ref
                      .read(userModeProvider.notifier)
                      .setMode(UserMode.passenger);
                });
              },
              icon: const Icon(Icons.person, color: Colors.white70),
              label: const Text(
                'CAMBIAR A MODO PASAJERO',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
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

    if (incomingTripsRaw.isNotEmpty) {}

    // ── Filtrar solo viajes razonablemente cercanos (500 km para pruebas) ──
    const double maxDistance = 16093.4; // 10 millas en metros
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
            return isVisible;
          }).toList();

    if (incomingTripsRaw.isNotEmpty && incomingTrips.isEmpty) {}

    // Recovery check if trip already exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final trip = ref.read(activeTripProvider).asData?.value;
      if (trip != null &&
          (trip.status == TripStatus.accepted ||
              trip.status == TripStatus.arrived ||
              trip.status == TripStatus.inProgress) &&
          !_isNavigatingToTrip) {
        _isNavigatingToTrip = true;
        _stopNotificationSound();
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'trip_management'),
            builder: (context) => DriverTripManagementScreen(tripId: trip.id),
          ),
        ).then((_) {
          if (mounted) setState(() => _isNavigatingToTrip = false);
        });
      }
    });

    ref.listen<AsyncValue<Trip?>>(activeTripProvider, (previous, next) {
      final trip = next.asData?.value;
      if (trip != null && trip.driverId != null) {
        if ((trip.status == TripStatus.accepted ||
                trip.status == TripStatus.arrived ||
                trip.status == TripStatus.inProgress) &&
            !_isNavigatingToTrip) {
          _isNavigatingToTrip = true;

          _stopNotificationSound();
          setState(() {
            _markers = {};
            _polylines = {};
          });
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
        final allTrips = next.asData?.value ?? [];
        final nearbyTrips = allTrips.where((t) {
          if (_currentPosition == null) return true;
          final dist = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            t.pickupLocation.latitude,
            t.pickupLocation.longitude,
          );
          return dist <= 16093.4; // 10 miles
        }).toList();

        if (nearbyTrips.isNotEmpty) {
          final firstTrip = nearbyTrips.first;
          _playNotificationSound(firstTrip);
          _showTripOnMap(firstTrip);
        }
      } else if (nextCount == 0 && prevCount > 0) {
        _stopNotificationSound();
        setState(() {
          _markers = {};
          _polylines = {};
        });
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          GoogleMap(
            markers: _markers,
            polylines: _polylines,
            circles: _heatmapCircles,
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
            buildingsEnabled: false,
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
                        _playNotificationSound(rawTrips.first);
                        _showTripOnMap(rawTrips.first);
                      }
                    }
                  } else {
                    _stopNotificationSound();
                    setState(() => _markers = {});
                  }

                  // Optimistically sync to database
                  try {
                    final currUser = FirebaseAuth.instance.currentUser;
                    if (currUser != null) {
                      await FirebaseFirestore.instance
                          .collection('driver_data')
                          .doc(currUser.uid)
                          .update({'is_online': newStatus});
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

          // Menu - Integrated (Not floating as much)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DriverServiceSettingsScreen(),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.menu_open_rounded,
                  color: Colors.black,
                  size: 26,
                ),
              ),
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
                                    '\$${(stats['earnings'] ?? 0.0).toStringAsFixed(2)}',
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

          // My Location Button
          if (incomingTrips.isEmpty && !hasActiveTrip)
            Positioned(
              bottom: 130,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  if (_currentPosition != null && _mapController != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          zoom: 16.0,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: Colors.black,
                    size: 26,
                  ),
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
                pickupDistance: _pickupDistance,
                pickupTime: _pickupTime,
                tripDistance: _tripDistance,
                tripTime: _tripTime,
                onReject: () {
                  _stopNotificationSound();
                  ref
                      .read(ignoredTripsProvider.notifier)
                      .ignore(
                        incomingTrips.first.id,
                        incomingTrips.first.price,
                      );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showTripOnMap(Trip? trip) async {
    if (trip == null || _mapController == null) return;

    // Cleanup previous trip state immediately
    _resetTripMetrics();
    _currentShowingTripId = trip.id;
    if (mounted) {
      setState(() {
        _markers = {};
        _polylines = {};
      });
    }

    BitmapDescriptor markerA;
    BitmapDescriptor markerB;

    List<LatLng>? polylineA;
    List<LatLng>? polylineB;

    if (_currentPosition != null) {
      try {
        final driverLoc = LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );

        // 1. Path to Pickup (A)
        final directionsA = await _mapsService.getDirections(
          driverLoc,
          trip.pickupLocation,
        );
        polylineA = directionsA['polyline'];
        _pickupDistance = directionsA['distance'];
        _pickupTime = directionsA['duration'];

        // 2. Path to Dropoff (B)
        final directionsB = await _mapsService.getDirections(
          trip.pickupLocation,
          trip.dropoffLocation,
          waypoints: trip.intermediateStops.map((s) => s.location).toList(),
        );
        polylineB = directionsB['polyline'];
        _tripDistance = directionsB['distance'];
        _tripTime = directionsB['duration'];
      } catch (e) {
        AppLogger.error('Error fetching new trip directions', error: e);
      }
    }

    if (_pickupTime != null && _pickupDistance != null) {
      markerA = await MarkerUtils.createABMarkerWithMetrics(
        letter: 'A',
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        timeText: '${_pickupTime} min',
        distanceText: '${(_pickupDistance! * 0.621371).toStringAsFixed(1)} mi',
      );
    } else {
      markerA = await MarkerUtils.createABMarker(
        letter: 'A',
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        label: 'Recogida',
      );
    }

    if (_tripTime != null && _tripDistance != null) {
      markerB = await MarkerUtils.createABMarkerWithMetrics(
        letter: 'B',
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        timeText: '${_tripTime} min',
        distanceText: '${(_tripDistance! * 0.621371).toStringAsFixed(1)} mi',
      );
    } else {
      markerB = await MarkerUtils.createABMarker(
        letter: 'B',
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        label: 'Destino',
      );
    }

    if (!mounted || _currentShowingTripId != trip.id) return;

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('pickup'),
          position: trip.pickupLocation,
          icon: markerA,
          anchor: const Offset(
            0.0,
            0.5,
          ), // Center the left-edge circle on the point
        ),
        for (int i = 0; i < trip.intermediateStops.length; i++)
          Marker(
            markerId: MarkerId('stop_$i'),
            position: trip.intermediateStops[i].location,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(title: 'Parada ${i + 1}'),
          ),
        Marker(
          markerId: const MarkerId('dropoff'),
          position: trip.dropoffLocation,
          icon: markerB,
          anchor: const Offset(
            0.0,
            0.5,
          ), // Center the left-edge circle on the point
        ),
      };

      if (polylineA != null || polylineB != null) {
        // Load the arrow icon for polyline caps
        MarkerUtils.createDriverArrowMarker().then((arrowIcon) {
          if (!mounted || _currentShowingTripId != trip.id) return;
          setState(() {
            _polylines = {
              if (polylineA != null)
                Polyline(
                  polylineId: const PolylineId('to_pickup'),
                  points: polylineA!,
                  color: Colors.blueAccent,
                  width: 6,
                  endCap: Cap.customCapFromBitmap(arrowIcon),
                  patterns: [
                    PatternItem.dash(15),
                    PatternItem.gap(10),
                  ], // Dotted to A
                ),
              if (polylineB != null)
                Polyline(
                  polylineId: const PolylineId('to_dropoff'),
                  points: polylineB,
                  color: Colors.black87,
                  width: 7,
                  endCap: Cap.customCapFromBitmap(arrowIcon),
                ),
            };
          });
        });
      }
    });

    final bounds = _getBounds([
      trip.pickupLocation,
      ...trip.intermediateStops.map((s) => s.location),
      trip.dropoffLocation,
      if (_currentPosition != null)
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
    ]);

    // Added padding to the bottom so points aren't covered by the card
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        MediaQuery.of(context).size.height *
            0.12, // Reduced padding to zoom closer to the points
      ),
    );
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(southwest: _center, northeast: _center);
    }

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
