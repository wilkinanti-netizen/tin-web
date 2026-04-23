import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:tincars/core/widgets/shimmer_loading.dart';

import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(tripHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'ACTIVIDAD',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: historyAsync.when(
        data: (trips) {
          if (trips.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.03),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        size: 100,
                        color: Colors.black.withValues(alpha: 0.1),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'TUS VIAJES APARECERÁN AQUÍ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cuando completes o canceles un viaje, podrás ver todos los detalles en esta sección.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.4),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: trips.length,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            itemBuilder: (context, index) {
              final trip = trips[index];
              return _buildPremiumTripCard(context, trip);
            },
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: ShimmerListLoading(itemCount: 6, height: 160),
        ),
        error: (err, stack) => Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumTripCard(BuildContext context, Trip trip) {
    final dateFormat = DateFormat('dd MMM, HH:mm', 'es');
    final isCancelled = trip.status == TripStatus.cancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/payment-details', extra: trip);
        },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.black.withOpacity(0.03)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Section (Vehicle + Date + Status)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isCancelled
                                ? Colors.red.withOpacity(0.05)
                                : Colors.blueAccent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isCancelled
                                ? Icons.close_rounded
                                : (trip.vehicleType == 'moto'
                                    ? Icons.motorcycle_rounded
                                    : Icons.directions_car_filled_rounded),
                            size: 24,
                            color: isCancelled ? Colors.red : Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.vehicleType.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateFormat.format(trip.createdAt),
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.4),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${trip.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: isCancelled ? Colors.grey : Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.5,
                            decoration: isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (isCancelled)
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text(
                              'CANCELADO',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'COMPLETADO',
                              style: TextStyle(
                                color: Colors.green[600],
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.black12),

              // Bottom Section (Addresses)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Row(
                  children: [
                    Column(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 10,
                          color: Colors.blueAccent,
                        ),
                        Container(
                          width: 2,
                          height: 20,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: Colors.grey.withOpacity(0.2),
                        ),
                        const Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: Colors.black,
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.pickupAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            trip.dropoffAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.grey[300],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
