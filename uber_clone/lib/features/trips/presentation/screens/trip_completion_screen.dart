import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/trips/presentation/screens/rating_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
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
    final driverDataAsync = widget.isDriver
        ? null
        : (trip.driverId != null
              ? ref.watch(otherDriverProfileProvider(trip.driverId!))
              : null);

    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                // ── Check animado ──

                // ── Título ──
                Text(
                  widget.isDriver
                      ? 'Viaje completado'
                      : 'Llegaste a tu destino',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isDriver
                      ? 'Tu ganancia ha sido registrada'
                      : 'Esperamos que hayas tenido un excelente viaje',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // ── Tarifa ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.isDriver ? 'GANANCIA FINAL' : 'TOTAL PAGADO',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${trip.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${trip.paymentMethod} ',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.35),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Ruta ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    children: [
                      _buildRouteRow(
                        Icons.my_location_rounded,
                        Colors.blueAccent,
                        'RECOGIDA',
                        trip.pickupAddress,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 9),
                        child: Column(
                          children: List.generate(
                            2,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              width: 1.5,
                              height: 3,
                              color: Colors.black.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                      ),
                      _buildRouteRow(
                        Icons.flag_rounded,
                        Colors.black,
                        'DESTINO FINAL',
                        trip.dropoffAddress,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Info conductor / pasajero ──
                otherUserAsync.when(
                  data: (user) {
                    if (user == null) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.05,
                            ),
                            backgroundImage: user.avatarUrl != null
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                            child: user.avatarUrl == null
                                ? const Icon(
                                    Icons.person_rounded,
                                    color: Colors.black26,
                                    size: 28,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.fullName,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                if (!widget.isDriver &&
                                    driverDataAsync != null) ...[
                                  driverDataAsync.when(
                                    data: (d) => Text(
                                      '${d?.vehicleModel ?? ''} • ${d?.vehiclePlate ?? ''}',
                                      style: TextStyle(
                                        color: Colors.black.withValues(
                                          alpha: 0.45,
                                        ),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    loading: () => const SizedBox.shrink(),
                                    error: (_, __) => const SizedBox.shrink(),
                                  ),
                                ] else
                                  Text(
                                    widget.isDriver
                                        ? 'Pasajero'
                                        : 'Tu conductor',
                                    style: TextStyle(
                                      color: Colors.black.withValues(
                                        alpha: 0.45,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user.averageRating?.toStringAsFixed(1) ?? '5.0',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // ── Botón calificar ──
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      AppLogger.log(
                        '[APP] Navegando a calificar viaje ${trip.id}',
                      );
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RatingScreen(
                            trip: trip,
                            isDriver: widget.isDriver,
                            otherUserName:
                                otherUserAsync.value?.fullName ??
                                (widget.isDriver ? 'Pasajero' : 'Conductor'),
                            otherUserAvatarUrl: otherUserAsync.value?.avatarUrl,
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
                      elevation: 4,
                      shadowColor: Colors.black26,
                    ),
                    child: const Text(
                      'CALIFICAR SERVICIO',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Saltar ──
                TextButton(
                  onPressed: () {
                    AppLogger.log(
                      '[APP] Calificación omitida para viaje ${trip.id}',
                    );
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: Text(
                    'Omitir',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteRow(
    IconData icon,
    Color color,
    String label,
    String address,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.3),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
}
