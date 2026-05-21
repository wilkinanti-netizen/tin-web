import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/domain/services/pricing_service.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/l10n/app_localizations.dart';
import 'package:tincars/features/passenger/presentation/screens/searching_driver_screen.dart';
import "package:tincars/core/widgets/premium_glass_container.dart";
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/core/utils/map_styles.dart';
import 'package:tincars/core/widgets/premium_shimmer.dart';
import 'package:tincars/features/profile/presentation/screens/cards_screen.dart';
import 'package:tincars/features/trips/domain/services/stripe_service.dart';
import 'package:tincars/core/utils/marker_utils.dart';
import 'package:tincars/core/services/realtime_location_service.dart';
import 'package:tincars/core/services/surge_pricing_service.dart';

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
    _pickupIcon = await MarkerUtils.createABMarker(
      letter: 'A',
      backgroundColor: Colors.blueAccent,
      foregroundColor: Colors.white,
      label: 'Recogida',
    );

    // B, C, ...: Intermediate Stops
    for (int i = 0; i < widget.intermediateStops.length; i++) {
      final char = String.fromCharCode(66 + i); // 66 is 'B'
      _stopIcons[i] = await MarkerUtils.createABMarker(
        letter: char,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        label: 'Parada ${i + 1}',
      );
    }

    // Last: Dropoff
    final lastChar = String.fromCharCode(66 + widget.intermediateStops.length);
    _dropoffIcon = await MarkerUtils.createABMarker(
      letter: lastChar,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      label: 'Destino',
    );

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

    HapticFeedback.mediumImpact();
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
          ref
              .read(pricingServiceProvider)
              .calculatePrice(widget.distanceInKm, _selectedVehicleType) +
          (_priceAdjustments[_selectedVehicleType] ?? 0.0) +
          (widget.intermediateStops.length *
              (ref
                      .read(pricingServiceProvider)
                      .getPricingConfig(_selectedVehicleType)['base']
                  as double)),
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
            ref
                .read(pricingServiceProvider)
                .calculatePrice(widget.distanceInKm, _selectedVehicleType) +
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
      } else {}

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

      // Record demand in RTDB for heatmap visualization
      RealtimeLocationService.instance.recordTripDemand(
        widget.pickupLocation.latitude,
        widget.pickupLocation.longitude,
      );

      // Apply surge pricing if applicable
      final surgeMultiplier = await SurgePricingService.instance
          .getSurgeMultiplier(widget.pickupLocation);
      final surgedPrice = finalTrip.price * surgeMultiplier;

      final tripWithSurge = Trip(
        id: finalTrip.id,
        passengerId: finalTrip.passengerId,
        pickupLocation: finalTrip.pickupLocation,
        dropoffLocation: finalTrip.dropoffLocation,
        pickupAddress: finalTrip.pickupAddress,
        dropoffAddress: finalTrip.dropoffAddress,
        intermediateStops: finalTrip.intermediateStops,
        distance: finalTrip.distance,
        price: double.parse(surgedPrice.toStringAsFixed(2)),
        status: finalTrip.status,
        createdAt: finalTrip.createdAt,
        vehicleType: finalTrip.vehicleType,
        paymentMethod: finalTrip.paymentMethod,
        comment: finalTrip.comment,
        hasExtraLuggage: finalTrip.hasExtraLuggage,
        hasPets: finalTrip.hasPets,
        passengerEmoji: finalTrip.passengerEmoji,
        paymentIntentId: finalTrip.paymentIntentId,
        paymentStatus: finalTrip.paymentStatus,
      );

      // Trigger the request
      await ref.read(tripControllerProvider.notifier).createTrip(tripWithSurge);
      AppLogger.log('VehicleSelectionScreen: Llamada a createTrip finalizada (surge: x${surgeMultiplier.toStringAsFixed(2)})');

      // Check for errors in the state after creation
      final controllerState = ref.read(tripControllerProvider);
      if (controllerState.hasError) {
        throw controllerState.error!;
      }

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

  Widget _buildTopAddressesOverview() {
    return PremiumGlassContainer(
      color: Colors.white,
      opacity: 0.95,
      blur: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAddressLine(
            "Punto A",
            widget.pickupAddress,
            Colors.blueAccent,
            true,
          ),
          for (int i = 0; i < widget.intermediateStops.length; i++)
            _buildAddressLine(
              "Parada ${i + 1}",
              widget.intermediateStops[i].address,
              Colors.orange,
              true,
            ),
          _buildAddressLine(
            "Destino",
            widget.dropoffAddress,
            Colors.redAccent,
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressLine(
    String label,
    String address,
    Color color,
    bool showLine,
  ) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (showLine)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: Colors.grey[300],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                address,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
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

        final selectedBasePrice = ref
            .read(pricingServiceProvider)
            .calculatePrice(widget.distanceInKm, _selectedVehicleType);
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
                            HapticFeedback.lightImpact();
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
    // Escuchar cambios en las tarjetas para establecer el método predeterminado
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(savedCardsProvider, (
      previous,
      next,
    ) {
      if (next.hasValue &&
          next.value!.isNotEmpty &&
          _paymentMethod == 'Efectivo') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _paymentMethod = 'Tarjeta';
            });
            AppLogger.log(
              'VehicleSelectionScreen: Tarjeta detectada, cambiando método predeterminado a Tarjeta',
            );
          }
        });
      }
    });

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Full Screen Map
          GoogleMap(
            onMapCreated: (controller) {
              mapController = controller;
              controller.setMapStyle(MapStyles.silverStyle);
              _updateMapBounds();
            },
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height * 0.62,
              top: 50,
            ),
            initialCameraPosition: CameraPosition(
              target: widget.pickupLocation,
              zoom: 15,
            ),
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
            polylines: _mapPolylines,
            zoomControlsEnabled: false,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 2. Top Header (Back + Route Overview)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildTopAddressesOverview()),
              ],
            ),
          ),

          // 3. Bottom Selection Panel - Static Fixed Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  // Vehicle List (shrink-wrapped, no scroll needed)
                  if (_isLoadingServices)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: List.generate(
                          3,
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: PremiumShimmer(
                              width: double.infinity,
                              height: 72,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    ..._availableServices.map((type) {
                      final config = ref
                          .read(pricingServiceProvider)
                          .getPricingConfig(type);
                      final isSelected = _selectedVehicleType == type;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 3,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedVehicleType = type);
                          },
                          child: _buildServiceCard(
                            config['name'],
                            _getVehicleAssetForType(type),
                            ref
                                .read(pricingServiceProvider)
                                .formatPrice(
                                  ref
                                          .read(pricingServiceProvider)
                                          .calculatePrice(
                                            widget.distanceInKm,
                                            type,
                                          ) +
                                      (widget.intermediateStops.length *
                                          (config['base'] as double)),
                                ),
                            isSelected,
                            type,
                          ),
                        ),
                      );
                    }),

                  // Footer: Payment + Request + Options
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      MediaQuery.of(context).padding.bottom + 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Left: Payment
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showPaymentMethodsSheet();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getPaymentIcon(),
                              size: 24,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Center: Confirm Button
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isSearching
                                  ? null
                                  : _createTripRequest,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isSearching
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      l10n.requestTrip.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Right: Options
                        GestureDetector(
                          onTap: _showOptionsDialog,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Stack(
                              children: [
                                const Icon(
                                  Icons.tune_rounded,
                                  size: 24,
                                  color: Colors.black,
                                ),
                                if (_hasExtraLuggage ||
                                    _hasPets ||
                                    (_comment != null && _comment!.isNotEmpty))
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
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
    );
  }

  void _showVehicleInfoScreen(String type) {
    HapticFeedback.mediumImpact();
    final config = ref.read(pricingServiceProvider).getPricingConfig(type);
    final capacity = ref.read(pricingServiceProvider).getVehicleCapacity(type);
    final description = ref
        .read(pricingServiceProvider)
        .getVehicleDescription(type);
    final basePrice = ref
        .read(pricingServiceProvider)
        .calculatePrice(widget.distanceInKm, type);
    final stopCharges =
        widget.intermediateStops.length * (config['base'] as double);
    final suggestedPrice = basePrice + stopCharges;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final adjustment = _priceAdjustments[type] ?? 0.0;
            final priceHint = ref
                .read(pricingServiceProvider)
                .formatPrice(suggestedPrice);

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  config['name'],
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                centerTitle: true,
              ),
              body: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Hero(
                              tag: 'info_car_$type',
                              child: Image.asset(
                                _getVehicleAssetForType(type),
                                width: 250,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            "Sobre este servicio",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.people_alt_rounded,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "Capacidad: $capacity personas",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          const Text(
                            "Tu propuesta de precio",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Puedes ajustar el precio para que los conductores acepten más rápido tu viaje.",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                          ),
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            hintText: priceHint,
                                            prefixText: r"$ ",
                                            prefixStyle: const TextStyle(
                                              fontSize: 20,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          onChanged: (value) {
                                            final val = value.replaceAll(
                                              RegExp(r'[^0-9.]'),
                                              '',
                                            );
                                            final newPrice = double.tryParse(
                                              val,
                                            );
                                            if (newPrice != null) {
                                              if (newPrice >= suggestedPrice) {
                                                setModalState(() {
                                                  _priceAdjustments[type] =
                                                      newPrice - suggestedPrice;
                                                });
                                                setState(() {});
                                              }
                                            }
                                          },
                                          controller:
                                              TextEditingController.fromValue(
                                                TextEditingValue(
                                                  text:
                                                      (suggestedPrice +
                                                              adjustment)
                                                          .toStringAsFixed(0),
                                                  selection:
                                                      TextSelection.collapsed(
                                                        offset:
                                                            (suggestedPrice +
                                                                    adjustment)
                                                                .toStringAsFixed(
                                                                  0,
                                                                )
                                                                .length,
                                                      ),
                                                ),
                                              ),
                                        ),
                                        const Text(
                                          "Toca para editar el precio",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  _buildAdjustButton(Icons.add_rounded, () {
                                    setModalState(() {
                                      _priceAdjustments[type] =
                                          adjustment + 1.0;
                                    });
                                    setState(() {});
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          "CONFIRMAR PROPUESTA",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: const Offset(0, 0),
          ).animate(anim1),
          child: child,
        );
      },
    );
  }

  Widget _buildAdjustButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black, size: 24),
      ),
    );
  }

  String _getVehicleAssetForType(String type) {
    switch (type) {
      case 'essentials_xl':
        return 'assets/vehiculos/essentialxl.png';
      case 'executive':
        return 'assets/vehiculos/executive.png';
      case 'signature_lux':
        return 'assets/vehiculos/signatuve.png';
      default:
        return 'assets/vehiculos/essentials.png';
    }
  }

  void _updateMapBounds() {
    mapController.animateCamera(
      CameraUpdate.newLatLngBounds(widget.bounds, 15),
    );
  }

  Widget _buildServiceCard(
    String title,
    String assetPath,
    String subtitle,
    bool isSelected,
    String type,
  ) {
    final capacity = ref.read(pricingServiceProvider).getVehicleCapacity(type);
    final description = ref
        .read(pricingServiceProvider)
        .getVehicleDescription(type);
    final basePrice = ref
        .read(pricingServiceProvider)
        .calculatePrice(widget.distanceInKm, type);
    final adjustment = _priceAdjustments[type] ?? 0.0;
    final stopCharges =
        widget.intermediateStops.length *
        (ref.read(pricingServiceProvider).getPricingConfig(type)['base']
            as double);
    final finalPrice = basePrice + adjustment + stopCharges;

    return GestureDetector(
      onTap: () => setState(() => _selectedVehicleType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black.withOpacity(0.04) : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey[100]!,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                const SizedBox(width: 4),
                Image.asset(
                  assetPath,
                  width: 60,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.directions_car_rounded,
                    size: 28,
                    color: Colors.black26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.person_rounded,
                            size: 11,
                            color: Colors.grey[600],
                          ),
                          Text(
                            " $capacity",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          // Price displayed next to name
                          Text(
                            ref
                                .read(pricingServiceProvider)
                                .formatPrice(finalPrice),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            // Elegant premium +$1 pill chip
                            GestureDetector(
                              onTap: () {
                                final current = _priceAdjustments[type] ?? 0.0;
                                setState(
                                  () => _priceAdjustments[type] = current + 1.0,
                                );
                                HapticFeedback.selectionClick();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1a1a1a),
                                      Color(0xFF3d3d3d),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      '\$1',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // Keep right spacing so the info icon doesn't overlap
                          const SizedBox(width: 22),
                        ],
                      ),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                onTap: () => _showVehicleInfoScreen(type),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
