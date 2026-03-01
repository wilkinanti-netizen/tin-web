import 'package:tincars/core/utils/app_logger.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:uuid/uuid.dart';

class DriverRegistrationScreen extends ConsumerStatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  ConsumerState<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState
    extends ConsumerState<DriverRegistrationScreen> {
  final _picker = ImagePicker();
  final _dniController = TextEditingController();
  final _pageController = PageController();
  int _currentPage = 0;
  DateTime? _birthDate;
  bool _isLoading = false;

  File? _facePhoto;
  File? _licenseFrontPhoto;
  File? _licenseBackPhoto;
  File? _dniFrontPhoto;
  File? _dniBackPhoto;
  File? _registrationPhoto;
  File? _vehiclePhoto;

  final _vehicleController = TextEditingController();
  final _plateController = TextEditingController();
  VehicleType _selectedVehicleType = VehicleType.essentials;

  @override
  void initState() {
    super.initState();
    // Pre-check if user is already pending or active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProfileProvider).asData?.value;
      if (user != null &&
          (user.driverStatus == DriverStatus.pending ||
              user.driverStatus == DriverStatus.active)) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ya tienes un registro en proceso o activo.'),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _dniController.dispose();
    _vehicleController.dispose();
    _plateController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool _canGoToNextStep() {
    if (_currentPage == 0) {
      return _facePhoto != null &&
          _dniFrontPhoto != null &&
          _dniBackPhoto != null &&
          _dniController.text.isNotEmpty &&
          _birthDate != null;
    } else if (_currentPage == 1) {
      return _licenseFrontPhoto != null && _licenseBackPhoto != null;
    } else if (_currentPage == 2) {
      return _registrationPhoto != null &&
          _vehiclePhoto != null &&
          _vehicleController.text.isNotEmpty &&
          _plateController.text.isNotEmpty;
    }
    return true;
  }

  void _nextPage() {
    if (_canGoToNextStep()) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _pickImage(String type) async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Compress image
    );

    if (pickedFile != null) {
      setState(() {
        final file = File(pickedFile.path);
        switch (type) {
          case 'face':
            _facePhoto = file;
            break;
          case 'license_front':
            _licenseFrontPhoto = file;
            break;
          case 'license_back':
            _licenseBackPhoto = file;
            break;
          case 'dni_front':
            _dniFrontPhoto = file;
            break;
          case 'dni_back':
            _dniBackPhoto = file;
            break;
          case 'registration':
            _registrationPhoto = file;
            break;
          case 'vehicle':
            _vehiclePhoto = file;
            break;
        }
      });
    }
  }

  Future<String?> _uploadImage(
    File imageFile,
    String type,
    String userId,
  ) async {
    AppLogger.log('DEBUG: 📸 Subiendo imagen [$type]...');
    try {
      final ext = imageFile.path.split('.').last;
      final fileName = '${userId}_${type}_${const Uuid().v4()}.$ext';

      await Supabase.instance.client.storage
          .from('driver_verifications')
          .upload(fileName, imageFile);

      final url = Supabase.instance.client.storage
          .from('driver_verifications')
          .getPublicUrl(fileName);
      AppLogger.log('DEBUG: ✅ $type subida: $url');
      return url;
    } catch (e) {
      AppLogger.log('DEBUG: ❌ ERROR subiendo $type: $e');
      return null;
    }
  }

  Future<void> _submitApplication() async {
    AppLogger.log('DEBUG: 🏁 Iniciando _submitApplication');
    FocusScope.of(context).unfocus();
    if (_facePhoto == null ||
        _licenseFrontPhoto == null ||
        _licenseBackPhoto == null ||
        _dniFrontPhoto == null ||
        _dniBackPhoto == null ||
        _registrationPhoto == null ||
        _vehiclePhoto == null ||
        _dniController.text.isEmpty ||
        _birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, completa todos los datos y sube todas las fotos.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    AppLogger.log('DEBUG: ⏳ Estado cargando (Loading) activado');

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        AppLogger.log('DEBUG: ❌ ERROR - Usuario nulo en Supabase Auth');
        throw Exception('Usuario no autenticado.');
      }

      final userId = user.id;
      AppLogger.log('DEBUG: 👤 ID de usuario: $userId');

      AppLogger.log('DEBUG: 📁 Iniciando carga masiva de fotos al Storage...');
      // 1. Upload photos to storage
      final faceUrl = await _uploadImage(_facePhoto!, 'face', userId);
      final lFrontUrl = await _uploadImage(
        _licenseFrontPhoto!,
        'license_front',
        userId,
      );
      final lBackUrl = await _uploadImage(
        _licenseBackPhoto!,
        'license_back',
        userId,
      );
      final dFrontUrl = await _uploadImage(
        _dniFrontPhoto!,
        'dni_front',
        userId,
      );
      final dBackUrl = await _uploadImage(_dniBackPhoto!, 'dni_back', userId);
      final registrationUrl = await _uploadImage(
        _registrationPhoto!,
        'reg',
        userId,
      );
      final vehicleUrl = await _uploadImage(_vehiclePhoto!, 'vehicle', userId);

      AppLogger.log('DEBUG: ✅ Fotos subidas correctamente.');

      if (faceUrl == null ||
          lFrontUrl == null ||
          lBackUrl == null ||
          dFrontUrl == null ||
          dBackUrl == null ||
          registrationUrl == null ||
          vehicleUrl == null) {
        AppLogger.log('DEBUG: ❌ ERROR - Al menos una URL es nula');
        throw Exception('Error al subir una o más imágenes.');
      }

      print(
        'DEBUG: 📄 [PASO 1] Insertando datos en tabla driver_verifications (DNI: ${_dniController.text})',
      );
      // 2. Upsert into driver_verifications table
      await Supabase.instance.client.from('driver_verifications').upsert({
        'driver_id': userId,
        'dni_number': _dniController.text.trim(),
        'birth_date': _birthDate!.toIso8601String().split('T')[0],
        'face_photo_url': faceUrl,
        'license_photo_url': lFrontUrl,
        'license_back_photo_url': lBackUrl,
        'dni_front_photo_url': dFrontUrl,
        'dni_back_photo_url': dBackUrl,
        'registration_photo_url': registrationUrl,
        'vehicle_photo_url': vehicleUrl,
        'status': 'pending',
        'rejection_reason': null,
      }, onConflict: 'driver_id');
      AppLogger.log('DEBUG: ✅ Registro en driver_verifications exitoso');

      print(
        'DEBUG: 🚗 [PASO 2] Insertando datos en tabla driver_data (Modelo: ${_vehicleController.text})',
      );
      // 3. Insert into driver_data table
      await Supabase.instance.client.from('driver_data').upsert({
        'profile_id': userId,
        'vehicle_model': _vehicleController.text.trim(),
        'vehicle_plate': _plateController.text.trim().toUpperCase(),
        'vehicle_type': _selectedVehicleType.name,
        'is_verified': false,
        'active_services': [_selectedVehicleType.name],
      }, onConflict: 'profile_id');
      AppLogger.log('DEBUG: ✅ Registro en driver_data exitoso');

      AppLogger.log('DEBUG: 👤 [PASO 3] Actualizando perfil de usuario...');
      // 4. Update user profile explicitly to set driver_status
      await Supabase.instance.client
          .from('profiles')
          .update({'driver_status': DriverStatus.pending.name})
          .eq('id', userId);
      AppLogger.log('DEBUG: ✅ Perfil actualizado a pending');

      AppLogger.log('DEBUG: 🎉 TODO COMPLETADO CON ÉXITO');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud enviada con éxito. En revisión.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to profile
      }
    } catch (e) {
      AppLogger.log('DEBUG: 🚨 ERROR FATAL en _submitApplication: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      AppLogger.log('DEBUG: 🏁 Finalizando proceso (Loading = false)');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildImageSelector(
    String title,
    String type,
    File? file,
    IconData defaultIcon,
  ) {
    return GestureDetector(
      onTap: () => _pickImage(type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: file != null ? Colors.black : Colors.grey[300]!,
            width: file != null ? 2 : 1,
          ),
          boxShadow: [
            if (file == null)
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  image: file != null
                      ? DecorationImage(
                          image: FileImage(file),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: file == null
                    ? Icon(defaultIcon, color: Colors.grey[400], size: 24)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: file != null
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
              Icon(
                file != null
                    ? Icons.check_circle
                    : Icons.arrow_forward_ios_rounded,
                color: file != null ? Colors.green : Colors.grey[300],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          "Paso ${_currentPage + 1} de 3",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Row(
                  children: List.generate(3, (index) {
                    return Expanded(
                      child: Container(
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index <= _currentPage
                              ? Colors.black
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    _buildPersonalInfoStep(),
                    _buildLicenseStep(),
                    _buildVehicleStep(),
                  ],
                ),
              ),

              // Bottom Navigation
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey[100]!)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      if (_currentPage > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _previousPage,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              side: BorderSide(
                                color: Colors.grey[300]!,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "Atrás",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (_currentPage > 0) const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : (_currentPage < 2
                                    ? _nextPage
                                    : _submitApplication),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _currentPage < 2
                                      ? "SIGUIENTE"
                                      : "ENVIAR SOLICITUD",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: PremiumGlassContainer(
                  padding: EdgeInsets.all(24),
                  color: Colors.white,
                  opacity: 0.9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.black),
                      SizedBox(height: 16),
                      Text("Subiendo documentos..."),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Información Personal",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Identifícate con tus documentos básicos.",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _dniController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Cédula / DNI",
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined, color: Colors.black),
                  const SizedBox(width: 12),
                  Text(
                    _birthDate == null
                        ? "Fecha de Nacimiento"
                        : "${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}",
                    style: TextStyle(
                      color: _birthDate == null ? Colors.grey : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildImageSelector(
            "Foto de Perfil (Selfie)",
            "face",
            _facePhoto,
            Icons.person_outline,
          ),
          _buildImageSelector(
            "Cédula Frontal",
            "dni_front",
            _dniFrontPhoto,
            Icons.credit_card,
          ),
          _buildImageSelector(
            "Cédula Posterior",
            "dni_back",
            _dniBackPhoto,
            Icons.credit_card,
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Documentos de Conducción",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Queremos asegurar que eres un conductor capacitado.",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          _buildImageSelector(
            "Licencia (Frente)",
            "license_front",
            _licenseFrontPhoto,
            Icons.assignment_ind_outlined,
          ),
          _buildImageSelector(
            "Licencia (Dorso)",
            "license_back",
            _licenseBackPhoto,
            Icons.assignment_ind_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Tu Vehículo",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Cuéntanos sobre el auto que usarás.",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          _buildImageSelector(
            "Tarjeta de Propiedad",
            "registration",
            _registrationPhoto,
            Icons.description_outlined,
          ),
          _buildImageSelector(
            "Foto del Vehículo",
            "vehicle",
            _vehiclePhoto,
            Icons.directions_car_outlined,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _vehicleController,
            decoration: InputDecoration(
              labelText: "Modelo del Vehículo (Ej: Toyota Corolla 2022)",
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.drive_eta_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _plateController,
            decoration: InputDecoration(
              labelText: "Placa / Matrícula",
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.pin_outlined),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Categoría de Servicio",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<VehicleType>(
                value: _selectedVehicleType,
                isExpanded: true,
                items: VehicleType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedVehicleType = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
