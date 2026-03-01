import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/trips/presentation/screens/trip_chat_screen.dart';
import 'package:tincars/features/trips/presentation/screens/searching_driver_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trip_tracking_screen.dart';
import 'package:tincars/l10n/app_localizations.dart';

import 'package:url_launcher/url_launcher_string.dart';

class TripStatusWidget extends ConsumerWidget {
  final Trip trip;
  final VoidCallback? onCancel;

  const TripStatusWidget({super.key, required this.trip, this.onCancel});

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final url = 'tel:$phoneNumber';
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () {
        if (trip.status == TripStatus.requested) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SearchingDriverScreen(
                tripId: trip.id,
                pickupLocation: trip.pickupLocation,
                dropoffLocation: trip.dropoffLocation,
                pickupAddress: trip.pickupAddress,
                dropoffAddress: trip.dropoffAddress,
                vehicleType: trip.vehicleType,
              ),
            ),
          );
        } else if (trip.status == TripStatus.accepted ||
            trip.status == TripStatus.arrived ||
            trip.status == TripStatus.inProgress) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TripTrackingScreen(tripId: trip.id),
            ),
          );
        }
      },
      child: PremiumGlassContainer(
        color: Colors.white,
        opacity: 0.95,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _getStatusColor(trip.status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _getStatusText(trip.status, l10n),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                if (trip.status == TripStatus.requested ||
                    trip.status == TripStatus.accepted ||
                    trip.status == TripStatus.arrived)
                  TextButton(
                    onPressed: () {
                      AppLogger.log(
                        '[VIAJE] Verificando estado en RT para: ${trip.id}',
                      );
                      onCancel?.call();
                    },
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),

            // Driver Info (if accepted)
            if (trip.driverId != null) ...[
              ref
                  .watch(otherUserProfileProvider(trip.driverId!))
                  .when(
                    data: (driverUser) {
                      return ref
                          .watch(otherDriverProfileProvider(trip.driverId!))
                          .when(
                            data: (driverData) {
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 25,
                                        backgroundColor: Colors.black,
                                        backgroundImage:
                                            driverUser?.avatarUrl != null
                                            ? NetworkImage(
                                                driverUser!.avatarUrl!,
                                              )
                                            : null,
                                        child: driverUser?.avatarUrl == null
                                            ? const Icon(
                                                Icons.person,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            driverUser?.fullName ?? 'Conductor',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                color: Colors.amber,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                driverUser?.averageRating
                                                        ?.toStringAsFixed(1) ??
                                                    '5.0',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      // Vehicle Info
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            driverData?.vehicleModel ??
                                                'Vehículo',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            driverData?.vehiclePlate ?? 'S/P',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            AppLogger.log(
                                              '[PASAJERO] Abriendo chat con conductor ${trip.driverId} en viaje ${trip.id}',
                                            );
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    TripChatScreen(
                                                      tripId: trip.id,
                                                      otherUserId:
                                                          trip.driverId!,
                                                      otherUserName:
                                                          driverUser
                                                              ?.fullName ??
                                                          'Conductor',
                                                    ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.chat_outlined),
                                          label: const Text('Chat'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[100],
                                            foregroundColor: Colors.black,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            AppLogger.log(
                                              '[PASAJERO] Llamando al conductor: ${driverUser?.phoneNumber ?? "sin número"}',
                                            );
                                            _makePhoneCall(
                                              driverUser?.phoneNumber,
                                            );
                                          },
                                          icon: const Icon(Icons.call_outlined),
                                          label: const Text('Llamar'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[100],
                                            foregroundColor: Colors.black,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (e, s) =>
                                const Text('Error cargando vehículo'),
                          );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, s) => const Text('Error cargando conductor'),
                  ),
              const SizedBox(height: 20),
            ],

            // Trip Details
            Row(
              children: [
                const Icon(Icons.my_location, color: Colors.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    trip.pickupAddress,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    trip.dropoffAddress,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.requested:
        return Colors.orange;
      case TripStatus.accepted:
        return Colors.blue;
      case TripStatus.arrived:
        return Colors.green;
      case TripStatus.inProgress:
        return Colors.blueAccent;
      case TripStatus.completed:
        return Colors.black;
      case TripStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(TripStatus status, AppLocalizations l10n) {
    switch (status) {
      case TripStatus.requested:
        return 'Buscando conductor...';
      case TripStatus.accepted:
        return 'Conductor en camino';
      case TripStatus.arrived:
        return 'Tu conductor ha llegado';
      case TripStatus.inProgress:
        return 'En viaje';
      case TripStatus.completed:
        return 'Viaje finalizado';
      case TripStatus.cancelled:
        return 'Viaje cancelado';
    }
  }
}
