import 'package:tincars/core/utils/app_logger.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:tincars/core/utils/emoji_marker_generator.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/driver/presentation/screens/driver_chat_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trip_completion_screen.dart';
import 'package:tincars/core/utils/marker_utils.dart';
import 'package:tincars/features/trips/presentation/controllers/chat_controller.dart';
import 'package:tincars/core/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:tincars/core/services/maps_service.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';
import 'package:tincars/features/trips/domain/services/pricing_service.dart';
import 'package:tincars/core/services/realtime_location_service.dart';

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

  // Custom Map Style (Google Maps Silver/Clean Navigation)
  static const String _silverMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#f5f5f5"}]
  },
  {
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#616161"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#f5f5f5"}]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#bdbdbd"}]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [{"color": "#eeeeee"}]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#757575"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [{"color": "#e5e5e5"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#ffffff"}]
  },
  {
    "featureType": "road.arterial",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#757575"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#dadada"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#616161"}]
  },
  {
    "featureType": "road.local",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#9e9e9e"}]
  },
  {
    "featureType": "transit.line",
    "elementType": "geometry",
    "stylers": [{"color": "#e5e5e5"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#c9c9c9"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#9e9e9e"}]
  }
]
''';
  bool _isUpdatingStatus = false;
  bool _isRedirectingToCompletion = false;
  LatLng? _currentDriverLocation;
  double _currentDriverHeading = 0.0;
  StreamSubscription<Position>? _positionSubscription;
  bool _isAutoCenterEnabled = true;
  double _currentZoom = 18.5;
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
  BitmapDescriptor? _personMarker;
  
  Timer? _waitTimer;
  int _waitSecondsRemaining = 60;
  double _waitFeeAccumulated = 0.0;
  int _extraWaitSeconds = 0;

  // Reuse a single MapsService instance to avoid creating new HTTP clients
  final MapsService _mapsService = MapsService();

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

    // Defer icon loading until we have trip data if possible,
    // or just load defaults and let the stream update them.
    _loadMapIcons();
    _startLocationSharing();

    // Initialize location from current trip data if available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final trip = ref.read(tripStreamProvider(widget.tripId)).asData?.value;
      if (trip != null) {
        if (trip.driverLocation != null) {
          setState(() {
            _currentDriverLocation = trip.driverLocation;
            _currentDriverHeading = (trip.driverHeading ?? 0.0).toDouble();
          });
        } else {
          // Optimization: Try last known position first for instant result
          final lastPos = await Geolocator.getLastKnownPosition();
          if (lastPos != null && mounted) {
            setState(() {
              _currentDriverLocation = LatLng(
                lastPos.latitude,
                lastPos.longitude,
              );
            });
          }

          // Then try to get fresh position if lastPos is null or stale
          try {
            final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
              ),
            );
            if (mounted) {
              setState(() {
                _currentDriverLocation = LatLng(pos.latitude, pos.longitude);
              });
            }
          } catch (_) {}
        }
        _fetchDirections(trip);
      }
    });
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    _positionSubscription?.cancel();
    _pulseController.dispose();
    mapController?.dispose();
    mapController = null;
    super.dispose();
  }

  void _startWaitTimer(String? vehicleType) {
    _waitTimer?.cancel();
    _waitFeeAccumulated = 0.0;
    _extraWaitSeconds = 0;
    _waitSecondsRemaining = ref.read(pricingServiceProvider).getFreeWaitMinutes(vehicleType ?? 'essentials') * 60;

    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_waitSecondsRemaining > 0) {
        setState(() => _waitSecondsRemaining--);
      } else {
        setState(() {
          _extraWaitSeconds++;
          final pricing = ref.read(pricingServiceProvider);
          final freeSecs = pricing.getFreeWaitMinutes(vehicleType ?? 'essentials') * 60;
          _waitFeeAccumulated = pricing.calculateWaitFee(
            vehicleType ?? 'essentials',
            freeSecs + _extraWaitSeconds,
          );
        });
      }
    });
  }

  Future<void> _loadMapIcons([
    List<TripStop> intermediateStops = const [],
  ]) async {
    // Load the driver arrow first so it appears instantly
    MarkerUtils.createDriverArrowMarker()
        .then((icon) {
          if (mounted) {
            setState(() => _driverArrowIcon = icon);
          }
        })
        .catchError((_) {});

    MarkerUtils.createPersonMarker()
        .then((icon) {
          if (mounted) {
            setState(() => _personMarker = icon);
          }
        })
        .catchError((_) {});

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
        _stopIcons.clear();
        for (int i = 0; i < intermediateStops.length; i++) {
          _stopIcons[i] = results[2 + i];
        }
      });
    }
  }

  void _startLocationSharing() async {
    // Verificar permisos
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      AppLogger.log(
        'DriverTripManagementScreen: Permiso de ubicación no disponible.',
      );
      return;
    }

    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText:
              "TinCars está rastreando tu ubicación durante el viaje.",
          notificationTitle: "Viaje en Progreso",
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      );
    }

    _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            final loc = LatLng(position.latitude, position.longitude);
            final heading = position.heading;

            // Solo actualizar Firestore si nos hemos movido más de 10 metros
            final lastLoc = _currentDriverLocation;
            double distanceMoved = 0;
            if (lastLoc != null) {
              distanceMoved = Geolocator.distanceBetween(
                lastLoc.latitude,
                lastLoc.longitude,
                position.latitude,
                position.longitude,
              );
            }

            if (lastLoc == null || distanceMoved > 10) {
              // Write to Firestore (for persistence/queries)
              ref
                  .read(tripControllerProvider.notifier)
                  .updateLocation(
                    widget.tripId,
                    position.latitude,
                    position.longitude,
                    heading: heading,
                  );
              // Write to RTDB (cheaper real-time updates)
              RealtimeLocationService.instance.updateTripDriverLocation(
                widget.tripId,
                position.latitude,
                position.longitude,
                heading: heading,
              );
            }

            if (mounted) {
              final bool isUpdatingForFirstTime =
                  _currentDriverLocation == null;

              // SNAP TO ROAD LOGIC
              LatLng snappedLoc = loc;
              if (_lastDirections != null) {
                final polyline = _lastDirections!['polyline'] as List<LatLng>?;
                if (polyline != null && polyline.isNotEmpty) {
                  snappedLoc = _mapsService.findNearestPointOnPolyline(
                    loc,
                    polyline,
                  );
                }
              }

              setState(() {
                _currentDriverLocation = snappedLoc;
                if (isUpdatingForFirstTime) {
                  _lastDirectionsLoc = snappedLoc;
                }
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
                    30) {
                  _lastDirectionsLoc = loc;
                  _fetchDirections(currentTrip);
                }
              }

              if (_isAutoCenterEnabled) {
                _updateCamera(loc, heading);
              }
            }
          },
          onError: (error) {
            AppLogger.error('Error en el stream de ubicación (viaje): $error');
          },
        );
  }

  void _updateCamera(LatLng location, double heading) {
    // Throttling camera updates to 500ms for smooth navigation while preserving battery
    final now = DateTime.now();
    if (_lastCameraUpdate != null &&
        now.difference(_lastCameraUpdate!) <
            const Duration(milliseconds: 500)) {
      return;
    }
    _lastCameraUpdate = now;

    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: _currentZoom,
          tilt: 60.0,
          bearing: heading,
        ),
      ),
    );
  }

  Future<void> _updateStatus(TripStatus newStatus) async {
    setState(() => _isUpdatingStatus = true);
    try {
      final trip = ref.read(tripStreamProvider(widget.tripId)).asData?.value;
      
      // Si el conductor inicia el viaje y hubo tiempo de espera extra
      if (newStatus == TripStatus.inProgress && 
          trip?.status == TripStatus.arrived && 
          _waitFeeAccumulated > 0) {
        final newPrice = trip!.price + _waitFeeAccumulated;
        await ref.read(tripControllerProvider.notifier).updatePrice(
          widget.tripId, 
          newPrice,
          waitFee: _waitFeeAccumulated,
        );
      }

      await ref
          .read(tripControllerProvider.notifier)
          .updateStatus(widget.tripId, newStatus);
          
      if (newStatus == TripStatus.inProgress) {
        _waitTimer?.cancel();
        _waitTimer = null;
      }
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

  void _handleSOS() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'SOS / EMERGENCIA',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Deseas contactar a los servicios de emergencia?'),
            SizedBox(height: 12),
            Text(
              'Esta acción iniciará una llamada directa al número de emergencias local (911) para garantizar tu seguridad.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final url = 'tel:911';
              if (await canLaunchUrlString(url)) {
                await launchUrlString(url);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('LLAMAR 911'),
          ),
        ],
      ),
    );
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
    LatLng? start = _currentDriverLocation ?? trip.driverLocation;

    if (start == null) {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        start = LatLng(lastPos.latitude, lastPos.longitude);
        // ACTUALIZACIÓN CRÍTICA: Guardar en el estado para que el marcador sea visible
        if (mounted && _currentDriverLocation == null) {
          setState(() => _currentDriverLocation = start);
        }
      }
    }

    if (start == null) {
      return;
    }

    LatLng end = trip.dropoffLocation;
    if (isToDestination) {
      // Si hay paradas intermedias pendientes, navegamos a la primera disponible
      final pendingStopIndex = trip.intermediateStops.indexWhere(
        (s) => !s.isCompleted,
      );
      if (pendingStopIndex != -1) {
        end = trip.intermediateStops[pendingStopIndex].location;
      }
    } else {
      end = trip.pickupLocation;
    }

    // Evitar llamadas innecesarias si el inicio y fin son iguales (p.ej. ya en el punto)
    // Evitar llamadas innecesarias si el inicio y fin son iguales (p.ej. ya en el punto)
    if (start.latitude == end.latitude && start.longitude == end.longitude) {
      if (mounted) {
        setState(() => _lastDirections = null);
      }
      return;
    }

    try {
      final directions = await _mapsService.getDirections(start, end);
      if (mounted) {
        setState(() {
          _lastDirections = directions;
          // Ya no actualizamos distancia/tiempo aquí para evitar demoras
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
    // Listen for new chat messages
    ref.listen(tripMessagesProvider(widget.tripId), (previous, next) {
      final prevMessages = previous?.value ?? [];
      final nextMessages = next.value ?? [];

      if (nextMessages.isNotEmpty &&
          nextMessages.length > prevMessages.length) {
        final lastMessage = nextMessages.last;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        // Only notify if the message is from the OTHER user
        if (lastMessage.senderId != currentUserId) {
          NotificationService.instance.showChatMessageNotification(
            senderName: 'Pasajero',
            messageText: lastMessage.text,
            tripId: widget.tripId,
          );
        }
      }
    });

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
      if (prevTrip?.status != trip.status ||
          prevTrip?.intermediateStops.length != trip.intermediateStops.length) {
        // Force immediate UI update to Point B if starting trip
        if (trip.status == TripStatus.inProgress &&
            prevTrip?.status != TripStatus.inProgress) {
          setState(() {
            _lastDirections = null; // Clear old pickup route
            _isUpdatingStatus = false;
          });
        }

        _loadMapIcons(trip.intermediateStops);
        _fetchDirections(trip);
      }

      // Timer de espera para el conductor
      if (trip.status == TripStatus.arrived && _waitTimer == null) {
        _startWaitTimer(trip.vehicleType);
      } else if (trip.status != TripStatus.arrived && _waitTimer != null) {
        _waitTimer?.cancel();
        _waitTimer = null;
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

    // Route Path (Main Guidance) - Double layered for premium effect
    if (_lastDirections != null) {
      final points = _lastDirections!['polyline'] as List<LatLng>?;
      if (points != null && points.isNotEmpty) {
        final isToDestination = trip.status == TripStatus.inProgress;
        final mainColor = isToDestination
            ? Colors
                  .green
                  .shade700 // Deep green for destination
            : Colors.blue.shade700; // Deep blue for pickup

        // Outer Glow / Border Polyline for premium depth
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route_glow'),
            points: points,
            color: mainColor.withOpacity(0.2),
            width: 16,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );

        // Background Shadow Polyline
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route_border'),
            points: points,
            color: Colors.black87.withOpacity(0.1),
            width: 12,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );

        // Main Core Polyline (Google Maps Style)
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route_polyline_driver'),
            points: points,
            color: mainColor,
            width: 7,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
            zIndex: 1,
          ),
        );
      }
    } else if (_currentDriverLocation != null) {
      // Fallback: Siempre mostrar una línea hacia el objetivo si no hay direcciones
      LatLng target = (trip.status == TripStatus.inProgress)
          ? trip.dropoffLocation
          : trip.pickupLocation;

      polylines.add(
        Polyline(
          polylineId: const PolylineId('fallback_guide_line'),
          points: [_currentDriverLocation!, target],
          color: (trip.status == TripStatus.inProgress)
              ? Colors.green
              : Colors.blue,
          width: 6,
          patterns: [], // Always solid
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

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
      // 1. Designated Pickup Point (Always at requested location)
      if (trip.status != TripStatus.inProgress)
        Marker(
          markerId: const MarkerId('pickup_point_a'),
          position: trip.pickupLocation,
          icon: _pickupIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(title: 'Punto de Recogida'),
        ),

      // 3. Destination Marker ('B', 'C'...)
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
          icon:
              _stopIcons[index] ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          anchor: const Offset(0.5, 0.5),
          alpha: stop.isCompleted ? 0.4 : 1.0,
          infoWindow: InfoWindow(title: 'Parada ${index + 1}'),
        );
      }),
      // 4. Driver Arrow/Car (Solo si tenemos ubicación real)
      if (_currentDriverLocation != null || trip.driverLocation != null)
        Marker(
          markerId: const MarkerId('driver_arrow'),
          position: _currentDriverLocation ?? trip.driverLocation!,
          icon: _driverArrowIcon ?? BitmapDescriptor.defaultMarker,
          rotation: _calculateDriverRotation(trip),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndex: 20, // Top-most priority
        ),

      // 5. Passenger Live Marker (If available and trip not started yet)
      if (trip.status != TripStatus.inProgress &&
          trip.passengerLocation != null)
        Marker(
          markerId: const MarkerId('passenger_live_marker'),
          position: trip.passengerLocation!,
          icon:
              _passengerAvatarMarker ??
              (_customEmojiMarker ??
                  (_personMarker ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ))),
          anchor: const Offset(0.5, 0.5),
          zIndex: 15,
          infoWindow: const InfoWindow(title: 'Pasajero'),
        ),
    };

    return Stack(
      children: [
        GoogleMap(
          key: ValueKey('driver_map_${widget.tripId}_${trip.status.name}'),
          onMapCreated: (controller) {
            mapController = controller;
            controller.setMapStyle(_silverMapStyle);
            // Smaller delay for faster appearance
            Future.delayed(const Duration(milliseconds: 100), () {
              _fetchDirections(trip);
            });
          },
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.12,
            top: 200,
          ),
          initialCameraPosition: CameraPosition(
            target:
                _currentDriverLocation ??
                trip.driverLocation ??
                trip.pickupLocation,
            zoom: 18.0,
            tilt: 60, // Higher tilt for more perspective
          ),
          markers: markers,
          polylines: polylines,
          myLocationEnabled: false, // Quitar punto azul, usamos nuestra flecha
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          onCameraMove: (position) {
            _currentZoom = position.zoom;
          },
          mapToolbarEnabled: false,
          buildingsEnabled: false,
          trafficEnabled: false,
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          child: _buildTopStatusHUD(trip),
        ),
        Positioned(
          bottom: 360, // Above the GPS FAB
          right: 20,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'zoom_in',
                onPressed: () {
                  mapController?.animateCamera(CameraUpdate.zoomIn());
                },
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 8,
                shape: const CircleBorder(),
                child: const Icon(Icons.add_rounded),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.small(
                heroTag: 'zoom_out',
                onPressed: () {
                  mapController?.animateCamera(CameraUpdate.zoomOut());
                },
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 8,
                shape: const CircleBorder(),
                child: const Icon(Icons.remove_rounded),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 300, // Moved higher to avoid covering bottom panel
          right: 20,
          child: FloatingActionButton(
            heroTag: 'gps_fab',
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
            child: Icon(Icons.gps_fixed_rounded, size: 28),
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
    // Determine the current stage
    int currentStage = 1;
    int totalStages = 2 + (trip.intermediateStops.length);

    String stageLabel = "Recogida";
    if (trip.status == TripStatus.accepted ||
        trip.status == TripStatus.arrived) {
      currentStage = 1;
      stageLabel = "Recogida";
    } else if (trip.status == TripStatus.inProgress) {
      // Find which stop we are going to
      final nextStopIndex = trip.intermediateStops.indexWhere(
        (s) => !s.isCompleted,
      );
      if (nextStopIndex != -1) {
        currentStage = 2 + nextStopIndex;
        stageLabel = "Parada ${nextStopIndex + 1}";
      } else {
        currentStage = totalStages;
        stageLabel = "Destino";
      }
    }

    return PremiumGlassContainer(
      color: Colors.white,
      opacity: 0.95,
      blur: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: BorderRadius.circular(40),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "$currentStage/$totalStages",
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildTopStatusIndicator(trip),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stageLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.blueAccent.withOpacity(0.7),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  _getTopBarAddressText(trip),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_lastDirections != null &&
                    _lastDirections!['duration_text'] != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: Colors.blueAccent.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_lastDirections!['duration_text']} (${_lastDirections!['distance_text']})',
                        style: TextStyle(
                          color: Colors.blueAccent.shade700,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
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
      final pendingStopIndex = trip.intermediateStops.indexWhere(
        (s) => !s.isCompleted,
      );
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
          if (trip.status == TripStatus.arrived) ...[
            const SizedBox(height: 16),
            _buildWaitTimeInfo(),
          ],
          const SizedBox(height: 24),
          _buildActionButton(trip),
          const SizedBox(height: 16),
          _buildSecondaryActions(trip, passengerAsync),
        ],
      ),
    );
  }

  Widget _buildWaitTimeInfo() {
    final bool isExtraWait = _waitSecondsRemaining <= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExtraWait ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isExtraWait ? Colors.orange : Colors.green).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isExtraWait ? Icons.warning_amber_rounded : Icons.timer_outlined,
            color: isExtraWait ? Colors.orange.shade700 : Colors.green.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExtraWait ? 'ESPERA CON CARGO' : 'TIEMPO DE CORTESÍA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isExtraWait ? Colors.orange.shade800 : Colors.green.shade800,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  isExtraWait
                      ? 'Saldo acumulado: +\$${_waitFeeAccumulated.toStringAsFixed(2)} (${_formatElapsed(_extraWaitSeconds)})'
                      : 'Restan: ${_formatElapsed(_waitSecondsRemaining)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatElapsed(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'INICIAR NAVEGACIÓN GPS',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Selecciona tu aplicación favorita para conducir a $address',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.5),
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildNavigationAppRow(
                icon: Icons.map_rounded,
                iconColor: Colors.green.shade600,
                name: 'Google Maps',
                description: 'Navegación turn-by-turn con mapas de Google',
                onTap: () async {
                  Navigator.pop(context);
                  final url = 'https://www.google.com/maps/dir/?api=1&destination=${loc.latitude},${loc.longitude}&travelmode=driving';
                  await _launchMapUrl(url);
                },
              ),
              const SizedBox(height: 12),
              _buildNavigationAppRow(
                icon: Icons.directions_car_rounded,
                iconColor: Colors.blue.shade600,
                name: 'Waze',
                description: 'Alertas de tráfico, policía y radares en tiempo real',
                onTap: () async {
                  Navigator.pop(context);
                  final url = 'https://waze.com/ul?ll=${loc.latitude},${loc.longitude}&navigate=yes';
                  await _launchMapUrl(url);
                },
              ),
              if (isIOS) ...[
                const SizedBox(height: 12),
                _buildNavigationAppRow(
                  icon: Icons.apple_rounded,
                  iconColor: Colors.grey.shade900,
                  name: 'Apple Maps',
                  description: 'Mapas oficiales de Apple optimizados para iOS',
                  onTap: () async {
                    Navigator.pop(context);
                    final url = 'http://maps.apple.com/?daddr=${loc.latitude},${loc.longitude}&dirflg=d';
                    await _launchMapUrl(url);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchMapUrl(String url) async {
    try {
      if (await canLaunchUrlString(url)) {
        await launchUrlString(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        await launchUrlString(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      AppLogger.log('Error launching navigation app: $e');
    }
  }

  Widget _buildNavigationAppRow({
    required IconData icon,
    required Color iconColor,
    required String name,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.04)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.black.withOpacity(0.25),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
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
                  builder: (context) => DriverChatScreen(
                    tripId: widget.tripId,
                    passengerId: trip.passengerId,
                    passengerName: passengerAsync.value?.fullName ?? 'Pasajero',
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSecondaryAction(
            icon: Icons.call_rounded,
            label: 'LLAMAR',
            color: Colors.green[700]!,
            onTap: () => _makePhoneCall(passengerAsync.value?.phoneNumber),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSecondaryAction(
            icon: Icons.security_rounded,
            label: 'SOS',
            color: Colors.red[700]!,
            onTap: () => _handleSOS(),
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
      final pendingStopIndex = trip.intermediateStops.indexWhere(
        (s) => !s.isCompleted,
      );

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
        final pendingStopIndex = trip.intermediateStops.indexWhere(
          (s) => !s.isCompleted,
        );
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
      final pendingStopIndex = trip.intermediateStops.indexWhere(
        (s) => !s.isCompleted,
      );
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
      case TripStatus.cancelled:
        return Colors.red;
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
        final pendingStopIndex = trip.intermediateStops.indexWhere(
          (s) => !s.isCompleted,
        );
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
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
                SizedBox(width: 8),
                Text('¡Advertencia!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No te encuentras cerca de $targetName (${(distance / 1000).toStringAsFixed(1)} km de distancia).',
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'CONTINUAR CANCELACIÓN',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
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

    if (!mounted) return;

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
}
