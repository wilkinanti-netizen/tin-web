import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:tincars/core/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Update the user profile with the current device ID and FCM token
  static Future<void> updateSessionInfo() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final deviceId = await getUniqueDeviceId();
      final fcmToken = await NotificationService.instance.getToken();

      final Map<String, dynamic> updates = {
        'device_id': deviceId,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (fcmToken != null) {
        updates['fcm_token'] = fcmToken;
      }

      await FirebaseFirestore.instance
          .collection('profiles')
          .doc(user.uid)
          .update(updates);

      debugPrint('Session info updated for user ${user.uid}: DeviceID: $deviceId, HasToken: ${fcmToken != null}');
    } catch (e) {
      debugPrint('Error updating session info: $e');
    }
  }
}
