import 'package:tincars/core/utils/app_logger.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:tincars/core/utils/emoji_marker_generator.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/trips/presentation/screens/trip_chat_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trip_completion_screen.dart';
import 'package:tincars/core/utils/marker_utils.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:tincars/core/services/maps_service.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';

class DriverTripManagementScreen extends ConsumerStatefulWidget {
  final String tripId;
  const DriverTripManagementScreen({super.key, required this.tripId});

  @override
  ConsumerState<DriverTripManagementScreen> createState() =>
      _DriverTripManagementScreenState();
}

class _DriverTripManagementScreenState
    extends ConsumerState<DriverTripManagementScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? mapController;
  bool _isUpdatingStatus = false;
  bool _isRedirectingToCompletion = false;
  LatLng? _currentDriverLocation;
  double _currentDriverHeading = 0.0;
  StreamSubscription<Position>? _positionSubscription;
  bool _isAutoCenterEnabled = true;
  DateTime? _lastCameraUpdate;

  // Cache
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  final Map<int, BitmapDescriptor> _stopIcons = {};
  String? _lastEmoji;
  Map<String, dynamic>? _lastDirections;
  LatLng? _lastDirectionsLoc;
  BitmapDescriptor? _customEmojiMarker;
  BitmapDescriptor? _passengerAvatarMarker;
  BitmapDescriptor? _driverArrowIcon;
  String? _estimatedDistance;
  String? _estimatedDuration;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadMapIcons();
    _startLocationSharing();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadMapIcons([List<TripStop> intermediateStops = const []]) async {
    final List<Future<BitmapDescriptor>> futures = [
      MarkerUtils.createABMarker(
        letter: 'A',
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        label: '',
      ),
      MarkerUtils.createABMarker(
        letter: String.fromCharCode(66 + intermediateStops.length),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        label: '',
      ),
      MarkerUtils.createDriverArrowMarker(),
    ];

    // Add intermediate markers futures
    for (int i = 0; i < intermediateStops.length; i++) {
      futures.add(
        MarkerUtils.createABMarker(
          letter: String.fromCharCode(66 + i),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          label: '',
        ),
      );
    }

    final results = await Future.wait(futures);

    if (mounted) {
      setState(() {
        _pickupIcon = results[0];
        _dropoffIcon = results[1];
        _driverArrowIcon = results[2];
        _stopIcons.clear();
        for (int i = 0; i < intermediateStops.length; i++) {
          _stopIcons[i] = results[3 + i];
        }
      });
    }
  }

  void _startLocationSharing() {
    LocationSettings locationSettings;

    if (Theme.of(context).platform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText:
              "TinCars está rastreando tu ubicación durante el viaje.",
          notificationTitle: "Viaje en Progreso",
          enableWakeLock: true,
        ),
      );
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          final loc = LatLng(position.latitude, position.longitude);
          final heading = position.heading;

          print(
            'DriverTripManagement: New location from Geolocator: (${position.latitude}, ${position.longitude}) heading=${position.heading}',
          );

          ref
              .read(tripControllerProvider.notifier)
              .updateLocation(
                widget.tripId,
                position.latitude,
                position.longitude,
                heading: heading,
              );

          if (mounted) {
            final bool isUpdatingForFirstTime = _currentDriverLocation == null;
            setState(() {
              _currentDriverLocation = loc;
              if (heading != 0) {
                _currentDriverHeading = heading;
              }
            });

            final currentTrip = ref
                .read(tripStreamProvider(widget.tripId))
                .asData
                ?.value;

            if (currentTrip != null) {
              if (isUpdatingForFirstTime || _lastDirectionsLoc == null) {
                _lastDirectionsLoc = loc;
                _fetchDirections(currentTrip);
              } else if (Geolocator.distanceBetween(
                    _lastDirectionsLoc!.latitude,
                    _lastDirectionsLoc!.longitude,
                    loc.latitude,
                    loc.longitude,
                  ) >
                  20) {
                _lastDirectionsLoc = loc;
                _fetchDirections(currentTrip);
              }
            }

            if (_isAutoCenterEnabled) {
              _updateCamera(loc, heading);
            }
          }
        });
  }

  void _updateCamera(LatLng location, double heading) {
    // Throttling camera updates to once every 2 seconds to save battery/performance
    final now = DateTime.now();
    if (_lastCameraUpdate != null &&
        now.difference(_lastCameraUpdate!) <
            const Duration(milliseconds: 1500)) {
      return;
    }
    _lastCameraUpdate = now;

    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: 19.5, // Much closer
          tilt: 45.0, // 3D perspective
          bearing: heading,
        ),
      ),
    );
  }

  Future<void> _updateStatus(TripStatus newStatus) async {
    setState(() => _isUpdatingStatus = true);
    try {
      await ref
          .read(tripControllerProvider.notifier)
          .updateStatus(widget.tripId, newStatus);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final url = 'tel:$phoneNumber';
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
      }
    }
  }

  Future<void> _loadPassengerEmojiMarker(String emoji) async {
    final marker = await EmojiMarkerGenerator.createEmojiMarker(emoji);
    if (mounted) {
      setState(() {
        _customEmojiMarker = marker;
      });
    }
  }

  Future<void> _loadPassengerUrlMarker(String url) async {
    final marker = await MarkerUtils.createAvatarFromUrl(url);
    if (mounted) {
      setState(() {
        _passengerAvatarMarker = marker;
      });
    }
  }

  void _fetchDirections(Trip trip) async {
    final bool isToDestination =
        trip.status == TripStatus.inProgress ||
        trip.status == TripStatus.arrived;

    // Si estamos yendo a recoger, la ruta es desde donde estoy hasta el pickup
    // Si ya llegamos o ya iniciamos, la ruta es desde donde estoy hasta el destino (o la siguiente parada)
    final LatLng start = _currentDriverLocation ?? trip.pickupLocation;
    
    LatLng end = trip.dropoffLocation;
    if (isToDestination) {
      // Si hay paradas intermedias pendientes, navegamos a la primera disponible
      final pendingStopIndex = trip.intermediateStops.indexWhere((s) => !s.isCompleted);
      if (pendingStopIndex != -1) {
        end = trip.intermediateStops[pendingStopIndex].location;
      }
    } else {
      end = trip.pickupLocation;
    }

    // Evitar llamadas innecesarias si el inicio y fin son iguales (p.ej. ya en el punto)
    if (start.latitude == end.latitude && start.longitude == end.longitude) {
      if (mounted) {
        setState(() => _lastDirections = null);
      }
      return;
    }

    print(
      'DriverTripManagement: Fetching directions from $start to $end (isToDestination: $isToDestination, status: ${trip.status.name})',
    );

    try {
      final directions = await MapsService().getDirections(start, end);
      if (mounted) {
        setState(() {
          _lastDirections = directions;
          _estimatedDistance = directions['distance_text'] ?? "${directions['distance'].toStringAsFixed(1)} km";
          _estimatedDuration = directions['duration_text'];
        });
      }
    } catch (e) {
      AppLogger.log('Error fetching directions: $e');
      // If it fails, maybe clear last directions to avoid showing stale route
      if (mounted) {
        setState(() => _lastDirections = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripStreamProvider(widget.tripId));

    // Navigation listener for trip completion/cancellation
    ref.listen<AsyncValue<Trip>>(tripStreamProvider(widget.tripId), (
      previous,
      next,
    ) {
      final trip = next.asData?.value;
      if (trip == null) return;

      if (trip.status == TripStatus.completed && !_isRedirectingToCompletion) {
        _isRedirectingToCompletion = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TripCompletionScreen(trip: trip, isDriver: true),
            ),
          );
        });
      } else if (trip.status == TripStatus.cancelled &&
          !_isRedirectingToCompletion) {
        _isRedirectingToCompletion = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
        });
      }

      // Dynamic Directions Update on status change
      final prevTrip = previous?.asData?.value;
      if (prevTrip?.status != trip.status) {
        print(
          'DriverTripManagement: Status changed from ${prevTrip?.status} to ${trip.status}. Updating directions.',
        );
        // Pequeño delay para asegurar que el estado se ha propagado si es necesario
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _fetchDirections(trip);
        });
      }
    });

    return Scaffold(
      body: PopScope(
        canPop: false,
        child: tripAsync.when(
          data: (trip) {
            // Check if icons need to be reloaded (if stops count changed)
            if (_stopIcons.length != trip.intermediateStops.length) {
              _loadMapIcons(trip.intermediateStops);
            }

            final passengerAsync = ref.watch(
              otherUserProfileProvider(trip.passengerId),
            );
            return _buildMapContent(trip, passengerAsync);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildMapContent(Trip trip, AsyncValue<AppUser?> passengerAsync) {
    Set<Polyline> polylines = {};

    // Route Path (Main Guidance)
    if (_lastDirections != null) {
      final points = _lastDirections!['polyline'] as List<LatLng>?;
      if (points != null) {
        final isToDestination = trip.status == TripStatus.inProgress;
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route_polyline_driver'),
            points: points,
            color: isToDestination ? Colors.green : Colors.blueAccent,
            width: 8,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      }
    }

    final passengerLoc = trip.status == TripStatus.inProgress
        ? trip.dropoffLocation
        : (trip.passengerLocation ?? trip.pickupLocation);
    final dropoffLoc = trip.dropoffLocation;

    // Load Passenger Marker (Emoji or Avatar)
    final passenger = passengerAsync.value;
    final emojiToUse = trip.passengerEmoji ?? passenger?.mapEmoji;
    final avatarToUse = passenger?.avatarUrl;

    if (emojiToUse != null &&
        emojiToUse.isNotEmpty &&
        emojiToUse != _lastEmoji) {
      _lastEmoji = emojiToUse;
      _loadPassengerEmojiMarker(emojiToUse);
    } else if (avatarToUse != null &&
        avatarToUse.isNotEmpty &&
        _passengerAvatarMarker == null) {
      _loadPassengerUrlMarker(avatarToUse);
    }

    final Set<Marker> markers = {
      // 1. Passenger Marker (Emoji or 'A')
      if (trip.status != TripStatus.inProgress)
        Marker(
          markerId: const MarkerId('passenger_marker'),
          position: passengerLoc,
          icon:
              _passengerAvatarMarker ??
              _customEmojiMarker ??
              _pickupIcon ??
              BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
        ),
      // 2. Destination Marker ('B', 'C'...)
      Marker(
        markerId: const MarkerId('dropoff_marker'),
        position: dropoffLoc,
        icon: _dropoffIcon ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: 'Destino Final'),
      ),
      // 3. Intermediate Stops
      ...trip.intermediateStops.asMap().entries.map((entry) {
        final index = entry.key;
        final stop = entry.value;
        return Marker(
          markerId: MarkerId('stop_$index'),
          position: stop.location,
          icon: _stopIcons[index] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          anchor: const Offset(0.5, 0.5),
          alpha: stop.isCompleted ? 0.4 : 1.0,
          infoWindow: InfoWindow(title: 'Parada ${index + 1}'),
        );
      }),
      // 4. Driver Arrow
      if (_currentDriverLocation != null)
        Marker(
          markerId: const MarkerId('driver_arrow'),
          position: _currentDriverLocation!,
          icon: _driverArrowIcon ?? BitmapDescriptor.defaultMarker,
          rotation: _calculateDriverRotation(trip),
          anchor: const Offset(0.5, 0.5),
          flat: true,
        ),
    };

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) {
            mapController = controller;
            _fetchDirections(trip);
          },
          onCameraMoveStarted: () {
            // Optional: allow user to take control
          },
          initialCameraPosition: CameraPosition(
            target: _currentDriverLocation ?? trip.pickupLocation,
            zoom: 19.5,
            tilt: 45,
          ),
          markers: markers,
          polylines: polylines,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          buildingsEnabled: true,
          trafficEnabled: false,
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          child: _buildTopStatusHUD(trip),
        ),
        Positioned(
          bottom: 320, // Moved higher as requested
          right: 20, // A bit more spacing
          child: FloatingActionButton(
            onPressed: () {
              setState(() => _isAutoCenterEnabled = !_isAutoCenterEnabled);
              if (_isAutoCenterEnabled && _currentDriverLocation != null) {
                _updateCamera(_currentDriverLocation!, _currentDriverHeading);
              }
            },
            backgroundColor: Colors.white,
            foregroundColor: _isAutoCenterEnabled
                ? Colors.blueAccent
                : Colors.black87,
            elevation: 8,
            shape: const CircleBorder(),
            child: Icon(
              Icons.gps_fixed_rounded,
              size: 28, // Bigger icon
            ),
          ),
        ),
        // Stats Row (Distance/Time) Overlay
        Positioned(
          bottom: 235, // Just above the bottom panel
          left: 20,
          right: 20,
          child: PremiumGlassContainer(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            opacity: 0.9,
            blur: 10,
            borderRadius: BorderRadius.circular(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.route_outlined, _estimatedDistance ?? "${trip.distance.toStringAsFixed(1)} km", "Distancia"),
                _buildStatItem(Icons.access_time_outlined, _estimatedDuration ?? "-- min", "Tiempo est."),
                if (trip.intermediateStops.isNotEmpty)
                  _buildStatItem(
                    Icons.add_location_alt_outlined, 
                    "\$${trip.price.toStringAsFixed(2)}", 
                    "Total Viaje"
                  ),
              ],
            ),
          ),
        ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomPanel(trip),
        ),
      ],
    );
  }

  Widget _buildTopStatusHUD(Trip trip) {
    return PremiumGlassContainer(
      color: Colors.white,
      opacity: 0.95,
      blur: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(40),
      child: Row(
        children: [
          _buildTopStatusIndicator(trip),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getTopBarAddressText(trip),
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _buildTopNavButton(trip),
          if (trip.status == TripStatus.accepted ||
              trip.status == TripStatus.arrived) ...[
            const SizedBox(width: 8),
            _buildCancelIconButton(trip),
          ],
        ],
      ),
    );
  }

  Widget _buildTopStatusIndicator(Trip trip) {
    if (trip.status == TripStatus.inProgress) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(_pulseAnimation.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(_pulseAnimation.value * 0.4),
                blurRadius: 8 * _pulseAnimation.value,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      );
    }
    return const Icon(
      Icons.gps_fixed_rounded,
      color: Colors.blueAccent,
      size: 18,
    );
  }

  Widget _buildTopNavButton(Trip trip) {
    final bool isToDestination =
        trip.status == TripStatus.inProgress ||
        trip.status == TripStatus.arrived;
        
    LatLng targetLoc = trip.pickupLocation;
    String targetAddress = trip.pickupAddress;
    
    if (isToDestination) {
      final pendingStopIndex = trip.intermediateStops.indexWhere((s) => !s.isCompleted);
      if (pendingStopIndex != -1) {
        targetLoc = trip.intermediateStops[pendingStopIndex].location;
        targetAddress = trip.intermediateStops[pendingStopIndex].address;
      } else {
        targetLoc = trip.dropoffLocation;
        targetAddress = trip.dropoffAddress;
      }
    }
    return GestureDetector(
      onTap: () => _openNavigationWithLocation(targetLoc, targetAddress),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.navigation_rounded, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(
              'NAVEGAR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelIconButton(Trip trip) {
    return GestureDetector(
      onTap: () => _showCancellationDialog(trip),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.close_rounded,
          color: Colors.redAccent,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildBottomPanel(Trip trip) {
    final passengerAsync = ref.watch(
      otherUserProfileProvider(trip.passengerId),
    );
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPassengerHeader(trip, passengerAsync),
          const SizedBox(height: 24),
          _buildActionButton(trip),
          const SizedBox(height: 16),
          _buildSecondaryActions(trip, passengerAsync),
        ],
      ),
    );
  }

  Widget _buildPassengerHeader(Trip trip, AsyncValue<dynamic> passengerAsync) {
    final passenger = passengerAsync.value;
    final avatarUrl = passenger?.avatarUrl;

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _getStatusColor(trip.status).withOpacity(0.1),
            shape: BoxShape.circle,
            image: avatarUrl != null && avatarUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(avatarUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Icon(
                  trip.status == TripStatus.inProgress
                      ? Icons.navigation_rounded
                      : Icons.person_pin_circle_rounded,
                  color: _getStatusColor(trip.status),
                  size: 28,
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                passengerAsync.value?.fullName ?? 'Pasajero',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.5,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(Trip trip) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isUpdatingStatus ? null : () => _handleNextStep(trip),
        style: ElevatedButton.styleFrom(
          backgroundColor: _getStatusColor(trip.status),
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _isUpdatingStatus
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _getButtonText(trip.status, trip),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  Future<void> _openNavigationWithLocation(LatLng loc, String address) async {
    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=${loc.latitude},${loc.longitude}';
    final appleMapsUrl =
        'http://maps.apple.com/?daddr=${loc.latitude},${loc.longitude}';

    try {
      if (await canLaunchUrlString(googleMapsUrl)) {
        await launchUrlString(
          googleMapsUrl,
          mode: LaunchMode.externalApplication,
        );
      } else if (await canLaunchUrlString(appleMapsUrl)) {
        await launchUrlString(
          appleMapsUrl,
          mode: LaunchMode.externalApplication,
        );
      } else {
        await launchUrlString(googleMapsUrl, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      AppLogger.log('Error opening navigation: $e');
    }
  }

  Widget _buildSecondaryActions(Trip trip, AsyncValue<dynamic> passengerAsync) {
    return Row(
      children: [
        Expanded(
          child: _buildSecondaryAction(
            icon: Icons.chat_bubble_rounded,
            label: 'CHAT',
            color: Colors.black87,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TripChatScreen(
                    tripId: widget.tripId,
                    otherUserId: trip.passengerId,
                    otherUserName: passengerAsync.value?.fullName ?? 'Pasajero',
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSecondaryAction(
            icon: Icons.call_rounded,
            label: 'LLAMAR',
            color: Colors.green[700]!,
            onTap: () => _makePhoneCall(passengerAsync.value?.phoneNumber),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNextStep(Trip trip) async {
    if (trip.status == TripStatus.accepted) {
      _updateStatus(TripStatus.arrived);
    } else if (trip.status == TripStatus.arrived) {
      _updateStatus(TripStatus.inProgress);
    } else if (trip.status == TripStatus.inProgress) {
      // Verificar si hay paradas intermedias pendientes
      final pendingStopIndex =
          trip.intermediateStops.indexWhere((s) => !s.isCompleted);

      if (pendingStopIndex != -1) {
        // Completar parada intermedia
        await ref
            .read(tripControllerProvider.notifier)
            .completeStop(widget.tripId, pendingStopIndex);
      } else {
        _showCompletionConfirmationDialog(trip);
      }
    }
  }

  Future<void> _showCompletionConfirmationDialog(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text(
              'Finalizar Viaje',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Advertencia!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No debes cobrar si aún no has terminado el viaje por completo.',
              style: TextStyle(color: Colors.black87),
            ),
            SizedBox(height: 12),
            Text(
              '¿Estás seguro de que ya llegaste al Punto B y deseas procesar el cobro ahora?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'AÚN NO',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('SÍ, FINALIZAR'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _updateStatus(TripStatus.completed);
    }
  }

  String _getButtonText(TripStatus status, Trip trip) {
    switch (status) {
      case TripStatus.accepted:
        return 'HE LLEGADO';
      case TripStatus.arrived:
        return 'INICIAR VIAJE';
      case TripStatus.inProgress:
        final pendingStopIndex =
            trip.intermediateStops.indexWhere((s) => !s.isCompleted);
        if (pendingStopIndex != -1) {
          return 'LLEGUÉ A PARADA ${pendingStopIndex + 1}';
        }
        return 'TERMINAR VIAJE';
      default:
        return 'CONTINUAR';
    }
  }

  String _getTopBarAddressText(Trip trip) {
    if (trip.status == TripStatus.inProgress) {
      final pendingStopIndex =
          trip.intermediateStops.indexWhere((s) => !s.isCompleted);
      if (pendingStopIndex != -1) {
        return 'Parada ${pendingStopIndex + 1}: ${trip.intermediateStops[pendingStopIndex].address}';
      }
      return 'Destino: ${trip.dropoffAddress}';
    }
    return 'Recogida: ${trip.pickupAddress}';
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.accepted:
        return Colors.blueAccent;
      case TripStatus.arrived:
        return Colors.green;
      case TripStatus.inProgress:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showCancellationDialog(Trip trip) async {
    // Proximity warning logic
    if (_currentDriverLocation != null) {
      LatLng currentTarget = trip.pickupLocation;
      String targetName = "el punto de recogida";

      if (trip.status == TripStatus.inProgress) {
        final pendingStopIndex = trip.intermediateStops.indexWhere((s) => !s.isCompleted);
        if (pendingStopIndex != -1) {
          currentTarget = trip.intermediateStops[pendingStopIndex].location;
          targetName = "la Parada ${pendingStopIndex + 1}";
        } else {
          currentTarget = trip.dropoffLocation;
          targetName = "el destino final";
        }
      }

      final distance = Geolocator.distanceBetween(
        _currentDriverLocation!.latitude,
        _currentDriverLocation!.longitude,
        currentTarget.latitude,
        currentTarget.longitude,
      );

      if (distance > 500) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Text('¡Advertencia!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No te encuentras cerca de $targetName (${(distance/1000).toStringAsFixed(1)} km de distancia).',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Si cancelas ahora:\n• El pago será devuelto íntegramente al pasajero.\n• Tu cuenta puede ser sancionada.\n• El sistema marcará esta cancelación como inapropiada.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('VOLVER AL VIAJE'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50]),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('CONTINUAR CANCELACIÓN', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    final TextEditingController reasonController = TextEditingController();
    final List<String> commonReasons = [
      'No aparece el pasajero',
      'El pasajero no tiene efectivo',
      'Mucha distancia para llegar',
      'Emergencia personal',
      'Otro',
    ];
    String? selectedReason;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cancelar viaje'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Por qué deseas cancelar este viaje?'),
              const SizedBox(height: 16),
              ...commonReasons.map(
                (r) => RadioListTile<String>(
                  title: Text(r),
                  value: r,
                  groupValue: selectedReason,
                  onChanged: (val) =>
                      setDialogState(() => selectedReason = val),
                ),
              ),
              if (selectedReason == 'Otro')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe el motivo...',
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('VOLVER'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(
                context,
                selectedReason == 'Otro'
                    ? reasonController.text
                    : selectedReason,
              ),
              child: const Text(
                'CANCELAR',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (reason != null && mounted) {
      try {
        await ref
            .read(tripControllerProvider.notifier)
            .updateStatus(
              widget.tripId,
              TripStatus.cancelled,
              cancellationReason: reason,
            );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al cancelar: $e')));
        }
      }
    }
  }

  double _calculateDriverRotation(Trip trip) {
    if (_lastDirections == null || _currentDriverLocation == null) {
      return _currentDriverHeading;
    }

    final points = _lastDirections!['polyline'] as List<LatLng>?;
    if (points == null || points.length < 2) return _currentDriverHeading;

    // Find the segment the driver is currently on or closest to
    int closestIndex = 0;
    double minDistance = double.maxFinite;

    for (int i = 0; i < points.length; i++) {
      final dist = Geolocator.distanceBetween(
        _currentDriverLocation!.latitude,
        _currentDriverLocation!.longitude,
        points[i].latitude,
        points[i].longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    // Use bearing to the next point on the polyline
    if (closestIndex < points.length - 1) {
      return Geolocator.bearingBetween(
        points[closestIndex].latitude,
        points[closestIndex].longitude,
        points[closestIndex + 1].latitude,
        points[closestIndex + 1].longitude,
      );
    }

    return _currentDriverHeading;
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w500,
            color: Colors.black38,
          ),
        ),
      ],
    );
  }
}
