import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tincars/features/profile/data/profile_repository.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';
import 'package:tincars/features/profile/domain/models/payout_request.dart';
import 'package:tincars/features/profile/domain/models/payout_method.dart';
import 'package:tincars/features/profile/domain/models/emergency_contact.dart';
import 'package:tincars/features/profile/domain/models/driver_verification.dart';
import 'package:tincars/core/services/session_service.dart';
import 'package:tincars/features/auth/data/auth_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final driverProfileProvider = FutureProvider<DriverProfile?>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    AppLogger.log('driverProfileProvider: No hay usuario autenticado');
    return null;
  }
  AppLogger.log('driverProfileProvider: Cargando perfil para ${user.uid}...');
  final profile = await ref
      .read(profileRepositoryProvider)
      .getDriverData(user.uid);
  if (profile == null) {
  } else {
    AppLogger.log('driverProfileProvider: Perfil de conductor cargado exitosamente');
  }
  return profile;
});

final userProfileProvider = FutureProvider<AppUser?>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return null;
  return ref.read(profileRepositoryProvider).getUserProfile(user.uid);
});

final otherUserProfileProvider = FutureProvider.family<AppUser?, String>((ref, userId) async {
  return ref.read(profileRepositoryProvider).getUserProfile(userId);
});

final otherDriverProfileProvider = FutureProvider.family<DriverProfile?, String>((ref, userId) async {
  return ref.read(profileRepositoryProvider).getDriverData(userId);
});

final driverVerificationProvider = FutureProvider.family<DriverVerification?, String>((ref, userId) async {
  return ref.read(profileRepositoryProvider).getDriverVerification(userId);
});

final payoutMethodsProvider = FutureProvider<List<PayoutMethod>>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return [];
  return ref.read(profileRepositoryProvider).getPayoutMethods(user.uid);
});

final payoutRequestsProvider = FutureProvider<List<PayoutRequest>>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return [];
  return ref.read(profileRepositoryProvider).getPayoutRequests(user.uid);
});

final emergencyContactsProvider = FutureProvider<List<EmergencyContact>>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return [];
  return ref.read(profileRepositoryProvider).getEmergencyContacts(user.uid);
});

final sessionLockProvider = StreamProvider<bool>((ref) async* {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    yield true;
    return;
  }

  final localDeviceId = await SessionService.getUniqueDeviceId();

  yield* FirebaseFirestore.instance
      .collection('profiles')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists) return true;
    final remoteDeviceId = snapshot.data()?['device_id'];
    if (remoteDeviceId != null && remoteDeviceId != localDeviceId) {
      AppLogger.log('[SESSION] Discrepancia de dispositivo detectada. Local: $localDeviceId, Remoto: $remoteDeviceId');
      return false;
    } else {
      return true;
    }
  });
});
