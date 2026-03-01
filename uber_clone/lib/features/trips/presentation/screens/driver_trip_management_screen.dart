import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/trips/presentation/screens/trip_chat_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trip_completion_screen.dart';
import 'package:tincars/core/utils/marker_utils.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:tincars/core/services/maps_service.dart';

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
  Timer? _locationTimer;
  bool _isUpdatingStatus = false;
  LatLng? _currentDriverLocation;

  // Cache para evitar flickering
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  BitmapDescriptor? _vehicleIcon;
  Map<String, dynamic>? _lastDirections;
  LatLng? _lastStart;
  LatLng? _lastEnd;

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
    _locationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadMapIcons() async {
    final results = await Future.wait([
      MarkerUtils.createABMarker(
        letter: 'A',
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        label: '',
      ),
      MarkerUtils.createABMarker(
        letter: 'B',
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        label: '',
      ),
      MarkerUtils.createVehicleMarker(),
    ]);

    if (mounted) {
      setState(() {
        _pickupIcon = results[0];
        _dropoffIcon = results[1];
        _vehicleIcon = results[2];
      });
    }
  }

  void _startLocationSharing() {
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        final loc = LatLng(position.latitude, position.longitude);

        ref
            .read(tripControllerProvider.notifier)
            .updateLocation(
              widget.tripId,
              position.latitude,
              position.longitude,
            );

        if (mounted) {
          setState(() => _currentDriverLocation = loc);
        }
      } catch (e) {
        debugPrint('Error sharing location: $e');
      }
    });
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

  LatLngBounds _getBounds(List<LatLng> locations) {
    double? minLat, maxLat, minLng, maxLng;
    for (var loc in locations) {
      if (minLat == null || loc.latitude < minLat) minLat = loc.latitude;
      if (maxLat == null || loc.latitude > maxLat) maxLat = loc.latitude;
      if (minLng == null || loc.longitude < minLng) minLng = loc.longitude;
      if (maxLng == null || loc.longitude > maxLng) maxLng = loc.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripStreamProvider(widget.tripId));

    return Scaffold(
      body: PopScope(
        canPop: false,
        child: tripAsync.when(
          data: (trip) {
            if (trip.status == TripStatus.completed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TripCompletionScreen(trip: trip, isDriver: true),
                  ),
                );
              });
            } else if (trip.status == TripStatus.cancelled) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              });
            }

            if (trip.status == TripStatus.inProgress &&
                _currentDriverLocation != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                mapController?.animateCamera(
                  CameraUpdate.newLatLng(_currentDriverLocation!),
                );
              });
            }

            return _buildMapContent(trip);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildMapContent(Trip trip) {
    final LatLng start = trip.pickupLocation;
    final LatLng end = trip.dropoffLocation;

    if (_lastStart != start || _lastEnd != end) {
      _lastStart = start;
      _lastEnd = end;
      MapsService().getDirections(start, end).then((directions) {
        if (mounted) setState(() => _lastDirections = directions);
      });
    }

    Set<Polyline> polylines = {};
    if (_lastDirections != null) {
      final points = _lastDirections!['polyline'] as List<LatLng>?;
      if (points != null) {
        final isToDestination = trip.status == TripStatus.inProgress;
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route_polyline_driver'),
            points: points,
            color: isToDestination ? Colors.green : Colors.blueAccent,
            width: 5,
            patterns: isToDestination
                ? []
                : [PatternItem.dot, PatternItem.gap(10)],
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      }
    }

    final isToDestination = trip.status == TripStatus.inProgress;
    final targetMarkerLoc = isToDestination
        ? trip.dropoffLocation
        : trip.pickupLocation;
    BitmapDescriptor? markerIcon = isToDestination ? _dropoffIcon : _pickupIcon;

    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('target_destination'),
        position: targetMarkerLoc,
        icon: markerIcon ?? BitmapDescriptor.defaultMarker,
      ),
      if (_currentDriverLocation != null)
        Marker(
          markerId: const MarkerId('driver_pos'),
          position: _currentDriverLocation!,
          icon:
              _vehicleIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          anchor: const Offset(0.5, 0.5),
        ),
    };

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) {
            mapController = controller;
            if (_lastDirections != null) {
              _fitBounds(_lastDirections!['bounds']);
            } else {
              final targetLoc = trip.status == TripStatus.inProgress
                  ? trip.dropoffLocation
                  : trip.pickupLocation;
              final currentLoc = _currentDriverLocation ?? targetLoc;
              final bounds = _getBounds([currentLoc, targetLoc]);
              controller.animateCamera(
                CameraUpdate.newLatLngBounds(bounds, 80),
              );
            }
          },
          initialCameraPosition: CameraPosition(
            target: trip.pickupLocation,
            zoom: 15,
          ),
          markers: markers,
          polylines: polylines,
          myLocationEnabled: true,
          zoomControlsEnabled: false,
        ),
        Positioned(
          top: 60,
          left: 20,
          right: 20,
          child: _buildTopStatusHUD(trip),
        ),
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 20,
          left: 20,
          right: 20,
          child: _buildBottomPanel(trip),
        ),
      ],
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
        if (mounted)
          mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 80),
          );
      });
    } catch (_) {}
  }

  Widget _buildTopStatusHUD(Trip trip) {
    return PremiumGlassContainer(
      color: Colors.black,
      opacity: 0.8,
      blur: 20,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      borderRadius: BorderRadius.circular(40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (trip.status == TripStatus.inProgress)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: _pulseAnimation.value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(
                        alpha: _pulseAnimation.value * 0.6,
                      ),
                      blurRadius: 8 * _pulseAnimation.value,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            )
          else
            const Icon(
              Icons.gps_fixed_rounded,
              color: Colors.blueAccent,
              size: 18,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getTopBarAddressText(trip),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trip.status == TripStatus.accepted ||
              trip.status == TripStatus.arrived)
            IconButton(
              icon: const Icon(
                Icons.cancel_outlined,
                color: Colors.redAccent,
                size: 20,
              ),
              onPressed: () => _showCancellationDialog(trip),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(Trip trip) {
    final passengerAsync = ref.watch(
      otherUserProfileProvider(trip.passengerId),
    );
    return PremiumGlassContainer(
      color: Colors.white,
      opacity: 0.95,
      blur: 20,
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPassengerHeader(trip, passengerAsync),
          if (trip.status == TripStatus.inProgress) ...[
            const SizedBox(height: 14),
            _buildDistanceRestante(trip.distance),
          ],
          const SizedBox(height: 24),
          _buildActionButton(trip),
          if (trip.status == TripStatus.inProgress) ...[
            const SizedBox(height: 16),
            _buildNavButton(trip),
          ],
          const SizedBox(height: 16),
          _buildSecondaryActions(trip, passengerAsync),
        ],
      ),
    );
  }

  Widget _buildPassengerHeader(Trip trip, AsyncValue<dynamic> passengerAsync) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getStatusColor(trip.status).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            trip.status == TripStatus.inProgress
                ? Icons.navigation_rounded
                : Icons.person_pin_circle_rounded,
            color: _getStatusColor(trip.status),
            size: 28,
          ),
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
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                trip.status == TripStatus.inProgress
                    ? 'Hacia: ${trip.dropoffAddress}'
                    : 'Recogida: ${trip.pickupAddress}',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDistanceRestante(double distance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.route_rounded, color: Colors.grey.shade400, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Distancia restante: ${distance.toStringAsFixed(1)} km',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
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
                _getButtonText(trip.status),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  Widget _buildNavButton(Trip trip) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () => _showNavigationOptions(trip),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black12, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.turn_right_rounded, size: 22),
            SizedBox(width: 8),
            Text(
              'NAVEGAR',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
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
            color: Colors.black,
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
        const SizedBox(width: 8),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNextStep(Trip trip) {
    if (trip.status == TripStatus.accepted)
      _updateStatus(TripStatus.arrived);
    else if (trip.status == TripStatus.arrived)
      _updateStatus(TripStatus.inProgress);
    else if (trip.status == TripStatus.inProgress)
      _updateStatus(TripStatus.completed);
  }

  String _getButtonText(TripStatus status) {
    switch (status) {
      case TripStatus.accepted:
        return 'HE LLEGADO';
      case TripStatus.arrived:
        return 'INICIAR VIAJE';
      case TripStatus.inProgress:
        return 'TERMINAR VIAJE';
      default:
        return 'CONTINUAR';
    }
  }

  String _getTopBarAddressText(Trip trip) {
    return trip.status == TripStatus.inProgress
        ? 'Destino: ${trip.dropoffAddress}'
        : 'Recogida: ${trip.pickupAddress}';
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

  void _showNavigationOptions(Trip trip) {
    final dest = trip.status == TripStatus.inProgress
        ? trip.dropoffLocation
        : trip.pickupLocation;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Navegar con',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildNavOption(
              'Google Maps',
              url: 'comgooglemaps://?daddr=${dest.latitude},${dest.longitude}',
              fallbackUrl:
                  'https://www.google.com/maps/dir/?api=1&destination=${dest.latitude},${dest.longitude}',
              icon: Icons.map,
            ),
            _buildNavOption(
              'Waze',
              url: 'waze://?ll=${dest.latitude},${dest.longitude}&navigate=yes',
              fallbackUrl:
                  'https://waze.com/ul?ll=${dest.latitude},${dest.longitude}&navigate=yes',
              icon: Icons.directions_car,
            ),
            _buildNavOption(
              'Apple Maps',
              url: 'maps://?daddr=${dest.latitude},${dest.longitude}',
              fallbackUrl:
                  'http://maps.apple.com/?daddr=${dest.latitude},${dest.longitude}',
              icon: Icons.apple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavOption(
    String title, {
    required String url,
    required String fallbackUrl,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      onTap: () async {
        Navigator.pop(context);
        bool launched = false;
        try {
          if (await canLaunchUrlString(url))
            launched = await launchUrlString(url);
        } catch (_) {}
        if (!launched) {
          if (await canLaunchUrlString(fallbackUrl))
            await launchUrlString(fallbackUrl);
        }
      },
    );
  }

  Future<void> _showCancellationDialog(Trip trip) async {
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
                'CONFIRMAR CANCELACIÓN',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (reason != null && mounted) {
      await ref
          .read(tripControllerProvider.notifier)
          .updateStatus(
            trip.id,
            TripStatus.cancelled,
            cancellationReason: reason,
          );
    }
  }
}
