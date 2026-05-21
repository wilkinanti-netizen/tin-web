import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/core/utils/map_styles.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:tincars/features/passenger/presentation/screens/trip_cancellation_screen.dart';
import 'package:tincars/core/utils/app_logger.dart';
import 'package:tincars/core/services/maps_service.dart';
import 'package:tincars/l10n/app_localizations.dart';
import 'package:tincars/features/trips/domain/services/pricing_service.dart';

class SearchingDriverScreen extends ConsumerStatefulWidget {
  final String tripId;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final String pickupAddress;
  final String dropoffAddress;
  final List<TripStop> intermediateStops;
  final Set<Polyline>? polylines;
  final LatLngBounds? bounds;
  final String vehicleType;

  const SearchingDriverScreen({
    super.key,
    required this.tripId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.intermediateStops = const [],
    this.polylines,
    this.bounds,
    required this.vehicleType,
  });

  @override
  ConsumerState<SearchingDriverScreen> createState() =>
      _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends ConsumerState<SearchingDriverScreen>
    with TickerProviderStateMixin {
  late GoogleMapController mapController;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  final Map<int, BitmapDescriptor> _stopIcons = {};
  bool _isPriceIncreasing = false;
  bool _isUpdatingPrice = false;
  Timer? _timeoutTimer;
  int _secondsWaiting = 0;
  double? _optimisticPrice;
  Map<String, dynamic>? _directions;
  bool _isClosing = false;

  // New visual variables
  AnimationController? _radarController;
  Animation<double>? _radarAnimation;

  int _messageIndex = 0;
  Timer? _messageTimer;
  final List<String> _dynamicMessages = [
    'Buscando el auto más cercano...',
    'Analizando demanda y tráfico en tiempo real...',
    'Contactando conductores a menos de 5 min...',
    'Priorizando tu oferta en la red...',
    'Optimizando tu ruta de viaje...',
  ];

  Timer? _cameraDriftTimer;
  double _currentBearing = 0.0;

  @override
  void initState() {
    super.initState();
    _createCustomMarkers();
    _startTimeout();
    _fetchDirections();

    // Radar pulse animation
    _radarController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _radarAnimation = Tween<double>(begin: 30.0, end: 420.0).animate(
      CurvedAnimation(parent: _radarController!, curve: Curves.easeOut),
    )..addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    // Cycle messages every 4 seconds
    _messageTimer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _dynamicMessages.length;
        });
      }
    });

    // Subtle cinematic camera drone drift
    Future.delayed(const Duration(seconds: 2), () {
      _startCameraDrift();
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _messageTimer?.cancel();
    _cameraDriftTimer?.cancel();
    _radarController?.dispose();
    super.dispose();
  }

  void _startCameraDrift() {
    _cameraDriftTimer = Timer.periodic(const Duration(seconds: 8), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      try {
        _currentBearing = (_currentBearing + 4.0) % 360.0;
        final double targetZoom = 14.8 + 0.3 * math.sin(_secondsWaiting * 0.1);

        mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: widget.pickupLocation,
              zoom: targetZoom,
              bearing: _currentBearing,
              tilt: 15.0, // High-status perspective tilt
            ),
          ),
        );
      } catch (_) {}
    });
  }

  Future<void> _fetchDirections() async {
    try {
      final directions = await MapsService().getDirections(
        widget.pickupLocation,
        widget.dropoffLocation,
        waypoints: widget.intermediateStops.map((s) => s.location).toList(),
      );
      if (mounted) {
        setState(() {
          _directions = directions;
        });
        _fitBounds(directions['bounds']);
      }
    } catch (e) {
      AppLogger.log('Error fetching directions in SearchingDriverScreen: $e');
    }
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
      // Adjusted padding to 60 for a tighter zoom on points A and B
      mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    } catch (_) {}
  }

  void _startTimeout() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsWaiting++);
      if (_secondsWaiting >= 480) {
        // 8 minutes timeout
        t.cancel();
        _autoCancelNoDriver();
      }
    });
  }

  Future<void> _autoCancelNoDriver() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          l10n.noDriverAvailableTitle,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        content: Text(
          l10n.noDriverAvailableMessage,
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.keepWaiting,
              style: const TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.cancel,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != false && mounted) {
      ref
          .read(tripControllerProvider.notifier)
          .updateStatus(widget.tripId, TripStatus.cancelled);
      Navigator.pop(context);
    } else if (mounted) {
      setState(() => _secondsWaiting = 0);
      _startTimeout();
    }
  }

  Future<void> _createCustomMarkers() async {
    // A: Pickup
    _pickupIcon = await _getMarkerIcon('A', Colors.blueAccent);

    // B, C, ...: Intermediate Stops
    for (int i = 0; i < widget.intermediateStops.length; i++) {
      final char = String.fromCharCode(66 + i); // 66 is 'B'
      _stopIcons[i] = await _getMarkerIcon(char, Colors.orange);
    }

    // Last: Dropoff
    final lastChar = String.fromCharCode(66 + widget.intermediateStops.length);
    _dropoffIcon = await _getMarkerIcon(lastChar, Colors.redAccent);



    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _getMarkerIcon(String label, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 90.0;

    // Shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3);
    canvas.drawCircle(
      const Offset(size / 2, size / 2 + 4),
      size / 2 - 4,
      shadowPaint,
    );

    final Paint circlePaint = Paint()..color = color;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 8,
      circlePaint,
    );

    final Paint innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 22,
      innerPaint,
    );

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: label,
      style: TextStyle(
        fontSize: 40.0,
        fontWeight: FontWeight.w900,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        size / 2 - textPainter.width / 2,
        size / 2 - textPainter.height / 2,
      ),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }



  void _cancelTrip(Trip trip) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TripCancellationScreen(trip: trip),
      ),
    );

    if (result == true && mounted) {
      // No necesitamos hacer pop aquí porque TripCancellationScreen ya hizo popUntil(isFirst)
    }
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
        if (_optimisticPrice != null && trip.price >= _optimisticPrice!) {
          _optimisticPrice = null;
        }

        final prevStatus = prev?.asData?.value.status;
        if (trip.status != prevStatus) {}

        if (trip.status == TripStatus.accepted ||
            trip.status == TripStatus.arrived ||
            trip.status == TripStatus.inProgress) {
          _timeoutTimer?.cancel();
          if (mounted && !_isClosing) {
            setState(() => _isClosing = true);
            Navigator.of(context).pop();
          }
        } else if (trip.status == TripStatus.cancelled) {
          _timeoutTimer?.cancel();
          if (mounted && !_isClosing) {
            _isClosing = true;
            setState(() {});
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      }
    });

    return PopScope(
      canPop:
          _isClosing ||
          tripAsync.value?.status == TripStatus.cancelled ||
          tripAsync.value?.status == TripStatus.completed,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: tripAsync.when(
          data: (trip) {
            final displayPrice = _optimisticPrice ?? trip.price;

            return Stack(
              children: [
                GoogleMap(
                  key: ValueKey('searching_map_${widget.tripId}'),
                  onMapCreated: (controller) {
                    mapController = controller;
                    mapController.setMapStyle(MapStyles.silverStyle);
                    Future.delayed(const Duration(milliseconds: 500), () {
                      final bounds =
                          widget.bounds ??
                          LatLngBounds(
                            southwest: LatLng(
                              widget.pickupLocation.latitude <
                                      widget.dropoffLocation.latitude
                                  ? widget.pickupLocation.latitude
                                  : widget.dropoffLocation.latitude,
                              widget.pickupLocation.longitude <
                                      widget.dropoffLocation.longitude
                                  ? widget.pickupLocation.longitude
                                  : widget.dropoffLocation.longitude,
                            ),
                            northeast: LatLng(
                              widget.pickupLocation.latitude >
                                      widget.dropoffLocation.latitude
                                  ? widget.pickupLocation.latitude
                                  : widget.dropoffLocation.latitude,
                              widget.pickupLocation.longitude >
                                      widget.dropoffLocation.longitude
                                  ? widget.pickupLocation.longitude
                                  : widget.dropoffLocation.longitude,
                            ),
                          );
                      mapController.animateCamera(
                        CameraUpdate.newLatLngBounds(bounds, 90),
                      );
                    });
                  },
                  initialCameraPosition: CameraPosition(
                    target: widget.pickupLocation,
                    zoom: 15,
                  ),
                  polylines: _directions != null
                      ? {
                          Polyline(
                            polylineId: const PolylineId('route_polyline'),
                            points: _directions!['polyline'] as List<LatLng>,
                            color: Colors.black,
                            width: 5,
                            startCap: Cap.roundCap,
                            endCap: Cap.roundCap,
                          ),
                        }
                      : widget.polylines != null && widget.polylines!.isNotEmpty
                      ? widget.polylines!
                      : {
                          Polyline(
                            polylineId: const PolylineId('fallback_route'),
                            points: [
                              widget.pickupLocation,
                              widget.dropoffLocation,
                            ],
                            color: Colors.black,
                            width: 4,
                            patterns: [
                              PatternItem.dash(20),
                              PatternItem.gap(10),
                            ],
                          ),
                        },
                  markers: {
                    if (_pickupIcon != null)
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: widget.pickupLocation,
                        icon: _pickupIcon!,
                        anchor: const Offset(0.5, 0.5),
                        zIndexInt: 2,
                      ),
                    if (widget.intermediateStops.isNotEmpty)
                      ...widget.intermediateStops.asMap().entries.map((entry) {
                        final index = entry.key;
                        final stop = entry.value;
                        return Marker(
                          markerId: MarkerId('stop_$index'),
                          position: stop.location,
                          icon:
                              _stopIcons[index] ??
                              BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueOrange,
                              ),
                          anchor: const Offset(0.5, 0.5),
                        );
                      }),
                    if (_dropoffIcon != null)
                      Marker(
                        markerId: const MarkerId('dropoff'),
                        position: widget.dropoffLocation,
                        icon: _dropoffIcon!,
                        anchor: const Offset(0.5, 0.5),
                        zIndexInt: 1,
                      ),
                  },
                  circles: _radarController != null ? {
                    Circle(
                      circleId: const CircleId('radar_pulse_1'),
                      center: widget.pickupLocation,
                      radius: _radarAnimation!.value,
                      fillColor: Colors.blueAccent.withValues(alpha: 0.08 * (1.0 - _radarController!.value)),
                      strokeColor: Colors.blueAccent.withValues(alpha: 0.25 * (1.0 - _radarController!.value)),
                      strokeWidth: 2,
                    ),
                    Circle(
                      circleId: const CircleId('radar_pulse_2'),
                      center: widget.pickupLocation,
                      radius: _radarAnimation!.value * 0.65,
                      fillColor: Colors.blueAccent.withValues(alpha: 0.12 * (1.0 - (_radarController!.value * 1.5).clamp(0.0, 1.0))),
                      strokeColor: Colors.blueAccent.withValues(alpha: 0.3 * (1.0 - (_radarController!.value * 1.5).clamp(0.0, 1.0))),
                      strokeWidth: 1,
                    ),
                  } : {},
                  zoomControlsEnabled: false,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // Address Summary HUD (Premium Glass)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 20,
                  right: 20,
                  child: PremiumGlassContainer(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    opacity: 0.95,
                    blur: 20,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.25,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildAddressRow(
                              "A",
                              widget.pickupAddress,
                              Colors.blueAccent,
                            ),
                            if (widget.intermediateStops.isNotEmpty)
                              ...widget.intermediateStops.asMap().entries.map((
                                entry,
                              ) {
                                final index = entry.key;
                                final stop = entry.value;
                                return Column(
                                  children: [
                                    const SizedBox(height: 12),
                                    _buildAddressRow(
                                      String.fromCharCode(66 + index),
                                      stop.address,
                                      Colors.orange,
                                    ),
                                  ],
                                );
                              }),
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                            const SizedBox(height: 12),
                            _buildAddressRow(
                              String.fromCharCode(
                                66 + widget.intermediateStops.length,
                              ),
                              widget.dropoffAddress,
                              Colors.black87,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Searching HUD - White, Flat, Full width
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 32,
                      bottom: 40,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.03),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                    backgroundColor: Colors.black12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.searchingDriver,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 500),
                                    transitionBuilder: (Widget child, Animation<double> animation) {
                                      return FadeTransition(opacity: animation, child: child);
                                    },
                                    child: Text(
                                      _dynamicMessages[_messageIndex],
                                      key: ValueKey<String>(_dynamicMessages[_messageIndex]),
                                      style: TextStyle(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _priceStatusDot(),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${l10n.yourOffer} · ${ref.read(pricingServiceProvider).getVehicleName(widget.vehicleType).toUpperCase()}",
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: TextStyle(
                                    color: _isPriceIncreasing
                                        ? Colors.green
                                        : Colors.black,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                  child: Text(
                                    "\$${displayPrice.toStringAsFixed(2)}",
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber[50]!.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber[300]!.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.flash_on_rounded, color: Colors.amber[800], size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    "PRIORITY MATCH",
                                    style: TextStyle(
                                      color: Colors.amber[900],
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "INCENTIVAR CONDUCTORES CERCANOS (MÁS RÁPIDO)",
                            style: TextStyle(
                              color: Colors.black38,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildIncentiveChip(1.0, trip.price),
                              const SizedBox(width: 8),
                              _buildIncentiveChip(2.0, trip.price),
                              const SizedBox(width: 8),
                              _buildIncentiveChip(3.0, trip.price),
                              const SizedBox(width: 8),
                              _buildIncentiveChip(5.0, trip.price),
                            ],
                          ),
                        ),

                        // Stats Row (KM, Time, Stops Cost)
                        if (widget.intermediateStops.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  Icons.add_location_alt_outlined,
                                  "\$${(widget.intermediateStops.length * (ref.read(pricingServiceProvider).getPricingConfig(trip.vehicleType)['base'] as double)).toStringAsFixed(2)}",
                                  "Parada extra",
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: TextButton(
                            onPressed: () => _cancelTrip(trip),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              backgroundColor: Colors.redAccent.withValues(
                                alpha: 0.1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              l10n.cancelTrip,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (e, s) => Center(
            child: Text(
              "Error: $e",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _priceStatusDot() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: _isPriceIncreasing ? Colors.black : Colors.green,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildAddressRow(String label, String address, Color color) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }



  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.black38,
          ),
        ),
      ],
    );
  }

  void _increasePriceWithAmount(double backendPrice, double amount) async {
    if (_isUpdatingPrice) return;

    final currentBase = _optimisticPrice ?? backendPrice;
    final newPrice = currentBase + amount;

    setState(() {
      _isPriceIncreasing = true;
      _isUpdatingPrice = true;
      _optimisticPrice = newPrice;
    });

    try {
      HapticFeedback.mediumImpact();
      await ref
          .read(tripControllerProvider.notifier)
          .updatePrice(widget.tripId, newPrice);
      if (mounted) setState(() => _isUpdatingPrice = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPriceIncreasing = false;
          _isUpdatingPrice = false;
          _optimisticPrice = backendPrice;
        });
      }
    }
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isPriceIncreasing = false);
    });
  }

  Widget _buildIncentiveChip(double amount, double backendPrice) {
    return GestureDetector(
      onTap: () => _increasePriceWithAmount(backendPrice, amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt_rounded,
              color: Colors.amber[700],
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              "+\$${amount.toStringAsFixed(0)}",
              style: const TextStyle(
                color: Colors.black87,
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
}
