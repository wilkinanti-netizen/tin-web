import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tincars/features/auth/data/auth_repository.dart';
import 'package:tincars/core/services/session_service.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';

part 'auth_controller.g.dart';

@riverpod
class AuthController extends _$AuthController {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithEmailAndPassword(email, password),
    );
    if (state.hasError) {
    } else {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        final deviceId = await SessionService.getUniqueDeviceId();
        await ref
            .read(profileRepositoryProvider)
            .updateDeviceId(user.uid, deviceId);
      }
    }
  }

  Future<void> signUp(
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
    String? licensePath,
    String? insurancePath,
    String? referralCode,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(
      () {
        return ref
            .read(authRepositoryProvider)
            .createUserWithEmailAndPassword(
              email,
              password,
              fullName,
              isDriver,
              phone: phone,
              ssnLast4: ssnLast4,
              vehicleYear: vehicleYear,
              vehicleModel: vehicleModel,
              vehiclePlate: vehiclePlate,
              vehicleColor: vehicleColor,
              vehicleType: vehicleType,
              backgroundCheckConsent: backgroundCheckConsent,
              licensePath: licensePath,
              insurancePath: insurancePath,
              referralCode: referralCode,
            );
      }
    );

    if (state.hasError) {
    } else {
    }
  }

  Future<void> signInWithPhone(String phone) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithPhone(phone),
    );
    if (state.hasError) {
    }
  }

  Future<void> verifyOtp(String phone, String token) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).verifyPhoneOtp(phone, token),
    );
    if (state.hasError) {
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
  }

  Future<void> signInWithApple() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithApple(),
    );
  }

  Future<void> signOut() async {
    // Invalidate profile providers to clear cached data
    ref.invalidate(userProfileProvider);
    ref.invalidate(driverProfileProvider);
    await ref.read(authRepositoryProvider).signOut();
  }
}
