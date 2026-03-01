import 'package:tincars/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';
import 'package:tincars/features/profile/domain/models/payout_method.dart';

class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository(this._supabase);

  // Obtener el perfil general del usuario
  Future<AppUser?> getUserProfile(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      return AppUser.fromJson(data);
    } catch (e) {
      AppLogger.log('Error al obtener perfil: $e');
      return null;
    }
  }

  // Obtener los datos del conductor si existen
  Future<DriverProfile?> getDriverData(String userId) async {
    try {
      final data = await _supabase
          .from('driver_data')
          .select()
          .eq('profile_id', userId)
          .maybeSingle();

      if (data == null) return null;
      return DriverProfile.fromJson(data);
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
    await _supabase.from('profiles').update(updates).eq('id', userId);
  }

  // Actualizar ID del dispositivo para vinculación de sesión
  Future<void> updateDeviceId(String userId, String? deviceId) async {
    AppLogger.log(
      '[PROFILE] Vinculando dispositivo $deviceId al usuario $userId',
    );
    await _supabase
        .from('profiles')
        .update({'device_id': deviceId})
        .eq('id', userId);
  }

  // Guardar preferencias de servicio del conductor (solo los campos editables)
  Future<void> saveDriverData(DriverProfile driver) async {
    AppLogger.log(
      '[PROFILE] Guardando preferencias conductor: ${driver.profileId}',
    );
    print(
      '[PROFILE] Servicios activos: ${driver.activeServices.map((e) => e.name).toList()}',
    );

    // Solo actualizamos los campos editables, sin tocar is_verified ni otros
    await _supabase
        .from('driver_data')
        .update({
          'active_services': driver.activeServices.map((e) => e.name).toList(),
        })
        .eq('profile_id', driver.profileId);

    AppLogger.log('[PROFILE] Preferencias guardadas OK');
  }

  // Sumar a ganancias
  Future<void> addToEarnings(String userId, double amount) async {
    try {
      final currentData = await _supabase
          .from('driver_data')
          .select('total_earnings')
          .eq('profile_id', userId)
          .maybeSingle();

      if (currentData == null) return;

      final currentEarnings =
          (currentData['total_earnings'] as num?)?.toDouble() ?? 0.0;

      await _supabase
          .from('driver_data')
          .update({'total_earnings': currentEarnings + amount})
          .eq('profile_id', userId);
    } catch (e) {
      AppLogger.log('Error al actualizar ganancias: $e');
    }
  }

  // --- Payout Methods (Bank Accounts) ---

  Future<List<PayoutMethod>> getPayoutMethods(String userId) async {
    try {
      final response = await _supabase
          .from('payout_methods')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PayoutMethod.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.log('Error al obtener métodos de cobro: $e');
      return [];
    }
  }

  Future<void> savePayoutMethod(String userId, PayoutMethod method) async {
    final data = method.toJson();
    data['user_id'] = userId;

    await _supabase.from('payout_methods').insert(data);
  }

  Future<void> deletePayoutMethod(String id) async {
    await _supabase.from('payout_methods').delete().eq('id', id);
  }
}
