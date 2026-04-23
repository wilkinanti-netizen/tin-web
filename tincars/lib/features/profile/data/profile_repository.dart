import 'package:tincars/core/utils/app_logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';
import 'package:tincars/features/profile/domain/models/payout_request.dart';
import 'package:tincars/features/profile/domain/models/payout_method.dart';
import 'package:tincars/features/profile/domain/models/emergency_contact.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ProfileRepository();

  // Obtener el perfil general del usuario
  Future<AppUser?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('profiles').doc(userId).get();
      if (!doc.exists) return null;
      return AppUser.fromJson(doc.data()!);
    } catch (e) {
      AppLogger.log('Error al obtener perfil: $e');
      return null;
    }
  }

  // Buscar perfil por código de referido
  Future<AppUser?> getProfileByReferralCode(String code) async {
    try {
      final query = await _firestore
          .collection('profiles')
          .where('referral_code', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return AppUser.fromJson(query.docs.first.data());
    } catch (e) {
      AppLogger.log('Error al buscar por código de referido: $e');
      return null;
    }
  }

  // Obtener los datos del conductor si existen
  Future<DriverProfile?> getDriverData(String userId) async {
    try {
      final doc = await _firestore.collection('driver_data').doc(userId).get();
      if (!doc.exists) return null;
      return DriverProfile.fromJson(doc.data()!);
    } catch (e) {
      AppLogger.log('Error al obtener datos de conductor: $e');
      return null;
    }
  }

  // Actualizar perfil
  Future<void> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    await _firestore.collection('profiles').doc(userId).update(updates);
  }

  // Generar y actualizar código de referido si no tiene uno
  Future<void> ensureReferralCode(String userId) async {
    final user = await getUserProfile(userId);
    if (user != null &&
        (user.referralCode == null || user.referralCode!.isEmpty)) {
      final newCode = _generateReferralCode(user.fullName);
      await updateProfile(userId, {'referral_code': newCode});
      AppLogger.log('[REFERRAL] Código generado para ${user.id}: $newCode');
    }
  }

  String _generateReferralCode(String name) {
    final prefix = name.length >= 3
        ? name.substring(0, 3).toUpperCase()
        : name.toUpperCase().padRight(3, 'X');
    final random = DateTime.now().millisecondsSinceEpoch.toString().substring(10);
    return '$prefix$random';
  }

  // Actualizar ID del dispositivo para vinculación de sesión
  Future<void> updateDeviceId(String userId, String? deviceId) async {
    AppLogger.log('[PROFILE] Vinculando dispositivo $deviceId al usuario $userId');
    await _firestore.collection('profiles').doc(userId).update({'device_id': deviceId});
  }

  // Guardar preferencias de servicio del conductor
  Future<void> saveDriverData(DriverProfile driver) async {
    AppLogger.log('[PROFILE] Guardando preferencias conductor: ${driver.profileId}');
    await _firestore.collection('driver_data').doc(driver.profileId).update({
      'active_services': driver.activeServices.map((e) => e.name).toList(),
    });
    AppLogger.log('[PROFILE] Preferencias guardadas OK');
  }

  // Sumar a ganancias
  Future<void> addToEarnings(String userId, double amount) async {
    try {
      final batch = _firestore.batch();
      
      final driverRef = _firestore.collection('driver_data').doc(userId);
      batch.update(driverRef, {'total_earnings': FieldValue.increment(amount)});

      final profileRef = _firestore.collection('profiles').doc(userId);
      batch.update(profileRef, {'wallet_balance': FieldValue.increment(amount)});

      await batch.commit();
    } catch (e) {
      AppLogger.log('Error al actualizar ganancias: $e');
    }
  }

  // Actualizar ubicación del conductor (fuera de viaje)
  Future<void> updateLocation(
    String userId,
    double lat,
    double lng, {
    double? heading,
  }) async {
    try {
      await _firestore.collection('driver_data').doc(userId).update({
        'last_lat': lat,
        'last_lng': lng,
        if (heading != null) 'last_heading': heading,
        'last_location_update': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.log('Error al actualizar ubicación idle: $e');
    }
  }

  // Actualizar saldo de la billetera
  Future<void> updateWalletBalance(
    String userId,
    double amount, {
    bool isIncrement = true,
  }) async {
    try {
      await _firestore.collection('profiles').doc(userId).update({
        'wallet_balance': FieldValue.increment(isIncrement ? amount : -amount),
      });
    } catch (e) {
      AppLogger.log('Error al actualizar billetera: $e');
      rethrow;
    }
  }

  // --- Payout Methods (Bank Accounts) ---
  Future<List<PayoutMethod>> getPayoutMethods(String userId) async {
    try {
      final query = await _firestore
          .collection('payout_methods')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();

      return query.docs.map((doc) => PayoutMethod.fromJson(doc.data())).toList();
    } catch (e) {
      AppLogger.log('Error al obtener métodos de cobro: $e');
      return [];
    }
  }

  Future<void> savePayoutMethod(String userId, PayoutMethod method) async {
    final data = method.toJson();
    data['user_id'] = userId;
    data['created_at'] = FieldValue.serverTimestamp();
    await _firestore.collection('payout_methods').add(data);
  }

  // --- Payout Requests (Withdrawals) ---
  Future<void> requestPayout(PayoutRequest request) async {
    final data = request.toJson();
    data['created_at'] = FieldValue.serverTimestamp();
    await _firestore.collection('payout_requests').add(data);
  }

  Future<List<PayoutRequest>> getPayoutRequests(String userId) async {
    try {
      final query = await _firestore
          .collection('payout_requests')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();

      return query.docs.map((doc) => PayoutRequest.fromJson(doc.data())).toList();
    } catch (e) {
      AppLogger.log('Error al obtener solicitudes de retiro: $e');
      return [];
    }
  }

  Future<void> deletePayoutMethod(String id) async {
    await _firestore.collection('payout_methods').doc(id).delete();
  }

  // --- Admin Methods ---
  Future<List<AppUser>> getPendingDrivers() async {
    try {
      final query = await _firestore
          .collection('profiles')
          .where('driver_status', isEqualTo: 'pending')
          .where('is_driver', isEqualTo: true)
          .get();

      return query.docs.map((doc) => AppUser.fromJson(doc.data())).toList();
    } catch (e) {
      AppLogger.log('Error al obtener conductores pendientes: $e');
      return [];
    }
  }

  Future<void> updateDriverStatus(String userId, DriverStatus status) async {
    await _firestore.collection('profiles').doc(userId).update({'driver_status': status.name});
  }

  Future<List<PayoutRequest>> getAllPayoutRequests({PayoutStatus? status}) async {
    try {
      Query query = _firestore.collection('payout_requests');
      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }
      final result = await query.orderBy('created_at', descending: true).get();
      return result.docs.map((doc) => PayoutRequest.fromJson(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      AppLogger.log('Error al obtener solicitudes de retiro (admin): $e');
      return [];
    }
  }

  Future<void> updatePayoutStatus(String requestId, PayoutStatus status, {String? adminComment}) async {
    final updates = {
      'status': status.name,
      if (adminComment != null) 'admin_comment': adminComment,
      'updated_at': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('payout_requests').doc(requestId).update(updates);
  }

  // --- Emergency Contacts ---
  Future<List<EmergencyContact>> getEmergencyContacts(String userId) async {
    try {
      final query = await _firestore
          .collection('emergency_contacts')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();

      return query.docs.map((doc) => EmergencyContact.fromJson(doc.data())).toList();
    } catch (e) {
      AppLogger.log('Error al obtener contactos de emergencia: $e');
      return [];
    }
  }

  Future<void> saveEmergencyContact(EmergencyContact contact) async {
    final data = contact.toJson();
    if (data['id'] == null) {
      final docRef = _firestore.collection('emergency_contacts').doc();
      data['id'] = docRef.id;
      data['created_at'] = FieldValue.serverTimestamp();
      await docRef.set(data);
    } else {
      await _firestore.collection('emergency_contacts').doc(data['id']).update(data);
    }
  }

  Future<void> deleteEmergencyContact(String id) async {
    await _firestore.collection('emergency_contacts').doc(id).delete();
  }
}
