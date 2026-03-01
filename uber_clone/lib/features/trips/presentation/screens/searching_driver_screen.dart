import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'dart:ui' as ui;
import 'package:tincars/features/trips/presentation/screens/trip_tracking_screen.dart';

import 'package:flutter/services.dart';
import 'package:tincars/l10n/app_localizations.dart';

class SearchingDriverScreen extends ConsumerStatefulWidget {
  final String tripId;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final String pickupAddress;
  final String dropoffAddress;
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
  bool _isPriceIncreasing = false;
  bool _isUpdatingPrice = false;
  Timer? _timeoutTimer;
  int _secondsWaiting = 0;
  double? _optimisticPrice;

  @override
  void initState() {
    super.initState();

    _createCustomMarkers();
    _startTimeout();
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
    _pickupIcon = await _getMarkerIcon('A', Colors.blueAccent);
    _dropoffIcon = await _getMarkerIcon('B', Colors.redAccent);

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

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _increasePrice(double backendPrice) async {
    if (_isUpdatingPrice) return;

    // Determine the base price to increase from
    final currentBase = _optimisticPrice ?? backendPrice;
    final newPrice = currentBase + 1.0; // Increment of 1.00

    setState(() {
      _isPriceIncreasing = true;
      _isUpdatingPrice = true;
      _optimisticPrice = newPrice;
    });

    try {
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

  void _cancelTrip() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          l10n.cancelRequestTitle,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          l10n.cancelRequestMessage,
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.no, style: const TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(
              l10n.yesCancel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref
          .read(tripControllerProvider.notifier)
          .updateStatus(widget.tripId, TripStatus.cancelled);
      if (mounted) Navigator.pop(context);
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

        if (trip.status == TripStatus.accepted ||
            trip.status == TripStatus.arrived ||
            trip.status == TripStatus.inProgress) {
          _timeoutTimer?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TripTrackingScreen(tripId: widget.tripId),
            ),
          );
        }
      }
    });

    return PopScope(
      canPop: false,
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
                  onMapCreated: (controller) {
                    mapController = controller;
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
                  polylines:
                      widget.polylines != null && widget.polylines!.isNotEmpty
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
                        zIndex: 2,
                      ),
                    if (_dropoffIcon != null)
                      Marker(
                        markerId: const MarkerId('dropoff'),
                        position: widget.dropoffLocation,
                        icon: _dropoffIcon!,
                        anchor: const Offset(0.5, 0.5),
                        zIndex: 1,
                      ),
                  },
                  zoomControlsEnabled: false,
                  myLocationEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // Removed advanced radar sweep overlay

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
                    child: Column(
                      children: [
                        _buildAddressRow(
                          "A",
                          widget.pickupAddress,
                          Colors.blueAccent,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 1,
                          color: Colors.black.withValues(alpha: 0.05),
                        ),
                        const SizedBox(height: 12),
                        _buildAddressRow(
                          "B",
                          widget.dropoffAddress,
                          Colors.black87,
                        ),
                      ],
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
                          color: Colors.black.withOpacity(0.05),
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
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.black,
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
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.connectingDrivers,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
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
                                      "${l10n.yourOffer} · ${widget.vehicleType.toUpperCase()}",
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
                            _buildGlassActionButton(
                              icon: Icons.add_circle_outline_rounded,
                              label: "${l10n.addPrice} \$1.00",
                              onTap: () => _increasePrice(trip.price),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: TextButton(
                            onPressed: _cancelTrip,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              backgroundColor: Colors.redAccent.withOpacity(
                                0.1,
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

  Widget _buildGlassActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Removed RadarSweepPainter completely
