import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tincars/core/utils/app_logger.dart';
import 'package:tincars/features/support/presentation/screens/my_tickets_screen.dart';

class SupportScreen extends ConsumerStatefulWidget {
  final String? tripId;
  final String? driverName;

  const SupportScreen({super.key, this.tripId, this.driverName});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  String? _selectedCategory;
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;

  final List<Map<String, dynamic>> _categories = [
    {
      'id': 'lost_item',
      'icon': Icons.work_outline_rounded,
      'title': 'Objeto perdido',
      'subtitle': 'Dejé algo en el vehículo',
      'color': Colors.orange,
    },
    {
      'id': 'safety',
      'icon': Icons.shield_outlined,
      'title': 'Problema de seguridad',
      'subtitle': 'Reportar un incidente de seguridad',
      'color': Colors.red,
    },
    {
      'id': 'payment',
      'icon': Icons.credit_card_rounded,
      'title': 'Problema con el cobro',
      'subtitle': 'Cargo incorrecto o doble cobro',
      'color': Colors.blue,
    },
    {
      'id': 'driver_behavior',
      'icon': Icons.person_off_outlined,
      'title': 'Comportamiento del conductor',
      'subtitle': 'Conducción peligrosa o mala actitud',
      'color': Colors.purple,
    },
    {
      'id': 'route',
      'icon': Icons.route_rounded,
      'title': 'Problema con la ruta',
      'subtitle': 'Ruta incorrecta o desvío innecesario',
      'color': Colors.teal,
    },
    {
      'id': 'other',
      'icon': Icons.help_outline_rounded,
      'title': 'Otro problema',
      'subtitle': 'Algo más que necesite atención',
      'color': Colors.grey,
    },
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Centro de Ayuda',
          style: GoogleFonts.outfit(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.black87),
            tooltip: 'Mis Tickets',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
              );
            },
          ),
        ],
      ),
      body: _submitted ? _buildSuccessView() : _buildFormView(),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 60,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '¡Reporte Enviado!',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedCategory == 'lost_item'
                  ? 'Hemos notificado al conductor sobre tu objeto perdido. Te contactaremos pronto para coordinar la devolución.'
                  : 'Nuestro equipo revisará tu caso y te contactará a la brevedad.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1C1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Volver al inicio',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.tripId != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reporte relacionado con tu viaje reciente${widget.driverName != null ? ' con ${widget.driverName}' : ''}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Text(
            '¿Cuál es tu problema?',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...(_categories.map((cat) => _buildCategoryTile(cat))),
          if (_selectedCategory != null) ...[
            const SizedBox(height: 24),
            Text(
              'Describe tu problema',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: _selectedCategory == 'lost_item'
                      ? 'Describe el objeto que dejaste (ej: mochila negra, teléfono Samsung)...'
                      : 'Describe con detalle lo que ocurrió...',
                  hintStyle: GoogleFonts.outfit(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                ),
                style: GoogleFonts.outfit(fontSize: 14),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1C1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Enviar Reporte',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> category) {
    final isSelected = _selectedCategory == category['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (category['color'] as Color).withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (category['color'] as Color).withOpacity(0.4)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (category['color'] as Color).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                category['icon'] as IconData,
                color: category['color'] as Color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category['title'] as String,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    category['subtitle'] as String,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? category['color'] as Color
                  : Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor describe tu problema')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      final reportData = {
        'user_id': userId,
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'trip_id': widget.tripId,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('support_tickets')
          .add(reportData);

      // If lost item, also create a notification job for the driver
      if (_selectedCategory == 'lost_item' && widget.tripId != null) {
        final tripDoc = await FirebaseFirestore.instance
            .collection('trips')
            .doc(widget.tripId)
            .get();

        if (tripDoc.exists) {
          final driverId = tripDoc.data()?['driver_id'];
          if (driverId != null) {
            await FirebaseFirestore.instance
                .collection('notification_jobs')
                .add({
              'title': '📦 Objeto perdido reportado',
              'body':
                  'Un pasajero reportó un objeto olvidado en tu vehículo. Revisa la app para más detalles.',
              'target': driverId,
              'created_at': FieldValue.serverTimestamp(),
              'status': 'pending',
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
      }
    } catch (e) {
      AppLogger.error('Error submitting support ticket', error: e);
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar reporte: $e')),
        );
      }
    }
  }
}
