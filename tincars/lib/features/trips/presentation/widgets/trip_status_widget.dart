import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/passenger/presentation/screens/passenger_chat_screen.dart';
import 'package:tincars/features/passenger/presentation/screens/searching_driver_screen.dart';
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
        HapticFeedback.lightImpact();
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
                intermediateStops: trip.intermediateStops,
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 40,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicator strip
            Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: _getStatusColor(trip.status).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24, 20, 24,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Header
                  Row(
                    children: [
                      // Animated Status Dot
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _getStatusColor(trip.status),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor(trip.status).withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _getStatusText(trip.status, l10n),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A0A0A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      if (trip.status == TripStatus.requested ||
                          trip.status == TripStatus.accepted ||
                          trip.status == TripStatus.arrived)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            AppLogger.log(
                              '[VIAJE] Verificando estado en RT para: ${trip.id}',
                            );
                            onCancel?.call();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

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
                                        // Driver card
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF7F7F8),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            children: [
                                              // Avatar
                                              Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: const Color(0xFF0A0A0A),
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                  image: driverUser?.avatarUrl != null
                                                      ? DecorationImage(
                                                          image: NetworkImage(
                                                            driverUser!.avatarUrl!,
                                                          ),
                                                          fit: BoxFit.cover,
                                                        )
                                                      : null,
                                                ),
                                                child: driverUser?.avatarUrl == null
                                                    ? const Icon(
                                                        Icons.person_rounded,
                                                        color: Colors.white,
                                                        size: 22,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      driverData?.vehicleModel ?? 'Vehículo',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 15,
                                                        color: Color(0xFF0A0A0A),
                                                        letterSpacing: -0.3,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          driverData?.vehicleColor ?? '',
                                                          style: TextStyle(
                                                            color: Colors.black.withValues(alpha: 0.5),
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Vehicle model tag
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  driverData?.vehiclePlate ?? 'S/P',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 11,
                                                    color: Colors.blueAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        // Action Buttons
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildActionButton(
                                                icon: Icons.chat_bubble_rounded,
                                                label: 'Chat',
                                                onTap: () {
                                                  AppLogger.log(
                                                    '[PASAJERO] Abriendo chat con conductor ${trip.driverId} en viaje ${trip.id}',
                                                  );
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          PassengerChatScreen(
                                                            tripId: trip.id,
                                                            driverId:
                                                                trip.driverId!,
                                                            driverName:
                                                                driverUser
                                                                    ?.fullName ??
                                                                'Conductor',
                                                          ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _buildActionButton(
                                                icon: Icons.call_rounded,
                                                label: 'Llamar',
                                                color: const Color(0xFF00C853),
                                                onTap: () {
                                                  AppLogger.log(
                                                    '[PASAJERO] Llamando al conductor: ${driverUser?.phoneNumber ?? "sin número"}',
                                                  );
                                                  _makePhoneCall(
                                                    driverUser?.phoneNumber,
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                  loading: () => const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: LinearProgressIndicator(
                                      minHeight: 2,
                                      color: Color(0xFF2962FF),
                                      backgroundColor: Color(0xFFF0F0F0),
                                    ),
                                  ),
                                  error: (e, s) =>
                                      const Text('Error cargando vehículo'),
                                );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(
                              minHeight: 2,
                              color: Color(0xFF2962FF),
                              backgroundColor: Color(0xFFF0F0F0),
                            ),
                          ),
                          error: (e, s) => const Text('Error cargando conductor'),
                        ),
                    const SizedBox(height: 14),
                  ],

                  // Route Summary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.03),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildRouteRow(
                          icon: Icons.circle,
                          iconColor: const Color(0xFF2962FF),
                          iconSize: 8,
                          text: trip.pickupAddress,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 3.5),
                          child: Container(
                            width: 1,
                            height: 16,
                            color: Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        _buildRouteRow(
                          icon: Icons.circle,
                          iconColor: const Color(0xFFFF3D00),
                          iconSize: 8,
                          text: trip.dropoffAddress,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteRow({
    required IconData icon,
    required Color iconColor,
    required double iconSize,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: iconSize),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color(0xFF2A2A2A),
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF0A0A0A),
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.requested:
        return const Color(0xFFFF9800);
      case TripStatus.accepted:
        return const Color(0xFF2962FF);
      case TripStatus.arrived:
        return const Color(0xFF00C853);
      case TripStatus.inProgress:
        return const Color(0xFF2962FF);
      case TripStatus.completed:
        return const Color(0xFF0A0A0A);
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
