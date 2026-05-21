import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tincars/features/auth/presentation/controllers/auth_controller.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:tincars/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralController = TextEditingController();

  // Driver specific controllers
  final _dniController = TextEditingController();
  DateTime? _birthDate;
  final _motivationController = TextEditingController();
  final _hoursPerWeekController = TextEditingController();
  final _ssnController = TextEditingController();
  bool _hasExperience = false;
  bool _backgroundCheckConsent = false;
  bool _termsAccepted = false;

  final _vehicleYearController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  VehicleType _selectedVehicleType = VehicleType.essentials;

  bool _isPasswordVisible = false;
  bool _isDriver = false;
  int _currentStep = 0; // 0: Basic, 1: Info, 2: License, 3: Vehicle

  final ImagePicker _picker = ImagePicker();
  XFile? _faceImage;
  XFile? _licenseFrontImage;
  XFile? _dniFrontImage;
  XFile? _dniBackImage;
  XFile? _registrationImage;
  XFile? _vehicleImage;
  XFile? _insuranceImage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _referralController.dispose();
    _dniController.dispose();
    _motivationController.dispose();
    _hoursPerWeekController.dispose();
    _ssnController.dispose();
    _vehicleYearController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    _vehicleColorController.dispose();
    super.dispose();
  }

  void _handleRegister() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || name.length < 3) {
      _showError("Por favor, ingresa tu nombre completo (mínimo 3 letras)");
      return;
    }
    if (phone.isEmpty) {
      _showError("Por favor, ingresa tu número de teléfono");
      return;
    }
    if (phone.length < 8) {
      _showError("Por favor, ingresa un número de teléfono válido");
      return;
    }
    final emailRegex = RegExp(
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
    );
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      _showError(
        "Por favor, ingresa un correo electrónico válido (ejemplo: usuario@gmail.com)",
      );
      return;
    }
    if (password.length < 6) {
      _showError("La contraseña debe tener al menos 6 caracteres");
      return;
    }

    if (_isDriver && _currentStep == 0) {
      setState(() => _currentStep = 1);
      return;
    }

    if (_isDriver && _currentStep == 1) {
      if (_dniController.text.isEmpty ||
          _birthDate == null ||
          _faceImage == null ||
          _dniFrontImage == null ||
          _dniBackImage == null ||
          _motivationController.text.isEmpty ||
          _hoursPerWeekController.text.isEmpty ||
          _ssnController.text.isEmpty ||
          !_backgroundCheckConsent ||
          !_termsAccepted) {
        _showError(
          "Por favor completa todos los campos de información personal y acepta los términos",
        );
        return;
      }
      setState(() => _currentStep = 2);
      return;
    }

    if (_isDriver && _currentStep == 2) {
      if (_licenseFrontImage == null) {
        _showError(
          "Por favor, sube la foto frontal de tu licencia de conducir",
        );
        return;
      }
      setState(() => _currentStep = 3);
      return;
    }

    if (_isDriver && _currentStep == 3) {
      if (_registrationImage == null ||
          _vehicleImage == null ||
          _insuranceImage == null ||
          _vehicleModelController.text.isEmpty ||
          _vehiclePlateController.text.isEmpty) {
        _showError(
          "Por favor completa los detalles del vehículo y sube los documentos requeridos",
        );
        return;
      }
    }

    ref
        .read(authControllerProvider.notifier)
        .signUp(
          email.toLowerCase(),
          password,
          name,
          _isDriver,
          phone: phone,
          ssnLast4: _ssnController.text.trim(),
          vehicleYear: _vehicleYearController.text.trim(),
          vehicleModel: _vehicleModelController.text.trim(),
          vehiclePlate: _vehiclePlateController.text.trim(),
          vehicleColor: _vehicleColorController.text.trim(),
          vehicleType: _selectedVehicleType.name,
          backgroundCheckConsent: _backgroundCheckConsent,
          termsAccepted: _termsAccepted,
          dniNumber: _dniController.text.trim(),
          birthDate: _birthDate,
          motivation: _motivationController.text.trim(),
          hoursPerWeek: int.tryParse(_hoursPerWeekController.text.trim()),
          hasExperience: _hasExperience,
          facePath: _faceImage?.path,
          licenseFrontPath: _licenseFrontImage?.path,
          dniFrontPath: _dniFrontImage?.path,
          dniBackPath: _dniBackImage?.path,
          registrationPath: _registrationImage?.path,
          vehiclePath: _vehicleImage?.path,
          insurancePath: _insuranceImage?.path,
          referralCode: _referralController.text.trim(),
        );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          switch (type) {
            case 'face':
              _faceImage = image;
              break;
            case 'license_front':
              _licenseFrontImage = image;
              break;
            case 'dni_front':
              _dniFrontImage = image;
              break;
            case 'dni_back':
              _dniBackImage = image;
              break;
            case 'registration':
              _registrationImage = image;
              break;
            case 'vehicle':
              _vehicleImage = image;
              break;
            case 'insurance_policy':
              _insuranceImage = image;
              break;
          }
        });
      }
    } catch (e) {
      _showError("Error al seleccionar imagen: $e");
    }
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
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
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
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);

    ref.listen<AsyncValue>(authControllerProvider, (previous, next) {
      if (next.hasError) {
        final errorStr = next.error.toString().toLowerCase();
        String displayError = l10n.errorGenericAuth;
        if (errorStr.contains('already registered') ||
            errorStr.contains('already in use')) {
          displayError = l10n.errorEmailInUse;
        } else if (errorStr.contains('weak password') ||
            errorStr.contains('at least 6 characters')) {
          displayError = l10n.errorWeakPassword;
        } else if (errorStr.contains('invalid-email')) {
          displayError = l10n.errorInvalidEmail;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayError,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(20),
          ),
        );
      } else if (!next.isLoading && previous?.isLoading == true) {
        if (next.hasValue) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.successRegister)));
          context.go('/login');
        }
      }
    });

    String titleText = l10n.registerTitle;
    if (_currentStep == 1) titleText = "Información Personal";
    if (_currentStep == 2) titleText = "Licencia";
    if (_currentStep == 3) titleText = "Vehículo";

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?q=80&w=2070&auto=format&fit=crop',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: PremiumGlassContainer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titleText,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (_currentStep == 0) _buildBasicInfoStep(l10n),
                    if (_currentStep == 1) _buildPersonalInfoStep(),
                    if (_currentStep == 2) _buildLicenseStep(),
                    if (_currentStep == 3) _buildVehicleStep(),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: authState.isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.black,
                              )
                            : Text(
                                _isDriver && _currentStep < 3
                                    ? "Siguiente"
                                    : l10n.registerButton,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoStep(AppLocalizations l10n) {
    return Column(
      children: [
        _buildTextField(_nameController, '${l10n.nameLabel} *', Icons.person),
        const SizedBox(height: 16),
        _buildTextField(
          _phoneController,
          'Teléfono',
          Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildTextField(_emailController, l10n.emailLabel, Icons.email),
        const SizedBox(height: 16),
        _buildTextField(
          _passwordController,
          l10n.passwordLabel,
          Icons.lock,
          obscureText: !_isPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.white70,
            ),
            onPressed: () =>
                setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          _referralController,
          'Código de Referido (Opcional)',
          Icons.card_giftcard,
        ),
        const SizedBox(height: 25),
        const Text(
          'Tipo de Cuenta',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildRoleButton('Pasajero', Icons.person, !_isDriver),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildRoleButton('Conductor', Icons.drive_eta, _isDriver),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      children: [
        _buildTextField(
          _dniController,
          'Numero de licencia',
          Icons.badge_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white30),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_outlined, color: Colors.white70),
                const SizedBox(width: 12),
                Text(
                  _birthDate == null
                      ? "Fecha de Nacimiento"
                      : "${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}",
                  style: TextStyle(
                    color: _birthDate == null ? Colors.white70 : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildImageSelector(
          "Foto de Perfil (Selfie)",
          "face",
          _faceImage,
          Icons.person_outline,
        ),
        _buildImageSelector(
          "Id Frontal",
          "dni_front",
          _dniFrontImage,
          Icons.credit_card,
        ),
        _buildImageSelector(
          "Id Posterior",
          "dni_back",
          _dniBackImage,
          Icons.credit_card,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          _motivationController,
          '¿Por qué manejas con Tin?',
          Icons.lightbulb_outline,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          _hoursPerWeekController,
          'Horas por semana',
          Icons.schedule_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _buildToggleCard(
          label: _hasExperience
              ? "Sí, tengo experiencia"
              : "No tengo experiencia previa",
          value: _hasExperience,
          onChanged: (val) => setState(() => _hasExperience = val),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          _ssnController,
          'Número de Seguro Social (SSN)',
          Icons.fingerprint,
          obscureText: true,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _buildConsentCard(
          icon: Icons.manage_search_outlined,
          title: "Permiso para Verificación de Antecedentes",
          description: "Autorizo a Tin a realizar una verificación.",
          value: _backgroundCheckConsent,
          onChanged: (val) => setState(() => _backgroundCheckConsent = val),
        ),
        const SizedBox(height: 16),
        _buildConsentCard(
          icon: Icons.gavel_outlined,
          title: "Acepto los Términos y Condiciones",
          description: "He leído y acepto los Términos de Servicio.",
          value: _termsAccepted,
          onChanged: (val) => setState(() => _termsAccepted = val),
        ),
      ],
    );
  }

  Widget _buildLicenseStep() {
    return Column(
      children: [
        _buildImageSelector(
          "Licencia (Frente)",
          "license_front",
          _licenseFrontImage,
          Icons.assignment_ind_outlined,
        ),
      ],
    );
  }

  Widget _buildVehicleStep() {
    return Column(
      children: [
        _buildImageSelector(
          "Seguro del carro",
          "registration",
          _registrationImage,
          Icons.description_outlined,
        ),
        _buildImageSelector(
          "Foto del Vehículo",
          "vehicle",
          _vehicleImage,
          Icons.directions_car_outlined,
        ),
        _buildImageSelector(
          "Foto de Póliza de Seguro",
          "insurance_policy",
          _insuranceImage,
          Icons.policy_outlined,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          _vehicleModelController,
          'Modelo del Vehículo',
          Icons.car_repair,
        ),
        const SizedBox(height: 16),
        _buildTextField(_vehiclePlateController, 'Número de Placa', Icons.pin),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                _vehicleYearController,
                'Año',
                Icons.calendar_today,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                _vehicleColorController,
                'Color',
                Icons.palette,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white30),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<VehicleType>(
              value: _selectedVehicleType,
              isExpanded: true,
              dropdownColor: Colors.grey[900],
              iconEnabledColor: Colors.white,
              style: const TextStyle(color: Colors.white),
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
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white30),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildRoleButton(String label, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() {
        _isDriver = label == 'Conductor';
        if (!_isDriver) _currentStep = 0;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.white : Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelector(
    String title,
    String type,
    XFile? file,
    IconData defaultIcon,
  ) {
    return GestureDetector(
      onTap: () => _pickImage(type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: file != null ? Colors.greenAccent : Colors.white24,
            width: file != null ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  image: file != null
                      ? DecorationImage(
                          image: File(file.path).absolute.existsSync()
                              ? FileImage(File(file.path))
                              : NetworkImage(file.path) as ImageProvider,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: file == null
                    ? Icon(defaultIcon, color: Colors.white70, size: 24)
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
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(
                file != null
                    ? Icons.check_circle
                    : Icons.arrow_forward_ios_rounded,
                color: file != null ? Colors.greenAccent : Colors.white30,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: value ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value ? Colors.white : Colors.white30),
        ),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_circle : Icons.radio_button_unchecked,
              color: value ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: value ? Colors.black : Colors.white,
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? Colors.greenAccent : Colors.white30,
            width: value ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              value ? Icons.check_circle : icon,
              color: value ? Colors.greenAccent : Colors.white70,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
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
