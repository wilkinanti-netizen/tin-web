import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tin_admin/features/admin/presentation/controllers/admin_controller.dart';
import 'package:tin_admin/features/admin/domain/models/admin_settings.dart';
import 'package:tin_admin/core/widgets/premium_glass_container.dart';

class AdminSettingsTab extends ConsumerStatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  ConsumerState<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends ConsumerState<AdminSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  AdminSettings? _editableSettings;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(adminSettingsProvider);

    return settingsAsync.when(
      data: (settings) {
        // Initialize local state if not yet set
        _editableSettings ??= settings;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildCommissionSection(),
                const SizedBox(height: 32),
                _buildVehiclesSection(),
                const SizedBox(height: 40),
                _buildSaveButton(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONFIGURACIÓN GLOBAL',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Precios y Comisiones',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          'Gestiona las tarifas de viaje y el porcentaje de comisión para los conductores.',
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCommissionSection() {
    final comm = _editableSettings!.commission;

    return PremiumGlassContainer(
      color: Colors.white,
      opacity: 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.percent, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  Text(
                    'Comisión del Conductor',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Switch.adaptive(
                value: comm.enabled,
                activeColor: Colors.blueAccent,
                onChanged: (val) {
                  setState(() {
                    _editableSettings = AdminSettings(
                      commission: CommissionSettings(
                        enabled: val,
                        message: comm.message,
                        percentage: comm.percentage,
                        lastUpdated: comm.lastUpdated,
                      ),
                      vehicles: _editableSettings!.vehicles,
                    );
                  });
                },
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildNumberField(
                  label: 'Porcentaje (%)',
                  value: comm.percentage.toDouble(),
                  onChanged: (val) {
                    setState(() {
                      _editableSettings = AdminSettings(
                        commission: CommissionSettings(
                          enabled: comm.enabled,
                          message: comm.message,
                          percentage: val.toInt(),
                          lastUpdated: comm.lastUpdated,
                        ),
                        vehicles: _editableSettings!.vehicles,
                      );
                    });
                  },
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: _buildTextField(
                  label: 'Mensaje Informativo',
                  value: comm.message,
                  onChanged: (val) {
                    setState(() {
                      _editableSettings = AdminSettings(
                        commission: CommissionSettings(
                          enabled: comm.enabled,
                          message: val,
                          percentage: comm.percentage,
                          lastUpdated: comm.lastUpdated,
                        ),
                        vehicles: _editableSettings!.vehicles,
                      );
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            'TARIFAS POR VEHÍCULO',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ..._editableSettings!.vehicles.entries.map((entry) {
          return _buildVehicleCard(entry.key, entry.value);
        }).toList(),
      ],
    );
  }

  Widget _buildVehicleCard(String id, VehicleSettings vehicle) {
    return PremiumGlassContainer(
      margin: const EdgeInsets.only(bottom: 20),
      color: Colors.white,
      opacity: 0.9,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            _buildVehicleIcon(id),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.name,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Base: \$${vehicle.base.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        children: [
          const Divider(),
          const SizedBox(height: 16),
          _buildVehicleEditor(id, vehicle),
        ],
      ),
    );
  }

  Widget _buildVehicleEditor(String id, VehicleSettings vehicle) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildNumberField(
                label: 'Tarifa Base',
                value: vehicle.base,
                onChanged: (val) => _updateVehicle(id, vehicle.copyWith(base: val)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildNumberField(
                label: 'Base Fin de Semana',
                value: vehicle.baseWeekend,
                onChanged: (val) => _updateVehicle(id, vehicle.copyWith(baseWeekend: val)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildNumberField(
                label: 'Tarifa Espera (min)',
                value: vehicle.waitTimeFeePerMinute,
                onChanged: (val) => _updateVehicle(id, vehicle.copyWith(waitTimeFeePerMinute: val)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildNumberField(
                label: 'Minutos Espera Gratis',
                value: vehicle.waitTimeFreeMinutes.toDouble(),
                onChanged: (val) => _updateVehicle(id, vehicle.copyWith(waitTimeFreeMinutes: val.toInt())),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Descripción',
          value: vehicle.description,
          maxLines: 2,
          onChanged: (val) => _updateVehicle(id, vehicle.copyWith(description: val)),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Rangos de Distancia (Precio por KM)',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const SizedBox(height: 12),
        ...vehicle.distanceTiers.asMap().entries.map((tierEntry) {
          final idx = tierEntry.key;
          final tier = tierEntry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    label: 'Hasta KM',
                    value: tier.upToKm.toDouble(),
                    onChanged: (val) {
                      final newTiers = List<DistanceTier>.from(vehicle.distanceTiers);
                      newTiers[idx] = DistanceTier(pricePerKm: tier.pricePerKm, upToKm: val.toInt());
                      _updateVehicle(id, vehicle.copyWith(distanceTiers: newTiers));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField(
                    label: 'Precio / KM',
                    value: tier.pricePerKm,
                    onChanged: (val) {
                      final newTiers = List<DistanceTier>.from(vehicle.distanceTiers);
                      newTiers[idx] = DistanceTier(pricePerKm: val, upToKm: tier.upToKm);
                      _updateVehicle(id, vehicle.copyWith(distanceTiers: newTiers));
                    },
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  void _updateVehicle(String id, VehicleSettings newVehicle) {
    setState(() {
      final newVehicles = Map<String, VehicleSettings>.from(_editableSettings!.vehicles);
      newVehicles[id] = newVehicle;
      _editableSettings = AdminSettings(
        commission: _editableSettings!.commission,
        vehicles: newVehicles,
      );
    });
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required Function(String) onChanged,
    int maxLines = 1,
  }) {
    return TextFormField(
      initialValue: value,
      maxLines: maxLines,
      style: GoogleFonts.outfit(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 1),
        ),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildNumberField({
    required String label,
    required double value,
    required Function(double) onChanged,
  }) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: Colors.grey[600], fontWeight: FontWeight.normal),
        filled: true,
        fillColor: Colors.grey[50],
        prefixIcon: const Icon(Icons.attach_money, size: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (val) {
        final d = double.tryParse(val);
        if (d != null) onChanged(d);
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: Colors.blueAccent.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'GUARDAR CAMBIOS',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(adminControllerProvider.notifier).updateAdminSettings(_editableSettings!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildVehicleIcon(String id) {
    String assetPath;
    switch (id) {
      case 'essentials':
        assetPath = 'assets/logo/vehiculos/essentials.png';
        break;
      case 'essentials_xl':
        assetPath = 'assets/logo/vehiculos/essentialxl.png';
        break;
      case 'executive':
        assetPath = 'assets/logo/vehiculos/executive.png';
        break;
      case 'signature_lux':
        assetPath = 'assets/logo/vehiculos/signatuve.png';
        break;
      default:
        return const Icon(Icons.directions_car, size: 32);
    }
    return Image.asset(assetPath, width: 40);
  }
}

extension on VehicleSettings {
  VehicleSettings copyWith({
    double? base,
    double? baseWeekend,
    int? capacity,
    String? description,
    List<DistanceTier>? distanceTiers,
    String? name,
    double? waitTimeFeePerMinute,
    int? waitTimeFreeMinutes,
  }) {
    return VehicleSettings(
      base: base ?? this.base,
      baseWeekend: baseWeekend ?? this.baseWeekend,
      capacity: capacity ?? this.capacity,
      description: description ?? this.description,
      distanceTiers: distanceTiers ?? this.distanceTiers,
      name: name ?? this.name,
      waitTimeFeePerMinute: waitTimeFeePerMinute ?? this.waitTimeFeePerMinute,
      waitTimeFreeMinutes: waitTimeFreeMinutes ?? this.waitTimeFreeMinutes,
    );
  }
}
