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
import 'package:tincars/features/trips/presentation/screens/trip_chat_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trip_completion_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trip_cancellation_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:tincars/l10n/app_localizations.dart';
import 'package:tincars/core/utils/marker_utils.dart';
import 'package:tincars/core/services/maps_service.dart';
import 'package:tincars/core/utils/map_styles.dart';
import 'package:tincars/features/trips/domain/services/pricing_service.dart';
import 'package:flutter/services.dart';

class TripTrackingScreen extends ConsumerStatefulWidget {
  final String tripId;
  const TripTrackingScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends ConsumerState<TripTrackingScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? mapController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _tripTimer;
  Timer? _locationTimer;
  Timer? _waitTimer;
  int _elapsedSeconds = 0;
  int _waitSecondsRemaining = 300; // 5 minutes
  TripStatus? _lastStatus;

  // Cache para evitar flickering
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  BitmapDescriptor? _vehicleIcon;
  final Map<int, BitmapDescriptor> _stopIcons = {};
  String? _lastEmoji;
  bool _isRedirectingToCompletion = false;
  Map<String, dynamic>? _lastDirections;
  LatLng? _lastStart;
  LatLng? _lastEnd;
  Map<String, dynamic>? _driverDirections;
  LatLng? _lastDriverDirectionsLoc;
  String? _estimatedDistance;
  String? _estimatedDuration;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tripTimer?.cancel();
    _locationTimer?.cancel();
    _waitTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMapIcons([List<TripStop> intermediateStops = const []]) async {
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
      MarkerUtils.createVehicleMarker(),
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

  int _getWaitTimeForCategory(String type) {
    switch (type.toLowerCase()) {
      case 'essentials-eco':
        return 180; // 3 minutos
      case 'essentials_xl':
        return 180; // 3 minutos
      case 'executive':
        return 300; // 5 minutos
      case 'signature_lux':
        return 300; // 5 minutos
      default:
        return 180;
    }
  }

  void _startWaitTimer(String? vehicleType) {
    _waitTimer?.cancel();
    _waitSecondsRemaining = _getWaitTimeForCategory(
      vehicleType ?? 'essentials',
    );
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_waitSecondsRemaining > 0) {
        setState(() => _waitSecondsRemaining--);
      } else {
        timer.cancel();
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
            accuracy: LocationAccuracy.high,
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

    mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100), // 100px de padding
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

              // 2. Notify contacts (Mock SMS)
              for (var contact in contacts) {
                AppLogger.log(
                  'Enviando Alerta SOS a ${contact.name} (${contact.phoneNumber}): "¡EMERGENCIA! Estoy en un viaje de TINS. Sigue mi ubicación aquí: https://tincars.app/track/${widget.tripId}"',
                );
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
    // Simulate sharing
    Clipboard.setData(ClipboardData(text: 'Sigue mi viaje en TINS: $shareUrl'));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enlace de seguimiento copiado al portapapeles'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleModifyTrip(Trip trip) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _AddStopSheet(initialLocation: trip.pickupLocation),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recalculando tarifa...'), duration: Duration(seconds: 2)),
      );

      final LatLng newPointLoc = result['location'];
      final String newPointAddress = result['address'];
      final bool isNewDestination = result['isDestination'] ?? false;

      try {
        final driverLoc = trip.driverLocation ?? trip.pickupLocation;
        final originalDistance = trip.distance > 0 ? trip.distance : 0.1;
        
        // Estimate distance traveled since pickup
        final distanceTraveled = Geolocator.distanceBetween(
          trip.pickupLocation.latitude,
          trip.pickupLocation.longitude,
          driverLoc.latitude,
          driverLoc.longitude,
        ) / 1000.0;
        
        double newSegmentDistance;
        double newDistance;
        LatLng newDropoff;
        String newDropoffAddress;
        List<TripStop> newStops = List.from(trip.intermediateStops);

        if (isNewDestination) {
          final directions = await MapsService().getDirections(driverLoc, newPointLoc);
          newSegmentDistance = directions['distance'];
          newDistance = distanceTraveled + newSegmentDistance;
          newDropoff = newPointLoc;
          newDropoffAddress = newPointAddress;
        } else {
          // Add stop before current destination
          final directionsToStop = await MapsService().getDirections(driverLoc, newPointLoc);
          final directionsToFinal = await MapsService().getDirections(newPointLoc, trip.dropoffLocation);
          newSegmentDistance = directionsToStop['distance'] + directionsToFinal['distance'];
          newDistance = distanceTraveled + newSegmentDistance;
          newDropoff = trip.dropoffLocation;
          newDropoffAddress = trip.dropoffAddress;
          newStops.add(TripStop(location: newPointLoc, address: newPointAddress));
        }

        final double newTotalPrice = PricingService().calculateModifiedTripPrice(
          originalPrice: trip.price,
          originalDistance: originalDistance,
          distanceTraveled: distanceTraveled,
          newSegmentDistance: newSegmentDistance,
          vehicleType: trip.vehicleType,
        );

        await ref.read(tripControllerProvider.notifier).modifyTrip(
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
            SnackBar(content: Text('Error al modificar: $e'), backgroundColor: Colors.red),
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

  void _showDriverPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(url, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tripAsync = ref.watch(tripStreamProvider(widget.tripId));

    ref.listen<AsyncValue<Trip>>(tripStreamProvider(widget.tripId), (
      prev,
      next,
    ) {
      final trip = next.asData?.value;
      if (trip != null) {
        final prevTrip = prev?.asData?.value;
        if (prevTrip != null) {
          if (prevTrip.driverLocation != trip.driverLocation) {
            print(
              'TripTracking: [LOCATION_CHANGE] Conductor se movió a: ${trip.driverLocation}',
            );
          }
          if (prevTrip.status != trip.status) {
            print('TripTracking: [STATUS_CHANGE] Nuevo estado: ${trip.status}');
          }
        }

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
            context.go('/home');
          });
        }
      }
    });

    return Scaffold(
      body: tripAsync.when(
        data: (trip) {
          if (trip == null) {
            return const Center(child: Text('Viaje no encontrado'));
          }

          // Check if icons need to be reloaded (if stops count changed)
          if (_stopIcons.length != trip.intermediateStops.length) {
            _loadMapIcons(trip.intermediateStops);
          }

          final driverLoc = trip.driverLocation;

          final driverAsync = trip.driverId != null
              ? ref.watch(otherUserProfileProvider(trip.driverId!))
              : const AsyncValue.data(null);
          final driverProfileAsync = trip.driverId != null
              ? ref.watch(otherDriverProfileProvider(trip.driverId!))
              : const AsyncValue.data(null);

          // Auto-follow conductor durante la aproximación e inProgress
          if ((trip.status == TripStatus.accepted ||
                  trip.status == TripStatus.arrived ||
                  trip.status == TripStatus.inProgress) &&
              driverLoc != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _moveCameraToDriver(driverLoc);
            });
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
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (e, s) {
          print('TripTracking: [ERROR] Fallo al cargar viaje: $e');
          print('TripTracking: [STACK] $s');
          return Center(child: Text('Error: $e'));
        },
      ),
    );
  }

  void _fitBounds(Map<String, dynamic> boundsData) {
    try {
      final bounds = LatLngBounds(
        southwest: LatLng(
          boundsData['southwest']['lat'],
          boundsData['southwest']['lng'],
        ),
        northeast: LatLng(
          boundsData['northeast']['lat'],
          boundsData['northeast']['lng'],
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
    final LatLng start = trip.pickupLocation;
    final LatLng end = trip.dropoffLocation;

    // Cargar emoji marker si cambió o no existe
    if (trip.passengerEmoji != null &&
        trip.passengerEmoji!.isNotEmpty &&
        trip.passengerEmoji != _lastEmoji) {
      _loadPassengerEmojiMarker(trip.passengerEmoji!);
    }

    if (_lastStart != start || _lastEnd != end) {
      _lastStart = start;
      _lastEnd = end;
      MapsService().getDirections(
        start, 
        end,
        waypoints: trip.intermediateStops.map((s) => s.location).toList(),
      ).then((directions) {
        if (mounted) setState(() => _lastDirections = directions);
      });
    }

    Set<Polyline> polylines = {};
    if (_lastDirections != null) {
      final points = _lastDirections!['polyline'] as List<LatLng>?;
      if (points != null) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route_polyline'),
            points: points,
            color: isToDropoff ? Colors.green : Colors.blue.withOpacity(0.8),
            width: 5,
            patterns: isToDropoff ? [] : [PatternItem.dot, PatternItem.gap(10)],
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      }
    }

    // Live Route from Driver
    if (_lastDriverDirectionsLoc == null ||
        Geolocator.distanceBetween(
              _lastDriverDirectionsLoc!.latitude,
              _lastDriverDirectionsLoc!.longitude,
              driverLoc.latitude,
              driverLoc.longitude,
            ) >
            20) {
      _lastDriverDirectionsLoc = driverLoc;
      final target = isToDropoff ? trip.dropoffLocation : trip.pickupLocation;
      MapsService().getDirections(driverLoc, target).then((directions) {
        if (mounted) setState(() => _driverDirections = directions);
      });
    }

    if (_driverDirections != null) {
      final points = _driverDirections!['polyline'] as List<LatLng>?;
      if (points != null) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('driver_live_route'),
            points: points,
            color: Colors.blueAccent.withValues(alpha: 0.6),
            width: 4,
            patterns: [PatternItem.dash(15), PatternItem.gap(10)],
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );
      }
    }

    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('driver'),
        position: driverLoc,
        icon: _vehicleIcon ?? BitmapDescriptor.defaultMarker,
        rotation: trip.driverHeading ?? 0,
      ),
      Marker(
        markerId: const MarkerId('passenger'),
        position: trip.passengerLocation ?? trip.pickupLocation,
        icon: _pickupIcon ?? BitmapDescriptor.defaultMarker,
      ),
      for (int i = 0; i < trip.intermediateStops.length; i++)
        Marker(
          markerId: MarkerId('stop_$i'),
          position: trip.intermediateStops[i].location,
          icon: _stopIcons[i] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          alpha: trip.intermediateStops[i].isCompleted ? 0.5 : 1.0,
          infoWindow: InfoWindow(title: 'Parada ${i + 1}'),
        ),
      Marker(
        markerId: const MarkerId('dropoff'),
        position: end,
        icon: _dropoffIcon ?? BitmapDescriptor.defaultMarker,
      ),
    };

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) {
            mapController = controller;
            mapController?.setMapStyle(MapStyles.silverStyle);
            if (_lastDirections != null) _fitBounds(_lastDirections!['bounds']);
          },
          initialCameraPosition: CameraPosition(
            target: trip.pickupLocation,
            zoom: 15,
          ),
          markers: markers,
          polylines: polylines,
          zoomControlsEnabled: false,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
        ),
        // Reduced and more elegant floating status HUD
        Positioned(
          top: MediaQuery.of(context).padding.top + 20,
          left: 40,
          right: 40,
          child: _buildTopStatusHUD(trip, l10n),
        ),
        // Floating action buttons removed as requested by user
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomPanel(trip, driverAsync, driverProfileAsync, l10n),
        ),
      ],
    );
  }

  Widget _buildTopStatusHUD(Trip trip, AppLocalizations l10n) {
    try {
      if (trip.status == TripStatus.arrived) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.35),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EL CONDUCTOR TE ESTÁ ESPERANDO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'TIEMPO DE CORTESÍA: ${_formatElapsed(_waitSecondsRemaining)}',
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
      final statusText = _getStatusText(trip.status, l10n).toUpperCase();

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
          border: Border.all(color: Colors.grey.shade100),
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
                          final pendingIndex = trip.intermediateStops.indexWhere((s) => !s.isCompleted);
                          return pendingIndex != -1 
                            ? 'VIAJANDO A PARADA ${pendingIndex + 1}'
                            : 'VIAJANDO AL DESTINO';
                        })()
                      : statusText,
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
                      'LLEGA EN $driverEtaMinutes MIN'.toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
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
    } catch (e, s) {
      print('TripTracking: [HUD_CRASH] $e');
      print('TripTracking: [HUD_STACK] $s');
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

  Widget _buildBottomPanel(
    Trip trip,
    AsyncValue<dynamic> driverAsync,
    AsyncValue<dynamic> driverProfileAsync, // New
    AppLocalizations l10n,
  ) {
    try {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDriverRow(trip, driverAsync, driverProfileAsync, l10n),
            const SizedBox(height: 20),
            _buildVehicleInfoSection(trip, driverProfileAsync, l10n),
            const SizedBox(height: 20),
            _buildRouteTimeline(trip),
            const SizedBox(height: 12),
          ],
        ),
      );
    } catch (e, s) {
      print('TripTracking: [PANEL_CRASH] $e');
      print('TripTracking: [PANEL_STACK] $s');
      return const SizedBox.shrink();
    }
  }

  Widget _buildVehicleInfoSection(
    Trip trip,
    AsyncValue<dynamic> driverProfileAsync,
    AppLocalizations l10n,
  ) {
    final profile = driverProfileAsync.value;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.directions_car_filled_rounded,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  profile?.vehicleModel ?? trip.vehicleType.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                if (profile?.vehicleColor != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    profile!.vehicleColor!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                Text(
                  profile?.vehiclePlate.toUpperCase() ?? '...',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber[400],
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'PLACA',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),

        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${trip.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            Text(
              l10n.fare.toUpperCase(),
              style: TextStyle(
                color: Colors.black.withOpacity(0.3),
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDriverAvatar(dynamic driver, TripStatus status) {
    return GestureDetector(
      onTap: () {
        if (driver?.avatarUrl != null) {
          _showDriverPhoto(context, driver.avatarUrl!);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _getStatusColor(status).withOpacity(0.35),
            width: 2.5,
          ),
        ),
        child: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey.shade100,
          backgroundImage: driver?.avatarUrl != null
              ? NetworkImage(driver.avatarUrl!)
              : null,
          child: driver?.avatarUrl == null
              ? const Icon(
                  Icons.person_rounded,
                  color: Colors.black45,
                  size: 32,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildDriverRow(
    Trip trip,
    AsyncValue<dynamic> driverAsync,
    AsyncValue<dynamic> driverProfileAsync,
    AppLocalizations l10n,
  ) {
    return driverAsync.when(
      data: (driver) {
        return Row(
          children: [
            _buildDriverAvatar(driver, trip.status),
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
                      letterSpacing: -0.5,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 14,
                      ),
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
      },
      loading: () => const Center(child: LinearProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
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
                      builder: (context) => TripChatScreen(
                        tripId: trip.id,
                        otherUserId: trip.driverId ?? '',
                        otherUserName: driver?.fullName ?? l10n.driver,
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
              leading: const Icon(Icons.share_rounded, color: Colors.blue),
              title: const Text(
                'Compartir viaje',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleShareTrip();
              },
            ),
            if (trip.status == TripStatus.accepted || trip.status == TripStatus.arrived || trip.status == TripStatus.inProgress)
              ListTile(
                leading: const Icon(Icons.add_location_alt_rounded, color: Colors.orange),
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
                  if (result == true && mounted) {
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

  Widget _buildStatusBadge(TripStatus status, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
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
      child: Container(
        width: 2,
        height: 15,
        color: Colors.grey.shade300,
      ),
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

  String _getStatusText(TripStatus status, AppLocalizations l10n) {
    switch (status) {
      case TripStatus.accepted:
        return 'Tu conductor va en camino';
      case TripStatus.arrived:
        return 'El conductor ha llegado';
      case TripStatus.inProgress:
        return 'Viaje en curso';
      default:
        return 'Buscando conductor...';
    }
  }
}

class _AddStopSheet extends StatefulWidget {
  final LatLng initialLocation;
  const _AddStopSheet({required this.initialLocation});

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
      final suggestions = await _mapsService.getAutocompleteSuggestions(val, _sessionToken);
      if (mounted) setState(() => _suggestions = suggestions);
    } catch (_) {}
  }

  void _onSelectSuggestion(Map<String, dynamic> suggestion, bool asDestination) async {
    setState(() => _isLoading = true);
    try {
      final location = await _mapsService.getPlaceDetails(suggestion['place_id']);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Modificar Viaje', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Si cambias el destino o añades una parada, la tarifa se recalculará según la distancia recorrida y el nuevo trayecto.', 
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                  subtitle: Text(s['structured_formatting']['secondary_text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('¿Cómo desea modificar?'),
                        content: const Text('Seleccione si desea cambiar el destino final o añadir este punto como una parada intermedia.'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _onSelectSuggestion(s, false);
                            },
                            child: const Text('AÑADIR PARADA'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _onSelectSuggestion(s, true);
                            },
                            child: const Text('NUEVO DESTINO'),
                          ),
                        ],
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
