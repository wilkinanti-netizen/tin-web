import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/features/passenger/presentation/screens/searching_driver_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trip_tracking_screen.dart';
import 'package:tincars/features/passenger/presentation/screens/trip_cancellation_screen.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tincars/core/services/notification_service.dart';

import 'package:tincars/core/utils/marker_utils.dart';
import 'package:tincars/features/passenger/presentation/screens/vehicle_selection_screen.dart';
import 'package:tincars/features/profile/presentation/screens/set_address_screen.dart';
import 'package:tincars/features/trips/presentation/widgets/trip_status_widget.dart';
import 'package:tincars/core/utils/permission_service.dart';
import 'package:tincars/core/services/maps_service.dart';
import 'package:tincars/l10n/app_localizations.dart';
import 'package:tincars/features/home/presentation/providers/user_mode_provider.dart';
import 'package:tincars/features/passenger/presentation/screens/trip_planning_screen.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/core/utils/map_styles.dart';
import 'package:flutter/services.dart';
import 'package:tincars/features/home/presentation/providers/nearby_drivers_provider.dart';
import 'package:tincars/features/home/presentation/providers/main_nav_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  GoogleMapController? mapController;
  static const LatLng _center = LatLng(4.6097, -74.0817); // Bogotá, Colombia
  LatLng? _initialPosition;
  Set<Marker> _markers = {};
  bool _isRedirectingToTrip = false;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  BitmapDescriptor? _vehicleIcon;
  StreamSubscription<Position>? _positionSubscription;
  bool _isFollowingUser = true;
  String _currentAddress = "Obteniendo ubicación...";
  Position? _currentPosition;
  String? _recentlyCancelledTripId;
  String? _lastRedirectedTripId; // Tracker to prevent duplicate pushes

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _loadMarkerIcons();
    _setInitialLocation();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() {
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen(
          (Position position) {
            if (mounted) {
              setState(() => _currentPosition = position);
              if (_isFollowingUser) {
                _centerCamera(position);
              }
              _updateCurrentAddress(position);
            }
          },
          onError: (error) {
            debugPrint('HomeScreen location error: $error');
          },
        );
  }

  Future<void> _updateCurrentAddress(Position pos) async {
    try {
      final address = await _mapsService.getAddressFromLatLng(
        LatLng(pos.latitude, pos.longitude),
      );
      if (mounted) setState(() => _currentAddress = address);
    } catch (_) {}
  }

  void _centerCamera(Position position) {
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        16,
      ),
    );
  }

  Future<void> _setInitialLocation() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted) {
        setState(() => _initialPosition = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  Future<void> _loadMarkerIcons() async {
    final pickup = await MarkerUtils.createABMarker(
      letter: 'A',
      backgroundColor: Colors.blueAccent,
      foregroundColor: Colors.white,
      label: 'Recogida',
    );
    final dropoff = await MarkerUtils.createABMarker(
      letter: 'B',
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      label: 'Destino',
    );
    final vehicle = await MarkerUtils.createVehicleMarker();

    if (mounted) {
      setState(() {
        _pickupIcon = pickup;
        _dropoffIcon = dropoff;
        _vehicleIcon = vehicle;
      });
    }
  }

  Future<void> _checkLocationPermission() async {
    final granted = await PermissionService.instance.handleLocationPermission(
      context,
    );
    if (granted) {
      try {
        await Geolocator.getCurrentPosition();
        // El stream de ubicación o el método de centrado se encargarán del resto
      } catch (e) {
        debugPrint('Error getting initial position in HomeScreen: $e');
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    mapController?.setMapStyle(MapStyles.silverStyle);
    _getCurrentLocation(); // Auto-center on creation
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFollowingUser = true);
    try {
      Position position = await Geolocator.getCurrentPosition();
      _centerCamera(position);
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _onMenuPressed() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _handleTripRedirection(Trip trip) {
    if (_isRedirectingToTrip) return;

    final String redirectionKey = '${trip.id}_${trip.status.name}';
    if (redirectionKey == _lastRedirectedTripId) {
      return;
    }

    _lastRedirectedTripId = redirectionKey;
    setState(() => _isRedirectingToTrip = true);

    if (trip.status == TripStatus.requested) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchingDriverScreen(
            tripId: trip.id,
            pickupLocation: trip.pickupLocation,
            dropoffLocation: trip.dropoffLocation,
            pickupAddress: trip.pickupAddress,
            dropoffAddress: trip.dropoffAddress,
            intermediateStops: trip.intermediateStops,
            vehicleType: trip.vehicleType,
          ),
        ),
      ).then((result) {
        if (mounted) {
          setState(() => _isRedirectingToTrip = false);
          if (result == true) {
            _recentlyCancelledTripId = trip.id;
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) setState(() => _recentlyCancelledTripId = null);
            });
          } else {
            // Check if status changed to accepted/etc while we were in search screen
            final currentTrip = ref.read(activeTripProvider).asData?.value;
            if (currentTrip != null &&
                currentTrip.id == trip.id &&
                currentTrip.status != TripStatus.requested) {
              _handleTripRedirection(currentTrip);
            }
          }
        }
      });
    } else if (trip.status == TripStatus.accepted ||
        trip.status == TripStatus.arrived ||
        trip.status == TripStatus.inProgress) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TripTrackingScreen(tripId: trip.id),
        ),
      ).then((_) {
        if (mounted) setState(() => _isRedirectingToTrip = false);
      });
    } else {
      setState(() => _isRedirectingToTrip = false);
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapsService _mapsService = MapsService();
  bool _isLoadingRoute = false;

  void _updateCameraForTrip(Trip trip) {
    if (mapController == null) return;

    final driverLoc = trip.driverLocation;
    final pickup = trip.pickupLocation;
    final destination = trip.dropoffLocation;

    if (driverLoc == null) return;

    final LatLngBounds bounds;
    if (trip.status == TripStatus.accepted ||
        trip.status == TripStatus.arrived) {
      bounds = LatLngBounds(
        southwest: LatLng(
          driverLoc.latitude < pickup.latitude
              ? driverLoc.latitude
              : pickup.latitude,
          driverLoc.longitude < pickup.longitude
              ? driverLoc.longitude
              : pickup.longitude,
        ),
        northeast: LatLng(
          driverLoc.latitude > pickup.latitude
              ? driverLoc.latitude
              : pickup.latitude,
          driverLoc.longitude > pickup.longitude
              ? driverLoc.longitude
              : pickup.longitude,
        ),
      );
    } else if (trip.status == TripStatus.inProgress) {
      bounds = LatLngBounds(
        southwest: LatLng(
          driverLoc.latitude < destination.latitude
              ? driverLoc.latitude
              : destination.latitude,
          driverLoc.longitude < destination.longitude
              ? driverLoc.longitude
              : destination.longitude,
        ),
        northeast: LatLng(
          driverLoc.latitude > destination.latitude
              ? driverLoc.latitude
              : destination.latitude,
          driverLoc.longitude > destination.longitude
              ? driverLoc.longitude
              : destination.longitude,
        ),
      );
    } else {
      return;
    }

    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  Future<void> _handleQuickAction(String type, String title) async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString('${type}_address');
    final lat = prefs.getDouble('${type}_lat');
    final lng = prefs.getDouble('${type}_lng');

    if (address == null || lat == null || lng == null) {
      final success = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetAddressScreen(actionType: type, title: title),
        ),
      );

      if (success == true) {
        _handleQuickAction(type, title);
      }
      return;
    }

    setState(() => _isLoadingRoute = true);

    try {
      Position position = await Geolocator.getCurrentPosition();
      final currentLoc = LatLng(position.latitude, position.longitude);
      final destLoc = LatLng(lat, lng);

      final currentAddress = await _mapsService.getAddressFromLatLng(
        currentLoc,
      );

      final directions = await _mapsService.getDirections(currentLoc, destLoc);

      final boundsData = directions['bounds'];
      final latLngBounds = LatLngBounds(
        southwest: LatLng(
          boundsData['southwest']['lat'],
          boundsData['southwest']['lng'],
        ),
        northeast: LatLng(
          boundsData['northeast']['lat'],
          boundsData['northeast']['lng'],
        ),
      );

      final List<LatLng> polylinePoints = directions['polyline'];

      if (!mounted) return;

      setState(() => _isLoadingRoute = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VehicleSelectionScreen(
            pickupLocation: currentLoc,
            dropoffLocation: destLoc,
            pickupAddress: currentAddress,
            dropoffAddress: address,
            distanceInKm: directions['distance'],
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: polylinePoints,
                color: Colors.black,
                width: 5,
              ),
            },
            bounds: latLngBounds,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error calculando ruta a $title: $e')),
        );
      }
    }
  }

  Future<void> _showCancellationDialog(Trip trip) async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripCancellationScreen(trip: trip),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activeTrip = ref.watch(activeTripProvider).asData?.value;
    final userProfile = ref.watch(userProfileProvider).asData?.value;
    final isPassenger = ref.watch(userModeProvider) == UserMode.passenger;
    final tripHistory = ref.watch(tripHistoryProvider).asData?.value ?? [];
    final recentTrips = tripHistory
        .where((t) => t.status == TripStatus.completed)
        .take(3)
        .toList();

    // Initial redirection if trip exists (Recovery)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final trip = ref.read(activeTripProvider).asData?.value;

      if (trip != null &&
          !_isRedirectingToTrip &&
          trip.id != _recentlyCancelledTripId) {
        _handleTripRedirection(trip);
      } else if (trip == null && _isRedirectingToTrip) {
        setState(() => _isRedirectingToTrip = false);
      }
    });

    // Auto-navigation for active trips (Status Update)
    ref.listen<AsyncValue<Trip?>>(activeTripProvider, (previous, next) {
      final trip = next.asData?.value;
      final prevTrip = previous?.asData?.value;

      if (trip != null) {
        if (isPassenger && prevTrip != null && prevTrip.status != trip.status) {
          if (trip.status == TripStatus.accepted) {
            NotificationService.instance.showTripStatusNotification(
              title: '¡Conductor asignado!',
              body: 'Tu conductor está en camino para recogerte.',
            );
          } else if (trip.status == TripStatus.arrived) {
            NotificationService.instance.showTripStatusNotification(
              title: '¡Tu conductor ha llegado!',
              body: 'El conductor te está esperando en el punto de recogida.',
            );
          } else if (trip.status == TripStatus.inProgress) {
            NotificationService.instance.showTripStatusNotification(
              title: '¡Viaje iniciado!',
              body: 'Dirigiéndonos a tu destino. ¡Buen viaje!',
            );
          }
        }
      }

      if (trip == null) {
        if (_isRedirectingToTrip) {
          setState(() => _isRedirectingToTrip = false);
        }
        return;
      }

      // Only redirect if:
      // 1. We aren't already in a redirection flow
      // 2. We are moving from NO TRIP -> TRIP
      // 3. We are moving from SEARCHING -> TRACKING
      if (!_isRedirectingToTrip) {
        final bool isSearching = trip.status == TripStatus.requested;
        final bool isTracking =
            trip.status == TripStatus.accepted ||
            trip.status == TripStatus.arrived ||
            trip.status == TripStatus.inProgress;

        // Skip if this trip was just cancelled by the user
        if (trip.id == _recentlyCancelledTripId) {
          return;
        }

        final bool wasSearching = prevTrip?.status == TripStatus.requested;
        final bool wasTracking =
            prevTrip?.status == TripStatus.accepted ||
            prevTrip?.status == TripStatus.arrived ||
            prevTrip?.status == TripStatus.inProgress;

        if (isSearching && !wasSearching) {
          _handleTripRedirection(trip);
        } else if (isTracking && !wasTracking) {
          _handleTripRedirection(trip);
        }
      }
    });

    // --- Nearby Drivers Logic ---
    final nearbyDriversList =
        ref.watch(nearbyDriversProvider).asData?.value ?? [];

    // Update markers dynamically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final Set<Marker> newMarkers = {};

      if (activeTrip != null) {
        // --- CASE 1: ACTIVE TRIP ---
        if (_pickupIcon != null) {
          newMarkers.add(
            Marker(
              markerId: const MarkerId('pickup'),
              position: activeTrip.pickupLocation,
              icon: _pickupIcon!,
              infoWindow: InfoWindow(title: l10n.pickup),
            ),
          );
        }
        if (_dropoffIcon != null) {
          newMarkers.add(
            Marker(
              markerId: const MarkerId('dropoff'),
              position: activeTrip.dropoffLocation,
              icon: _dropoffIcon!,
              infoWindow: InfoWindow(title: l10n.destination),
            ),
          );
        }

        if (activeTrip.driverLocation != null) {
          newMarkers.add(
            Marker(
              markerId: const MarkerId('driver'),
              position: activeTrip.driverLocation!,
              icon: _vehicleIcon!,
              rotation: activeTrip.driverHeading ?? 0,
              infoWindow: InfoWindow(title: l10n.driver),
            ),
          );
        }

        // Auto-zoom only if markers significantly changed
        _updateCameraForTrip(activeTrip);
      } else {
        // --- CASE 2: IDLE ---
        // Se ha deshabilitado la visualización de conductores cercanos a petición del usuario
        // para que solo se vea el punto azul de su ubicación.
        /*
        for (final driver in nearbyDriversList) {
          if (driver.lastLat != null &&
              driver.lastLng != null &&
              _vehicleIcon != null) {
            newMarkers.add(
              Marker(
                markerId: MarkerId('driver_${driver.profileId}'),
                position: LatLng(driver.lastLat!, driver.lastLng!),
                icon: _vehicleIcon!,
                rotation: driver.lastHeading ?? 0,
                anchor: const Offset(0.5, 0.5),
                flat: true,
              ),
            );
          }
        }
        */
      }

      // Update state if markers list changed (simplified check)
      if (_markers.length != newMarkers.length || activeTrip != null) {
        setState(() => _markers = newMarkers);
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _initialPosition ?? _center,
              zoom: 16.0,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onCameraMoveStarted: () {
              // If user starts dragging, stop following
              if (_isFollowingUser) {
                setState(() => _isFollowingUser = false);
              }
            },
          ),

          // Premium Floating Location Pill
          if (activeTrip == null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF00C853,
                            ).withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _currentAddress,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!_isFollowingUser)
                      GestureDetector(
                        onTap: _getCurrentLocation,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2962FF,
                            ).withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.my_location_rounded,
                            size: 16,
                            color: Color(0xFF2962FF),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Premium Bottom Panel (v3)
          if (activeTrip == null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  28,
                  24,
                  MediaQuery.of(context).padding.bottom + 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 40,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Greeting Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (userProfile?.fullName != null)
                                Text(
                                  '${_getTimeGreeting().toUpperCase()}, ${userProfile!.fullName?.split(' ').first ?? ''}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black.withValues(alpha: 0.3),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              const Text(
                                '¿Cuál es tu destino?',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0A0A0A),
                                  letterSpacing: -1.2,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Profile avatar
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(mainNavIndexProvider.notifier)
                                .setIndex(2); // Go to Profile
                          },
                          child: Hero(
                            tag: 'profile_avatar',
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  width: 1,
                                ),
                                image:
                                    (userProfile?.avatarUrl != null &&
                                        userProfile!.avatarUrl!.isNotEmpty)
                                    ? DecorationImage(
                                        image: NetworkImage(
                                          userProfile.avatarUrl!,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child:
                                  (userProfile?.avatarUrl == null ||
                                      userProfile!.avatarUrl!.isEmpty)
                                  ? Center(
                                      child: Text(
                                        userProfile?.fullName?.isNotEmpty ==
                                                true
                                            ? userProfile!.fullName![0]
                                                  .toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Premium Search Bar
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TripPlanningScreen(
                              initialPickupLocation: _currentPosition != null
                                  ? LatLng(
                                      _currentPosition!.latitude,
                                      _currentPosition!.longitude,
                                    )
                                  : _center,
                              initialPickupAddress: _currentAddress,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 25,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.03),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.search_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Ingresar destino...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black.withValues(alpha: 0.3),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.black.withValues(alpha: 0.1),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Saved & Recent Destinations
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildQuickAction(
                            icon: Icons.home_rounded,
                            label: 'Casa',
                            onTap: () =>
                                _handleQuickAction('casa', 'Configurar Casa'),
                          ),
                          const SizedBox(width: 10),
                          _buildQuickAction(
                            icon: Icons.work_rounded,
                            label: 'Trabajo',
                            onTap: () => _handleQuickAction(
                              'trabajo',
                              'Configurar Trabajo',
                            ),
                          ),
                          ...recentTrips.map((trip) {
                            String label = trip.dropoffAddress.split(',').first;
                            if (label.length > 18) {
                              label = '${label.substring(0, 15)}...';
                            }

                            return Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: _buildQuickAction(
                                icon: Icons.schedule_rounded,
                                label: label,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TripPlanningScreen(
                                        initialPickupLocation:
                                            _currentPosition != null
                                            ? LatLng(
                                                _currentPosition!.latitude,
                                                _currentPosition!.longitude,
                                              )
                                            : _center,
                                        initialPickupAddress: _currentAddress,
                                        initialDropoffLocation:
                                            trip.dropoffLocation,
                                        initialDropoffAddress:
                                            trip.dropoffAddress,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Active Trip Widget
          if (activeTrip != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: TripStatusWidget(
                trip: activeTrip,
                onCancel: () => _showCancellationDialog(activeTrip),
              ),
            ),

          // Custom Menu Button (Only for Drivers)
          if (!isPassenger)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Colors.black,
                    size: 26,
                  ),
                  onPressed: _onMenuPressed,
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(),
                ),
              ),
            ),

          if (_isLoadingRoute)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF1A1A1A), size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
