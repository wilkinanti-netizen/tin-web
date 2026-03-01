import 'package:tincars/core/utils/app_logger.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/trips/presentation/screens/trip_chat_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trip_completion_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tincars/l10n/app_localizations.dart';
import 'package:tincars/core/utils/marker_utils.dart';
import 'package:tincars/core/services/maps_service.dart';

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
  int _elapsedSeconds = 0;
  TripStatus? _lastStatus;

  // Cache para evitar flickering
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  BitmapDescriptor? _vehicleIcon;
  Map<String, dynamic>? _lastDirections;
  LatLng? _lastStart;
  LatLng? _lastEnd;

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
    super.dispose();
  }

  Future<void> _loadMapIcons() async {
    final results = await Future.wait([
      MarkerUtils.createABMarker(
        letter: 'A',
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        label: 'Recogida',
      ),
      MarkerUtils.createABMarker(
        letter: 'B',
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        label: 'Destino',
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

  void _startTripTimer() {
    _tripTimer?.cancel();
    _elapsedSeconds = 0;
    _tripTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  String _formatElapsed(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final uri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  void _moveCameraToDriver(LatLng driverLoc) {
    mapController?.animateCamera(CameraUpdate.newLatLng(driverLoc));
  }

  void _showDriverPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black,
                child: InteractiveViewer(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                style: IconButton.styleFrom(backgroundColor: Colors.white24),
              ),
            ),
          ),
        ],
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
        if (trip.status == TripStatus.completed) {
          AppLogger.log('[PASAJERO] Viaje completado detectado en listen');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TripCompletionScreen(trip: trip, isDriver: false),
            ),
          );
        } else if (trip.status == TripStatus.cancelled) {
          AppLogger.log('[PASAJERO] Viaje cancelado detectado en listen');
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });

    return Scaffold(
      body: tripAsync.when(
        data: (trip) {
          final driverLoc = trip.driverLocation;
          final driverAsync = trip.driverId != null
              ? ref.watch(otherUserProfileProvider(trip.driverId!))
              : const AsyncValue.data(null);

          // Auto-follow conductor durante inProgress
          if (trip.status == TripStatus.inProgress && driverLoc != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _moveCameraToDriver(driverLoc);
            });
          }

          // Iniciar timer cuando empieza el viaje
          if (trip.status == TripStatus.inProgress &&
              _lastStatus != TripStatus.inProgress) {
            _lastStatus = TripStatus.inProgress;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _startTripTimer(),
            );
          } else if (trip.status != TripStatus.inProgress &&
              _lastStatus == TripStatus.inProgress) {
            _lastStatus = trip.status;
            _tripTimer?.cancel();
          }

          return PopScope(
            canPop: false,
            child: _buildMapContent(trip, driverAsync, l10n),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
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
    AppLocalizations l10n,
  ) {
    final bool isToDropoff = trip.status == TripStatus.inProgress;
    final LatLng driverLoc = trip.driverLocation ?? trip.pickupLocation;
    final LatLng start =
        (trip.status == TripStatus.accepted ||
            trip.status == TripStatus.arrived ||
            trip.status == TripStatus.inProgress)
        ? driverLoc
        : trip.pickupLocation;
    final LatLng end = isToDropoff ? trip.dropoffLocation : trip.pickupLocation;

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
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route_polyline'),
            points: points,
            color: isToDropoff
                ? Colors.green
                : Colors.blue.withValues(alpha: 0.8),
            width: 5,
            patterns: isToDropoff ? [] : [PatternItem.dot, PatternItem.gap(10)],
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      }
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                onMapCreated: (controller) {
                  mapController = controller;
                  if (_lastDirections != null)
                    _fitBounds(_lastDirections!['bounds']);
                },
                initialCameraPosition: CameraPosition(
                  target: trip.pickupLocation,
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: trip.pickupLocation,
                    icon: _pickupIcon ?? BitmapDescriptor.defaultMarker,
                    infoWindow: InfoWindow(title: l10n.pickup),
                  ),
                  Marker(
                    markerId: const MarkerId('dropoff'),
                    position: trip.dropoffLocation,
                    icon: _dropoffIcon ?? BitmapDescriptor.defaultMarker,
                    infoWindow: InfoWindow(title: l10n.destination),
                  ),
                  if (trip.driverLocation != null)
                    Marker(
                      markerId: const MarkerId('driver'),
                      position: trip.driverLocation!,
                      icon:
                          _vehicleIcon ??
                          BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueYellow,
                          ),
                      infoWindow: InfoWindow(title: l10n.yourDriver),
                    ),
                },
                polylines: polylines,
                zoomControlsEnabled: false,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
              ),
              Positioned(
                top:
                    MediaQuery.of(context).padding.top +
                    70, // Bajado para evitar superposición
                right: 20,
                child: _buildSOSButton(),
              ),
              Positioned(
                top: 60,
                left: 20,
                right: 20,
                child: _buildTopStatusHUD(trip, l10n),
              ),
            ],
          ),
        ),
        _buildBottomPanel(trip, driverAsync, l10n),
      ],
    );
  }

  Widget _buildSOSButton() {
    return GestureDetector(
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('🆘 Emergency'),
            content: const Text(
              'Do you want to call 911?\n\nYour location will be shared with emergency services.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Call 911',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
        if (confirm == true) launchUrl(Uri(scheme: 'tel', path: '911'));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.4),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sos, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatusHUD(Trip trip, AppLocalizations l10n) {
    return PremiumGlassContainer(
      color: Colors.black,
      opacity: 0.75,
      blur: 20,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      borderRadius: BorderRadius.circular(40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStatusIndicator(trip.status),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getStatusText(trip.status, l10n).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trip.status == TripStatus.inProgress)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatElapsed(_elapsedSeconds),
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
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
              color: _getStatusColor(
                status,
              ).withValues(alpha: _pulseAnimation.value),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor(
                    status,
                  ).withValues(alpha: _pulseAnimation.value * 0.6),
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
    AppLocalizations l10n,
  ) {
    return Container(
      color: Colors.white,
      child: PremiumGlassContainer(
        color: Colors.white,
        opacity: 0.95,
        blur: 25,
        padding: const EdgeInsets.all(24),
        borderRadius: BorderRadius.circular(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDriverInfo(trip, driverAsync, l10n),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(height: 1, color: Colors.black12),
            ),
            _buildFareAndStatus(trip, l10n),
            if (trip.status != TripStatus.inProgress) ...[
              const SizedBox(height: 16),
              _buildRouteRow(
                icon: Icons.my_location,
                color: Colors.blueAccent,
                address: trip.pickupAddress,
              ),
              const SizedBox(height: 8),
              _buildRouteRow(
                icon: Icons.location_on,
                color: Colors.redAccent,
                address: trip.dropoffAddress,
              ),
            ],
            if (trip.status == TripStatus.inProgress) ...[
              const SizedBox(height: 16),
              _buildInProgressDropoff(trip.dropoffAddress),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfo(
    Trip trip,
    AsyncValue<dynamic> driverAsync,
    AppLocalizations l10n,
  ) {
    final driver = driverAsync.value;
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (driver?.avatarUrl != null) {
              _showDriverPhoto(context, driver!.avatarUrl!);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _getStatusColor(trip.status).withValues(alpha: 0.35),
                width: 2.5,
              ),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.black12,
              backgroundImage: driver?.avatarUrl != null
                  ? NetworkImage(driver!.avatarUrl!)
                  : null,
              child: driver?.avatarUrl == null
                  ? const Icon(
                      Icons.person_rounded,
                      color: Colors.black54,
                      size: 32,
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driver?.fullName ?? l10n.driver,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${driver?.averageRating?.toStringAsFixed(1) ?? "5.0"} • ${_getVehicleInfo(trip)}',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _buildActionsRow(trip, driver, l10n),
      ],
    );
  }

  Widget _buildActionsRow(Trip trip, dynamic driver, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildCircularAction(
          icon: Icons.chat_bubble_rounded,
          color: Colors.black,
          onTap: () {
            if (trip.driverId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TripChatScreen(
                    tripId: widget.tripId,
                    otherUserId: trip.driverId!,
                    otherUserName: driver?.fullName ?? l10n.driver,
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(width: 10),
        _buildCircularAction(
          icon: Icons.call_rounded,
          color: Colors.green[700]!,
          onTap: () => _makePhoneCall(driver?.phoneNumber),
        ),
        const SizedBox(width: 10),
        _buildCircularAction(
          icon: Icons.close_rounded,
          color: Colors.redAccent,
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Cancelar viaje'),
                content: const Text(
                  '¿Estás seguro de que deseas cancelar el viaje?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      'Sí, cancelar',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await ref
                  .read(tripControllerProvider.notifier)
                  .updateStatus(
                    trip.id,
                    TripStatus.cancelled,
                    cancellationReason: "Cancelado por el pasajero",
                  );
              if (mounted)
                Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
      ],
    );
  }

  Widget _buildFareAndStatus(Trip trip, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.fare,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.5),
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '\$${trip.price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        _buildStatusBadge(trip.status, l10n),
      ],
    );
  }

  Widget _buildStatusBadge(TripStatus status, AppLocalizations l10n) {
    return PremiumGlassContainer(
      color: _getStatusColor(status),
      opacity: 0.15,
      blur: 10,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      borderRadius: BorderRadius.circular(15),
      child: Text(
        _getStatusBadgeLabel(status, l10n).toUpperCase(),
        style: TextStyle(
          color: _getStatusColor(status),
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildRouteRow({
    required IconData icon,
    required Color color,
    required String address,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            address,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInProgressDropoff(String dropoffAddress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              dropoffAddress,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
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

  String _getStatusBadgeLabel(TripStatus status, AppLocalizations l10n) {
    switch (status) {
      case TripStatus.accepted:
        return 'Aceptado';
      case TripStatus.arrived:
        return 'Llegó';
      case TripStatus.inProgress:
        return 'En viaje';
      default:
        return 'Esperando';
    }
  }

  String _getVehicleInfo(Trip trip) {
    return 'Conductor';
  }
}
