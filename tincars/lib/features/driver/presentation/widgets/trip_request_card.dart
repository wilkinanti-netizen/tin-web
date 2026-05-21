import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:tincars/features/trips/domain/services/pricing_service.dart';

class TripRequestCard extends ConsumerStatefulWidget {
  final Trip trip;
  final Position? driverPosition;
  final double? pickupDistance;
  final int? pickupTime;
  final double? tripDistance;
  final int? tripTime;
  final VoidCallback? onReject;

  const TripRequestCard({
    super.key,
    required this.trip,
    this.driverPosition,
    this.pickupDistance,
    this.pickupTime,
    this.tripDistance,
    this.tripTime,
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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      ref
          .read(tripControllerProvider.notifier)
          .rejectTrip(widget.trip.id, user.uid);
    } else {
      ref
          .read(ignoredTripsProvider.notifier)
          .ignore(widget.trip.id, widget.trip.price);
    }
    widget.onReject?.call();
  }

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutQuart),
        );
    _slideController.forward();
    _startCountdown();
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

    return Stack(
      children: [
        // Floating Card
        Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: _slideAnim,
            child: PremiumGlassContainer(
              opacity: 0.98,
              blur: 30,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                32,
                24,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${trip.paymentMethod.toUpperCase()} · ${ref.read(pricingServiceProvider).getVehicleName(trip.vehicleType).toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Passenger Info row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.black12,
                        backgroundImage: passengerAsync.value?.avatarUrl != null
                            ? NetworkImage(passengerAsync.value!.avatarUrl!)
                            : null,
                        child: passengerAsync.value?.avatarUrl == null
                            ? const Icon(Icons.person, color: Colors.black45)
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
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 14,
                                ),
                                Text(
                                  ' ${passengerAsync.value?.averageRating?.toStringAsFixed(1) ?? '5.0'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${trip.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Wait time policy banner
                  Builder(builder: (context) {
                    final pricing = ref.read(pricingServiceProvider);
                    final freeMin = pricing.getFreeWaitMinutes(trip.vehicleType);
                    final fee = pricing.getWaitFeePerMinute(trip.vehicleType);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$freeMin min de espera gratis • '
                              '\$${fee.toStringAsFixed(2)}/min después',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 20),
                   _buildCompactAddress(
                    Icons.trip_origin_rounded,
                    Colors.blueAccent,
                    trip.pickupAddress,
                  ),
                  
                  // Intermediate Stops if any
                  if (trip.intermediateStops.isNotEmpty) ...[
                    for (int i = 0; i < trip.intermediateStops.length; i++) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 11),
                        child: SizedBox(
                          height: 12,
                          child: VerticalDivider(
                            width: 2,
                            color: Colors.black12,
                            thickness: 2,
                          ),
                        ),
                      ),
                      _buildCompactAddress(
                        Icons.add_location_alt_rounded,
                        Colors.orange,
                        trip.intermediateStops[i].address,
                        isStop: true,
                        stopNumber: i + 1,
                      ),
                    ],
                  ],

                  const Padding(
                    padding: EdgeInsets.only(left: 11),
                    child: SizedBox(
                      height: 12,
                      child: VerticalDivider(
                        width: 2,
                        color: Colors.black12,
                        thickness: 2,
                      ),
                    ),
                  ),
                  _buildCompactAddress(
                    Icons.location_on_rounded,
                    Colors.redAccent,
                    trip.dropoffAddress,
                  ),
                  const SizedBox(height: 28),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: _ActionButton(
                          label: 'RECHAZAR',
                          color: Colors.redAccent,
                          isOutlined: true,
                          onPressed: _handleIgnore,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _AcceptButton(
                          trip: trip,
                          onLoading: (loading) {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Floating Top Countdown
        Positioned(
          top: MediaQuery.of(context).padding.top + 20,
          right: 20,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The progress indicator
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: _secondsLeft / 30,
                  strokeWidth: 4,
                  color: _secondsLeft <= 5 ? Colors.red : Colors.black,
                  backgroundColor: Colors.black12,
                ),
              ),
              // Unboxed Text with shadow
              Text(
                '$_secondsLeft',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Colors.black87,
                  shadows: [
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactAddress(IconData icon, Color color, String address, {bool isStop = false, int? stopNumber}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isStop)
                Text(
                  'PARADA $stopNumber',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 1,
                  ),
                ),
              Text(
                address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isOutlined;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.isOutlined,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: isOutlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
    );
  }
}

class _AcceptButton extends ConsumerStatefulWidget {
  final Trip trip;
  final Function(bool) onLoading;
  const _AcceptButton({required this.trip, required this.onLoading});
  @override
  ConsumerState<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends ConsumerState<_AcceptButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                setState(() => _isLoading = true);
                widget.onLoading(true);
                try {
                  await ref
                      .read(tripControllerProvider.notifier)
                      .acceptTrip(widget.trip.id, user.uid);
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
                  if (mounted) {
                    setState(() => _isLoading = false);
                    widget.onLoading(false);
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: Colors.greenAccent,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'ACEPTAR',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }
}
