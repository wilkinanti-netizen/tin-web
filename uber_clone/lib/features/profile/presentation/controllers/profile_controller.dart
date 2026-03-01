import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tincars/features/profile/data/profile_repository.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';
import 'package:tincars/features/profile/domain/models/payout_method.dart';
import 'package:tincars/core/services/session_service.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(Supabase.instance.client);
});

final driverProfileProvider = FutureProvider<DriverProfile?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    AppLogger.log('driverProfileProvider: No hay usuario autenticado');
    return null;
  }
  AppLogger.log('driverProfileProvider: Cargando perfil para ${user.id}...');
  final profile = await ref
      .read(profileRepositoryProvider)
      .getDriverData(user.id);
  if (profile == null) {
    print(
      'driverProfileProvider: No se encontró perfil de conductor para ${user.id}',
    );
  } else {
    AppLogger.log(
      'driverProfileProvider: Perfil de conductor cargado exitosamente',
    );
  }
  return profile;
});

final userProfileProvider = FutureProvider<AppUser?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  return ref.read(profileRepositoryProvider).getUserProfile(user.id);
});

final otherUserProfileProvider = FutureProvider.family<AppUser?, String>((
  ref,
  userId,
) async {
  return ref.read(profileRepositoryProvider).getUserProfile(userId);
});
final otherDriverProfileProvider =
    FutureProvider.family<DriverProfile?, String>((ref, userId) async {
      return ref.read(profileRepositoryProvider).getDriverData(userId);
    });

final payoutMethodsProvider = FutureProvider<List<PayoutMethod>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  return ref.read(profileRepositoryProvider).getPayoutMethods(user.id);
});

final sessionLockProvider = StreamProvider<bool>((ref) async* {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    yield true; // No hay usuario, no hay bloqueo
    return;
  }

  final localDeviceId = await SessionService.getUniqueDeviceId();

  // Escuchamos cambios en el perfil del usuario en tiempo real
  final stream = Supabase.instance.client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', user.id);

  await for (final data in stream) {
    if (data.isEmpty) {
      yield true;
      continue;
    }

    final remoteDeviceId = data.first['device_id'];

    if (remoteDeviceId != null && remoteDeviceId != localDeviceId) {
      AppLogger.log(
        '[SESSION] Discrepancia de dispositivo detectada. Local: $localDeviceId, Remoto: $remoteDeviceId',
      );
      yield false; // Sesión bloqueada/inválida
    } else {
      yield true; // Sesión válida
    }
  }
});
