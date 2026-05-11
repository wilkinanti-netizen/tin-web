import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/core/utils/marker_utils.dart';
import 'package:tincars/features/driver/presentation/screens/invoice_pdf_helper.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';

class DriverTripDetailScreen extends ConsumerStatefulWidget {
  final Trip trip;

  const DriverTripDetailScreen({super.key, required this.trip});

  @override
  ConsumerState<DriverTripDetailScreen> createState() =>
      _DriverTripDetailScreenState();
}

class _DriverTripDetailScreenState
    extends ConsumerState<DriverTripDetailScreen> {
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  Future<void> _loadMarkers() async {
    final pickupIcon = await MarkerUtils.createABMarker(
      letter: 'A',
      backgroundColor: Colors.blueAccent,
      foregroundColor: Colors.white,
      label: 'Recogida',
    );
    final dropoffIcon = await MarkerUtils.createABMarker(
      letter: 'B',
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      label: 'Destino',
    );

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.trip.pickupLocation,
          icon: pickupIcon,
        ),
        Marker(
          markerId: const MarkerId('dropoff'),
          position: widget.trip.dropoffLocation,
          icon: dropoffIcon,
        ),
      };

      // Agregar paradas intermedias
      for (int i = 0; i < widget.trip.intermediateStops.length; i++) {
        _markers.add(
          Marker(
            markerId: MarkerId('stop_$i'),
            position: widget.trip.intermediateStops[i].location,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
        );
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitBounds();
  }

  void _fitBounds() {
    if (_mapController == null) return;

    final LatLngBounds bounds;
    final p1 = widget.trip.pickupLocation;
    final p2 = widget.trip.dropoffLocation;

    double minLat = p1.latitude < p2.latitude ? p1.latitude : p2.latitude;
    double maxLat = p1.latitude > p2.latitude ? p1.latitude : p2.latitude;
    double minLng = p1.longitude < p2.longitude ? p1.longitude : p2.longitude;
    double maxLng = p1.longitude > p2.longitude ? p1.longitude : p2.longitude;

    for (var stop in widget.trip.intermediateStops) {
      if (stop.location.latitude < minLat) minLat = stop.location.latitude;
      if (stop.location.latitude > maxLat) maxLat = stop.location.latitude;
      if (stop.location.longitude < minLng) minLng = stop.location.longitude;
      if (stop.location.longitude > maxLng) maxLng = stop.location.longitude;
    }

    bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _showReceipt(Trip trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReceiptModal(trip: trip),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the trip in real-time
    final tripAsync = ref.watch(tripStreamProvider(widget.trip.id));

    return tripAsync.when(
      data: (trip) {
        final dateStr = DateFormat(
          'EEEE, d MMMM yyyy',
          'es',
        ).format(trip.createdAt);
        final timeStr = DateFormat('hh:mm a').format(trip.createdAt);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(
              'Detalle del Viaje',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mapa
                SizedBox(
                  height: 250,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: widget.trip.pickupLocation,
                      zoom: 14,
                    ),
                    onMapCreated: _onMapCreated,
                    markers: _markers,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    liteModeEnabled: false,
                    buildingsEnabled: false,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fecha y Hora
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              color: Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Ruta
                      _buildRouteSection(trip),

                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Detalles del Vehículo
                      const Text(
                        'VEHÍCULO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              trip.vehicleType == 'moto'
                                  ? Icons.motorcycle_rounded
                                  : Icons.drive_eta_rounded,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.vehicleType.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const Text(
                                'Servicio completado',
                                style: TextStyle(
                                  color: Colors.black45,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Botón de Factura
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showReceipt(trip),
                          icon: const Icon(Icons.receipt_long_rounded),
                          label: const Text('VER RECIBO / FACTURA'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildRouteSection(Trip trip) {
    return Column(
      children: [
        _buildLocationRow(
          icon: Icons.circle,
          iconColor: Colors.blueAccent,
          address: trip.pickupAddress,
          label: 'Origen',
        ),
        if (trip.intermediateStops.isNotEmpty) ...[
          for (var stop in trip.intermediateStops)
            _buildLocationRow(
              icon: Icons.location_on_rounded,
              iconColor: Colors.grey,
              address: stop.address,
              label: 'Parada',
              isStop: true,
            ),
        ],
        _buildLocationRow(
          icon: Icons.square,
          iconColor: Colors.black,
          address: trip.dropoffAddress,
          label: 'Destino',
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String address,
    required String label,
    bool isLast = false,
    bool isStop = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Icon(icon, size: isStop ? 16 : 12, color: iconColor),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade200,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.black38,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptModal extends StatelessWidget {
  final Trip trip;

  const _ReceiptModal({required this.trip});

  @override
  Widget build(BuildContext context) {
    final total = trip.price;
    final tip = trip.tipAmount ?? 0.0;
    final driverEarning = (total * 0.75) + tip;
    final appFee = total * 0.25;

    return Container(
      margin: const EdgeInsets.only(top: 100),
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 32),
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 60),
          const SizedBox(height: 16),
          const Text(
            'RECIBO DE VIAJE',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          ),
          Text(
            '#${trip.id.substring(0, 8).toUpperCase()}',
            style: const TextStyle(
              color: Colors.black26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),

          _buildReceiptRow('Tarifa del viaje', '\$${total.toStringAsFixed(0)}'),
          if (tip > 0)
            _buildReceiptRow(
              'Propina',
              '\$${tip.toStringAsFixed(0)}',
              color: Colors.green,
            ),
          const Divider(height: 40),
          _buildReceiptRow(
            'Tu ganancia neta',
            '\$${driverEarning.toStringAsFixed(0)}',
            isBold: true,
            color: Colors.green,
          ),
          _buildReceiptRow(
            'Descuento App TinCars (25%)',
            '-\$${appFee.toStringAsFixed(0)}',
            color: Colors.redAccent,
          ),

          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.payment_rounded, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'MÉTODO DE PAGO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      trip.paymentMethod,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Completado',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'CERRAR',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => InvoicePdfHelper.generateAndPrintInvoice(trip),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('IMPRIMIR PDF'),
            style: TextButton.styleFrom(foregroundColor: Colors.black45),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.black87,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
