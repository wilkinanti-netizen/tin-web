import 'package:tincars/core/utils/app_logger.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tincars/core/utils/marker_utils.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:geolocator/geolocator.dart';

class TripRequestCard extends ConsumerStatefulWidget {
  final Trip trip;
  final Position? driverPosition;
  final VoidCallback? onReject;

  const TripRequestCard({
    super.key,
    required this.trip,
    this.driverPosition,
    this.onReject,
  });

  @override
  ConsumerState<TripRequestCard> createState() => _TripRequestCardState();
}

class _TripRequestCardState extends ConsumerState<TripRequestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  int _secondsLeft = 30;
  Timer? _countdownTimer;

  void _handleIgnore() {
    _stopNotificationSound();
    ref
        .read(ignoredTripsProvider.notifier)
        .ignore(widget.trip.id, widget.trip.price);
    widget.onReject?.call();
  }

  void _stopNotificationSound() {
    // Helper for consistency
  }

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _slideController.forward();
    _startCountdown();
    _loadMarkers();
  }

  Future<void> _loadMarkers() async {
    final distToPickup = widget.driverPosition != null
        ? Geolocator.distanceBetween(
                widget.driverPosition!.latitude,
                widget.driverPosition!.longitude,
                widget.trip.pickupLocation.latitude,
                widget.trip.pickupLocation.longitude,
              ) /
              1000
        : 0.0;

    await MarkerUtils.createABMarker(
      letter: 'A',
      backgroundColor: Colors.white,
      foregroundColor: Colors.blueAccent,
      label: '${distToPickup.toStringAsFixed(1)} km',
    );

    await MarkerUtils.createABMarker(
      letter: 'B',
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      label: '${widget.trip.distance.toStringAsFixed(1)} km',
    );
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _handleIgnore();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passengerAsync = ref.watch(
      otherUserProfileProvider(widget.trip.passengerId),
    );
    final trip = widget.trip;

    final double distanceToPickup = widget.driverPosition != null
        ? Geolocator.distanceBetween(
                widget.driverPosition!.latitude,
                widget.driverPosition!.longitude,
                trip.pickupLocation.latitude,
                trip.pickupLocation.longitude,
              ) /
              1000
        : 0.0;

    final int timeToPickup = (distanceToPickup * 2.5 + 1).toInt().clamp(1, 999);
    final int tripTime = (trip.distance * 2.0 + 2).toInt().clamp(1, 999);

    return SlideTransition(
      position: _slideAnim,
      child: Container(
        color: Colors.white,
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              children: [
                // ── Badge NUEVO VIAJE + countdown ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'NUEVO VIAJE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Countdown
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _secondsLeft <= 5
                            ? Colors.redAccent
                            : Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$_secondsLeft',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // ── Precio Gigante ──
                Text(
                  '\$${trip.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 80,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    height: 1,
                  ),
                ),
                Text(
                  trip.paymentMethod.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 40),

                // ── Pasajero ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.black.withValues(alpha: 0.05),
                      backgroundImage: passengerAsync.value?.avatarUrl != null
                          ? NetworkImage(passengerAsync.value!.avatarUrl!)
                          : null,
                      child: passengerAsync.value?.avatarUrl == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.black54,
                              size: 32,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          passengerAsync.value?.fullName ?? 'Cargando...',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              passengerAsync.value?.averageRating
                                      ?.toStringAsFixed(1) ??
                                  '5.0',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                // ── Ruta A → B ──
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    children: [
                      _buildRouteBigRow(
                        'A',
                        trip.pickupAddress,
                        'A ${distanceToPickup.toStringAsFixed(1)} km · $timeToPickup min de ti',
                        Colors.blueAccent,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(color: Colors.black12, height: 1),
                      ),
                      _buildRouteBigRow(
                        'B',
                        trip.dropoffAddress,
                        'Viaje de ${trip.distance.toStringAsFixed(1)} km · $tripTime min aprox.',
                        Colors.black87,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Botones ──
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _handleIgnore,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(
                            color: Colors.redAccent,
                            width: 2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'IGNORAR',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 70,
                        child: _AcceptButton(trip: trip),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteBigRow(
    String label,
    String address,
    String sub,
    Color color,
  ) {
    return Row(
      children: [
        _circleLabel(label, color, size: 40),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                address,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                sub,
                style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _circleLabel(String label, Color color, {double size = 28}) {
    Color displayColor = color == Colors.white ? Colors.black : color;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: displayColor.withValues(alpha: 0.1),
        border: Border.all(
          color: displayColor.withValues(alpha: 0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: displayColor,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.45,
          ),
        ),
      ),
    );
  }
}

// ── Botón Aceptar ──
class _AcceptButton extends ConsumerStatefulWidget {
  final Trip trip;
  const _AcceptButton({required this.trip});
  @override
  ConsumerState<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends ConsumerState<_AcceptButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading
          ? null
          : () async {
              final user = Supabase.instance.client.auth.currentUser;
              if (user == null) return;
              setState(() => _isLoading = true);
              AppLogger.log('[CONDUCTOR] Aceptando viaje ${widget.trip.id}');
              try {
                await ref
                    .read(tripControllerProvider.notifier)
                    .acceptTrip(widget.trip.id, user.id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Este viaje ya fue aceptado por otro conductor.',
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_rounded, size: 20, color: Colors.greenAccent),
                SizedBox(width: 8),
                Text(
                  'ACEPTAR',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
    );
  }
}
