import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/core/utils/map_styles.dart';
import 'package:tincars/core/widgets/premium_shimmer.dart';
import 'package:tincars/features/profile/presentation/screens/cards_screen.dart';
import 'package:tincars/features/trips/domain/services/stripe_service.dart';

class VehicleSelectionScreen extends ConsumerStatefulWidget {
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final String pickupAddress;
  final String dropoffAddress;
  final List<TripStop> intermediateStops;
  final double distanceInKm;
  final Set<Polyline> polylines;
  final LatLngBounds bounds;

  const VehicleSelectionScreen({
    super.key,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.intermediateStops = const [],
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
  final Map<int, BitmapDescriptor> _stopIcons = {};
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
            color: Colors.grey.withValues(alpha: 0.5), // Más visible
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
    // A: Pickup
    _pickupIcon = await _getMarkerIcon('A', Colors.blue);
    
    // B, C, ...: Intermediate Stops
    for (int i = 0; i < widget.intermediateStops.length; i++) {
      final char = String.fromCharCode(66 + i); // 66 is 'B'
      _stopIcons[i] = await _getMarkerIcon(char, Colors.orange);
    }
    
    // Last: Dropoff
    final lastChar = String.fromCharCode(66 + widget.intermediateStops.length);
    _dropoffIcon = await _getMarkerIcon(lastChar, Colors.red);
    
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
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2);
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

  // Extra Options State
  String _paymentMethod = 'Efectivo';
  String? _comment;
  bool _hasExtraLuggage = false;
  bool _hasPets = false;
  final Map<String, double> _priceAdjustments = {};

  void _createTripRequest() async {
    AppLogger.log('VehicleSelectionScreen: Iniciando _createTripRequest...');
    final user = FirebaseAuth.instance.currentUser;
    AppLogger.log('VehicleSelectionScreen: Usuario actual: ${user?.uid}');
    if (user == null) {
      AppLogger.log('VehicleSelectionScreen: ERROR - Usuario es null');
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final passengerEmoji = ref
        .read(userProfileProvider)
        .asData
        ?.value
        ?.mapEmoji;

    final trip = Trip(
      id: const Uuid().v4(),
      passengerId: user.uid,
      pickupLocation: widget.pickupLocation,
      dropoffLocation: widget.dropoffLocation,
      pickupAddress: widget.pickupAddress,
      dropoffAddress: widget.dropoffAddress,
      intermediateStops: widget.intermediateStops,
      distance: widget.distanceInKm,
      price:
          _pricingService.calculatePrice(
            widget.distanceInKm,
            _selectedVehicleType,
          ) +
          (_priceAdjustments[_selectedVehicleType] ?? 0.0) +
          (widget.intermediateStops.length *
              (_pricingService.getPricingConfig(_selectedVehicleType)['base'] as double)),
      status: TripStatus.requested,
      createdAt: DateTime.now(),
      vehicleType: _selectedVehicleType,
      paymentMethod: _paymentMethod,
      comment: _comment,
      hasExtraLuggage: _hasExtraLuggage,
      hasPets: _hasPets,
      passengerEmoji: passengerEmoji,
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
          'VehicleSelectionScreen: Pago con tarjeta seleccionada, iniciando Stripe PaymentSheet',
        );
        final price =
            _pricingService.calculatePrice(
              widget.distanceInKm,
              _selectedVehicleType,
            ) +
            (_priceAdjustments[_selectedVehicleType] ?? 0.0);

        // 1. Inicializar el PaymentSheet (llama a la Edge Function)
        final paymentData = await StripeService.instance.initPaymentSheet(
          user.uid,
          price,
          'usd', // Moneda en dólares
        );

        // 2. Mostrar la pasarela al usuario
        await StripeService.instance.displayPaymentSheet();

        // 3. Si llega aquí sin error, el pago fue autorizado
        // El ID real suele estar en el campo 'paymentIntent' de la respuesta o data['paymentIntentId']
        paymentIntentId = paymentData['paymentIntentId'] ?? 'pi_captured';
        paymentStatus = 'succeeded';

        AppLogger.log(
          'VehicleSelectionScreen: Pago exitoso con Stripe. ID: $paymentIntentId',
        );
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
        intermediateStops: trip.intermediateStops,
        distance: trip.distance,
        price: trip.price,
        status: trip.status,
        createdAt: trip.createdAt,
        vehicleType: trip.vehicleType,
        paymentMethod: _paymentMethod,
        comment: _comment,
        hasExtraLuggage: _hasExtraLuggage,
        hasPets: _hasPets,
        passengerEmoji: trip.passengerEmoji,
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
              intermediateStops: finalTrip.intermediateStops,
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
        final userProfileAsync = ref.watch(userProfileProvider);
        final cardsAsync = ref.watch(savedCardsProvider);
        final hasCard =
            cardsAsync.value != null && cardsAsync.value!.isNotEmpty;
        final card = hasCard ? cardsAsync.value!.first : null;
        final walletBalance = userProfileAsync.value?.walletBalance ?? 0.0;
        final currencyFormat = NumberFormat.currency(
          symbol: r'$',
          decimalDigits: 2,
        );

        final selectedBasePrice = _pricingService.calculatePrice(
          widget.distanceInKm,
          _selectedVehicleType,
        );
        final selectedAdjustment =
            _priceAdjustments[_selectedVehicleType] ?? 0.0;
        final estimatedTotal = selectedBasePrice + selectedAdjustment;
        final hasSufficientBalance = walletBalance >= estimatedTotal;

        final payments = [
          {
            'name': 'Efectivo',
            'icon': Icons.payments_outlined,
            'desc': 'Paga al finalizar el viaje',
            'enabled': true,
          },
          {
            'name': 'Billetera',
            'icon': Icons.account_balance_wallet_rounded,
            'desc': 'Saldo: ${currencyFormat.format(walletBalance)}',
            'enabled': hasSufficientBalance,
            'error': !hasSufficientBalance ? 'Saldo insuficiente' : null,
          },
          {
            'name': 'Tarjeta Crédito/Débito',
            'icon': Icons.credit_card_rounded,
            'desc': hasCard
                ? '•••• ${card!['last4']}'
                : 'Visa, MasterCard, Amex',
            'enabled': true,
          },
        ];

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "Método de Pago",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 4,
                  bottom: 20,
                ),
                child: Text(
                  "Selecciona cómo deseas pagar este viaje",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              ...payments.map((p) {
                final isSelected =
                    _paymentMethod == p['name'] ||
                    (_paymentMethod == 'Tarjeta' &&
                        p['name'] == 'Tarjeta Crédito/Débito');
                final isEnabled = p['enabled'] as bool;
                final errorText = p['error'] as String?;

                return GestureDetector(
                  onTap: isEnabled
                      ? () async {
                          if (p['name'] == 'Tarjeta Crédito/Débito') {
                            final cards = await ref.read(
                              savedCardsProvider.future,
                            );
                            if (cards.isEmpty && mounted) {
                              Navigator.pop(context); // Close the sheet
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CardsScreen(),
                                ),
                              );
                              return;
                            }
                          }

                          setState(() {
                            _paymentMethod = p['name'] as String;
                            if (_paymentMethod == 'Tarjeta Crédito/Débito' &&
                                hasCard) {
                              _paymentMethod = 'Tarjeta';
                            }
                          });
                          if (mounted) Navigator.pop(context);
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 6,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.black.withOpacity(0.02)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? Colors.black
                            : (errorText != null
                                  ? Colors.red.withOpacity(0.3)
                                  : Colors.grey[200]!),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            p['icon'] as IconData,
                            color: isSelected ? Colors.white : Colors.black87,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['name'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: isEnabled ? Colors.black : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p['desc'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isEnabled
                                      ? Colors.black54
                                      : Colors.grey,
                                ),
                              ),
                              if (errorText != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      errorText,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.black,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
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
        activeThumbColor: Colors.black,
        activeTrackColor: Colors.black.withValues(alpha: 0.5),
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
              mapController.setMapStyle(MapStyles.silverStyle);
              _updateMapBounds();
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
              ...widget.intermediateStops.asMap().entries.map((entry) {
                final index = entry.key;
                final stop = entry.value;
                return Marker(
                  markerId: MarkerId('stop_$index'),
                  position: stop.location,
                  icon: _stopIcons[index] ?? BitmapDescriptor.defaultMarker,
                  anchor: const Offset(0.5, 0.5),
                  infoWindow: InfoWindow(title: 'Parada ${index + 1}'),
                );
              }),
              if (_dropoffIcon != null)
                Marker(
                  markerId: const MarkerId('dropoff'),
                  position: widget.dropoffLocation,
                  icon: _dropoffIcon!,
                  anchor: const Offset(0.5, 0.5),
                ),
            },
            padding: const EdgeInsets.only(top: 160, bottom: 350),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    color: Colors.white,
                    opacity: 0.98,
                    borderRadius: BorderRadius.circular(20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.2,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildAddressRow(
                              icon: Icons.my_location_rounded,
                              label: "Punto A",
                              address: widget.pickupAddress,
                              color: Colors.blueAccent,
                              isFirst: true,
                            ),
                            if (widget.intermediateStops.isNotEmpty)
                              ...widget.intermediateStops.asMap().entries.map((entry) {
                                final index = entry.key;
                                final stop = entry.value;
                                final letter = String.fromCharCode(66 + index);
                                return _buildAddressRow(
                                  icon: Icons.add_location_alt_rounded,
                                  label: "Punto $letter",
                                  address: stop.address,
                                  color: Colors.orange,
                                  isFirst: true,
                                );
                              }),
                            _buildAddressRow(
                              icon: Icons.location_on_rounded,
                              label: "Punto ${String.fromCharCode(66 + widget.intermediateStops.length)}",
                              address: widget.dropoffAddress,
                              color: Colors.black,
                              isFirst: false,
                            ),
                          ],
                        ),
                      ),
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
                        ? Column(
                            children: List.generate(
                              3,
                              (index) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: PremiumShimmer(
                                  width: double.infinity,
                                  height: 70,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
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
                  
                  if (widget.intermediateStops.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_location_alt_rounded, size: 18, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            "${widget.intermediateStops.length} ${widget.intermediateStops.length == 1 ? 'parada añadida' : 'paradas añadidas'}",
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange),
                          ),
                          const Spacer(),
                          Text(
                            "+${_pricingService.formatPrice(widget.intermediateStops.length * (_pricingService.getPricingConfig(_selectedVehicleType)['base'] as double))}",
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ],
                      ),
                    ),

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
      CameraUpdate.newLatLngBounds(widget.bounds, 50),
    );
  }

  Widget _buildAddressRow({
    required IconData icon,
    required String label,
    required String address,
    required Color color,
    required bool isFirst,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Column
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Icon(icon, size: 16, color: color)),
                ),
                if (isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Content Column
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isFirst ? 16.0 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
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

  Widget _buildPriceButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
            ),
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
    final stopCharges = widget.intermediateStops.length * (_pricingService.getPricingConfig(type)['base'] as double);
    final finalPrice = basePrice + adjustment + stopCharges;

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
