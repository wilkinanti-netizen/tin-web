import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:tincars/core/services/session_service.dart';

// Interface
abstract class AuthRepository {
  Stream<supabase.User?> get authStateChanges;
  supabase.User? get currentUser;
  Future<void> signInWithEmailAndPassword(String email, String password);
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
  });
  Future<void> signOut();
}

// Supabase Implementation
class SupabaseAuthRepository implements AuthRepository {
  final supabase.SupabaseClient _supabase;

  SupabaseAuthRepository(this._supabase);

  @override
  Stream<supabase.User?> get authStateChanges =>
      _supabase.auth.onAuthStateChange.map((event) => event.session?.user);

  @override
  supabase.User? get currentUser => _supabase.auth.currentUser;

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    AppLogger.log('AuthRepository: Intentando iniciar sesión');
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      print(
        'AuthRepository: Inicio de sesión exitoso. User ID: ${response.user?.id}',
      );
      await SessionService.updateSessionInfo();
    } catch (e) {
      AppLogger.log('AuthRepository: Error al iniciar sesión: $e');
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
  }) async {
    AppLogger.log('AuthRepository: Intentando registrar usuario');
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      AppLogger.log(
        'AuthRepository: Registro en Auth exitoso. User ID: ${user?.id}',
      );

      if (user != null) {
        AppLogger.log('AuthRepository: Creando perfil en base de datos...');
        await _supabase.from('profiles').insert({
          'id': user.id,
          'email': email,
          'full_name': fullName,
          'is_driver': isDriver,
          'phone_number': phone,
          'ssn_last_4': ssnLast4,
          'driver_status': isDriver ? 'pending' : null,
          'created_at': DateTime.now().toIso8601String(),
        });

        if (isDriver) {
          print(
            'AuthRepository: Creando datos del conductor en driver_data...',
          );
          await _supabase.from('driver_data').insert({
            'profile_id': user.id,
            'vehicle_model': vehicleModel ?? 'Unknown',
            'vehicle_plate': vehiclePlate ?? 'Unknown',
            'vehicle_type': vehicleType ?? 'essentials',
            'vehicle_year': vehicleYear,
            'vehicle_color': vehicleColor,
            'background_check_consent': backgroundCheckConsent ?? false,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        AppLogger.log('AuthRepository: Perfil creado exitosamente');
        await SessionService.updateSessionInfo();
      } else {
        print(
          'AuthRepository: ALERTA - El usuario es null después del registro',
        );
      }
    } catch (e) {
      AppLogger.log('AuthRepository: Error en registro: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    AppLogger.log('AuthRepository: Cerrando sesión...');
    await _supabase.auth.signOut();
    AppLogger.log('AuthRepository: Sesión cerrada');
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(supabase.Supabase.instance.client);
});

final authStateChangesProvider = StreamProvider<supabase.User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});
