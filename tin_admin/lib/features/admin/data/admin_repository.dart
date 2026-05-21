import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tin_admin/features/profile/domain/models/profiles.dart';
import 'package:tin_admin/features/trips/domain/models/trip_model.dart';
import 'package:tin_admin/features/admin/domain/models/admin_settings.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository(this._firestore);

  // Stream all profiles for real-time updates
  Stream<List<AppUser>> streamAllProfiles() {
    return _firestore
        .collection('profiles')
        .orderBy('full_name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id; // Inject document ID
            return AppUser.fromJson(data);
          }).toList(),
        );
  }

  // Fetch driver data
  Future<DriverProfile?> getDriverData(String userId) async {
    final doc = await _firestore.collection('driver_data').doc(userId).get();

    if (!doc.exists) return null;

    final data = doc.data()!;
    data['profile_id'] = doc.id; // Inject document ID for the model
    return DriverProfile.fromJson(data);
  }

  // Fetch driver verification docs
  Future<DriverVerification?> getDriverVerification(String userId) async {
    final doc = await _firestore
        .collection('driver_verifications')
        .doc(userId)
        .get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    data['driver_id'] = doc.id; // Inject document ID for the model
    return DriverVerification.fromJson(data);
  }

  // Update driver status and sync verification
  Future<void> updateDriverStatus(
    String userId,
    DriverStatus status, {
    String? rejectionReason,
    List<VehicleType>? activeServices,
    Map<String, String>? rejectedPhotos,
  }) async {
    final batch = _firestore.batch();

    final Map<String, dynamic> profileUpdates = {'driver_status': status.name};
    if (status == DriverStatus.active) {
      profileUpdates['is_driver'] = true;
    } else if (status == DriverStatus.rejected) {
      profileUpdates['has_been_rejected'] = true;
    }
    batch.update(_firestore.collection('profiles').doc(userId), profileUpdates);

    // 2. Update active services or rejection reason in driver_data
    final Map<String, dynamic> driverDataUpdates = {};
    if (activeServices != null && activeServices.isNotEmpty) {
      driverDataUpdates['active_services'] = activeServices
          .map((e) => e.name)
          .toList();
    }
    if (status == DriverStatus.rejected && rejectionReason != null) {
      driverDataUpdates['rejection_reason'] = rejectionReason;
    }
    if (status == DriverStatus.rejected && rejectedPhotos != null) {
      driverDataUpdates['rejected_photos'] = rejectedPhotos;
    }
    if (driverDataUpdates.isNotEmpty) {
      batch.update(
        _firestore.collection('driver_data').doc(userId),
        driverDataUpdates,
      );
    }

    // 2. Sync with driver_verifications table using set(merge:true) to be safe
    final verifRef = _firestore.collection('driver_verifications').doc(userId);
    final verifUpdates = <String, dynamic>{
      'status': status.name,
      'rejection_reason': rejectionReason,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (status == DriverStatus.rejected && rejectedPhotos != null) {
      verifUpdates['rejected_photos'] = rejectedPhotos;
    }
    batch.set(verifRef, verifUpdates, SetOptions(merge: true));

    // 3. Send Push Notification if approved or rejected
    if (status == DriverStatus.active) {
      final notifRef = _firestore.collection('notification_jobs').doc();
      batch.set(notifRef, {
        'title': '¡Cuenta Aprobada!',
        'body':
            'Felicidades, tu cuenta ha sido aprobada. ¡Ya puedes empezar a conducir!',
        'target': userId,
        'created_at': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } else if (status == DriverStatus.rejected) {
      final notifRef = _firestore.collection('notification_jobs').doc();
      batch.set(notifRef, {
        'title': 'Actualización de Documentos',
        'body':
            'Hemos revisado tus documentos. Por favor, revisa la app para corregir los errores.',
        'target': userId,
        'created_at': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    }

    await batch.commit();
  }

  // Stream all pending/requested trips globally
  Stream<List<Trip>> streamAllRequestedTrips() {
    return _firestore
        .collection('trips')
        .where('status', isEqualTo: 'requested')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id; // Inject document ID
            return Trip.fromJson(data);
          }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  // Delete a trip
  Future<void> deleteTrip(String tripId) async {
    await _firestore.collection('trips').doc(tripId).delete();
  }

  // Stream all completed and cancelled trips globally
  Stream<List<Trip>> streamTripHistory() {
    return _firestore
        .collection('trips')
        .where('status', whereIn: ['completed', 'cancelled'])
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id; // Inject document ID
            return Trip.fromJson(data);
          }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  // Fetch admin settings
  Future<AdminSettings> fetchAdminSettings() async {
    final doc = await _firestore
        .collection('admin_settings')
        .doc('pricing')
        .get();
    if (!doc.exists) {
      throw Exception('Admin settings document not found');
    }
    return AdminSettings.fromJson(doc.data()!);
  }

  // Stream admin settings
  Stream<AdminSettings> streamAdminSettings() {
    return _firestore
        .collection('admin_settings')
        .doc('pricing')
        .snapshots()
        .map((doc) => AdminSettings.fromJson(doc.data() ?? {}));
  }

  // Update admin settings
  Future<void> updateAdminSettings(AdminSettings settings) async {
    await _firestore
        .collection('admin_settings')
        .doc('pricing')
        .set(settings.toJson(), SetOptions(merge: true));
  }
}
