import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tin_admin/features/admin/data/admin_repository.dart';
import 'package:tin_admin/features/profile/domain/models/profiles.dart';
import 'package:tin_admin/features/trips/domain/models/trip_model.dart';
import 'package:tin_admin/features/admin/domain/models/admin_settings.dart';


final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(FirebaseFirestore.instance);
});

final allProfilesProvider = FutureProvider<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchAllProfiles();
});

final driverDataProvider = FutureProvider.family<DriverProfile?, String>((
  ref,
  userId,
) {
  return ref.watch(adminRepositoryProvider).getDriverData(userId);
});

final verificationDataProvider =
    FutureProvider.family<DriverVerification?, String>((ref, userId) {
      return ref.watch(adminRepositoryProvider).getDriverVerification(userId);
    });

final globalRequestedTripsProvider = StreamProvider<List<Trip>>((ref) {
  return ref.watch(adminRepositoryProvider).streamAllRequestedTrips();
});

final globalTripHistoryProvider = StreamProvider<List<Trip>>((ref) {
  return ref.watch(adminRepositoryProvider).streamTripHistory();
});

final adminSettingsProvider = StreamProvider<AdminSettings>((ref) {
  return ref.watch(adminRepositoryProvider).streamAdminSettings();
});


class AdminController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    return null;
  }

  Future<void> updateDriverStatus(
    String userId,
    DriverStatus status, {
    String? rejectionReason,
    List<VehicleType>? activeServices,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(adminRepositoryProvider).updateDriverStatus(
        userId,
        status,
        rejectionReason: rejectionReason,
        activeServices: activeServices,
      );
    });
  }

  Future<void> updateAdminSettings(AdminSettings settings) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(adminRepositoryProvider).updateAdminSettings(settings);
    });
  }
}

final adminControllerProvider = AsyncNotifierProvider<AdminController, void>(
  () {
    return AdminController();
  },
);
