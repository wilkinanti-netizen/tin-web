import 'package:share_plus/share_plus.dart';
import 'package:tincars/core/utils/app_logger.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/passenger/presentation/screens/passenger_chat_screen.dart';
import 'package:tincars/features/trips/presentation/controllers/chat_controller.dart';
import 'package:tincars/core/services/notification_service.dart';
import 'package:tincars/features/trips/presentation/screens/trip_completion_screen.dart';
import 'package:tincars/features/passenger/presentation/screens/trip_cancellation_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:tincars/l10n/app_localizations.dart';
import 'package:tincars/core/utils/marker_utils.dart';
import 'package:tincars/core/services/maps_service.dart';
import 'package:tincars/features/trips/domain/services/pricing_service.dart';
import 'package:intl/intl.dart';

class TripTrackingScreen extends ConsumerStatefulWidget {
  final String tripId;
  const TripTrackingScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends ConsumerState<TripTrackingScreen>
    with TickerProviderStateMixin {
  GoogleMapController? mapController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _tripTimer;
  Timer? _locationTimer;
  Timer? _waitTimer;
  int _elapsedSeconds = 0;
  int _waitSecondsRemaining = 60;
  double _waitFeeAccumulated = 0.0;
  int _extraWaitSeconds = 0;
  TripStatus? _lastStatus;
  bool _isAutoCenterEnabled = true;

  static const String _premiumGoogleMapStyle = '''
[
  {
    "featureType": "administrative",
    "elementType": "geometry.fill",
    "stylers": [{"visibility": "on"}]
  },
  {
    "featureType": "poi",
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.business",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.medical",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.school",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [{"color": "#c8e6c9"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#388e3c"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#ffe082"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#ffd54f"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.icon",
    "stylers": [{"visibility": "on"}]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry",
    "stylers": [{"color": "#ffffff"}]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#dcdcdc"}]
  },
  {
    "featureType": "road.local",
    "elementType": "geometry",
    "stylers": [{"color": "#ffffff"}]
  },
  {
    "featureType": "road.local",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#e0e0e0"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#90caf9"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#1565c0"}]
  }
]
''';

  // Cache para evitar flickering
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  BitmapDescriptor? _vehicleIcon;
  final Map<int, BitmapDescriptor> _stopIcons = {};
  String? _lastEmoji;
  String? _lastVehicleType;

  // Smooth Movement Variables
  AnimationController? _movementController;
  LatLng? _oldDriverLoc;
  LatLng? _targetDriverLoc;
  double? _oldHeading;
  double? _targetHeading;
  LatLng? _smoothDriverLoc;
  double _smoothHeading = 0;
  bool _isRedirectingToCompletion = false;
  Map<String, dynamic>? _lastDirections;
  LatLng? _lastStart;
  LatLng? _lastEnd;
  Map<String, dynamic>? _driverDirections;
  LatLng? _lastDriverDirectionsLoc;
  final MapsService _mapsService = MapsService();

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
    _startTripTimer();
    _loadMapIcons();

    _movementController =
        AnimationController(
          vsync: this,
          duration: const Duration(
            milliseconds: 2000,
          ), // Standard update interval
        )..addListener(() {
          if (_oldDriverLoc != null && _targetDriverLoc != null) {
            final lat =
                _oldDriverLoc!.latitude +
                (_targetDriverLoc!.latitude - _oldDriverLoc!.latitude) *
                    _movementController!.value;
            final lng =
                _oldDriverLoc!.longitude +
                (_targetDriverLoc!.longitude - _oldDriverLoc!.longitude) *
                    _movementController!.value;

            double diff = _targetHeading! - _oldHeading!;
            while (diff < -180) {
              diff += 360;
            }
            while (diff > 180) {
              diff -= 360;
            }
            final heading = _oldHeading! + diff * _movementController!.value;

            setState(() {
              _smoothDriverLoc = LatLng(lat, lng);
              _smoothHeading = heading;
            });
          }
        });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final trip = ref.read(tripStreamProvider(widget.tripId)).asData?.value;
      if (trip != null) {
        _updateDirections(trip);
      }
    });
  }

  void _updateDirections(Trip trip) async {
    final start = trip.pickupLocation;
    final end = trip.dropoffLocation;
    final driverLoc = trip.driverLocation ?? trip.pickupLocation;
    final isToDropoff = trip.status == TripStatus.inProgress;

    // Main Route (Pickup to Dropoff)
    if (_lastStart != start || _lastEnd != end || _lastDirections == null) {
      _lastStart = start;
      _lastEnd = end;
      try {
        final directions = await MapsService().getDirections(
          start,
          end,
          waypoints: trip.intermediateStops.map((s) => s.location).toList(),
        );
        if (mounted) setState(() => _lastDirections = directions);
      } catch (e) {
        AppLogger.log('Error updating main directions: $e');
      }
    }

    // Live Driver Route
    if (_lastDriverDirectionsLoc == null ||
        Geolocator.distanceBetween(
              _lastDriverDirectionsLoc!.latitude,
              _lastDriverDirectionsLoc!.longitude,
              driverLoc.latitude,
              driverLoc.longitude,
            ) >
            30) {
      _lastDriverDirectionsLoc = driverLoc;
      final target = isToDropoff ? trip.dropoffLocation : trip.pickupLocation;
      try {
        final directions = await MapsService().getDirections(driverLoc, target);
        if (mounted) setState(() => _driverDirections = directions);
      } catch (e) {
        AppLogger.log('Error updating driver live directions: $e');
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tripTimer?.cancel();
    _locationTimer?.cancel();
    _waitTimer?.cancel();
    _movementController?.dispose();
    super.dispose();
  }

  Future<void> _loadMapIcons({
    List<TripStop> intermediateStops = const [],
    String? vehicleType,
  }) async {
    final List<Future<BitmapDescriptor>> futures = [
      MarkerUtils.createABMarker(
        letter: 'A',
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        label: 'Recogida',
      ),
      MarkerUtils.createABMarker(
        letter: String.fromCharCode(66 + intermediateStops.length),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        label: 'Destino',
      ),
      MarkerUtils.createVehicleMarker(vehicleType: vehicleType),
    ];

    // Add intermediate markers futures
    for (int i = 0; i < intermediateStops.length; i++) {
      futures.add(
        MarkerUtils.createABMarker(
          letter: String.fromCharCode(66 + i),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          label: 'Parada ${i + 1}',
        ),
      );
    }

    final results = await Future.wait(futures);

    if (mounted) {
      setState(() {
        _pickupIcon = results[0];
        _dropoffIcon = results[1];
        _vehicleIcon = results[2];
        _stopIcons.clear();
        for (int i = 0; i < intermediateStops.length; i++) {
          _stopIcons[i] = results[3 + i];
        }
      });
    }
  }

  void _startTripTimer() {
    _tripTimer?.cancel();
    _elapsedSeconds = 0;
    _tripTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      _timeNotifier.value = _elapsedSeconds;
    });
  }

  final ValueNotifier<int> _timeNotifier = ValueNotifier<int>(0);

  void _startWaitTimer(String? vehicleType) {
    _waitTimer?.cancel();
    _waitFeeAccumulated = 0.0;
    _extraWaitSeconds = 0;

    // Usamos el valor del service que ahora es 1 min por defecto
    _waitSecondsRemaining =
        ref
            .read(pricingServiceProvider)
            .getFreeWaitMinutes(vehicleType ?? 'essentials') *
        60;

    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_waitSecondsRemaining > 0) {
        setState(() => _waitSecondsRemaining--);
      } else {
        // Tiempo de espera extra con cargo
        setState(() {
          _extraWaitSeconds++;
          final pricing = ref.read(pricingServiceProvider);
          final freeSecs =
              pricing.getFreeWaitMinutes(vehicleType ?? 'essentials') * 60;
          _waitFeeAccumulated = pricing.calculateWaitFee(
            vehicleType ?? 'essentials',
            freeSecs + _extraWaitSeconds,
          );
        });
      }
    });
  }

  String _formatElapsed(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _startPassengerLocationSharing() {
    if (_locationTimer != null && _locationTimer!.isActive) return;

    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium, // Reduce battery usage for passenger
            timeLimit: Duration(seconds: 5),
          ),
        );
        ref
            .read(tripControllerProvider.notifier)
            .updatePassengerLocation(
              widget.tripId,
              position.latitude,
              position.longitude,
            );
      } catch (e) {
        AppLogger.log('Error sharing passenger location: $e');
      }
    });
  }

  void _stopPassengerLocationSharing() {
    _locationTimer?.cancel();
  }

  Future<void> _loadPassengerEmojiMarker(String emoji) async {
    if (mounted) {
      setState(() {
        _lastEmoji = emoji;
      });
    }
  }

  void _moveCameraToDriver(LatLng driverLoc) {
    // Obtener el punto de referencia: pickup si el conductor viene hacia el pasajero,
    // o dropoff si el viaje ya está en progreso
    final trip = ref.read(tripStreamProvider(widget.tripId)).value;
    if (trip == null) return;

    final LatLng targetPoint = trip.status == TripStatus.inProgress
        ? trip.dropoffLocation
        : trip.pickupLocation;

    // Calcular bounds que incluyan al conductor y al punto de referencia
    final bounds = LatLngBounds(
      southwest: LatLng(
        driverLoc.latitude < targetPoint.latitude
            ? driverLoc.latitude
            : targetPoint.latitude,
        driverLoc.longitude < targetPoint.longitude
            ? driverLoc.longitude
            : targetPoint.longitude,
      ),
      northeast: LatLng(
        driverLoc.latitude > targetPoint.latitude
            ? driverLoc.latitude
            : targetPoint.latitude,
        driverLoc.longitude > targetPoint.longitude
            ? driverLoc.longitude
            : targetPoint.longitude,
      ),
    );

    if (!mounted || mapController == null) return;
    mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        165,
      ), // Increased padding for a wider view during the trip
    );
  }

  void _handleSOS() async {
    final contacts = await ref
        .read(profileRepositoryProvider)
        .getEmergencyContacts(FirebaseAuth.instance.currentUser!.uid);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'SOS / EMERGENCIA',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Deseas contactar a los servicios de emergencia?'),
            if (contacts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'También notificaremos a tus ${contacts.length} contactos de confianza con tu ubicación en tiempo real.',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
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

              // 1. Call emergency services
              launchUrl(Uri.parse('tel:123'));

              // 2. Open SMS App with pre-filled message
              if (contacts.isNotEmpty) {
                final phoneNumbers = contacts.map((c) => c.phoneNumber).join(',');
                final message = '¡EMERGENCIA! Estoy en un viaje de TINS. Sigue mi ubicación en tiempo real aquí: https://tincars.app/track/${widget.tripId}';
                final smsUrl = 'sms:$phoneNumbers?body=${Uri.encodeComponent(message)}';
                
                try {
                  final uri = Uri.parse(smsUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    AppLogger.log('Could not launch SMS URL');
                  }
                } catch (e) {
                  AppLogger.log('Error launching SMS: $e');
                }
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Alertas de emergencia enviadas a tus contactos',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('ACTIVAR SOS'),
          ),
        ],
      ),
    );
  }

  void _handleShareTrip() {
    final shareUrl = 'https://tincars.app/track/${widget.tripId}';
    final text =
        '¡Hola! Sigue mi viaje en tiempo real con TINS aquí: $shareUrl';

    Share.share(text, subject: 'Seguimiento de mi viaje TINS');
  }

  void _handleShareWhatsApp() async {
    final shareUrl = 'https://tincars.app/track/${widget.tripId}';
    final text =
        '¡Hola! Sigue mi viaje en tiempo real con TINS aquí: $shareUrl';
    final whatsappUrl = "whatsapp://send?text=${Uri.encodeComponent(text)}";

    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
      await launchUrl(Uri.parse(whatsappUrl));
    } else {
      // Fallback to web whatsapp or just generic share if app not installed
      final webUrl = "https://wa.me/?text=${Uri.encodeComponent(text)}";
      if (await canLaunchUrl(Uri.parse(webUrl))) {
        await launchUrl(Uri.parse(webUrl));
      } else {
        Share.share(text);
      }
    }
  }

  Future<void> _handleModifyTrip(Trip trip) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _AddStopSheet(
        initialLocation: trip.pickupLocation,
        currentStopsCount: trip.intermediateStops.length,
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recalculando tarifa...'),
          duration: Duration(seconds: 2),
        ),
      );

      final LatLng newPointLoc = result['location'];
      final String newPointAddress = result['address'];
      final bool isNewDestination = result['isDestination'] ?? false;

      try {
        final driverLoc = trip.driverLocation ?? trip.pickupLocation;
        final originalDistance = trip.distance > 0 ? trip.distance : 0.1;

        // Only calculate distance traveled if the trip has actually started (passenger is in the car)
        double distanceTraveled = 0.0;
        if (trip.status == TripStatus.inProgress) {
          distanceTraveled =
              Geolocator.distanceBetween(
                trip.pickupLocation.latitude,
                trip.pickupLocation.longitude,
                driverLoc.latitude,
                driverLoc.longitude,
              ) /
              1000.0;
        }

        double newSegmentDistance;
        double newDistance;
        LatLng newDropoff;
        String newDropoffAddress;
        List<TripStop> newStops = List.from(trip.intermediateStops);

        if (isNewDestination) {
          final LatLng startRoutePoint = trip.status == TripStatus.inProgress
              ? driverLoc
              : trip.pickupLocation;

          final directions = await MapsService().getDirections(
            startRoutePoint,
            newPointLoc,
          );
          newSegmentDistance = directions['distance'];
          newDistance = distanceTraveled + newSegmentDistance;
          newDropoff = newPointLoc;
          newDropoffAddress = newPointAddress;
        } else {
          // Add stop before current destination
          final LatLng startRoutePoint = trip.status == TripStatus.inProgress
              ? driverLoc
              : trip.pickupLocation;

          final directionsToStop = await MapsService().getDirections(
            startRoutePoint,
            newPointLoc,
          );
          final directionsToFinal = await MapsService().getDirections(
            newPointLoc,
            trip.dropoffLocation,
          );
          newSegmentDistance =
              directionsToStop['distance'] + directionsToFinal['distance'];
          newDistance = distanceTraveled + newSegmentDistance;
          newDropoff = trip.dropoffLocation;
          newDropoffAddress = trip.dropoffAddress;
          newStops.add(
            TripStop(location: newPointLoc, address: newPointAddress),
          );
        }

        final double newTotalPrice = ref
            .read(pricingServiceProvider)
            .calculateModifiedTripPrice(
              originalPrice: trip.price,
              originalDistance: originalDistance,
              distanceTraveled: distanceTraveled,
              newSegmentDistance: newSegmentDistance,
              vehicleType: trip.vehicleType,
            );

        await ref
            .read(tripControllerProvider.notifier)
            .modifyTrip(
              tripId: trip.id,
              newStops: newStops,
              newPrice: newTotalPrice,
              newDistance: newDistance,
              newDropoff: newDropoff,
              newDropoffAddress: newDropoffAddress,
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Viaje modificado con éxito')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al modificar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _handleCallDriver(String? phoneNumber) async {
    final phone =
        phoneNumber ?? "123456789"; // Fallback to a default if not found
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo realizar la llamada')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            senderName: 'Conductor',
            messageText: lastMessage.text,
            tripId: widget.tripId,
          );
        }
      }
    });

    final tripAsync = ref.watch(tripStreamProvider(widget.tripId));

    ref.listen<AsyncValue<Trip>>(tripStreamProvider(widget.tripId), (
      prev,
      next,
    ) {
      final trip = next.asData?.value;
      if (trip != null) {
        final prevTrip = prev?.asData?.value;
        if (prevTrip != null) {}

        if (trip.status == TripStatus.completed &&
            !_isRedirectingToCompletion) {
          _isRedirectingToCompletion = true;
          AppLogger.log('[PASAJERO] Viaje completado. PostFrame para navegar.');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    TripCompletionScreen(trip: trip, isDriver: false),
              ),
            );
          });
        } else if (trip.status == TripStatus.cancelled &&
            !_isRedirectingToCompletion) {
          _isRedirectingToCompletion = true;
          AppLogger.log('[PASAJERO] Viaje cancelado. PostFrame para volver.');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            // Volver al home de forma segura
            Navigator.of(context).popUntil((route) => route.isFirst);
          });
        }

        // Update directions on status or location change
        if (prevTrip?.status != trip.status ||
            (prevTrip != null &&
                trip.driverLocation != null &&
                prevTrip.driverLocation != trip.driverLocation &&
                Geolocator.distanceBetween(
                      prevTrip.driverLocation!.latitude,
                      prevTrip.driverLocation!.longitude,
                      trip.driverLocation!.latitude,
                      trip.driverLocation!.longitude,
                    ) >
                    30) ||
            prevTrip?.intermediateStops.length !=
                trip.intermediateStops.length) {
          _updateDirections(trip);
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: tripAsync.when(
        skipLoadingOnRefresh: true, // Crucial for preventing flickers
        data: (trip) {
          // Check if icons need to be reloaded (if stops count or vehicle type changed)
          if (_stopIcons.length != trip.intermediateStops.length ||
              _lastVehicleType != trip.vehicleType) {
            _lastVehicleType = trip.vehicleType;
            _loadMapIcons(
              intermediateStops: trip.intermediateStops,
              // Removed vehicleType to use the generic 'old' car icon
            );
          }

          final driverLoc = trip.driverLocation;
          final driverAsync = trip.driverId != null
              ? ref.watch(otherUserProfileProvider(trip.driverId!))
              : const AsyncValue.data(null);
          final driverProfileAsync = trip.driverId != null
              ? ref.watch(otherDriverProfileProvider(trip.driverId!))
              : const AsyncValue.data(null);

          // Auto-follow conductor e Interpolación de movimiento
          if (driverLoc != null) {
            // SNAP TO ROAD LOGIC (Passenger side)
            LatLng processedLoc = driverLoc;
            final polyline = _driverDirections?['polyline'] as List<LatLng>?;
            if (polyline != null && polyline.isNotEmpty) {
              processedLoc = _mapsService.findNearestPointOnPolyline(
                driverLoc,
                polyline,
              );
            }

            // Inicializar ubicación suave si es nula (primera vez)
            if (_smoothDriverLoc == null) {
              _smoothDriverLoc = processedLoc;
              _smoothHeading = (trip.driverHeading ?? 0).toDouble();
              _targetDriverLoc = processedLoc;
              _targetHeading = _smoothHeading;
            }

            if (_targetDriverLoc != processedLoc) {
              _oldDriverLoc = _smoothDriverLoc ?? processedLoc;
              _targetDriverLoc = processedLoc;
              _oldHeading = _smoothHeading;
              _targetHeading = (trip.driverHeading ?? 0).toDouble();
              _movementController?.forward(from: 0);
            }

            if (trip.status == TripStatus.accepted ||
                trip.status == TripStatus.arrived ||
                trip.status == TripStatus.inProgress) {
              if (_isAutoCenterEnabled) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _moveCameraToDriver(_smoothDriverLoc ?? driverLoc);
                });
              }
            }
          }

          // Compartir ubicación del pasajero si el viaje está en curso, aceptado o el conductor ha llegado.
          if (trip.status == TripStatus.accepted ||
              trip.status == TripStatus.arrived ||
              trip.status == TripStatus.inProgress) {
            _startPassengerLocationSharing();
          } else {
            _stopPassengerLocationSharing();
          }

          // Iniciar timer cuando empieza el viaje o cuando llega el conductor
          if (trip.status == TripStatus.inProgress &&
              _lastStatus != TripStatus.inProgress) {
            _lastStatus = TripStatus.inProgress;
            _waitTimer?.cancel();

            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _startTripTimer(),
            );
          } else if (trip.status == TripStatus.arrived &&
              _lastStatus != TripStatus.arrived) {
            _lastStatus = TripStatus.arrived;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _startWaitTimer(trip.vehicleType),
            );
          } else if (trip.status != TripStatus.inProgress &&
              trip.status != TripStatus.arrived &&
              (_lastStatus == TripStatus.inProgress ||
                  _lastStatus == TripStatus.arrived)) {
            _lastStatus = trip.status;
            _tripTimer?.cancel();
            _waitTimer?.cancel();
          }

          return PopScope(
            canPop:
                trip.status == TripStatus.cancelled ||
                trip.status == TripStatus.completed,
            child: _buildMapContent(
              trip,
              driverAsync,
              driverProfileAsync,
              l10n,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _fitBounds(Map<String, dynamic> boundsData) {
    try {
      if (boundsData['southwest'] == null || boundsData['northeast'] == null)
        return;
      if (boundsData['southwest']['lat'] == null ||
          boundsData['southwest']['lng'] == null)
        return;
      if (boundsData['northeast']['lat'] == null ||
          boundsData['northeast']['lng'] == null)
        return;

      final bounds = LatLngBounds(
        southwest: LatLng(
          (boundsData['southwest']['lat'] as num).toDouble(),
          (boundsData['southwest']['lng'] as num).toDouble(),
        ),
        northeast: LatLng(
          (boundsData['northeast']['lat'] as num).toDouble(),
          (boundsData['northeast']['lng'] as num).toDouble(),
        ),
      );
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 80),
          );
        }
      });
    } catch (_) {}
  }

  Widget _buildMapContent(
    Trip trip,
    AsyncValue<dynamic> driverAsync,
    AsyncValue<dynamic> driverProfileAsync, // New
    AppLocalizations l10n,
  ) {
    final bool isToDropoff = trip.status == TripStatus.inProgress;
    final LatLng driverLoc = trip.driverLocation ?? trip.pickupLocation;
    final LatLng end = trip.dropoffLocation;

    // Cargar emoji marker si cambió o no existe
    if (trip.passengerEmoji != null &&
        trip.passengerEmoji!.isNotEmpty &&
        trip.passengerEmoji != _lastEmoji) {
      _loadPassengerEmojiMarker(trip.passengerEmoji!);
    }

    Set<Polyline> polylines = {};
    if (_lastDirections != null) {
      final points = _lastDirections!['polyline'] as List<LatLng>?;
      if (points != null) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route_polyline'),
            points: points,
            color: isToDropoff ? Colors.green : Colors.blue,
            width: 5,
            patterns: [], // Always solid
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      }
    }

    // Only show driver_live_route if NOT in progress and we want that extra line (usually confusing)
    // The user asked for "only blue and green", so we disable this extra dashed line.
    /*
    if (_driverDirections != null && trip.status != TripStatus.inProgress) {
      final points = _driverDirections!['polyline'] as List<LatLng>?;
      if (points != null) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('driver_live_route'),
            points: points,
            color: Colors.blueAccent.withOpacity(0.4),
            width: 4,
            patterns: [PatternItem.dash(15), PatternItem.gap(10)],
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );
      }
    }
    */

    final LatLng displayDriverLoc = _smoothDriverLoc ?? driverLoc;
    final double displayHeading = _smoothHeading;

    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('driver'),
        position: displayDriverLoc,
        icon: _vehicleIcon ?? BitmapDescriptor.defaultMarker,
        rotation: displayHeading,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      ),
      Marker(
        markerId: const MarkerId('pickup_point_a'),
        position: trip.pickupLocation,
        icon: _pickupIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: const InfoWindow(title: 'Punto de Recogida'),
      ),
      for (int i = 0; i < trip.intermediateStops.length; i++)
        Marker(
          markerId: MarkerId('stop_$i'),
          position: trip.intermediateStops[i].location,
          icon:
              _stopIcons[i] ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          alpha: trip.intermediateStops[i].isCompleted ? 0.5 : 1.0,
          infoWindow: InfoWindow(title: 'Parada ${i + 1}'),
        ),
      Marker(
        markerId: const MarkerId('dropoff'),
        position: end,
        icon: _dropoffIcon ?? BitmapDescriptor.defaultMarker,
      ),
    };

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          Listener(
            onPointerDown: (_) {
              if (_isAutoCenterEnabled) {
                setState(() {
                  _isAutoCenterEnabled = false;
                });
              }
            },
            child: GoogleMap(
              key: ValueKey('tracking_map_${widget.tripId}'),
              onMapCreated: (controller) {
                mapController = controller;
                controller.setMapStyle(_premiumGoogleMapStyle);
                if (_lastDirections != null)
                  _fitBounds(_lastDirections!['bounds']);
              },
              initialCameraPosition: CameraPosition(
                target: trip.pickupLocation,
                zoom: 15,
              ),
              markers: markers,
              polylines: polylines,
              zoomControlsEnabled: false,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              buildingsEnabled: true,
              trafficEnabled: true,
            ),
          ),
          // Reduced and more elegant floating status HUD
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 40,
            right: 40,
            child: Column(
              children: [
                _buildTopStatusHUD(trip, l10n, driverProfileAsync),
                if (trip.status == TripStatus.accepted &&
                    _driverDirections?['duration'] != null)
                  const SizedBox(height: 12),
              ],
            ),
          ),
          // GPS / Re-centrar FAB al estilo Uber
          if (!_isAutoCenterEnabled)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.38 + 16,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'passenger_gps_fab',
                onPressed: () {
                  setState(() => _isAutoCenterEnabled = true);
                  final targetLoc = _smoothDriverLoc ?? trip.driverLocation;
                  if (targetLoc != null) {
                    _moveCameraToDriver(targetLoc);
                  } else {
                    _moveCameraToDriver(trip.pickupLocation);
                  }
                },
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueAccent,
                elevation: 6,
                shape: const CircleBorder(),
                child: const Icon(Icons.gps_fixed_rounded, size: 24),
              ),
            ),
          // Premium Draggable Panel
          DraggableScrollableSheet(
            initialChildSize: 0.38,
            minChildSize: 0.38,
            maxChildSize: 0.88,
            snap: true,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 30,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: _buildBottomPanelContent(
                    trip,
                    driverAsync,
                    driverProfileAsync,
                    l10n,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatusHUD(
    Trip trip,
    AppLocalizations l10n,
    AsyncValue<dynamic> profileAsync,
  ) {
    try {
      if (trip.status == TripStatus.arrived) {
        final bool isExtraWait = _waitSecondsRemaining <= 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isExtraWait ? Colors.orange.shade700 : Colors.green.shade600,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: (isExtraWait ? Colors.orange : Colors.green).withOpacity(
                  0.35,
                ),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isExtraWait
                    ? Icons.warning_amber_rounded
                    : Icons.timer_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExtraWait
                        ? 'TIEMPO DE ESPERA AGOTADO'
                        : 'EL CONDUCTOR TE ESTÁ ESPERANDO',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    isExtraWait
                        ? 'CARGO EXTRA POR ESPERA: ${_formatElapsed(_extraWaitSeconds)} (+\$${_waitFeeAccumulated.toStringAsFixed(2)})'
                        : 'TIEMPO DE CORTESÍA: ${_formatElapsed(_waitSecondsRemaining)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }

      final driverEtaMinutes = _driverDirections?['duration'];

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatusIndicator(trip.status),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.status == TripStatus.inProgress
                        ? (() {
                            final pendingIndex = trip.intermediateStops
                                .indexWhere((s) => !s.isCompleted);
                            return pendingIndex != -1
                                ? 'VIAJANDO A PARADA ${pendingIndex + 1}'
                                : 'VIAJANDO AL DESTINO';
                          })()
                        : _getStatusText(
                            trip.status,
                            l10n,
                            vehicleModel: profileAsync.value?.vehicleModel,
                          ).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (trip.status == TripStatus.accepted &&
                      driverEtaMinutes != null)
                    Text(
                      'LLEGA EN ${driverEtaMinutes.round()} MIN (${_driverDirections?['distance_text'] ?? ""})'.toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  if (trip.status == TripStatus.inProgress &&
                      _driverDirections?['duration_text'] != null)
                    Text(
                      'LLEGA EN ${_driverDirections!['duration_text']} (${_driverDirections!['distance_text']})'.toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  if (trip.status == TripStatus.arrived)
                    Text(
                      'EL CONDUCTOR LLEGÓ'.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                ],
              ),
            ),
            if (trip.status == TripStatus.inProgress) ...[
              const SizedBox(width: 8),
              Container(width: 1, height: 12, color: Colors.black12),
              const SizedBox(width: 8),
              ValueListenableBuilder<int>(
                valueListenable: _timeNotifier,
                builder: (context, seconds, _) {
                  return Text(
                    _formatElapsed(seconds),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildStatusIndicator(TripStatus status) {
    if (status == TripStatus.inProgress) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(_pulseAnimation.value),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor(
                    status,
                  ).withOpacity(_pulseAnimation.value * 0.6),
                  blurRadius: 8 * _pulseAnimation.value,
                  spreadRadius: 2,
                ),
              ],
            ),
          );
        },
      );
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildBottomPanelContent(
    Trip trip,
    AsyncValue<dynamic> driverAsync,
    AsyncValue<dynamic> driverProfileAsync,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 1. Driver Row (Avatar + Name + Actions)
          _buildDriverRow(trip, driverAsync, driverProfileAsync, l10n),

          const SizedBox(height: 12),

          const SizedBox(height: 24),

          // 2. Vehicle Info (Compact)
          _buildVehicleInfo(trip, driverProfileAsync),

          const SizedBox(height: 24),

          // 3. Dynamic "Change Route" Button (Redesigned)
          if (trip.status == TripStatus.accepted ||
              trip.status == TripStatus.arrived ||
              trip.status == TripStatus.inProgress)
            _buildChangeRouteButton(trip),

          const SizedBox(height: 24),

          // 4. Route Timeline (Address)
          _buildRouteTimeline(trip),

          const SizedBox(height: 24),

          // 5. Price
          _buildPriceInfo(trip),
        ],
      ),
    );
  }

  Widget _buildChangeRouteButton(Trip trip) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2962FF), Color(0xFF00B0FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2962FF).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleModifyTrip(trip),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_location_alt_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Cambiar ruta',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleInfo(Trip trip, AsyncValue<dynamic> driverProfileAsync) {
    final profile = driverProfileAsync.asData?.value;
    if (profile == null) return const SizedBox.shrink();

    // Map vehicle type to asset
    String vehicleAsset = 'assets/vehiculos/auto.png';
    final typeStr = profile.vehicleType
        .toString()
        .split('.')
        .last
        .toLowerCase();
    if (typeStr.contains('xl')) {
      vehicleAsset = 'assets/vehiculos/essentialxl.png';
    } else if (typeStr.contains('essential')) {
      vehicleAsset = 'assets/vehiculos/essentials.png';
    } else if (typeStr.contains('executive')) {
      vehicleAsset = 'assets/vehiculos/executive.png';
    } else if (typeStr.contains('signature')) {
      vehicleAsset = 'assets/vehiculos/signatuve.png';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Image.asset(vehicleAsset, width: 80, height: 45, fit: BoxFit.contain),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.vehicleModel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.black,
                  ),
                ),
                Text(
                  profile.vehiclePlate.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceInfo(Trip trip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TARIFA ESTIMADA",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    trip.paymentMethod.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(
                  trip.price +
                      (trip.status == TripStatus.arrived
                          ? _waitFeeAccumulated
                          : 0.0),
                ),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          if (_waitFeeAccumulated > 0 && trip.status == TripStatus.arrived) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Cargo por espera",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "+\$${_waitFeeAccumulated.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDriverRow(
    Trip trip,
    AsyncValue<dynamic> driverAsync,
    AsyncValue<dynamic> driverProfileAsync,
    AppLocalizations l10n,
  ) {
    final driver = driverAsync.asData?.value;

    return Row(
      children: [
        // Driver Photo
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[200],
          backgroundImage: driver?.avatarUrl != null
              ? NetworkImage(driver!.avatarUrl!)
              : null,
          child: driver?.avatarUrl == null
              ? const Icon(Icons.person, color: Colors.grey)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                driver?.fullName ?? l10n.driver,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    '${driver?.averageRating?.toStringAsFixed(1) ?? "5.0"}',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildActionButtons(trip, driver, l10n),
      ],
    );
  }

  Widget _buildActionButtons(Trip trip, dynamic driver, AppLocalizations l10n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // SOS Button - Separate and prominent
        _buildCircularAction(
          icon: Icons.security_rounded,
          color: Colors.redAccent,
          onTap: () => _handleSOS(),
          tooltip: 'SOS',
        ),
        const SizedBox(width: 12),
        // Primary Communication (Chat/Call Grouped)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCircularAction(
                icon: Icons.chat_bubble_rounded,
                color: Colors.black87,
                showBg: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PassengerChatScreen(
                        tripId: trip.id,
                        driverId: trip.driverId ?? '',
                        driverName: driver?.fullName ?? l10n.driver,
                      ),
                    ),
                  );
                },
              ),
              _buildCircularAction(
                icon: Icons.call_rounded,
                color: Colors.black87,
                showBg: false,
                onTap: () => _handleCallDriver(driver?.phoneNumber),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Share / Cancel Menu
        _buildCircularAction(
          icon: Icons.more_horiz_rounded,
          color: Colors.black54,
          onTap: () => _showTripOptions(trip),
        ),
      ],
    );
  }

  void _showTripOptions(Trip trip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Colors.green),
              title: const Text(
                'Compartir por WhatsApp',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleShareWhatsApp();
              },
            ),
            ListTile(
              leading: const Icon(Icons.more_horiz_rounded, color: Colors.blue),
              title: const Text(
                'Otras opciones de compartido',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleShareTrip();
              },
            ),
            if (trip.status == TripStatus.accepted ||
                trip.status == TripStatus.arrived ||
                trip.status == TripStatus.inProgress)
              ListTile(
                leading: const Icon(
                  Icons.add_location_alt_rounded,
                  color: Colors.orange,
                ),
                title: const Text(
                  'Modificar destino / Añadir parada',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleModifyTrip(trip);
                },
              ),
            if (trip.status != TripStatus.inProgress)
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: const Text(
                  'Cancelar viaje',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TripCancellationScreen(trip: trip),
                    ),
                  );
                  if (result == true && context.mounted) {
                    context.go('/home');
                  }
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
    bool showBg = true,
  }) {
    return Material(
      color: showBg ? color.withOpacity(0.08) : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildRouteTimeline(Trip trip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimelineRow(
            icon: Icons.my_location_rounded,
            color: Colors.blueAccent,
            address: trip.pickupAddress,
            isCompleted: true,
          ),

          if (trip.intermediateStops.isNotEmpty) ...[
            for (var stop in trip.intermediateStops) ...[
              _buildTimelineDivider(),
              _buildTimelineRow(
                icon: Icons.add_location_alt_rounded,
                color: stop.isCompleted ? Colors.grey : Colors.orange,
                address: stop.address,
                isCompleted: stop.isCompleted,
              ),
            ],
          ],

          _buildTimelineDivider(),
          _buildTimelineRow(
            icon: Icons.location_on_rounded,
            color: Colors.redAccent,
            address: trip.dropoffAddress,
            isCompleted: false,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 11),
      child: Container(width: 2, height: 15, color: Colors.grey.shade300),
    );
  }

  Widget _buildTimelineRow({
    required IconData icon,
    required Color color,
    required String address,
    required bool isCompleted,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 12),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            address,
            style: TextStyle(
              color: isCompleted ? Colors.black54 : Colors.black87,
              fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w700,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.accepted:
        return Colors.blue;
      case TripStatus.arrived:
        return Colors.green;
      case TripStatus.inProgress:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(
    TripStatus status,
    AppLocalizations l10n, {
    String? vehicleModel,
  }) {
    final vehicle = vehicleModel ?? 'Tu conductor';
    switch (status) {
      case TripStatus.accepted:
        return '$vehicle va en camino';
      case TripStatus.arrived:
        return '$vehicle ha llegado';
      case TripStatus.inProgress:
        return 'Viaje en curso';
      case TripStatus.cancelled:
        return 'Viaje cancelado';
      default:
        return 'Buscando conductor...';
    }
  }
}

class _AddStopSheet extends StatefulWidget {
  final LatLng initialLocation;
  final int currentStopsCount;
  const _AddStopSheet({
    required this.initialLocation,
    required this.currentStopsCount,
  });

  @override
  State<_AddStopSheet> createState() => _AddStopSheetState();
}

class _AddStopSheetState extends State<_AddStopSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  final MapsService _mapsService = MapsService();
  final String _sessionToken = Uuid().v4();

  void _onSearchChanged(String val) async {
    if (val.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    try {
      final suggestions = await _mapsService.getAutocompleteSuggestions(
        val,
        _sessionToken,
      );
      if (mounted) setState(() => _suggestions = suggestions);
    } catch (_) {}
  }

  void _onSelectSuggestion(
    Map<String, dynamic> suggestion,
    bool asDestination,
  ) async {
    setState(() => _isLoading = true);
    try {
      final location = await _mapsService.getPlaceDetails(
        suggestion['place_id'],
      );
      if (mounted) {
        Navigator.pop(context, {
          'location': location,
          'address': suggestion['description'],
          'isDestination': asDestination,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Modificar Viaje',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Si cambias el destino o añades una parada, la tarifa se recalculará según la distancia recorrida y el nuevo trayecto.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar nueva ubicación...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 20),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          Expanded(
            child: ListView.builder(
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final s = _suggestions[index];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(s['structured_formatting']['main_text'] ?? ''),
                  subtitle: Text(
                    s['structured_formatting']['secondary_text'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        backgroundColor: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.route_rounded,
                                  size: 32,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                '¿Modificar viaje?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Selecciona si deseas cambiar tu destino final por completo o añadir este punto como una parada rápida.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _onSelectSuggestion(s, true);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade600,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.flag_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'NUEVO DESTINO',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: widget.currentStopsCount >= 2
                                      ? null
                                      : () {
                                          Navigator.pop(context);
                                          _onSelectSuggestion(s, false);
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.currentStopsCount >= 2
                                        ? Colors.grey.shade100
                                        : Colors.blue.shade50,
                                    foregroundColor: widget.currentStopsCount >= 2
                                        ? Colors.grey
                                        : Colors.blue.shade700,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_location_alt_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'AÑADIR PARADA',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
