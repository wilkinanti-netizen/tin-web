import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/features/trips/presentation/screens/searching_driver_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trip_tracking_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trip_cancellation_screen.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tincars/core/services/notification_service.dart';

import 'package:tincars/core/utils/marker_utils.dart';
import 'package:tincars/features/trips/presentation/screens/vehicle_selection_screen.dart';
import 'package:tincars/features/profile/presentation/screens/set_address_screen.dart';
import 'package:tincars/features/trips/presentation/widgets/trip_status_widget.dart';
import 'package:tincars/core/utils/permission_service.dart';
import 'package:tincars/core/services/maps_service.dart';
import 'package:tincars/l10n/app_localizations.dart';
import 'package:tincars/features/home/presentation/providers/user_mode_provider.dart';
import 'package:tincars/features/trips/presentation/screens/trip_planning_screen.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/core/utils/map_styles.dart';
import 'package:flutter/services.dart';
import 'package:tincars/features/home/presentation/providers/nearby_drivers_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late GoogleMapController mapController;
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
        ).listen((Position position) {
          if (mounted) {
            setState(() => _currentPosition = position);
            if (_isFollowingUser) {
              _centerCamera(position);
            }
            _updateCurrentAddress(position);
          }
        });
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
    mapController.animateCamera(
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
      backgroundColor: Colors.redAccent,
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
    mapController.setMapStyle(MapStyles.silverStyle);
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
      print(
        'HomeScreen: Skip redirection - Already handled for $redirectionKey',
      );
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
        if (prevTrip != null &&
            prevTrip.driverLocation != trip.driverLocation) {
          print(
            'HomeScreen: [TRIP_LOCATION_UPDATE] Conductor moviéndose a ${trip.driverLocation}',
          );
        }
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
        newMarkers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: activeTrip.pickupLocation,
            icon: _pickupIcon ?? BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(title: l10n.pickup),
          ),
        );
        newMarkers.add(
          Marker(
            markerId: const MarkerId('dropoff'),
            position: activeTrip.dropoffLocation,
            icon: _dropoffIcon ?? BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(title: l10n.destination),
          ),
        );

        if (activeTrip.driverLocation != null) {
          newMarkers.add(
            Marker(
              markerId: const MarkerId('driver'),
              position: activeTrip.driverLocation!,
              icon: _vehicleIcon ?? BitmapDescriptor.defaultMarker,
              rotation: activeTrip.driverHeading ?? 0,
              infoWindow: InfoWindow(title: l10n.driver),
            ),
          );
        }

        // Auto-zoom only if markers significantly changed
        _updateCameraForTrip(activeTrip);
      } else {
        // --- CASE 2: IDLE (SHOW NEARBY) ---
        for (final driver in nearbyDriversList) {
          if (driver.lastLat != null && driver.lastLng != null) {
            newMarkers.add(
              Marker(
                markerId: MarkerId('driver_${driver.profileId}'),
                position: LatLng(driver.lastLat!, driver.lastLng!),
                icon: _vehicleIcon ?? BitmapDescriptor.defaultMarker,
                rotation: driver.lastHeading ?? 0,
                anchor: const Offset(0.5, 0.5),
                flat: true,
              ),
            );
          }
        }
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

          // Top Address HUD (Premium)
          if (activeTrip == null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 20,
              right: 20,
              child: PremiumGlassContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: Colors.white,
                opacity: 0.95,
                blur: 20,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.pickup,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.blueAccent.withValues(alpha: 0.7),
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            _currentAddress,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (!_isFollowingUser)
                      GestureDetector(
                        onTap: _getCurrentLocation,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.my_location,
                            size: 18,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Premium Bottom Search Card (v2)
          if (activeTrip == null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 30,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (userProfile?.fullName != null)
                              Text(
                                'Hola ${userProfile!.fullName},',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black38,
                                ),
                              ),
                            const Text(
                              '¿A dónde vamos?',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Modern Search Bar
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
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.03),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              color: Colors.black,
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Introduce tu destino',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black.withValues(alpha: 0.4),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Quick Actions
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        children: [
                          _buildQuickAction(
                            icon: Icons.home_rounded,
                            label: 'Casa',
                            onTap: () =>
                                _handleQuickAction('casa', 'Configurar Casa'),
                          ),
                          const SizedBox(width: 12),
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
                            if (label.length > 20) {
                              label = '${label.substring(0, 17)}...';
                            }

                            return Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: _buildQuickAction(
                                icon: Icons.location_on_rounded,
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

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 100,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.03),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.black, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateCameraForTrip(Trip trip) {
    final points = [
      trip.pickupLocation,
      trip.dropoffLocation,
      if (trip.driverLocation != null) trip.driverLocation!,
    ];

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    mapController.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }
}
