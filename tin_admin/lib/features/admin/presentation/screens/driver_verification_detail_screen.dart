import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tin_admin/features/admin/presentation/controllers/admin_controller.dart';
import 'package:tin_admin/features/profile/domain/models/profiles.dart';
import 'package:tin_admin/core/widgets/premium_glass_container.dart';

class DriverVerificationDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;

  const DriverVerificationDetailScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  ConsumerState<DriverVerificationDetailScreen> createState() => _DriverVerificationDetailScreenState();
}

class _DriverVerificationDetailScreenState extends ConsumerState<DriverVerificationDetailScreen> {
  final List<VehicleType> _selectedCategories = [];
  bool _initialized = false;

  void _onCategoryToggled(VehicleType type) {
    setState(() {
      if (_selectedCategories.contains(type)) {
        if (_selectedCategories.length > 1) { // At least one category
          _selectedCategories.remove(type);
        }
      } else {
        _selectedCategories.add(type);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final verificationAsync = ref.watch(verificationDataProvider(widget.userId));
    final driverDataAsync = ref.watch(driverDataProvider(widget.userId));
    final profilesAsync = ref.watch(allProfilesProvider);

    // Initial state setup from existing driver data
    driverDataAsync.whenData((driverData) {
      if (!_initialized && driverData != null) {
        _selectedCategories.clear();
        _selectedCategories.addAll(driverData.activeServices);
        _initialized = true;
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(
          'VERIFICACIÓN: ${widget.userName}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Personal Info Section
            profilesAsync.when(
              data: (profiles) {
                final user = profiles.where((p) => p.id == widget.userId).firstOrNull;
                if (user == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection('DATOS DE CONTACTO', {
                      'Nombre': user.fullName,
                      'Email': user.email,
                      'Teléfono': user.phoneNumber ?? 'N/A',
                      'Ciudad': user.city ?? 'N/A',
                      'SSN (Últimos 4)': user.ssnLast4 ?? 'N/A',
                    }),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (e, s) => Text('Error perfiles: $e'),
            ),

            // Vehicle Info Section
            driverDataAsync.when(
              data: (driverData) {
                if (driverData == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection('INFORMACIÓN DEL VEHÍCULO', {
                      'Modelo': driverData.vehicleModel,
                      'Placa': driverData.vehiclePlate,
                      'Color': driverData.vehicleColor ?? 'N/A',
                      'Año': driverData.vehicleYear ?? 'N/A',
                      'Categoría Base': driverData.vehicleType.name.toUpperCase(),
                    }),
                    const SizedBox(height: 24),
                    
                    // --- Categories Selection Section ---
                    _SectionHeader('CATEGORÍAS PERMITIDAS PARA ESTE CONDUCTOR'),
                    const SizedBox(height: 12),
                    PremiumGlassContainer(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      opacity: 1,
                      child: Column(
                        children: VehicleType.values.map((type) {
                          final isSelected = _selectedCategories.contains(type);
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              type.name.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            value: isSelected,
                            onChanged: (_) => _onCategoryToggled(type),
                            activeColor: Colors.black,
                            controlAffinity: ListTileControlAffinity.trailing,
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (e, s) => Text('Error vehículo: $e'),
            ),

            // Documents
            verificationAsync.when(
              data: (verification) {
                if (verification == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection('DATOS GENERALES', {
                      'DNI / Cédula': verification.dniNumber ?? 'N/A',
                      'Estado Actual': verification.status.toUpperCase(),
                    }),
                    const SizedBox(height: 24),
                    _buildPhotoSection(context, 'DOCUMENTOS DE IDENTIDAD', [
                      if (verification.facePhotoUrl != null)
                        _PhotoItem('Selfie', verification.facePhotoUrl!),
                      if (verification.dniFrontPhotoUrl != null)
                        _PhotoItem('DNI Frontal', verification.dniFrontPhotoUrl!),
                      if (verification.dniBackPhotoUrl != null)
                        _PhotoItem('DNI Posterior', verification.dniBackPhotoUrl!),
                      if (verification.licensePhotoUrl != null)
                        _PhotoItem('Licencia (F)', verification.licensePhotoUrl!),
                      if (verification.registrationPhotoUrl != null)
                        _PhotoItem('Tarjeta Propiedad', verification.registrationPhotoUrl!),
                      if (verification.vehiclePhotoUrl != null)
                        _PhotoItem('Foto Vehículo', verification.vehiclePhotoUrl!),
                    ]),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error docs: $e'),
            ),

            const SizedBox(height: 40),
            PremiumGlassContainer(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              opacity: 1,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleApproval(context, ref, DriverStatus.rejected),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('RECHAZAR', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleApproval(context, ref, DriverStatus.active),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('APROBAR', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _handleApproval(BuildContext context, WidgetRef ref, DriverStatus status) async {
    String? rejectionReason;
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(status == DriverStatus.active ? '¿Aprobar conductor?' : '¿Rechazar conductor?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status == DriverStatus.active 
              ? 'Se guardarán las ${_selectedCategories.length} categorías seleccionadas.'
              : 'Indica el motivo del rechazo:'),
            if (status == DriverStatus.rejected) ...[
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                maxLines: 3,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () {
              rejectionReason = reasonController.text.trim();
              Navigator.pop(context, true);
            },
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(adminControllerProvider.notifier).updateDriverStatus(
        widget.userId,
        status,
        rejectionReason: rejectionReason,
        activeServices: status == DriverStatus.active ? _selectedCategories : null,
      );
      ref.invalidate(allProfilesProvider);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Widget _buildInfoSection(String title, Map<String, String> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title),
        const SizedBox(height: 12),
        PremiumGlassContainer(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          opacity: 1,
          child: Column(
            children: details.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                  Text(e.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection(BuildContext context, String title, List<_PhotoItem> photos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            return GestureDetector(
              onTap: () => _showFullScreen(context, photo.url, photo.title),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(photo.url, fit: BoxFit.cover),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showFullScreen(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Column(
          children: [
            AppBar(title: Text(title), leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))),
            Expanded(child: InteractiveViewer(child: Image.network(url))),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Text(title, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.2));
  }
}

class _PhotoItem {
  final String title;
  final String url;
  _PhotoItem(this.title, this.url);
}
