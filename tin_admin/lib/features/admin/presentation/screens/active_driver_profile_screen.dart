import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tin_admin/features/profile/domain/models/profiles.dart';
import 'package:tin_admin/core/widgets/premium_glass_container.dart';
import 'package:tin_admin/features/admin/presentation/controllers/admin_controller.dart';

// Provider to stream driver online status from driver_data
final driverOnlineStatusProvider = StreamProvider.family<bool, String>((ref, driverId) {
  return FirebaseFirestore.instance
      .collection('driver_data')
      .doc(driverId)
      .snapshots()
      .map((snap) => snap.data()?['is_online'] as bool? ?? false);
});

// Provider to stream admin messages for a driver
final driverAdminMessagesProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, driverId) {
  return FirebaseFirestore.instance
      .collection('driver_messages')
      .doc(driverId)
      .collection('messages')
      .orderBy('created_at', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.data()).toList());
});

class ActiveDriverProfileScreen extends ConsumerStatefulWidget {
  final AppUser driver;

  const ActiveDriverProfileScreen({super.key, required this.driver});

  @override
  ConsumerState<ActiveDriverProfileScreen> createState() => _ActiveDriverProfileScreenState();
}

class _ActiveDriverProfileScreenState extends ConsumerState<ActiveDriverProfileScreen> {
  final _messageController = TextEditingController();
  bool _sendingMessage = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    setState(() => _sendingMessage = true);
    try {
      await FirebaseFirestore.instance
          .collection('driver_messages')
          .doc(widget.driver.id)
          .collection('messages')
          .add({
        'text': message.trim(),
        'from': 'admin',
        'created_at': FieldValue.serverTimestamp(),
        'read': false,
      });
      // Also update a "last_message" field so the driver app can easily detect it
      await FirebaseFirestore.instance
          .collection('driver_messages')
          .doc(widget.driver.id)
          .set({
        'last_message': message.trim(),
        'last_message_at': FieldValue.serverTimestamp(),
        'has_unread': true,
        'driver_id': widget.driver.id,
      }, SetOptions(merge: true));

      _messageController.clear();
    } finally {
      setState(() => _sendingMessage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverDataAsync = ref.watch(driverDataProvider(widget.driver.id));
    final verificationAsync = ref.watch(verificationDataProvider(widget.driver.id));
    final onlineAsync = ref.watch(driverOnlineStatusProvider(widget.driver.id));
    final messagesAsync = ref.watch(driverAdminMessagesProvider(widget.driver.id));

    final isOnline = onlineAsync.asData?.value ?? false;

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
            // ── Profile Header with online status ──
            PremiumGlassContainer(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              opacity: 1,
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blueAccent.withOpacity(0.1),
                        backgroundImage: widget.driver.avatarUrl != null
                            ? NetworkImage(widget.driver.avatarUrl!)
                            : null,
                        child: widget.driver.avatarUrl == null
                            ? const Icon(Icons.person, size: 40, color: Colors.blueAccent)
                            : null,
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.driver.fullName,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          widget.driver.email,
                          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isOnline
                                      ? Colors.green.withOpacity(0.5)
                                      : Colors.grey.withOpacity(0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: isOnline ? Colors.green : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isOnline ? 'En línea' : 'Desconectado',
                                    style: TextStyle(
                                      color: isOnline ? Colors.green : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
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
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Contact Info ──
            _buildSection(
              context,
              'INFORMACIÓN PERSONAL',
              {
                'Teléfono': widget.driver.phoneNumber ?? 'No registrado',
                'Ciudad': widget.driver.city ?? 'No registrada',
                'SSN (Últimos 4)': widget.driver.ssnLast4 ?? 'N/A',
                'Referido por': widget.driver.referredById ?? 'Ninguno',
                'Es Líder': widget.driver.isLeader ? 'SÍ' : 'NO',
              },
              Icons.person_pin,
            ),
            const SizedBox(height: 24),

            // ── Vehicle Info ──
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

            // ── Documents ──
            _buildDocumentsSection(context, driverDataAsync, verificationAsync),
            const SizedBox(height: 24),

            // ── Messaging Section ──
            PremiumGlassContainer(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              opacity: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'Mensajes al Conductor',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      if (!isOnline)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withOpacity(0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.offline_bolt_outlined, size: 12, color: Colors.orange),
                              SizedBox(width: 4),
                              Text(
                                'Verá al conectarse',
                                style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 28),

                  // Message history
                  messagesAsync.when(
                    data: (messages) {
                      if (messages.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                Icon(Icons.chat_outlined, size: 40, color: Colors.grey[300]),
                                const SizedBox(height: 8),
                                Text(
                                  'Sin mensajes aún',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: messages.map((msg) {
                          final text = msg['text'] as String? ?? '';
                          final ts = msg['created_at'] as Timestamp?;
                          final date = ts != null
                              ? '${ts.toDate().day}/${ts.toDate().month} ${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                              : '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.admin_panel_settings, size: 16, color: Colors.blueAccent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                      const SizedBox(height: 4),
                                      Text(date, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),

                  const SizedBox(height: 16),

                  // Send message field
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          maxLines: 3,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: isOnline
                                ? 'Escribe un mensaje al conductor...'
                                : 'El conductor está desconectado. Igualmente puedes enviar un mensaje.',
                            hintStyle: const TextStyle(fontSize: 13),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.blueAccent),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _sendingMessage
                              ? null
                              : () => _sendMessage(_messageController.text),
                          icon: _sendingMessage
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: const Text('Enviar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Trip History ──
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
                          if (v.registrationPhotoUrl != null) _buildDocThumb(context, 'T. Propiedad', v.registrationPhotoUrl!),
                          if (v.vehiclePhotoUrl != null) _buildDocThumb(context, 'Vehículo', v.vehiclePhotoUrl!),
                          if (v.insurancePhotoUrl != null) _buildDocThumb(context, 'Seguro', v.insurancePhotoUrl!),
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
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(child: InteractiveViewer(child: Image.network(url))),
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  style: IconButton.styleFrom(backgroundColor: Colors.black45),
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
