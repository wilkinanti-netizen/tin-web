import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tin_admin/features/profile/domain/models/profiles.dart';
import 'package:tin_admin/core/widgets/premium_glass_container.dart';

class PassengerProfileScreen extends StatelessWidget {
  final AppUser passenger;

  const PassengerProfileScreen({super.key, required this.passenger});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: Text(
          'Perfil del Pasajero',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            PremiumGlassContainer(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              opacity: 1,
              child: Row(
                children: [
                   CircleAvatar(
                     radius: 40,
                     backgroundColor: Colors.orange.withOpacity(0.1),
                     backgroundImage: passenger.avatarUrl != null ? NetworkImage(passenger.avatarUrl!) : null,
                     child: passenger.avatarUrl == null
                         ? const Icon(Icons.person, size: 40, color: Colors.orange)
                         : null,
                   ),
                   const SizedBox(width: 20),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           passenger.fullName,
                           style: GoogleFonts.outfit(
                             fontSize: 24,
                             fontWeight: FontWeight.bold,
                             color: Colors.black87,
                           ),
                         ),
                         Text(
                           passenger.email,
                           style: GoogleFonts.outfit(
                             fontSize: 14,
                             color: Colors.grey[600],
                           ),
                         ),
                         const SizedBox(height: 8),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                           decoration: BoxDecoration(
                             color: Colors.blue.withOpacity(0.1),
                             borderRadius: BorderRadius.circular(20),
                             border: Border.all(color: Colors.blue.withOpacity(0.5)),
                           ),
                           child: const Text(
                             'PASAJERO',
                             style: TextStyle(
                               color: Colors.blue,
                               fontWeight: FontWeight.bold,
                               fontSize: 10,
                             ),
                           ),
                         ),
                       ],
                     ),
                   ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Contact Info
            PremiumGlassContainer(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              opacity: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información de Contacto',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Divider(height: 32),
                  _InfoRow(icon: Icons.phone, label: 'Teléfono', value: passenger.phoneNumber ?? 'No registrado'),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.star,
                    label: 'Líder',
                    value: passenger.isLeader ? 'Sí, es líder de ciudad y pasajero' : 'No',
                    valueColor: passenger.isLeader ? Colors.blueAccent : Colors.black87,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Trips placeholder
            PremiumGlassContainer(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              opacity: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historial de Viajes (Solicitados)',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Divider(height: 32),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'El historial detallado estará disponible próximamente.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
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
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: GoogleFonts.outfit(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
