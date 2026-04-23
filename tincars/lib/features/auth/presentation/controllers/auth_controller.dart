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
    print('[DEBUG] AuthController: Iniciando signIn');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithEmailAndPassword(email, password),
    );
    if (state.hasError) {
      print('[DEBUG] AuthController: Error en signIn: ${state.error}');
    } else {
      print(
        '[DEBUG] AuthController: signIn completado con éxito, vinculando dispositivo...',
      );
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
    print('[DEBUG] AuthController: Entering signUp method');
    print('[DEBUG] AuthController: email=$email, isDriver=$isDriver');
    if (isDriver) {
      print('[DEBUG] AuthController: Documents -> License: $licensePath, Insurance: $insurancePath');
    }
    
    state = const AsyncValue.loading();
    print('[DEBUG] AuthController: state set to loading');

    state = await AsyncValue.guard(
      () {
        print('[DEBUG] AuthController: Calling repository.createUserWithEmailAndPassword');
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
      print('[DEBUG] AuthController: Error en signUp: ${state.error}');
    } else {
      print('[DEBUG] AuthController: signUp completado con éxito');
    }
  }

  Future<void> signInWithPhone(String phone) async {
    print('[DEBUG] AuthController: Enviando OTP a $phone');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithPhone(phone),
    );
    if (state.hasError) {
      print('[DEBUG] AuthController: Error enviando OTP: ${state.error}');
    }
  }

  Future<void> verifyOtp(String phone, String token) async {
    print('[DEBUG] AuthController: Verificando OTP para $phone');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).verifyPhoneOtp(phone, token),
    );
    if (state.hasError) {
      print('[DEBUG] AuthController: Error verificando OTP: ${state.error}');
    }
  }

  Future<void> signInWithGoogle() async {
    print('[DEBUG] AuthController: Iniciando Google Sign In');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
  }

  Future<void> signInWithApple() async {
    print('[DEBUG] AuthController: Iniciando Apple Sign In');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithApple(),
    );
  }

  Future<void> signOut() async {
    print('[DEBUG] AuthController: Iniciando signOut');
    // Invalidate profile providers to clear cached data
    ref.invalidate(userProfileProvider);
    ref.invalidate(driverProfileProvider);
    await ref.read(authRepositoryProvider).signOut();
    print('[DEBUG] AuthController: signOut completado');
  }
}
