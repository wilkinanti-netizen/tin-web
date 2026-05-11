import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tincars/features/auth/presentation/controllers/auth_controller.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:tincars/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';

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
  final _ssnController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  String _selectedVehicleType = 'essentials';
  bool _backgroundCheckConsent = false;

  bool _isPasswordVisible = false;
  bool _isDriver = false;
  int _currentStep = 0; // 0: Basic, 1: Driver Info, 2: Documents

  final ImagePicker _picker = ImagePicker();
  XFile? _licenseImage;
  XFile? _insuranceImage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _ssnController.dispose();
    _vehicleYearController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    _vehicleColorController.dispose();
    _referralController.dispose();
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
    final emailRegex = RegExp(r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      _showError("Por favor, ingresa un correo electrónico válido (ejemplo: usuario@gmail.com)");
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
      if (_ssnController.text.trim().isEmpty) {
        _showError("Los últimos 4 del SSN son obligatorios para conductores");
        return;
      }
      if (_vehiclePlateController.text.trim().isEmpty) {
        _showError("El número de placa es obligatorio");
        return;
      }
      if (!_backgroundCheckConsent) {
        _showError("Debes aceptar la verificación de antecedentes");
        return;
      }
      setState(() => _currentStep = 2);
      return;
    }

    if (_isDriver && _currentStep == 2) {
      if (_licenseImage == null) {
        _showError("Por favor, sube tu licencia de conducir");
        return;
      }
      if (_insuranceImage == null) {
        _showError("Por favor, sube tu seguro vehicular");
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
          vehicleType: _selectedVehicleType,
          backgroundCheckConsent: _backgroundCheckConsent,
          licensePath: _licenseImage?.path,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);

    // Listen for auth state changes
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
          // Redirect to login instead of forcing phone OTP
          context.go('/login');
        }
      }
    });

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
                      _currentStep == 0
                          ? l10n.registerTitle
                          : _currentStep == 1
                          ? "Información del Vehículo"
                          : "Documentación",
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (_currentStep == 0)
                      _buildBasicInfoStep(l10n)
                    else if (_currentStep == 1)
                      _buildDriverInfoStep()
                    else
                      _buildDocumentsStep(),
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
                                _isDriver && _currentStep < 2
                                    ? "Siguiente"
                                    : l10n.registerButton,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (_currentStep == 0) ...[
                      const SizedBox(height: 20),
                      const SizedBox(height: 10),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          const Text(
                            'By signing up you agree to our ',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/terms'),
                            child: const Text(
                              'Terms',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(
                            ' and ',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/privacy'),
                            child: const Text(
                              'Privacy Policy',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
        _buildTextField(
          _nameController,
          '${l10n.nameLabel} * (Obligatorio)',
          Icons.person,
        ),
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
          keyboardType: TextInputType.text,
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

  Widget _buildDriverInfoStep() {
    return Column(
      children: [
        _buildTextField(
          _ssnController,
          'Últimos 4 del SSN',
          Icons.security,
          keyboardType: TextInputType.number,
        ),
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
        _buildTextField(
          _vehicleModelController,
          'Marca y Modelo',
          Icons.car_repair,
        ),
        const SizedBox(height: 16),
        _buildTextField(_vehiclePlateController, 'Número de Placa', Icons.pin),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedVehicleType,
          dropdownColor: Colors.grey[900],
          style: const TextStyle(color: Colors.white),
          decoration: _getInputDecoration('Tipo de Servicio', Icons.category),
          items: const [
            DropdownMenuItem(value: 'essentials', child: Text('Essentials ')),
            DropdownMenuItem(
              value: 'essentials_xl',
              child: Text('Essentials XL'),
            ),
            DropdownMenuItem(value: 'executive', child: Text('Executive ')),
          ],
          onChanged: (val) => setState(() => _selectedVehicleType = val!),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          title: const Text(
            "Consiento la verificación de antecedentes según leyes de USA",
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          value: _backgroundCheckConsent,
          activeColor: Colors.white,
          checkColor: Colors.black,
          onChanged: (val) => setState(() => _backgroundCheckConsent = val!),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
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
      decoration: _getInputDecoration(
        label,
        icon,
      ).copyWith(suffixIcon: suffixIcon),
    );
  }

  InputDecoration _getInputDecoration(String label, IconData icon) {
    return InputDecoration(
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

  Widget _buildDocumentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Documentación Requerida',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sube fotos claras de tus documentos para verificación.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 24),
        _buildDocumentPicker(
          'Licencia de Conducir',
          _licenseImage,
          () => _pickImage(true),
        ),
        const SizedBox(height: 16),
        _buildDocumentPicker(
          'Seguro Vehicular',
          _insuranceImage,
          () => _pickImage(false),
        ),
      ],
    );
  }

  Widget _buildDocumentPicker(String title, XFile? image, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: image != null ? Colors.greenAccent : Colors.white24,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  image != null ? Icons.check_circle : Icons.upload_file,
                  color: image != null ? Colors.greenAccent : Colors.white70,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (image != null)
                  const Text(
                    'CAMBIAR',
                    style: TextStyle(
                      color: Colors.white30,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            if (image != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(image.path),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(bool isLicense) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          if (isLicense) {
            _licenseImage = image;
          } else {
            _insuranceImage = image;
          }
        });
      }
    } catch (e) {
      _showError("Error al seleccionar imagen: $e");
    }
  }
}
