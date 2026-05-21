import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  ConsumerState<DriverVerificationDetailScreen> createState() =>
      _DriverVerificationDetailScreenState();
}

class _DriverVerificationDetailScreenState
    extends ConsumerState<DriverVerificationDetailScreen> {
  final List<VehicleType> _selectedCategories = [];
  bool _initialized = false;

  void _onCategoryToggled(VehicleType type) {
    setState(() {
      if (_selectedCategories.contains(type)) {
        if (_selectedCategories.length > 1) {
          // At least one category
          _selectedCategories.remove(type);
        }
      } else {
        _selectedCategories.add(type);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final verificationAsync = ref.watch(
      verificationDataProvider(widget.userId),
    );
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
      backgroundColor: const Color(
        0xFFF4F7FC,
      ), // Softer, more modern background
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        title: Text(
          'Revisión de Perfil',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Elegant Profile Header ---
            profilesAsync.when(
              data: (profiles) {
                final user = profiles
                    .where((p) => p.id == widget.userId)
                    .firstOrNull;
                if (user == null) return const SizedBox.shrink();
                return PremiumGlassContainer(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  opacity: 1,
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blueAccent.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: user.avatarUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  user.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 36,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 36,
                                color: Colors.blueAccent,
                              ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.5),
                                ),
                              ),
                              child: const Text(
                                'PENDIENTE DE APROBACIÓN',
                                style: TextStyle(
                                  color: Colors.orange,
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
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Text('Error perfiles: $e'),
            ),
            const SizedBox(height: 24),
            // Personal Info Section
            profilesAsync.when(
              data: (profiles) {
                final user = profiles
                    .where((p) => p.id == widget.userId)
                    .firstOrNull;
                if (user == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection(
                      'Datos de Contacto',
                      Icons.contact_mail_outlined,
                      {
                        'Nombre': user.fullName,
                        'Email': user.email,
                        'Teléfono': user.phoneNumber ?? 'N/A',
                        'Ciudad': user.city ?? 'N/A',
                        'SSN (Últimos 4)': user.ssnLast4 ?? 'N/A',
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
            ),

            // Vehicle Info Section
            driverDataAsync.when(
              data: (driverData) {
                if (driverData == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection(
                      'Información del Vehículo',
                      Icons.directions_car_outlined,
                      {
                        'Modelo': driverData.vehicleModel,
                        'Placa': driverData.vehiclePlate,
                        'Color': driverData.vehicleColor ?? 'N/A',
                        'Año': driverData.vehicleYear ?? 'N/A',
                        'Categoría Base': driverData.vehicleType.name
                            .toUpperCase(),
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- Categories Selection Section ---
                    _SectionHeader(
                      'Categorías Permitidas',
                      icon: Icons.category_outlined,
                    ),
                    const SizedBox(height: 16),
                    PremiumGlassContainer(
                      padding: const EdgeInsets.all(8),
                      color: Colors.white,
                      opacity: 1,
                      child: Column(
                        children: VehicleType.values.map((type) {
                          final isSelected = _selectedCategories.contains(type);
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.black.withOpacity(0.03)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: CheckboxListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              title: Text(
                                type.name.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 14,
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.grey[700],
                                ),
                              ),
                              value: isSelected,
                              onChanged: (_) => _onCategoryToggled(type),
                              activeColor: Colors.black,
                              checkColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              controlAffinity: ListTileControlAffinity.trailing,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, s) => Text('Error vehículo: $e'),
            ),

            // Documents
            verificationAsync.when(
              data: (verification) {
                if (verification == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection('Datos Generales', Icons.badge_outlined, {
                      'DNI / Cédula': verification.dniNumber ?? 'N/A',
                      'Estado Actual': verification.status.toUpperCase(),
                    }),
                    const SizedBox(height: 24),
                    _buildPhotoSection(
                      context,
                      ref,
                      'Documentos de Identidad',
                      verification.rejectedPhotos ?? {},
                      [
                        if (verification.facePhotoUrl != null)
                          _PhotoItem(
                            'face',
                            'Selfie',
                            verification.facePhotoUrl!,
                          ),
                        if (verification.dniFrontPhotoUrl != null)
                          _PhotoItem(
                            'dni_front',
                            'DNI Frontal',
                            verification.dniFrontPhotoUrl!,
                          ),
                        if (verification.dniBackPhotoUrl != null)
                          _PhotoItem(
                            'dni_back',
                            'DNI Posterior',
                            verification.dniBackPhotoUrl!,
                          ),
                        if (verification.licensePhotoUrl != null)
                          _PhotoItem(
                            'license_front',
                            'Licencia (Frontal)',
                            verification.licensePhotoUrl!,
                          ),
                        if (verification.registrationPhotoUrl != null)
                          _PhotoItem(
                            'registration',
                            'Tarjeta de Propiedad',
                            verification.registrationPhotoUrl!,
                          ),
                        if (verification.vehiclePhotoUrl != null)
                          _PhotoItem(
                            'vehicle',
                            'Foto del Vehículo',
                            verification.vehiclePhotoUrl!,
                          ),
                        if (verification.insurancePhotoUrl != null)
                          _PhotoItem(
                            'insurance_policy',
                            'Póliza de Seguro',
                            verification.insurancePhotoUrl!,
                          ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error docs: $e'),
            ),

            const SizedBox(height: 40),

            PremiumGlassContainer(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              opacity: 1,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _handleApproval(context, ref, DriverStatus.rejected),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'RECHAZAR PERFIL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _handleApproval(context, ref, DriverStatus.active),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                        shadowColor: Colors.black38,
                      ),
                      child: const Text(
                        'APROBAR PERFIL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
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

  void _handleApproval(
    BuildContext context,
    WidgetRef ref,
    DriverStatus status,
  ) async {
    String? rejectionReason;
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          status == DriverStatus.active
              ? '¿Aprobar conductor?'
              : '¿Rechazar conductor?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status == DriverStatus.active
                  ? 'Se guardarán las ${_selectedCategories.length} categorías seleccionadas.'
                  : 'Indica el motivo del rechazo:',
            ),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
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
      await ref
          .read(adminControllerProvider.notifier)
          .updateDriverStatus(
            widget.userId,
            status,
            rejectionReason: rejectionReason,
            activeServices: status == DriverStatus.active
                ? _selectedCategories
                : null,
          );
      ref.invalidate(allProfilesProvider);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Widget _buildInfoSection(
    String title,
    IconData icon,
    Map<String, String> details,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title, icon: icon),
        const SizedBox(height: 16),
        PremiumGlassContainer(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          opacity: 1,
          child: Column(
            children: details.entries
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            e.key,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            e.value,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    Map<String, String> rejectedPhotos,
    List<_PhotoItem> photos,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title, icon: Icons.photo_library_outlined),
        const SizedBox(height: 16),
        PremiumGlassContainer(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.white,
          opacity: 1,
          child: Column(
            children: photos.asMap().entries.map((entry) {
              final index = entry.key;
              final photo = entry.value;
              final isRejected = rejectedPhotos.containsKey(photo.id);
              final existingReason = rejectedPhotos[photo.id] ?? '';
              final isApproved = !isRejected;

              return _PhotoToggleRow(
                photo: photo,
                isApproved: isApproved,
                existingReason: existingReason,
                isFirst: index == 0,
                isLast: index == photos.length - 1,
                onTap: () => _showFullScreen(context, ref, photo),
                onToggleChanged: (approved) async {
                  if (!approved) {
                    // Will be handled by the text field submit inside _PhotoToggleRow
                    // When toggled to rejected, show reason input
                  } else {
                    // Remove rejection for this photo
                    final verif = ref
                        .read(verificationDataProvider(widget.userId))
                        .asData
                        ?.value;
                    final currentRejected = Map<String, String>.from(
                      verif?.rejectedPhotos ?? {},
                    );
                    currentRejected.remove(photo.id);
                    final newStatus = currentRejected.isEmpty
                        ? DriverStatus.pending
                        : DriverStatus.rejected;
                    await ref
                        .read(adminControllerProvider.notifier)
                        .updateDriverStatus(
                          widget.userId,
                          newStatus,
                          rejectionReason: currentRejected.isEmpty
                              ? null
                              : 'Fotos rechazadas',
                          rejectedPhotos: currentRejected,
                        );
                    ref.invalidate(verificationDataProvider(widget.userId));
                    ref.invalidate(allProfilesProvider);
                  }
                },
                onReasonSubmit: (reason) async {
                  final verif = ref
                      .read(verificationDataProvider(widget.userId))
                      .asData
                      ?.value;
                  final currentRejected = Map<String, String>.from(
                    verif?.rejectedPhotos ?? {},
                  );
                  currentRejected[photo.id] = reason;
                  await ref
                      .read(adminControllerProvider.notifier)
                      .updateDriverStatus(
                        widget.userId,
                        DriverStatus.rejected,
                        rejectionReason:
                            'Fotos rechazadas — ${currentRejected.keys.join(', ')}',
                        rejectedPhotos: currentRejected,
                      );
                  ref.invalidate(verificationDataProvider(widget.userId));
                  ref.invalidate(allProfilesProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${photo.title} rechazada. El conductor verá el motivo.',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showFullScreen(BuildContext context, WidgetRef ref, _PhotoItem photo) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(child: InteractiveViewer(child: Image.network(photo.url))),
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
                  photo.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  const _SectionHeader(this.title, {this.icon});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: Colors.blueAccent),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _PhotoItem {
  final String id;
  final String title;
  final String url;
  _PhotoItem(this.id, this.title, this.url);
}

// ── Stateful widget: one row per photo with toggle + inline reason input ──
class _PhotoToggleRow extends StatefulWidget {
  final _PhotoItem photo;
  final bool isApproved;
  final String existingReason;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final Future<void> Function(bool approved) onToggleChanged;
  final Future<void> Function(String reason) onReasonSubmit;

  const _PhotoToggleRow({
    required this.photo,
    required this.isApproved,
    required this.existingReason,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    required this.onToggleChanged,
    required this.onReasonSubmit,
  });

  @override
  State<_PhotoToggleRow> createState() => _PhotoToggleRowState();
}

class _PhotoToggleRowState extends State<_PhotoToggleRow> {
  late bool _approved;
  late TextEditingController _reasonController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _approved = widget.isApproved;
    _reasonController = TextEditingController(text: widget.existingReason);
  }

  @override
  void didUpdateWidget(_PhotoToggleRow old) {
    super.didUpdateWidget(old);
    if (old.isApproved != widget.isApproved) {
      _approved = widget.isApproved;
    }
    if (old.existingReason != widget.existingReason) {
      _reasonController.text = widget.existingReason;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!widget.isFirst) const Divider(height: 1, indent: 72),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Thumbnail — tap to enlarge
              GestureDetector(
                onTap: widget.onTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _approved
                            ? Colors.green.shade300
                            : Colors.red.shade300,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          widget.photo.url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        ),
                        if (!_approved)
                          Container(
                            color: Colors.red.withOpacity(0.3),
                            child: const Icon(
                              Icons.cancel,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Title + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.photo.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _approved ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _approved ? 'Aprobada' : 'Rechazada',
                          style: TextStyle(
                            fontSize: 12,
                            color: _approved ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Toggle switch
              Switch(
                value: _approved,
                activeColor: Colors.green,
                inactiveTrackColor: Colors.red.shade100,
                inactiveThumbColor: Colors.red,
                onChanged: _saving
                    ? null
                    : (val) async {
                        setState(() => _approved = val);
                        if (val) {
                          // Approved: clear rejection
                          setState(() => _saving = true);
                          await widget.onToggleChanged(true);
                          setState(() => _saving = false);
                        }
                        // If false: just show reason input below, don't save yet
                      },
              ),
            ],
          ),
        ),
        // Inline reason input — shown when rejected
        AnimatedCrossFade(
          firstChild: const SizedBox(height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Por qué se rechaza esta foto?',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reasonController,
                        autofocus: !_approved,
                        maxLines: 2,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Ej: La foto está borrosa o cortada...',
                          hintStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor: Colors.red.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.red.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.red.shade200),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                final reason = _reasonController.text.trim();
                                if (reason.isEmpty) return;
                                setState(() => _saving = true);
                                await widget.onReasonSubmit(reason);
                                setState(() => _saving = false);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Rechazar',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          crossFadeState: !_approved
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}
