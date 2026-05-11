import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/core/utils/map_styles.dart';

class PaymentDetailsScreen extends StatefulWidget {
  final Trip trip;

  const PaymentDetailsScreen({super.key, required this.trip});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
  }

  Future<void> _loadCustomMarkers() async {
    final pickup = await _getMarkerIcon('A', Colors.blueAccent);
    final dropoff = await _getMarkerIcon('B', Colors.black);
    if (mounted) {
      setState(() {
        _pickupIcon = pickup;
        _dropoffIcon = dropoff;
      });
    }
  }

  Future<BitmapDescriptor> _getMarkerIcon(String label, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 70.0;

    // Draw shadow
    final Paint shadowPaint = Paint()..color = Colors.black.withOpacity(0.2);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, shadowPaint);

    // Draw colored circle
    final Paint circlePaint = Paint()..color = color;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 5,
      circlePaint,
    );

    // Draw white inner circle
    final Paint innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 15,
      innerPaint,
    );

    // Draw text
    final TextPainter textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: label,
      style: TextStyle(
        fontSize: 50.0,
        fontWeight: FontWeight.bold,
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
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    // Calculate bounds logic
    double minLat = widget.trip.pickupLocation.latitude;
    double maxLat = widget.trip.pickupLocation.latitude;
    double minLng = widget.trip.pickupLocation.longitude;
    double maxLng = widget.trip.pickupLocation.longitude;

    if (widget.trip.dropoffLocation.latitude < minLat)
      minLat = widget.trip.dropoffLocation.latitude;
    if (widget.trip.dropoffLocation.latitude > maxLat)
      maxLat = widget.trip.dropoffLocation.latitude;
    if (widget.trip.dropoffLocation.longitude < minLng)
      minLng = widget.trip.dropoffLocation.longitude;
    if (widget.trip.dropoffLocation.longitude > maxLng)
      maxLng = widget.trip.dropoffLocation.longitude;

    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Detalles del Viaje',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Mini Map with Shadow
            Container(
              height: 220,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: GoogleMap(
                onMapCreated: (controller) {
                  _mapController = controller;
                  _mapController!.setMapStyle(MapStyles.silverStyle);
                  // Fit bounds with delay to allow map to initialize properly
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted && _mapController != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngBounds(bounds, 40),
                      );
                    }
                  });
                },
                initialCameraPosition: CameraPosition(
                  target: widget.trip.pickupLocation,
                  zoom: 14,
                ),
                markers: {
                  if (_pickupIcon != null)
                    Marker(
                      markerId: const MarkerId('pickup'),
                      position: widget.trip.pickupLocation,
                      icon: _pickupIcon!,
                      anchor: const Offset(0.5, 0.5),
                    ),
                  if (_dropoffIcon != null)
                    Marker(
                      markerId: const MarkerId('dropoff'),
                      position: widget.trip.dropoffLocation,
                      icon: _dropoffIcon!,
                      anchor: const Offset(0.5, 0.5),
                    ),
                },
                liteModeEnabled:
                    false, // Must be false to use map style and animateCamera properly on some versions, but let's try true if it breaks. Actually, static maps don't support custom bounds easily. Let's use normal map but disabled gestures.
                zoomGesturesEnabled: false,
                scrollGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
              ),
            ),

            Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateFormat
                                  .format(widget.trip.createdAt)
                                  .toUpperCase(),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Viaje ${widget.trip.status.name}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color:
                                    widget.trip.status == TripStatus.cancelled
                                    ? Colors.red
                                    : Colors.black,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.trip.vehicleType.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Travel Route Line
                    _buildAddressTimeline(
                      pickup: widget.trip.pickupAddress,
                      dropoff: widget.trip.dropoffAddress,
                    ),

                    const SizedBox(height: 32),
                    const Divider(height: 1),
                    const SizedBox(height: 32),

                    const Text(
                      'Resumen de Recibo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildPriceRow('Tarifa base', widget.trip.price),
                    if (widget.trip.tipAmount != null &&
                        widget.trip.tipAmount! > 0)
                      _buildPriceRow('Propina', widget.trip.tipAmount!),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Colors.black12),
                    const SizedBox(height: 16),

                    _buildPriceRow(
                      'Total Pagado',
                      widget.trip.price + (widget.trip.tipAmount ?? 0),
                      isTotal: true,
                    ),

                    const SizedBox(height: 32),

                    // Payment Method Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              widget.trip.paymentMethod == 'Efectivo'
                                  ? Icons.payments_rounded
                                  : Icons.credit_card_rounded,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Método de pago",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.trip.paymentMethod,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.trip.paymentStatus != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.trip.paymentStatus == 'succeeded'
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.trip.paymentStatus == 'succeeded'
                                    ? 'Pagado'
                                    : 'Pendiente',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      widget.trip.paymentStatus == 'succeeded'
                                      ? Colors.green[700]
                                      : Colors.orange[700],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressTimeline({
    required String pickup,
    required String dropoff,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(Icons.my_location_rounded, size: 20, color: Colors.blue),
            Container(
              width: 2,
              height: 30,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.grey[300],
            ),
            const Icon(
              Icons.location_on_rounded,
              size: 20,
              color: Colors.black,
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Punto A",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pickup,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Punto B",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dropoff,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Colors.black : Colors.grey[700],
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontSize: isTotal ? 20 : 15,
              color: Colors.black,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
