import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/features/trips/data/trip_repository.dart';

// Provider de viajes completados reales del conductor actual (ahora en Tiempo Real)
final driverCompletedTripsStreamProvider =
    StreamProvider.autoDispose<List<Trip>>((ref) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return Stream.value([]);

      return ref
          .watch(tripRepositoryProvider)
          .streamTripHistoryForDriver(user.id);
    });

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverProfile = ref.watch(driverProfileProvider);
    final todayStats = ref.watch(todayDriverStatsProvider);
    final completedTrips = ref.watch(driverCompletedTripsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          if (Navigator.canPop(context))
            SliverAppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.black,
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

                final todayEarnings =
                    todayStats.asData?.value['earnings'] ?? 0.0;
                final todayCount = (todayStats.asData?.value['count'] ?? 0.0)
                    .toInt();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        height: 24,
                      ), // Espacio arriba de saldo actual
                      // ── Main balance white card ──
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(35),
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
                            const Text(
                              'SALDO ACTUAL',
                              style: TextStyle(
                                color: Colors.black38,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '\$${profile.totalEarnings.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _miniStat(
                                  Icons.today,
                                  'Hoy',
                                  '\$${todayEarnings.toStringAsFixed(0)}',
                                ),
                                Container(
                                  height: 30,
                                  width: 1,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  color: Colors.grey.shade200,
                                ),
                                _miniStat(
                                  Icons.directions_car,
                                  'Viajes',
                                  '$todayCount',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Weekly Summary Mini-Grid ──
                      const Text(
                        'RESUMEN SEMANAL',
                        style: TextStyle(
                          color: Colors.black38,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _summaryCard(context, 'Lunes', '\$120', true),
                          _summaryCard(context, 'Martes', '\$85', false),
                          _summaryCard(context, 'Miércoles', '\$150', false),
                          _summaryCard(context, 'Jueves', '\$0', false),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // ── Activity Timeline Label ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ACTIVIDAD RECIENTE',
                            style: TextStyle(
                              color: Colors.black38,
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

  Widget _summaryCard(
    BuildContext context,
    String day,
    String amount,
    bool isSelected,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withValues(alpha: 0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? Colors.blueAccent.withValues(alpha: 0.3)
                : Colors.grey.shade100,
          ),
        ),
        child: Column(
          children: [
            Text(
              day.substring(0, 1),
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.black45,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final Trip trip;
  final bool isLast;

  const _TimelineItem({required this.trip, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final price = trip.price;
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
                        '\$${price.toStringAsFixed(0)}',
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
        ],
      ),
    );
  }
}
