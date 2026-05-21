import 'package:tincars/core/utils/app_logger.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isCorrectionMode = false;

  File? _facePhoto;
  File? _licenseFrontPhoto;
  File? _dniFrontPhoto;
  File? _dniBackPhoto;
  File? _registrationPhoto;
  File? _vehiclePhoto;
  File? _insurancePhoto;

  String? _existingFaceUrl;
  String? _existingLicenseFrontUrl;
  String? _existingDniFrontUrl;
  String? _existingDniBackUrl;
  String? _existingRegistrationUrl;
  String? _existingVehicleUrl;
  String? _existingInsuranceUrl;

  Map<String, String> _rejectedPhotos = {};

  String? _selectedCarColor;

  final _vehicleController = TextEditingController();
  final _plateController = TextEditingController();
  VehicleType _selectedVehicleType = VehicleType.essentials;

  // --- Step 4 fields ---
  final _totalSteps = 3;
  final _motivationController = TextEditingController();
  final _hoursPerWeekController = TextEditingController();
  final _ssnController = TextEditingController();
  final _insurancePolicyController = TextEditingController();
  bool _hasExperience = false;
  bool _backgroundCheckConsent = false;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProfileProvider).asData?.value;
      if (user != null) {
        if (user.driverStatus == DriverStatus.pending ||
            user.driverStatus == DriverStatus.active) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ya tienes un registro en proceso o activo.'),
            ),
          );
        } else if (user.driverStatus == DriverStatus.rejected) {
          _loadExistingData(user.id);
        }
      }
    });
  }

  Future<void> _loadExistingData(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('driver_verifications')
          .doc(userId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final rejectedPhotosRaw =
            data['rejected_photos'] as Map<String, dynamic>? ?? {};
        final rejectedPhotos = Map<String, String>.from(rejectedPhotosRaw);
        setState(() {
          _isCorrectionMode = true;
          _rejectedPhotos = rejectedPhotos;
          _existingFaceUrl = rejectedPhotos.containsKey('face')
              ? null
              : data['face_photo_url'];
          _existingLicenseFrontUrl = rejectedPhotos.containsKey('license_front')
              ? null
              : data['license_photo_url'];
          _existingDniFrontUrl = rejectedPhotos.containsKey('dni_front')
              ? null
              : data['dni_front_photo_url'];
          _existingDniBackUrl = rejectedPhotos.containsKey('dni_back')
              ? null
              : data['dni_back_photo_url'];
          _existingRegistrationUrl = rejectedPhotos.containsKey('registration')
              ? null
              : data['registration_photo_url'];
          _existingVehicleUrl = rejectedPhotos.containsKey('vehicle')
              ? null
              : data['vehicle_photo_url'];
          _existingInsuranceUrl = rejectedPhotos.containsKey('insurance_policy')
              ? null
              : data['insurance_photo_url'];

          if (data['dni_number'] != null)
            _dniController.text = data['dni_number'];
          if (data['ssn'] != null) _ssnController.text = data['ssn'];
          if (data['driver_motivation'] != null)
            _motivationController.text = data['driver_motivation'];
          if (data['hours_per_week'] != null)
            _hoursPerWeekController.text = data['hours_per_week'].toString();
          if (data['has_experience'] != null)
            _hasExperience = data['has_experience'];
          if (data['birth_date'] != null)
            _birthDate = (data['birth_date'] as Timestamp).toDate();
          if (data['background_check_consent'] != null)
            _backgroundCheckConsent = data['background_check_consent'];
          if (data['terms_accepted'] != null)
            _termsAccepted = data['terms_accepted'];
        });
      }
      final driverData = await FirebaseFirestore.instance
          .collection('driver_data')
          .doc(userId)
          .get();
      if (driverData.exists) {
        final data = driverData.data()!;
        setState(() {
          if (data['vehicle_model'] != null)
            _vehicleController.text = data['vehicle_model'];
          if (data['vehicle_plate'] != null)
            _plateController.text = data['vehicle_plate'];
          if (data['vehicle_color'] != null)
            _selectedCarColor = data['vehicle_color'];
          if (data['vehicle_type'] != null) {
            _selectedVehicleType = VehicleType.values.firstWhere(
              (e) => e.name == data['vehicle_type'],
              orElse: () => VehicleType.essentials,
            );
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading existing driver data: $e");
    }
  }

  @override
  void dispose() {
    _dniController.dispose();
    _vehicleController.dispose();
    _plateController.dispose();
    _pageController.dispose();
    _motivationController.dispose();
    _hoursPerWeekController.dispose();
    _ssnController.dispose();
    _insurancePolicyController.dispose();
    super.dispose();
  }

  bool _canGoToNextStep() {
    if (_currentPage == 0) {
      return (_facePhoto != null || _existingFaceUrl != null) &&
          (_dniFrontPhoto != null || _existingDniFrontUrl != null) &&
          (_dniBackPhoto != null || _existingDniBackUrl != null) &&
          _dniController.text.isNotEmpty &&
          _birthDate != null &&
          _motivationController.text.isNotEmpty &&
          _hoursPerWeekController.text.isNotEmpty &&
          _ssnController.text.isNotEmpty &&
          (_insurancePhoto != null || _existingInsuranceUrl != null) &&
          _backgroundCheckConsent &&
          _termsAccepted;
    } else if (_currentPage == 1) {
      return (_licenseFrontPhoto != null || _existingLicenseFrontUrl != null);
    } else if (_currentPage == 2) {
      return (_registrationPhoto != null || _existingRegistrationUrl != null) &&
          (_vehiclePhoto != null || _existingVehicleUrl != null) &&
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
        const SnackBar(
          content: Text(
            'Por favor completa todos los campos y acepta los términos',
          ),
        ),
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
      imageQuality: 70,
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
          case 'insurance_policy':
            _insurancePhoto = file;
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

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('driver_verifications')
          .child(fileName);

      await storageRef.putFile(imageFile);
      final url = await storageRef.getDownloadURL();

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

    if ((_facePhoto == null && _existingFaceUrl == null) ||
        (_licenseFrontPhoto == null && _existingLicenseFrontUrl == null) ||
        (_dniFrontPhoto == null && _existingDniFrontUrl == null) ||
        (_dniBackPhoto == null && _existingDniBackUrl == null) ||
        (_registrationPhoto == null && _existingRegistrationUrl == null) ||
        (_vehiclePhoto == null && _existingVehicleUrl == null) ||
        _dniController.text.isEmpty ||
        _birthDate == null ||
        _motivationController.text.isEmpty ||
        _hoursPerWeekController.text.isEmpty ||
        _ssnController.text.isEmpty ||
        (_insurancePhoto == null && _existingInsuranceUrl == null) ||
        !_backgroundCheckConsent ||
        !_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, completa todos los datos, sube todas las fotos y acepta los términos.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    AppLogger.log('DEBUG: ⏳ Estado cargando (Loading) activado');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        AppLogger.log('DEBUG: ❌ ERROR - Usuario nulo en Firebase Auth');
        throw Exception('Usuario no autenticado.');
      }

      final userId = user.uid;
      AppLogger.log('DEBUG: 👤 ID de usuario: $userId');

      AppLogger.log('DEBUG: 📁 Iniciando carga masiva de fotos al Storage...');
      final faceUrl = _facePhoto != null
          ? await _uploadImage(_facePhoto!, 'face', userId)
          : _existingFaceUrl;
      final lFrontUrl = _licenseFrontPhoto != null
          ? await _uploadImage(_licenseFrontPhoto!, 'license_front', userId)
          : _existingLicenseFrontUrl;
      final dFrontUrl = _dniFrontPhoto != null
          ? await _uploadImage(_dniFrontPhoto!, 'dni_front', userId)
          : _existingDniFrontUrl;
      final dBackUrl = _dniBackPhoto != null
          ? await _uploadImage(_dniBackPhoto!, 'dni_back', userId)
          : _existingDniBackUrl;
      final registrationUrl = _registrationPhoto != null
          ? await _uploadImage(_registrationPhoto!, 'reg', userId)
          : _existingRegistrationUrl;
      final vehicleUrl = _vehiclePhoto != null
          ? await _uploadImage(_vehiclePhoto!, 'vehicle', userId)
          : _existingVehicleUrl;
      final insuranceUrl = _insurancePhoto != null
          ? await _uploadImage(_insurancePhoto!, 'policy', userId)
          : _existingInsuranceUrl;

      AppLogger.log('DEBUG: ✅ Fotos subidas correctamente.');

      if (faceUrl == null ||
          lFrontUrl == null ||
          dFrontUrl == null ||
          dBackUrl == null ||
          registrationUrl == null ||
          vehicleUrl == null ||
          insuranceUrl == null) {
        AppLogger.log('DEBUG: ❌ ERROR - Al menos una URL es nula');
        throw Exception('Error al subir una o más imágenes.');
      }

      final batch = FirebaseFirestore.instance.batch();

      // 1. driver_verifications collection
      final verificationRef = FirebaseFirestore.instance
          .collection('driver_verifications')
          .doc(userId);

      batch.set(verificationRef, {
        'driver_id': userId,
        'dni_number': _dniController.text.trim(),
        'birth_date': Timestamp.fromDate(_birthDate!),
        'face_photo_url': faceUrl,
        'license_photo_url': lFrontUrl,
        'dni_front_photo_url': dFrontUrl,
        'dni_back_photo_url': dBackUrl,
        'registration_photo_url': registrationUrl,
        'vehicle_photo_url': vehicleUrl,
        'status': 'pending',
        'rejection_reason': null,
        'rejected_photos': FieldValue.delete(),
        'driver_motivation': _motivationController.text.trim(),
        'hours_per_week': int.tryParse(_hoursPerWeekController.text.trim()),
        'has_experience': _hasExperience,
        'ssn': _ssnController.text.trim(),
        'insurance_photo_url': insuranceUrl,
        'background_check_consent': _backgroundCheckConsent,
        'terms_accepted': _termsAccepted,
        'terms_accepted_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. driver_data collection
      final driverDataRef = FirebaseFirestore.instance
          .collection('driver_data')
          .doc(userId);

      batch.set(driverDataRef, {
        'profile_id': userId,
        'vehicle_model': _vehicleController.text.trim(),
        'vehicle_plate': _plateController.text.trim().toUpperCase(),
        'vehicle_type': _selectedVehicleType.name,
        'vehicle_color': _selectedCarColor,
        'is_verified': false,
        'active_services': [_selectedVehicleType.name],
        'doc_license_url': lFrontUrl,
        'doc_insurance_url': insuranceUrl,
        'updated_at': FieldValue.serverTimestamp(),
        'rejection_reason': null,
        'rejected_photos': FieldValue.delete(),
      }, SetOptions(merge: true));

      // 3. profiles collection
      final profileRef = FirebaseFirestore.instance
          .collection('profiles')
          .doc(userId);

      batch.update(profileRef, {
        'driver_status': 'pending',
        'is_driver': true,
        // Sync face photo as avatar so driver and passenger share the same photo
        if (faceUrl != null) 'avatar_url': faceUrl,
      });

      await batch.commit();
      AppLogger.log('DEBUG: ✅ Registro en Firestore exitoso');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud enviada con éxito. En revisión.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
    IconData defaultIcon, {
    String? existingUrl,
    String? rejectionReason,
  }) {
    final bool hasImage = file != null || existingUrl != null;
    final bool isRejected = rejectionReason != null && file == null;

    // Si la foto ya existe y no fue rechazada, no la mostramos para que el usuario
    // solo vea lo que tiene que subir / corregir.
    if (existingUrl != null && !isRejected) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _pickImage(type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isRejected ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRejected
                ? Colors.red.shade400
                : hasImage
                ? Colors.black
                : Colors.grey[300]!,
            width: (isRejected || hasImage) ? 2 : 1,
          ),
          boxShadow: [
            if (isRejected)
              BoxShadow(
                color: Colors.red.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            else if (!hasImage)
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isRejected ? Colors.red.shade100 : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      image: file != null
                          ? DecorationImage(
                              image: FileImage(file),
                              fit: BoxFit.cover,
                            )
                          : (existingUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(existingUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null),
                    ),
                    child: !hasImage
                        ? Icon(
                            isRejected ? Icons.cancel : defaultIcon,
                            color: isRejected
                                ? Colors.red.shade400
                                : Colors.grey[400],
                            size: 24,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isRejected
                                ? Colors.red.shade700
                                : Colors.black87,
                          ),
                        ),
                        if (isRejected)
                          Text(
                            'Toca para subir nueva foto',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade500,
                            ),
                          )
                        else if (hasImage)
                          const Text(
                            'Foto cargada ✓',
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    isRejected
                        ? Icons.upload_rounded
                        : hasImage
                        ? Icons.check_circle
                        : Icons.arrow_forward_ios_rounded,
                    color: isRejected
                        ? Colors.red.shade400
                        : hasImage
                        ? Colors.green
                        : Colors.grey[300],
                    size: isRejected ? 24 : 20,
                  ),
                ],
              ),
              if (isRejected) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rejectionReason!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
          "Paso ${_currentPage + 1} de $_totalSteps",
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
                  children: List.generate(_totalSteps, (index) {
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
                              : (_currentPage < _totalSteps - 1
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
                                  _currentPage < _totalSteps - 1
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

  // ──────────────────────────────────────────────
  //  STEP 1 – Personal Info
  // ──────────────────────────────────────────────
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
          if (!_isCorrectionMode) ...[
            TextField(
              controller: _dniController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Numero de licencia",
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
          ],
          _buildImageSelector(
            "Foto de Perfil (Selfie)",
            "face",
            _facePhoto,
            Icons.person_outline,
            existingUrl: _existingFaceUrl,
            rejectionReason: _rejectedPhotos['face'],
          ),
          _buildImageSelector(
            "Id Frontal",
            "dni_front",
            _dniFrontPhoto,
            Icons.credit_card,
            existingUrl: _existingDniFrontUrl,
            rejectionReason: _rejectedPhotos['dni_front'],
          ),
          _buildImageSelector(
            "Id Posterior",
            "dni_back",
            _dniBackPhoto,
            Icons.credit_card,
            existingUrl: _existingDniBackUrl,
            rejectionReason: _rejectedPhotos['dni_back'],
          ),
          if (!_isCorrectionMode) ...[
            const SizedBox(height: 28),

            // ── WHY DO YOU DRIVE WITH TIN? ──
            _buildSectionLabel(
              "¿Por qué manejas con Tin?",
              Icons.lightbulb_outline,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _motivationController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    "Ej: Quiero generar ingresos adicionales en mis tiempos libres...",
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── HOURS PER WEEK ──
            _buildSectionLabel(
              "¿Cuántas horas por semana planeas trabajar?",
              Icons.schedule_outlined,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hoursPerWeekController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "Ej: 20",
                suffixText: "horas / semana",
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── EXPERIENCE ──
            _buildSectionLabel(
              "¿Tienes experiencia como conductor?",
              Icons.star_border_rounded,
            ),
            const SizedBox(height: 8),
            _buildToggleCard(
              label: _hasExperience
                  ? "Sí, tengo experiencia"
                  : "No tengo experiencia previa",
              value: _hasExperience,
              onChanged: (val) => setState(() => _hasExperience = val),
            ),
            const SizedBox(height: 20),
          ],

          // ── INSURANCE POLICY PHOTO ──
          _buildSectionLabel(
            "Foto de la Póliza de Seguro",
            Icons.security_outlined,
          ),
          const SizedBox(height: 12),
          _buildImageSelector(
            "Cargar Foto de Póliza",
            "insurance_policy",
            _insurancePhoto,
            Icons.policy_outlined,
            existingUrl: _existingInsuranceUrl,
            rejectionReason: _rejectedPhotos['insurance_policy'],
          ),
          if (!_isCorrectionMode) ...[
            const SizedBox(height: 20),

            // ── SSN ──
            _buildSectionLabel(
              "Número de Seguro Social (SSN)",
              Icons.fingerprint,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.amber[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Tu SSN está encriptado y sólo se usa para verificación de identidad.",
                      style: TextStyle(fontSize: 12, color: Colors.amber[800]),
                    ),
                  ),
                ],
              ),
            ),
            TextField(
              controller: _ssnController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: InputDecoration(
                hintText: "XXX-XX-XXXX",
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 28),

            // ── BACKGROUND CHECK CONSENT ──
            _buildConsentCard(
              icon: Icons.manage_search_outlined,
              title: "Permiso para Verificación de Antecedentes",
              description:
                  "Autorizo a Tin a realizar una verificación de antecedentes penales, de tránsito y de identidad como requisito para ser admitido como conductor en la plataforma.",
              value: _backgroundCheckConsent,
              onChanged: (val) => setState(() => _backgroundCheckConsent = val),
            ),
            const SizedBox(height: 16),

            // ── TERMS & CONDITIONS ──
            _buildConsentCard(
              icon: Icons.gavel_outlined,
              title: "Acepto los Términos y Condiciones",
              description:
                  "He leído y acepto los Términos de Servicio y la Política de Privacidad de Tin. Entiendo que operar como conductor implica responsabilidades legales y de seguridad.",
              value: _termsAccepted,
              onChanged: (val) => setState(() => _termsAccepted = val),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  STEP 2 – License
  // ──────────────────────────────────────────────
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
            existingUrl: _existingLicenseFrontUrl,
            rejectionReason: _rejectedPhotos['license_front'],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  STEP 3 – Vehicle
  // ──────────────────────────────────────────────
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
            "Seguro del carro",
            "registration",
            _registrationPhoto,
            Icons.description_outlined,
            existingUrl: _existingRegistrationUrl,
            rejectionReason: _rejectedPhotos['registration'],
          ),
          _buildImageSelector(
            "Foto del Vehículo",
            "vehicle",
            _vehiclePhoto,
            Icons.directions_car_outlined,
            existingUrl: _existingVehicleUrl,
            rejectionReason: _rejectedPhotos['vehicle'],
          ),
          if (!_isCorrectionMode) ...[
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
              "Color del Vehículo",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (_selectedCarColor != null)
              Text(
                'Seleccionado: $_selectedCarColor',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            const SizedBox(height: 10),
            _buildColorPicker(),
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
        ],
      ),
    );
  }

  static const List<Map<String, dynamic>> _carColors = [
    {'name': 'Blanco', 'color': Color(0xFFF5F5F5), 'border': Color(0xFFDDDDDD)},
    {'name': 'Negro', 'color': Color(0xFF1A1A1A), 'border': Color(0xFF1A1A1A)},
    {'name': 'Gris', 'color': Color(0xFF9E9E9E), 'border': Color(0xFF9E9E9E)},
    {
      'name': 'Plateado',
      'color': Color(0xFFC0C0C0),
      'border': Color(0xFFAAAAAA),
    },
    {'name': 'Rojo', 'color': Color(0xFFD32F2F), 'border': Color(0xFFD32F2F)},
    {'name': 'Azul', 'color': Color(0xFF1565C0), 'border': Color(0xFF1565C0)},
    {
      'name': 'Azul Claro',
      'color': Color(0xFF29B6F6),
      'border': Color(0xFF29B6F6),
    },
    {'name': 'Verde', 'color': Color(0xFF2E7D32), 'border': Color(0xFF2E7D32)},
    {
      'name': 'Amarillo',
      'color': Color(0xFFFDD835),
      'border': Color(0xFFDDCC00),
    },
    {
      'name': 'Naranja',
      'color': Color(0xFFE65100),
      'border': Color(0xFFE65100),
    },
    {'name': 'Café', 'color': Color(0xFF5D4037), 'border': Color(0xFF5D4037)},
    {'name': 'Beige', 'color': Color(0xFFD7CCC8), 'border': Color(0xFFBCAAA4)},
    {'name': 'Morado', 'color': Color(0xFF6A1B9A), 'border': Color(0xFF6A1B9A)},
    {'name': 'Rosado', 'color': Color(0xFFF48FB1), 'border': Color(0xFFE91E8C)},
    {'name': 'Dorado', 'color': Color(0xFFFFD700), 'border': Color(0xFFCCAA00)},
    {'name': 'Vino', 'color': Color(0xFF880E4F), 'border': Color(0xFF880E4F)},
  ];

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _carColors.map((item) {
        final name = item['name'] as String;
        final color = item['color'] as Color;
        final borderColor = item['border'] as Color;
        final isSelected = _selectedCarColor == name;
        return GestureDetector(
          onTap: () => setState(() => _selectedCarColor = name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.black : borderColor,
                width: isSelected ? 3 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.08),
                  blurRadius: isSelected ? 10 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    size: 22,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black87),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleCard({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: value ? Colors.black : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value ? Colors.black : Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_circle : Icons.radio_button_unchecked,
              color: value ? Colors.white : Colors.grey[400],
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: value ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentCard({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? Colors.black : Colors.grey[300]!,
            width: value ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              value ? Icons.check_circle : icon,
              color: value ? Colors.white : Colors.grey[500],
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: value ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: value ? Colors.white70 : Colors.grey[600],
                      height: 1.4,
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
}
