import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:tincars/features/driver/presentation/screens/driver_registration_screen.dart';
import 'package:tincars/features/home/presentation/providers/user_mode_provider.dart';

// Provider to stream admin messages for this driver
final driverMessagesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, driverId) {
      return FirebaseFirestore.instance
          .collection('driver_messages')
          .doc(driverId)
          .collection('messages')
          .orderBy('created_at', descending: true)
          .limit(10)
          .snapshots()
          .map((snap) => snap.docs.map((d) => d.data()).toList());
    });

class DriverWaitingScreen extends ConsumerWidget {
  final String status; // 'pending' or 'rejected'
  final String? rejectionReason;
  final String? driverId;
  final Map<String, String>? rejectedPhotos;

  const DriverWaitingScreen({
    super.key,
    required this.status,
    this.rejectionReason,
    this.driverId,
    this.rejectedPhotos,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRejected = status == 'rejected';
    final messagesAsync = driverId != null
        ? ref.watch(driverMessagesProvider(driverId!))
        : null;

    // Mark messages as read when screen is visible
    if (driverId != null) {
      FirebaseFirestore.instance
          .collection('driver_messages')
          .doc(driverId)
          .set({'has_unread': false}, SetOptions(merge: true));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black, Color(0xFF1A1A1A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              children: [
                // Status icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isRejected
                        ? Colors.redAccent.withOpacity(0.1)
                        : Colors.blueAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isRejected ? Colors.redAccent : Colors.blueAccent,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isRejected
                        ? Icons.error_outline_rounded
                        : Icons.hourglass_empty_rounded,
                    color: isRejected ? Colors.redAccent : Colors.blueAccent,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  isRejected ? 'Solicitud Rechazada' : 'Documentos en Revisión',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isRejected
                      ? 'El equipo revisó tu solicitud y encontró algo que necesita corrección.'
                      : 'Hemos recibido tus documentos. Nuestro equipo los está validando.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Rejection reason global
                if (isRejected && rejectionReason != null)
                  PremiumGlassContainer(
                    padding: const EdgeInsets.all(18),
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.redAccent,
                    opacity: 0.08,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            rejectionReason!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Per-photo rejection details
                if (isRejected &&
                    rejectedPhotos != null &&
                    rejectedPhotos!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  PremiumGlassContainer(
                    padding: const EdgeInsets.all(18),
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white,
                    opacity: 0.05,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FOTOS QUE DEBES CORREGIR',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...rejectedPhotos!.entries.map((e) {
                          final photoName = _photoIdToName(e.key);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.redAccent.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.photo_camera,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        photoName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        e.value,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],

                // Admin messages
                if (messagesAsync != null) ...[
                  const SizedBox(height: 16),
                  messagesAsync.when(
                    data: (messages) {
                      if (messages.isEmpty) return const SizedBox.shrink();
                      return PremiumGlassContainer(
                        padding: const EdgeInsets.all(18),
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.white,
                        opacity: 0.05,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'MENSAJES DEL EQUIPO TIN',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...messages.map((msg) {
                              final text = msg['text'] as String? ?? '';
                              final ts = msg['created_at'] as Timestamp?;
                              final date = ts != null
                                  ? '${ts.toDate().day}/${ts.toDate().month} ${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                                  : '';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blueAccent.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      date,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],

                const SizedBox(height: 40),

                if (!isRejected)
                  PremiumGlassContainer(
                    padding: const EdgeInsets.all(20),
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white,
                    opacity: 0.05,
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blueAccent),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Tiempo estimado: 24-48 horas hábiles.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                if (isRejected)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const DriverRegistrationScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'CORREGIR Y REENVIAR',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  )
                else
                  const Text(
                    'Te notificaremos en cuanto seas activado.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),

                const SizedBox(height: 16),

                TextButton.icon(
                  onPressed: () {
                    ref.read(isModeTransitioningProvider.notifier).start();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      ref
                          .read(userModeProvider.notifier)
                          .setMode(UserMode.passenger);
                    });
                  },
                  icon: const Icon(Icons.person, color: Colors.white70),
                  label: const Text(
                    'CAMBIAR A MODO PASAJERO',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _photoIdToName(String id) {
    const map = {
      'face': 'Foto de Perfil (Selfie)',
      'license_front': 'Licencia de Conducir',
      'dni_front': 'ID Frontal',
      'dni_back': 'ID Posterior',
      'registration': 'Seguro del Carro',
      'vehicle': 'Foto del Vehículo',
      'insurance_policy': 'Póliza de Seguro',
    };
    return map[id] ?? id;
  }
}
