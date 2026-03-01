import 'package:tincars/core/utils/app_logger.dart';
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
    AppLogger.log('AuthController: Iniciando signIn');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithEmailAndPassword(email, password),
    );
    if (state.hasError) {
      AppLogger.log('AuthController: Error en signIn: ${state.error}');
    } else {
      AppLogger.log(
        'AuthController: signIn completado con éxito, vinculando dispositivo...',
      );
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        final deviceId = await SessionService.getUniqueDeviceId();
        await ref
            .read(profileRepositoryProvider)
            .updateDeviceId(user.id, deviceId);
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
  }) async {
    AppLogger.log('AuthController: Iniciando signUp');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
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
          ),
    );
    if (state.hasError) {
      AppLogger.log('AuthController: Error en signUp: ${state.error}');
    } else {
      AppLogger.log('AuthController: signUp completado con éxito');
    }
  }

  Future<void> signOut() async {
    AppLogger.log('AuthController: Iniciando signOut');
    await ref.read(authRepositoryProvider).signOut();
    AppLogger.log('AuthController: signOut completado');
  }
}
