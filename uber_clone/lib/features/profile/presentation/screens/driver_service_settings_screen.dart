import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';

class DriverServiceSettingsScreen extends ConsumerStatefulWidget {
  const DriverServiceSettingsScreen({super.key});

  @override
  ConsumerState<DriverServiceSettingsScreen> createState() =>
      _DriverServiceSettingsScreenState();
}

class _DriverServiceSettingsScreenState
    extends ConsumerState<DriverServiceSettingsScreen> {
  final List<VehicleType> _selectedServices = [];
  bool _isLoading = true;
  DriverProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final profile = await ref.read(driverProfileProvider.future);
    if (mounted && profile != null) {
      setState(() {
        _profile = profile;
        _selectedServices.clear();
        _selectedServices.addAll(profile.activeServices);
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (_profile == null || _selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar al menos un servicio.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedProfile = DriverProfile(
        profileId: _profile!.profileId,
        vehicleModel: _profile!.vehicleModel,
        vehiclePlate: _profile!.vehiclePlate,
        vehicleType: _profile!.vehicleType,
        activeServices: _selectedServices,
      );

      await ref.read(profileRepositoryProvider).saveDriverData(updatedProfile);

      // Invalidate the provider to refresh UI
      ref.invalidate(driverProfileProvider);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferencias actualizadas con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _toggleService(VehicleType type) {
    setState(() {
      if (_selectedServices.contains(type)) {
        if (_selectedServices.length > 1) {
          _selectedServices.remove(type);
        }
      } else {
        _selectedServices.add(type);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'CONFIGURACIÓN DE SERVICIO',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.5,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    children: [
                      const Text(
                        'Activa las categorías de viaje que deseas recibir. Entre más actives, más oportunidades de viaje tendrás.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      _buildServiceItem(
                        'ESSENTIALS',
                        'Servicio base estándar',
                        'assets/vehiculos/essentials.png',
                        VehicleType.essentials,
                      ),
                      _buildServiceItem(
                        'ESSENTIALS XL',
                        'Mayor capacidad de pasajeros',
                        'assets/vehiculos/essentialxl.png',
                        VehicleType.essentialXL,
                      ),
                      _buildServiceItem(
                        'EXECUTIVE',
                        'Viajes de lujo y alta gama',
                        'assets/vehiculos/executive.png',
                        VehicleType.executive,
                      ),
                      _buildServiceItem(
                        'SIGNATURE LUX',
                        'Máximo nivel de exclusividad',
                        'assets/vehiculos/signatuve.png',
                        VehicleType.signature,
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'GUARDAR PREFERENCIAS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildServiceItem(
    String name,
    String desc,
    String assetPath,
    VehicleType type,
  ) {
    final isSelected = _selectedServices.contains(type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => _toggleService(type),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.black : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.03),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  assetPath,
                  width: 45,
                  height: 45,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: isSelected ? Colors.black : Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.black87 : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isSelected,
                activeTrackColor: Colors.black.withOpacity(0.8),
                activeColor: Colors.white,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.black12,
                onChanged: (_) => _toggleService(type),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
