import 'package:tincars/core/utils/app_logger.dart';

/// Manages FCM registration, local notification display and routing.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> init() async {
    AppLogger.log(
      'NotificationService bypassed: Firebase disabled by user request.',
    );
  }

  Future<String?> getToken() async {
    return null;
  }
}
