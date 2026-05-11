import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/passenger/presentation/screens/passenger_rating_screen.dart';
import 'package:tincars/features/driver/presentation/screens/driver_rating_screen.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:flutter/services.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:intl/intl.dart';
import 'package:tincars/core/utils/app_logger.dart';

class TripCompletionScreen extends ConsumerStatefulWidget {
  final Trip trip;
  final bool isDriver;

  const TripCompletionScreen({
    super.key,
    required this.trip,
    this.isDriver = false,
  });

  @override
  ConsumerState<TripCompletionScreen> createState() =>
      _TripCompletionScreenState();
}

class _TripCompletionScreenState extends ConsumerState<TripCompletionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  double? _localTip;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0, 0.5, curve: Curves.easeIn),
    );
    AppLogger.log(
      'TripCompletionScreen: Inicializando para ${widget.isDriver ? "CONDUCTOR" : "PASAJERO"} - Viaje: ${widget.trip.id}',
    );
    _localTip = widget.trip.tipAmount;
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final otherUserId = widget.isDriver
        ? trip.passengerId
        : (trip.driverId ?? '');
    final otherUserAsync = ref.watch(otherUserProfileProvider(otherUserId));
    final dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(trip.createdAt);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    PremiumGlassContainer(
                      color: Colors.white,
                      opacity: 0.9,
                      blur: 20,
                      borderRadius: BorderRadius.circular(32),
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'RECIBO DE VIAJE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(
                                Icons.directions_car_rounded,
                                size: 24,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Divider(height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '\$',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                trip.price.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -2,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          if (widget.isDriver) ...[
                            Text(
                              'PRECIO TOTAL DEL VIAJE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.black.withValues(alpha: 0.3),
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.black.withOpacity(0.05),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _buildBreakdownRow(
                                    'Tarifa base',
                                    '\$${(trip.price - (trip.waitFee ?? 0)).toStringAsFixed(0)}',
                                  ),
                                  if (trip.waitFee != null && trip.waitFee! > 0) ...[
                                    const SizedBox(height: 8),
                                    _buildBreakdownRow(
                                      'Cargo por espera',
                                      '+\$${trip.waitFee!.toStringAsFixed(0)}',
                                      color: Colors.orange,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  _buildBreakdownRow(
                                    'Comisión TinCars (25%)',
                                    '-\$${(trip.price * 0.25).toStringAsFixed(0)}',
                                    isNegative: true,
                                  ),
                                  if (trip.tipAmount != null &&
                                      trip.tipAmount! > 0) ...[
                                    const SizedBox(height: 8),
                                    _buildBreakdownRow(
                                      'Propina extra',
                                      '+\$${trip.tipAmount!.toStringAsFixed(0)}',
                                      color: Colors.green,
                                    ),
                                  ],
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(height: 1),
                                  ),
                                  _buildBreakdownRow(
                                    'TU GANANCIA NETA',
                                    '\$${((trip.price * 0.75) + (trip.tipAmount ?? 0)).toStringAsFixed(0)}',
                                    isBold: true,
                                    color: Colors.green,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Text(
                            trip.paymentMethod.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.blueAccent.withValues(alpha: 0.7),
                              letterSpacing: 1.5,
                            ),
                          ),
                          if (_localTip != null && _localTip! > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              '+ \$${_localTip!.toStringAsFixed(0)} PROPINA',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Colors.green,
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          _buildReceiptRow(
                            Icons.my_location_rounded,
                            'Recogida',
                            trip.pickupAddress,
                          ),
                          const SizedBox(height: 20),
                          _buildReceiptRow(
                            Icons.location_on_rounded,
                            'Destino',
                            trip.dropoffAddress,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Divider(height: 1),
                          ),
                          otherUserAsync.when(
                            data: (user) {
                              if (user == null) return const SizedBox.shrink();
                              return Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: user.avatarUrl != null
                                        ? NetworkImage(user.avatarUrl!)
                                        : null,
                                    child: user.avatarUrl == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          widget.isDriver
                                              ? 'Pasajero'
                                              : 'Conductor',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black.withValues(
                                              alpha: 0.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        user.averageRating?.toStringAsFixed(
                                              1,
                                            ) ??
                                            '5.0',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.isDriver) ...[
                      const SizedBox(height: 24),
                      _buildTippingSection(trip),
                    ],
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => widget.isDriver
                                  ? DriverRatingScreen(
                                      trip: trip,
                                      passengerName:
                                          otherUserAsync.value?.fullName ??
                                          'Pasajero',
                                      passengerAvatarUrl:
                                          otherUserAsync.value?.avatarUrl,
                                    )
                                  : PassengerRatingScreen(
                                      trip: trip,
                                      driverName:
                                          otherUserAsync.value?.fullName ??
                                          'Conductor',
                                      driverAvatarUrl:
                                          otherUserAsync.value?.avatarUrl,
                                    ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 8,
                          shadowColor: Colors.black26,
                        ),
                        child: const Text(
                          'CALIFICAR SERVICIO',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                      child: Text(
                        'Omitir',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.3),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTippingSection(Trip trip) {
    final tip10 = trip.price * 0.1;
    final tip15 = trip.price * 0.15;
    final tip20 = trip.price * 0.2;

    return Column(
      children: [
        const Text(
          '¿Deseas agregar una propina?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTipButton('10%', tip10),
              const SizedBox(width: 12),
              _buildTipButton('15%', tip15),
              const SizedBox(width: 12),
              _buildTipButton('20%', tip20),
              const SizedBox(width: 12),
              _buildTipButton('Otro', 0, isCustom: true),
            ],
          ),
        ),
        if (_localTip != null && _localTip! > 0) ...[
          const SizedBox(height: 16),
          Text(
            'Propina de \$${_localTip!.toStringAsFixed(0)} agregada',
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTipButton(String label, double amount, {bool isCustom = false}) {
    final isSelected = _localTip == amount && amount > 0;

    return GestureDetector(
      onTap: () async {
        if (isCustom) {
          final customAmount = await _showCustomTipDialog();
          if (customAmount != null && customAmount > 0) {
            _applyTip(customAmount);
          }
        } else {
          _applyTip(amount);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.black12,
            width: 1.5,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
            if (!isCustom)
              Text(
                '\$${amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black38,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<double?> _showCustomTipDialog() async {
    final controller = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Propina personalizada'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Monto de la propina',
            prefixText: '\$ ',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              Navigator.pop(context, val);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _applyTip(double amount) {
    HapticFeedback.lightImpact();
    setState(() {
      _localTip = amount;
    });
    ref.read(tripControllerProvider.notifier).updateTip(widget.trip.id, amount);
  }

  Widget _buildReceiptRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.black38),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.black.withValues(alpha: 0.3),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
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
      ],
    );
  }

  Widget _buildBreakdownRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
    bool isNegative = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 12 : 11,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: color ?? (isBold ? Colors.black : Colors.black54),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: FontWeight.w900,
            color: color ?? (isNegative ? Colors.redAccent : Colors.black),
          ),
        ),
      ],
    );
  }
}
