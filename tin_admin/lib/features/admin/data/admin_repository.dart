import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tin_admin/features/profile/domain/models/profiles.dart';
import 'package:tin_admin/features/trips/domain/models/trip_model.dart';
import 'package:tin_admin/features/admin/domain/models/admin_settings.dart';


class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository(this._firestore);

  // Fetch all profiles
  Future<List<AppUser>> fetchAllProfiles() async {
    final query = await _firestore
        .collection('profiles')
        .orderBy('full_name')
        .get();
    return query.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // Inject document ID
      return AppUser.fromJson(data);
    }).toList();
  }

  // Fetch driver data
  Future<DriverProfile?> getDriverData(String userId) async {
    print('[DEBUG] AdminRepo: Fetching driver_data for $userId');
    final doc = await _firestore.collection('driver_data').doc(userId).get();

    print('[DEBUG] AdminRepo: driver_data exists: ${doc.exists}');
    if (!doc.exists) return null;

    final data = doc.data()!;
    data['profile_id'] = doc.id; // Inject document ID for the model
    return DriverProfile.fromJson(data);
  }

  // Fetch driver verification docs
  Future<DriverVerification?> getDriverVerification(String userId) async {
    print('[DEBUG] AdminRepo: Fetching driver_verifications for $userId');
    final doc = await _firestore
        .collection('driver_verifications')
        .doc(userId)
        .get();

    print('[DEBUG] AdminRepo: driver_verifications exists: ${doc.exists}');
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
  }) async {
    final batch = _firestore.batch();

    // 1. Update profile status and is_driver flag
    final Map<String, dynamic> profileUpdates = {'driver_status': status.name};
    if (status == DriverStatus.active) {
      profileUpdates['is_driver'] = true;
    }
    batch.update(_firestore.collection('profiles').doc(userId), profileUpdates);

    // 2. Update active services in driver_data if provided
    if (activeServices != null && activeServices.isNotEmpty) {
      batch.update(_firestore.collection('driver_data').doc(userId), {
        'active_services': activeServices.map((e) => e.name).toList(),
      });
    }

    // 2. Sync with driver_verifications table using set(merge:true) to be safe
    final verifRef = _firestore.collection('driver_verifications').doc(userId);
    batch.set(verifRef, {
      'status': status.name,
      'rejection_reason': rejectionReason,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

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
    final doc = await _firestore.collection('admin_settings').doc('pricing').get();
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
    await _firestore.collection('admin_settings').doc('pricing').set(
          settings.toJson(),
          SetOptions(merge: true),
        );
  }
}
