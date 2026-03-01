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
  int _secondsLeft = 15;
  Timer? _countdownTimer;

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
        widget.onReject?.call();
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

    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Badge NUEVO VIAJE + countdown ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
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
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'NUEVO VIAJE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Countdown
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _secondsLeft <= 5
                            ? Colors.redAccent
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _secondsLeft <= 5
                              ? Colors.redAccent
                              : Colors.black12,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$_secondsLeft',
                          style: TextStyle(
                            color: _secondsLeft <= 5
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Pasajero + Precio ──
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.black.withValues(alpha: 0.05),
                      backgroundImage: passengerAsync.value?.avatarUrl != null
                          ? NetworkImage(passengerAsync.value!.avatarUrl!)
                          : null,
                      child: passengerAsync.value?.avatarUrl == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.black54,
                              size: 26,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            passengerAsync.value?.fullName ?? 'Cargando...',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                                size: 13,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                passengerAsync.value?.averageRating
                                        ?.toStringAsFixed(1) ??
                                    '5.0',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Precio
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${trip.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          trip.paymentMethod.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Ruta A → B con km y min ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      // ── A — Punto de recogida ──
                      Row(
                        children: [
                          _circleLabel('A', Colors.blueAccent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trip.pickupAddress,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'A ${distanceToPickup.toStringAsFixed(1)} km · $timeToPickup min de ti',
                                  style: TextStyle(
                                    color: Colors.blueAccent.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Conector
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 13,
                          top: 4,
                          bottom: 4,
                        ),
                        child: Row(
                          children: [
                            Column(
                              children: List.generate(
                                3,
                                (_) => Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  width: 2,
                                  height: 4,
                                  color: Colors.black12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              '${trip.distance.toStringAsFixed(1)} km · $tripTime min de viaje',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.45),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── B — Destino ──
                      Row(
                        children: [
                          _circleLabel('B', Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trip.dropoffAddress,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Destino final del viaje',
                                  style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Botones ──
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: widget.onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: BorderSide(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'IGNORAR',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _AcceptButton(trip: trip)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleLabel(String label, Color color) {
    if (color == Colors.white)
      color = Colors.black; // Ensure white isn't invisible on white bg

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 13,
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
