import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/domain/services/pricing_service.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/l10n/app_localizations.dart';
import 'package:tincars/features/trips/presentation/screens/searching_driver_screen.dart';
import 'package:tincars/features/trips/presentation/screens/service_details_screen.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:tincars/features/profile/presentation/screens/cards_screen.dart';

class VehicleSelectionScreen extends ConsumerStatefulWidget {
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final String pickupAddress;
  final String dropoffAddress;
  final double distanceInKm;
  final Set<Polyline> polylines;
  final LatLngBounds bounds;

  const VehicleSelectionScreen({
    super.key,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.distanceInKm,
    required this.polylines,
    required this.bounds,
  });

  @override
  ConsumerState<VehicleSelectionScreen> createState() =>
      _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends ConsumerState<VehicleSelectionScreen>
    with SingleTickerProviderStateMixin {
  String _selectedVehicleType = 'essentials';
  final PricingService _pricingService = PricingService();
  bool _isSearching = false;
  late GoogleMapController mapController;

  // Map Animation State
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  late AnimationController _polylineAnimationController;
  List<LatLng> _animatedPolylinePoints = [];
  Set<Polyline> _mapPolylines = {};

  // Active Vehicle Filters
  Set<String> _availableServices = {};
  bool _isLoadingServices = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableServices();
    _polylineAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _polylineAnimationController.addListener(_updateAnimatedPolyline);

    _createCustomMarkers();
  }

  @override
  void dispose() {
    _polylineAnimationController.dispose();
    super.dispose();
  }

  void _updateAnimatedPolyline() {
    if (widget.polylines.isEmpty) return;

    final points = widget.polylines.first.points;
    if (points.isEmpty) return;

    final progress = _polylineAnimationController.value;
    final totalPoints = points.length;
    final visibleCount = (totalPoints * progress).toInt();

    if (mounted) {
      setState(() {
        _animatedPolylinePoints = points.sublist(
          0,
          visibleCount.clamp(1, totalPoints),
        );
        _mapPolylines = {
          // Background static polyline
          Polyline(
            polylineId: const PolylineId('route_bg'),
            points: points,
            color: Colors.grey.withAlpha(150), // Más visible
            width: 4,
          ),
          // Animated moving polyline
          Polyline(
            polylineId: const PolylineId('route_animated'),
            points: _animatedPolylinePoints,
            color: Colors.black,
            width: 5,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        };
      });
    }
  }

  Future<void> _createCustomMarkers() async {
    _pickupIcon = await _getMarkerIcon('A', Colors.blue);
    _dropoffIcon = await _getMarkerIcon('B', Colors.red);
    if (mounted) setState(() {});
  }

  Future<void> _loadAvailableServices() async {
    // Show all vehicles directly
    if (mounted) {
      setState(() {
        _availableServices = {
          'essentials',
          'essentials_xl',
          'executive',
          'signature_lux',
        };
        _isLoadingServices = false;
        if (!_availableServices.contains(_selectedVehicleType)) {
          _selectedVehicleType = _availableServices.first;
        }
      });
    }
  }

  Future<BitmapDescriptor> _getMarkerIcon(String label, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 70.0; // Más pequeño

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
      textDirection: TextDirection.ltr,
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

  // Extra Options State
  String _paymentMethod = 'Efectivo';
  String? _comment;
  bool _hasExtraLuggage = false;
  bool _hasPets = false;
  final Map<String, double> _priceAdjustments = {};

  void _createTripRequest() async {
    AppLogger.log('VehicleSelectionScreen: Iniciando _createTripRequest...');
    final user = Supabase.instance.client.auth.currentUser;
    AppLogger.log('VehicleSelectionScreen: Usuario actual: ${user?.id}');
    if (user == null) {
      AppLogger.log('VehicleSelectionScreen: ERROR - Usuario es null');
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final trip = Trip(
      id: const Uuid().v4(),
      passengerId: user.id,
      pickupLocation: widget.pickupLocation,
      dropoffLocation: widget.dropoffLocation,
      pickupAddress: widget.pickupAddress,
      dropoffAddress: widget.dropoffAddress,
      distance: widget.distanceInKm,
      price:
          _pricingService.calculatePrice(
            widget.distanceInKm,
            _selectedVehicleType,
          ) +
          (_priceAdjustments[_selectedVehicleType] ?? 0.0),
      status: TripStatus.requested,
      createdAt: DateTime.now(),
      vehicleType: _selectedVehicleType,
      paymentMethod: _paymentMethod,
      comment: _comment,
      hasExtraLuggage: _hasExtraLuggage,
      hasPets: _hasPets,
    );

    AppLogger.log('===================================================');
    AppLogger.log('🚗 CREANDO SOLICITUD DE VIAJE 🚗');
    AppLogger.log('🆔 Trip ID: ${trip.id}');
    AppLogger.log('👤 Pasajero ID: ${trip.passengerId}');
    print(
      '🚘 Tipo de Vehículo: ${trip.vehicleType} <--- ASEGURATE DE ESTAR ONLINE EN ESTE TIPO',
    );
    AppLogger.log('📊 Distancia: ${trip.distance} km');
    AppLogger.log('💲 Precio: ${trip.price}');
    AppLogger.log('💳 Pago: $_paymentMethod');
    AppLogger.log('===================================================');

    try {
      AppLogger.log('VehicleSelectionScreen: Procesando flujo de pago...');
      // SI EL PAGO ES POR TARJETA, PROCESAR STRIPE PRIMERO
      String? paymentIntentId;
      String? paymentStatus;

      if (_paymentMethod == 'Tarjeta') {
        AppLogger.log(
          'VehicleSelectionScreen: Pago con tarjeta seleccionada, saltando PaymentSheet ya que la tarjeta está guardada',
        );
        // Omitimos llamar a StripeService.instance.initPaymentSheet
        // ya que el usuario configuró su tarjeta previamente en CardsScreen.
        // El backend/cloud functions se encargará de cobrar a la tarjeta guardada.

        paymentIntentId = 'pi_mock_success';
        paymentStatus = 'succeeded';
      } else {
        print(
          'VehicleSelectionScreen: Pago en efectivo seleccionado, saltando Stripe',
        );
      }

      final finalTrip = Trip(
        id: trip.id,
        passengerId: trip.passengerId,
        pickupLocation: trip.pickupLocation,
        dropoffLocation: trip.dropoffLocation,
        pickupAddress: trip.pickupAddress,
        dropoffAddress: trip.dropoffAddress,
        distance: trip.distance,
        price: trip.price,
        status: trip.status,
        createdAt: trip.createdAt,
        vehicleType: trip.vehicleType,
        paymentMethod: _paymentMethod,
        comment: _comment,
        hasExtraLuggage: _hasExtraLuggage,
        hasPets: _hasPets,
        paymentIntentId: paymentIntentId,
        paymentStatus: paymentStatus,
      );

      final tripId = finalTrip.id;
      print(
        'VehicleSelectionScreen: Llamando a tripController.createTrip para ID: $tripId',
      );

      // Trigger the request
      await ref.read(tripControllerProvider.notifier).createTrip(finalTrip);
      AppLogger.log('VehicleSelectionScreen: Llamada a createTrip finalizada');

      // Check for errors in the state after creation
      final controllerState = ref.read(tripControllerProvider);
      if (controllerState.hasError) {
        print(
          'VehicleSelectionScreen: ERROR detectado en controllerState: ${controllerState.error}',
        );
        throw controllerState.error!;
      }

      print(
        'VehicleSelectionScreen: controllerState sin errores. Verificando montado...',
      );
      if (mounted) {
        AppLogger.log(
          'VehicleSelectionScreen: Navegando a SearchingDriverScreen...',
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SearchingDriverScreen(
              tripId: finalTrip.id,
              pickupLocation: finalTrip.pickupLocation,
              dropoffLocation: finalTrip.dropoffLocation,
              pickupAddress: finalTrip.pickupAddress,
              dropoffAddress: finalTrip.dropoffAddress,
              polylines: _mapPolylines,
              bounds: widget.bounds,
              vehicleType: finalTrip.vehicleType,
            ),
          ),
        );
      }
    } catch (e, stack) {
      AppLogger.log(
        'VehicleSelectionScreen: ERROR general en _createTripRequest: $e',
      );
      debugPrint('Stack: $stack');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear el viaje: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  void _showPaymentMethodsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _buildPaymentSheet(),
    );
  }

  Widget _buildPaymentSheet() {
    return Consumer(
      builder: (context, ref, child) {
        final cardsAsync = ref.watch(savedCardsProvider);
        final hasCard =
            cardsAsync.value != null && cardsAsync.value!.isNotEmpty;
        final card = hasCard ? cardsAsync.value!.first : null;

        final payments = [
          {
            'name': 'Cash',
            'icon': Icons.payments_outlined,
            'desc': 'Pay at the end of the trip',
          },
          {
            'name': 'Credit/Debit Card',
            'icon': Icons.credit_card_rounded,
            'desc': hasCard
                ? '•••• ${card!['last4']}'
                : 'Visa, MasterCard, Amex',
          },
        ];

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "Select Payment Method",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              ...payments.map((p) {
                final isSelected =
                    _paymentMethod == p['name'] ||
                    (_paymentMethod == 'Tarjeta' &&
                        p['name'] == 'Credit/Debit Card');
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      p['icon'] as IconData,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    p['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    p['desc'] as String,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : null,
                  onTap: () async {
                    if (p['name'] == 'Credit/Debit Card') {
                      final cards = await ref.read(savedCardsProvider.future);
                      if (cards.isEmpty && mounted) {
                        Navigator.pop(context); // Close the sheet
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CardsScreen(),
                          ),
                        );
                        return; // Don't change selected payment method yet
                      }
                      setState(() {
                        _paymentMethod = 'Tarjeta';
                      });
                    } else {
                      setState(() {
                        _paymentMethod = p['name'] as String;
                      });
                    }
                    if (mounted) Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showOptionsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildOptionsSheet(),
    );
  }

  Widget _buildOptionsSheet() {
    final commentController = TextEditingController(text: _comment);
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Opciones adicionales",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildOptionToggle(
                title: "Llevo más equipaje / cosas",
                subtitle:
                    "Informa al conductor que llevas maletas o carga extra.",
                icon: Icons.inventory_2_outlined,
                value: _hasExtraLuggage,
                onChanged: (val) {
                  setModalState(() => _hasExtraLuggage = val);
                  setState(() => _hasExtraLuggage = val);
                },
              ),
              const SizedBox(height: 12),
              _buildOptionToggle(
                title: "Llevo mascotas",
                subtitle: "Informa que viajas con tu mejor amigo.",
                icon: Icons.pets_outlined,
                value: _hasPets,
                onChanged: (val) {
                  setModalState(() => _hasPets = val);
                  setState(() => _hasPets = val);
                },
              ),
              const SizedBox(height: 16),
              const Text(
                "Comentario para el conductor",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "Ej: Estoy en la puerta principal portón gris...",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                onChanged: (val) {
                  _comment = val;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Guardar selección",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getPaymentIcon() {
    switch (_paymentMethod) {
      case 'Google Pay':
        return Icons.account_balance_wallet_outlined;
      case 'Apple Pay':
        return Icons.apple;
      case 'Tarjeta':
      case 'Credit/Debit Card':
        return Icons.credit_card_rounded;
      default:
        return Icons.payments_outlined;
    }
  }

  Widget _buildOptionToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? Colors.black : Colors.transparent),
      ),
      child: SwitchListTile.adaptive(
        secondary: Icon(icon, color: Colors.black),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        value: value,
        activeColor: Colors.black,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final essentialsPrice = _pricingService.calculatePrice(
      widget.distanceInKm,
      'essentials',
    );
    final essentialsXlPrice = _pricingService.calculatePrice(
      widget.distanceInKm,
      'essentials_xl',
    );
    final executivePrice = _pricingService.calculatePrice(
      widget.distanceInKm,
      'executive',
    );
    final signatureLuxPrice = _pricingService.calculatePrice(
      widget.distanceInKm,
      'signature_lux',
    );

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              mapController = controller;
              // Retraso para asegurar que los marcadores ya se agregaron
              Future.delayed(const Duration(milliseconds: 500), () {
                _updateMapBounds();
              });
            },
            initialCameraPosition: CameraPosition(
              target: widget.pickupLocation,
              zoom: 15,
            ),
            polylines: _mapPolylines,
            markers: {
              if (_pickupIcon != null)
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: widget.pickupLocation,
                  icon: _pickupIcon!,
                  anchor: const Offset(0.5, 0.5),
                ),
              if (_dropoffIcon != null)
                Marker(
                  markerId: const MarkerId('dropoff'),
                  position: widget.dropoffLocation,
                  icon: _dropoffIcon!,
                  anchor: const Offset(0.5, 0.5),
                ),
            },
            zoomControlsEnabled: false,
            myLocationEnabled: false,
          ),

          // Address Summary (Repositioned to Top)
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              children: [
                FloatingActionButton.small(
                  onPressed: () => Navigator.pop(context),
                  backgroundColor: Colors.white,
                  elevation: 4,
                  child: const Icon(Icons.arrow_back, color: Colors.black),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PremiumGlassContainer(
                    padding: const EdgeInsets.all(12),
                    color: Colors.white,
                    opacity: 0.95,
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        _buildAddressRow(
                          "A",
                          widget.pickupAddress,
                          Colors.blue,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Divider(indent: 35, height: 1),
                        ),
                        _buildAddressRow(
                          "B",
                          widget.dropoffAddress,
                          Colors.black,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.35,
                    ),
                    child: _isLoadingServices
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.black,
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                if (_availableServices.contains('essentials'))
                                  _buildServiceCard(
                                    _pricingService.getVehicleName(
                                      'essentials',
                                    ),
                                    'assets/vehiculos/essentials.png',
                                    _pricingService.formatPrice(
                                      essentialsPrice,
                                    ),
                                    _selectedVehicleType == 'essentials',
                                    'essentials',
                                  ),
                                if (_availableServices.contains(
                                      'essentials_xl',
                                    ) ||
                                    _availableServices.contains(
                                      'essentialXL',
                                    )) ...[
                                  const SizedBox(height: 4),
                                  _buildServiceCard(
                                    _pricingService.getVehicleName(
                                      'essentials_xl',
                                    ),
                                    'assets/vehiculos/essentialxl.png',
                                    _pricingService.formatPrice(
                                      essentialsXlPrice,
                                    ),
                                    _selectedVehicleType == 'essentials_xl' ||
                                        _selectedVehicleType == 'essentialXL',
                                    'essentials_xl',
                                  ),
                                ],
                                if (_availableServices.contains(
                                  'executive',
                                )) ...[
                                  const SizedBox(height: 4),
                                  _buildServiceCard(
                                    _pricingService.getVehicleName('executive'),
                                    'assets/vehiculos/executive.png',
                                    _pricingService.formatPrice(executivePrice),
                                    _selectedVehicleType == 'executive',
                                    'executive',
                                  ),
                                ],
                                if (_availableServices.contains(
                                      'signature_lux',
                                    ) ||
                                    _availableServices.contains(
                                      'signature',
                                    )) ...[
                                  const SizedBox(height: 4),
                                  _buildServiceCard(
                                    _pricingService.getVehicleName(
                                      'signature_lux',
                                    ),
                                    'assets/vehiculos/signatuve.png',
                                    _pricingService.formatPrice(
                                      signatureLuxPrice,
                                    ),
                                    _selectedVehicleType == 'signature_lux' ||
                                        _selectedVehicleType == 'signature',
                                    'signature_lux',
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),

                  const SizedBox(height: 12),

                  // Redesigned Bottom Bar: [Payment] [Confirm] [Options]
                  Row(
                    children: [
                      // Payment Selection (Icon Only)
                      IconButton(
                        onPressed: _showPaymentMethodsSheet,
                        icon: Icon(
                          _getPaymentIcon(),
                          size: 22,
                          color: Colors.black87,
                        ),
                        constraints: const BoxConstraints(
                          minHeight: 50,
                          minWidth: 50,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Confirm Trip Button (Center)
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed:
                                (_isSearching || _availableServices.isEmpty)
                                ? null
                                : _createTripRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              disabledBackgroundColor: Colors.black26,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isSearching
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    l10n.confirmRide.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Options Button (Right) with Indicator Dot
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            onPressed: _showOptionsDialog,
                            icon: Icon(
                              _comment != null && _comment!.isNotEmpty ||
                                      _hasExtraLuggage ||
                                      _hasPets
                                  ? Icons.tune
                                  : Icons.more_horiz,
                              size: 20,
                            ),
                            constraints: const BoxConstraints(
                              minHeight: 50,
                              minWidth: 50,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey[100],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          if (_comment != null && _comment!.isNotEmpty ||
                              _hasExtraLuggage ||
                              _hasPets)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateMapBounds() {
    mapController.animateCamera(
      CameraUpdate.newLatLngBounds(widget.bounds, 70),
    );
  }

  Widget _buildAddressRow(String label, String address, Color color) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Icon(Icons.chevron_right, color: Colors.grey, size: 14),
      ],
    );
  }

  Widget _buildPriceButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
          ],
        ),
        child: Icon(icon, size: 18, color: Colors.black),
      ),
    );
  }

  Widget _buildServiceCard(
    String title,
    String assetPath,
    String subtitle,
    bool isSelected,
    String type,
  ) {
    final capacity = _pricingService.getVehicleCapacity(type);
    final description = _pricingService.getVehicleDescription(type);
    final basePrice = _pricingService.calculatePrice(widget.distanceInKm, type);
    final adjustment = _priceAdjustments[type] ?? 0.0;
    final finalPrice = basePrice + adjustment;

    return GestureDetector(
      onTap: () => setState(() => _selectedVehicleType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[100] : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Image.asset(
              assetPath,
              width: 80, // Aumentado
              height: 60, // Aumentado
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.directions_car,
                size: 40,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (isSelected)
                        Row(
                          children: [
                            _buildPriceButton(Icons.remove, () {
                              final current = _priceAdjustments[type] ?? 0.0;
                              // Allow decrementing by $1, but ensure finalPrice doesn't go below $1 total
                              if (basePrice + current - 1.0 >= 1.0) {
                                setState(
                                  () => _priceAdjustments[type] = current - 1.0,
                                );
                              }
                            }),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                _pricingService.formatPrice(finalPrice),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _buildPriceButton(Icons.add, () {
                              final current = _priceAdjustments[type] ?? 0.0;
                              setState(
                                () => _priceAdjustments[type] = current + 1.0,
                              );
                            }),
                          ],
                        )
                      else
                        Text(
                          _pricingService.formatPrice(finalPrice),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ServiceDetailsScreen(vehicleType: type),
                          ),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          size: 12,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.person, size: 10, color: Colors.grey),
                      Text(
                        " $capacity  •  ",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Removed the secondary Ajustar Precio row as it is now inline above
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
