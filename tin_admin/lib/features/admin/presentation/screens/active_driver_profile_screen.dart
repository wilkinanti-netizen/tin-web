import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tin_admin/features/profile/domain/models/profiles.dart';
import 'package:tin_admin/core/widgets/premium_glass_container.dart';
import 'package:tin_admin/features/admin/presentation/controllers/admin_controller.dart';

class ActiveDriverProfileScreen extends ConsumerWidget {
  final AppUser driver;

  const ActiveDriverProfileScreen({super.key, required this.driver});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverDataAsync = ref.watch(driverDataProvider(driver.id));
    final verificationAsync = ref.watch(verificationDataProvider(driver.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: Text(
          'Perfil del Conductor',
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
                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                    backgroundImage: driver.avatarUrl != null ? NetworkImage(driver.avatarUrl!) : null,
                    child: driver.avatarUrl == null
                        ? const Icon(Icons.person, size: 40, color: Colors.blueAccent)
                        : null,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.fullName,
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          driver.email,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.withOpacity(0.5)),
                          ),
                          child: const Text(
                            'ACTIVO',
                            style: TextStyle(
                              color: Colors.green,
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
            _buildSection(
              context,
              'INFORMACIÓN PERSONAL',
              {
                'Teléfono': driver.phoneNumber ?? 'No registrado',
                'Ciudad': driver.city ?? 'No registrada',
                'SSN (Últimos 4)': driver.ssnLast4 ?? 'N/A',
                'Referido por': driver.referredById ?? 'Ninguno',
                'Es Líder': driver.isLeader ? 'SÍ' : 'NO',
              },
              Icons.person_pin,
            ),
            const SizedBox(height: 24),

            // Vehicle Info
            driverDataAsync.when(
              data: (data) => data == null
                  ? const SizedBox.shrink()
                  : _buildSection(
                      context,
                      'VEHÍCULO Y SERVICIOS',
                      {
                        'Modelo': data.vehicleModel,
                        'Placa': data.vehiclePlate,
                        'Color': data.vehicleColor ?? 'N/A',
                        'Año': data.vehicleYear ?? 'N/A',
                        'Tipo': data.vehicleType.name.toUpperCase(),
                        'Consentimiento Fondo': data.backgroundCheckConsent ? 'SÍ' : 'NO',
                      },
                      Icons.directions_car,
                    ),
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (e, _) => Text('Error vehículo: $e'),
            ),
            const SizedBox(height: 24),

            // Documents
            _buildDocumentsSection(context, driverDataAsync, verificationAsync),
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
                    'Historial de Viajes',
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

  Widget _buildSection(BuildContext context, String title, Map<String, String> details, IconData icon) {
    return PremiumGlassContainer(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      opacity: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blueAccent, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Column(
            children: details.entries
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Text(
                          '${e.key}:',
                          style: GoogleFonts.outfit(color: Colors.grey[700], fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.value,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black87),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(
      BuildContext context, AsyncValue<DriverProfile?> data, AsyncValue<DriverVerification?> verif) {
    return PremiumGlassContainer(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      opacity: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documentos y Verificación',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Divider(height: 32),
          data.when(
            data: (d) => d == null
                ? const Text('No hay documentos cargados en driver_data')
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (d.docPhotoUrl != null) _buildDocThumb(context, 'Perfil', d.docPhotoUrl!),
                      if (d.docLicenseUrl != null) _buildDocThumb(context, 'Licencia', d.docLicenseUrl!),
                      if (d.docInsuranceUrl != null) _buildDocThumb(context, 'Seguro', d.docInsuranceUrl!),
                      if (d.docRegistrationUrl != null) _buildDocThumb(context, 'Propiedad', d.docRegistrationUrl!),
                    ],
                  ),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Text('Error al cargar documentos'),
          ),
          const SizedBox(height: 20),
          verif.when(
            data: (v) => v == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Verificaciones adicionales:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (v.facePhotoUrl != null) _buildDocThumb(context, 'Selfie', v.facePhotoUrl!),
                          if (v.dniFrontPhotoUrl != null) _buildDocThumb(context, 'DNI Frontal', v.dniFrontPhotoUrl!),
                          if (v.dniBackPhotoUrl != null) _buildDocThumb(context, 'DNI Trasero', v.dniBackPhotoUrl!),
                          if (v.licensePhotoUrl != null) _buildDocThumb(context, 'Licencia (F)', v.licensePhotoUrl!),
                          if (v.licenseBackPhotoUrl != null) _buildDocThumb(context, 'Licencia (P)', v.licenseBackPhotoUrl!),
                          if (v.registrationPhotoUrl != null) _buildDocThumb(context, 'T. Propiedad', v.registrationPhotoUrl!),
                          if (v.vehiclePhotoUrl != null) _buildDocThumb(context, 'Vehículo', v.vehiclePhotoUrl!),
                        ],
                      ),
                    ],
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildDocThumb(BuildContext context, String title, String url) {
    return GestureDetector(
      onTap: () => _showFullScreen(context, url, title),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
              image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  void _showFullScreen(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Column(
          children: [
            AppBar(
              title: Text(title),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(child: InteractiveViewer(child: Image.network(url))),
          ],
        ),
      ),
    );
  }
}
