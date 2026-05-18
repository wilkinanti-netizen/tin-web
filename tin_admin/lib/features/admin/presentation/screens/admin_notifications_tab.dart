import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tin_admin/features/profile/domain/models/profiles.dart';
import 'package:tin_admin/features/admin/presentation/controllers/admin_controller.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminNotificationsTab extends ConsumerStatefulWidget {
  const AdminNotificationsTab({super.key});

  @override
  ConsumerState<AdminNotificationsTab> createState() =>
      _AdminNotificationsTabState();
}

class _AdminNotificationsTabState extends ConsumerState<AdminNotificationsTab> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _target = 'all'; // 'all', 'drivers', 'passengers'
  bool _isSending = false;

  // Reporte de envío
  bool _showReport = false;
  int _sentSuccess = 0;
  int _sentFailed = 0;
  List<dynamic> _failures = [];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('ENVIAR NOTIFICACIÓN PUSH'),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SEGMENTACIÓN',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildTargetChip('TODOS', 'all', Icons.groups),
                          const SizedBox(width: 12),
                          _buildTargetChip(
                            'CONDUCTORES',
                            'drivers',
                            Icons.drive_eta,
                          ),
                          const SizedBox(width: 12),
                          _buildTargetChip(
                            'PASAJEROS',
                            'passengers',
                            Icons.person,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'CONTENIDO',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Título de la notificación',
                        _titleController,
                        Icons.title,
                        1,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        'Mensaje detallado...',
                        _bodyController,
                        Icons.message_outlined,
                        4,
                      ),
                      const SizedBox(height: 32),

                      if (_showReport) _buildDeliveryReport(),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isSending ? null : _sendNotification,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1C1E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSending
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.send_rounded, size: 18),
                                    const SizedBox(width: 12),
                                    Text(
                                      'ENVIAR AHORA',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('PREVISTA EN MÓVIL'),
                const SizedBox(height: 24),
                _buildMobilePreview(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryReport() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 16,
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 8),
              Text(
                'REPORTE DE ÚLTIMO ENVÍO',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildReportStat('ÉXITO', '$_sentSuccess', Colors.green),
              _buildReportStat('FALLIDO', '$_sentFailed', Colors.red),
              _buildReportStat(
                'TOTAL',
                '${_sentSuccess + _sentFailed}',
                Colors.black87,
              ),
            ],
          ),
          if (_failures.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'DETALLES DE FALLOS:',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _failures.map((f) {
                    final email = f['email'] ?? 'Unknown';
                    final error = f['error'] ?? 'Unknown error';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $email: $error',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.red.shade700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1A1C1E).withOpacity(0.7),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTargetChip(String label, String value, IconData icon) {
    final isSelected = _target == value;
    return InkWell(
      onTap: () => setState(() {
        _target = value;
        _showReport = false; // Ocultar reporte al cambiar segmento
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF1A1C1E) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    TextEditingController controller,
    IconData icon,
    int lines,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        maxLines: lines,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.outfit(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildMobilePreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.grey.shade800, width: 8),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleController.text.isEmpty
                            ? 'Título de Notificación'
                            : _titleController.text,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _bodyController.text.isEmpty
                            ? 'Aquí aparecerá el contenido de tu mensaje masivo.'
                            : _bodyController.text,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 300),
        ],
      ),
    );
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    setState(() {
      _isSending = true;
      _showReport = false;
    });

    try {
      debugPrint('🔔 [PANEL] Iniciando envío de notificación...');
      debugPrint(
        '🔔 [PANEL] Datos: title=${_titleController.text}, body=${_bodyController.text}, target=$_target',
      );

      // 1. Call the HTTPS Callable function directly
      final result = await FirebaseFunctions.instance
          .httpsCallable('sendBroadcastNotification')
          .call({
            'title': _titleController.text.trim(),
            'body': _bodyController.text.trim(),
            'target': _target,
          });

      debugPrint('🔔 [PANEL] Respuesta recibida: ${result.data}');
      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        _sentSuccess = (data['successCount'] as num?)?.toInt() ?? 0;
        _sentFailed = (data['failureCount'] as num?)?.toInt() ?? 0;
        _failures = data['failures'] as List<dynamic>? ?? [];

        if (mounted) {
          setState(() => _showReport = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ $_sentSuccess enviadas, $_sentFailed fallidas (tokens limpiados)',
              ),
              backgroundColor: Colors.green,
            ),
          );
          _titleController.clear();
          _bodyController.clear();
        }
      } else {
        throw Exception(data['error'] ?? 'Error desconocido en el servidor');
      }
    } catch (e) {
      debugPrint('❌ [PANEL ERROR] Error al llamar a la función: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
