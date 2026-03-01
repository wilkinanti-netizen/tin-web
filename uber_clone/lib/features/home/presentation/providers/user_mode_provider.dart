import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tincars/core/providers/shared_prefs_provider.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';

enum UserMode { passenger, driver }

class UserModeNotifier extends Notifier<UserMode> {
  static const String _modeKey = 'last_user_mode';

  @override
  UserMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedMode = prefs.getString(_modeKey);
    if (savedMode == 'driver') return UserMode.driver;
    return UserMode.passenger;
  }

  void toggleMode() {
    final nextMode = state == UserMode.passenger
        ? UserMode.driver
        : UserMode.passenger;
    state = nextMode;
    _persistMode(nextMode);
  }

  void setMode(UserMode mode) {
    state = mode;
    _persistMode(mode);
  }

  Future<void> _persistMode(UserMode mode) async {
    // Save to local storage for immediate recovery
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_modeKey, mode.name);

    // Save to remote profile for sync across devices
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await ref.read(profileRepositoryProvider).updateProfile(user.id, {
          'last_mode': mode.name,
        });
      } catch (e) {
        AppLogger.log('Error persisting mode to remote: $e');
      }
    }
  }
}

final userModeProvider = NotifierProvider<UserModeNotifier, UserMode>(() {
  return UserModeNotifier();
});

class ModeTransitionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  set state(bool value) => super.state = value;

  void start() => state = true;
  void stop() => state = false;
}

final isModeTransitioningProvider =
    NotifierProvider<ModeTransitionNotifier, bool>(() {
      return ModeTransitionNotifier();
    });
