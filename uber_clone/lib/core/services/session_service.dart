import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionService {
  static final _deviceInfo = DeviceInfoPlugin();

  /// Get a unique identifier for the current physical device
  static Future<String> getUniqueDeviceId() async {
    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        return webInfo.userAgent ?? 'web-browser';
      }

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id; // Unique ID for Android
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'ios-device';
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }
    return 'unknown-device';
  }

  /// Update the user profile with the current device ID
  static Future<void> updateSessionInfo() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final deviceId = await getUniqueDeviceId();

      await supabase
          .from('profiles')
          .update({'device_id': deviceId})
          .eq('id', user.id);

      debugPrint(
        'Session info updated for user ${user.id}: DeviceID: $deviceId',
      );
    } catch (e) {
      debugPrint('Error updating session info: $e');
    }
  }
}
