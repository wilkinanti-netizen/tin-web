import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';

final nearbyDriversProvider = StreamProvider<List<DriverProfile>>((ref) {
  return FirebaseFirestore.instance
      .collection('driver_data')
      .where('is_online', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => DriverProfile.fromJson(doc.data()))
          .toList());
});
