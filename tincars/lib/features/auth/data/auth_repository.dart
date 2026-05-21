import 'dart:io';
import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tincars/core/services/session_service.dart';

// Interface
abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<void> signInWithEmailAndPassword(String email, String password);
  Future<void> signInWithPhone(String phone);
  Future<void> verifyPhoneOtp(String verificationId, String smsCode);
  Future<void> createUserWithEmailAndPassword(
    String email,
    String password,
    String fullName,
    bool isDriver, {
    String? phone,
    String? ssnLast4,
    String? vehicleYear,
    String? vehicleModel,
    String? vehiclePlate,
    String? vehicleColor,
    String? vehicleType,
    bool? backgroundCheckConsent,
    bool? termsAccepted,
    String? dniNumber,
    DateTime? birthDate,
    String? motivation,
    int? hoursPerWeek,
    bool? hasExperience,
    String? facePath,
    String? licenseFrontPath,
    String? dniFrontPath,
    String? dniBackPath,
    String? registrationPath,
    String? vehiclePath,
    String? insurancePath,
    String? referralCode,
  });
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> signOut();
}

// Firebase Implementation
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    AppLogger.log('AuthRepository: Intentando iniciar sesión');
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      AppLogger.log(
        'AuthRepository: Inicio de sesión exitoso. User ID: ${credential.user?.uid}',
      );
      await SessionService.updateSessionInfo();
    } catch (e) {
      AppLogger.log('AuthRepository: Error al iniciar sesión: $e');
      rethrow;
    }
  }

  @override
  Future<void> signInWithPhone(String phone) async {
    AppLogger.log('AuthRepository: Intentando enviar OTP al teléfono: $phone');
    // Note: Phone auth in Firebase requires specific handling for verification completion.
    // Usually this is handled in the UI with a verificationId.
    // For this migration, we'll assume the standard Firebase phone flow.
    throw UnimplementedError('Standard phone auth requires verificationId handling in UI');
  }

  @override
  Future<void> verifyPhoneOtp(String verificationId, String smsCode) async {
    AppLogger.log('AuthRepository: Verificando OTP');
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      AppLogger.log(
        'AuthRepository: OTP verificado con éxito. User ID: ${userCredential.user?.uid}',
      );
      await SessionService.updateSessionInfo();
    } catch (e) {
      AppLogger.log('AuthRepository: Error verificando OTP: $e');
      rethrow;
    }
  }

  @override
  Future<void> createUserWithEmailAndPassword(
    String email,
    String password,
    String fullName,
    bool isDriver, {
    String? phone,
    String? ssnLast4,
    String? vehicleYear,
    String? vehicleModel,
    String? vehiclePlate,
    String? vehicleColor,
    String? vehicleType,
    bool? backgroundCheckConsent,
    bool? termsAccepted,
    String? dniNumber,
    DateTime? birthDate,
    String? motivation,
    int? hoursPerWeek,
    bool? hasExperience,
    String? facePath,
    String? licenseFrontPath,
    String? dniFrontPath,
    String? dniBackPath,
    String? registrationPath,
    String? vehiclePath,
    String? insurancePath,
    String? referralCode,
  }) async {
    AppLogger.log('AuthRepository: Intentando registrar usuario $email');
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      AppLogger.log(
        'AuthRepository: Registro en Auth exitoso. User ID: ${user?.uid}',
      );

      if (user != null) {
        // Handle referral code
        String? referredById;
        if (referralCode != null && referralCode.isNotEmpty) {
          final profileQuery = await _firestore
              .collection('profiles')
              .where('referral_code', isEqualTo: referralCode.toUpperCase())
              .limit(1)
              .get();
          
          if (profileQuery.docs.isNotEmpty) {
            referredById = profileQuery.docs.first.id;
          }
        }

        // Create profile in Firestore
        await _firestore.collection('profiles').doc(user.uid).set({
          'id': user.uid,
          'email': email,
          'full_name': fullName,
          'is_driver': isDriver,
          'phone_number': phone,
          'ssn_last_4': ssnLast4,
          'driver_status': isDriver ? 'pending' : null,
          'referred_by_id': referredById,
          'created_at': FieldValue.serverTimestamp(),
          'wallet_balance': 0.0,
        });

        if (isDriver) {
          String? faceUrl;
          String? licenseFrontUrl;
          String? dniFrontUrl;
          String? dniBackUrl;
          String? registrationUrl;
          String? vehicleUrl;
          String? insuranceUrl;

          Future<String?> uploadDoc(String? path, String type) async {
            if (path == null) return null;
            final file = File(path);
            final ref = _storage.ref().child('driver_verifications/${user.uid}/${type}_${DateTime.now().millisecondsSinceEpoch}');
            await ref.putFile(file);
            return await ref.getDownloadURL();
          }

          try {
            faceUrl = await uploadDoc(facePath, 'face');
            licenseFrontUrl = await uploadDoc(licenseFrontPath, 'license_front');
            dniFrontUrl = await uploadDoc(dniFrontPath, 'dni_front');
            dniBackUrl = await uploadDoc(dniBackPath, 'dni_back');
            registrationUrl = await uploadDoc(registrationPath, 'reg');
            vehicleUrl = await uploadDoc(vehiclePath, 'vehicle');
            insuranceUrl = await uploadDoc(insurancePath, 'policy');
          } catch (e) {
            AppLogger.log('AuthRepository: Error subiendo documentos: $e');
          }

          // Sync with driver_verifications for Admin
          await _firestore.collection('driver_verifications').doc(user.uid).set({
            'driver_id': user.uid,
            'dni_number': dniNumber,
            'birth_date': birthDate != null ? Timestamp.fromDate(birthDate) : null,
            'face_photo_url': faceUrl,
            'license_photo_url': licenseFrontUrl,
            'dni_front_photo_url': dniFrontUrl,
            'dni_back_photo_url': dniBackUrl,
            'registration_photo_url': registrationUrl,
            'vehicle_photo_url': vehicleUrl,
            'insurance_photo_url': insuranceUrl,
            'status': 'pending',
            'rejection_reason': null,
            'driver_motivation': motivation,
            'hours_per_week': hoursPerWeek,
            'has_experience': hasExperience ?? false,
            'ssn': ssnLast4,
            'background_check_consent': backgroundCheckConsent ?? false,
            'terms_accepted': termsAccepted ?? false,
            'terms_accepted_at': FieldValue.serverTimestamp(),
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });

          // Create driver data
          await _firestore.collection('driver_data').doc(user.uid).set({
            'profile_id': user.uid,
            'vehicle_model': vehicleModel ?? 'Unknown',
            'vehicle_plate': vehiclePlate ?? 'Unknown',
            'vehicle_type': vehicleType ?? 'essentials',
            'vehicle_year': vehicleYear,
            'vehicle_color': vehicleColor,
            'is_verified': false,
            'doc_license_url': licenseFrontUrl,
            'doc_insurance_url': insuranceUrl,
            'total_earnings': 0.0,
            'active_services': [vehicleType ?? 'essentials'],
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }

        await SessionService.updateSessionInfo();
      }
    } catch (e) {
      AppLogger.log('AuthRepository: Error en registro: $e');
      rethrow;
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    // Standard Google Sign-In requires additional package like google_sign_in
    throw UnimplementedError('Google Sign-In requires google_sign_in package configuration');
  }

  @override
  Future<void> signInWithApple() async {
    throw UnimplementedError('Apple Sign-In requires sign_in_with_apple package configuration');
  }

  @override
  Future<void> signOut() async {
    AppLogger.log('AuthRepository: Cerrando sesión...');
    await _auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});
