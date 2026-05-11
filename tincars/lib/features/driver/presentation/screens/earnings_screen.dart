import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/trips/data/trip_repository.dart';
import 'package:tincars/features/driver/presentation/screens/driver_trip_detail_screen.dart';

import 'package:go_router/go_router.dart';
import 'package:tincars/features/trips/domain/services/pricing_service.dart';

// Provider de viajes completados reales del conductor actual (ahora en Tiempo Real)
final driverCompletedTripsStreamProvider =
    StreamProvider.autoDispose<List<Trip>>((ref) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return Stream.value([]);

      return ref
          .watch(tripRepositoryProvider)
          .streamTripHistoryForDriver(user.uid);
    });

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
    final driverProfile = ref.watch(driverProfileProvider);
    final completedTrips = ref.watch(driverCompletedTripsStreamProvider);
    
    // Obtener porcentaje de comisión dinámico
    final pricingConfig = ref.watch(pricingConfigProvider).asData?.value;
    final double commissionPercentage =
        (pricingConfig?.commission.enabled == true)
            ? pricingConfig!.commission.percentage
            : 0.0;
    final double driverFactor = (100 - commissionPercentage) / 100.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          if (Navigator.canPop(context))
            SliverAppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Theme.of(context).iconTheme.color,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              floating: true,
              snap: true,
            ),
          // ── Main Content ──
          SliverToBoxAdapter(
            child: driverProfile.when(
              data: (profile) {
                if (profile == null) return const SizedBox();

                final trips = completedTrips.value ?? [];

                // --- Cálculo de Datos Semanales Real ---
                final now = DateTime.now();
                // Encontrar el lunes de esta semana
                final monday = now.subtract(Duration(days: now.weekday - 1));
                final startOfWeek = DateTime(
                  monday.year,
                  monday.month,
                  monday.day,
                );

                final weeklyEarnings = List<double>.filled(7, 0.0);
                for (final trip in trips) {
                  if (!trip.createdAt.isBefore(startOfWeek)) {
                    final dayIndex = trip.createdAt.weekday - 1; // 0=Lun, 6=Dom
                    if (dayIndex >= 0 && dayIndex < 7) {
                      // Ganancia neta: Factor dinámico + 100% propina
                      weeklyEarnings[dayIndex] +=
                          (trip.price * driverFactor) + (trip.tipAmount ?? 0);
                    }
                  }
                }

                final totalWeekly = weeklyEarnings.fold<double>(
                  0.0,
                  (prev, elem) => prev + elem,
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      const SizedBox(height: 20),

                      const SizedBox(height: 20),
                      // ── Main balance white card ──
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(35),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'SALDO EN BILLETERA',
                              style: TextStyle(
                                color: Colors.black38,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '\$${(userProfile.value?.walletBalance ?? 0.0).toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _miniStat(
                                  Icons.star_rounded,
                                  'Calificación',
                                  (userProfile.value?.averageRating ?? 5.0)
                                      .toStringAsFixed(1),
                                ),
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: Colors.grey.shade100,
                                ),
                                _miniStat(
                                  Icons.route_rounded,
                                  'Viajes',
                                  trips.length.toString(),
                                ),
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: Colors.grey.shade100,
                                ),
                                _miniStat(
                                  Icons.account_balance_rounded,
                                  'Ganancia Total',
                                  '\$${profile.totalEarnings.toStringAsFixed(0)}',
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  context.push('/cards');
                                },
                                icon: const Icon(
                                  Icons.outbound_rounded,
                                  size: 18,
                                ),
                                label: const Text('RETIRAR FONDOS'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Weekly Summary Dashboard v2 ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RESUMEN SEMANAL',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            '\$${totalWeekly.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Custom Chart ──
                      Container(
                        height: 180,
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: CustomPaint(
                          painter: EarningsChartPainter(data: weeklyEarnings),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ── Activity Timeline Label ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ACTIVIDAD RECIENTE',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ),

          // ── Timeline List ──
          completedTrips.when(
            data: (trips) {
              if (trips.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No hay actividad reciente',
                      style: TextStyle(color: Colors.black26),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final trip = trips[index];
                  return _TimelineItem(
                    trip: trip,
                    isLast: index == trips.length - 1,
                  );
                }, childCount: trips.length),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Colors.black12),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.blueAccent),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class EarningsChartPainter extends CustomPainter {
  final List<double> data;
  EarningsChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;

    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.fill;

    final barWidth = size.width / (data.length * 2 - 1);
    final maxVal = data.reduce((a, b) => a > b ? a : b);

    // Text painter for days
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    final days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    // Reserve space for text
    final chartHeight = size.height - 24;

    for (int i = 0; i < data.length; i++) {
      final x = i * barWidth * 2;

      // Draw background bar
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barWidth, chartHeight),
        const Radius.circular(8),
      );
      canvas.drawRRect(bgRect, bgPaint);

      // Draw value bar if > 0
      if (data[i] > 0 && maxVal > 0) {
        final barHeight = (data[i] / maxVal) * chartHeight;
        final actualHeight = barHeight < 4.0 ? 4.0 : barHeight;
        final y = chartHeight - actualHeight;

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, actualHeight),
          const Radius.circular(8),
        );
        canvas.drawRRect(rect, paint);
      }

      // Draw day label
      textPainter.text = TextSpan(
        text: days[i],
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, chartHeight + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _TimelineItem extends ConsumerWidget {
  final Trip trip;
  final bool isLast;

  const _TimelineItem({required this.trip, required this.isLast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obtener porcentaje de comisión dinámico
    final pricingConfig = ref.watch(pricingConfigProvider).asData?.value;
    final double commissionPercentage =
        (pricingConfig?.commission.enabled == true)
            ? pricingConfig!.commission.percentage
            : 0.0;
    final double driverFactor = (100 - commissionPercentage) / 100.0;

    // Mostrar ganancia neta en la lista (Factor dinámico + Propina)
    final netPrice = (trip.price * driverFactor) + (trip.tipAmount ?? 0);
    final pickup = trip.pickupAddress;
    final dropoff = trip.dropoffAddress;
    final date = trip.createdAt;
    final timeStr = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left Timeline Graphics ──
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.blueAccent.withValues(alpha: 0.5),
                        Colors.grey.shade200,
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),

          // ── Trip Card ──
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriverTripDetailScreen(trip: trip),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: Colors.black26,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${netPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      pickup,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.arrow_downward,
                          size: 10,
                          color: Colors.black26,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dropoff,
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
}
