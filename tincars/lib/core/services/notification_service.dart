import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tincars/core/utils/app_logger.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:io';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    // Request FCM permissions
    if (Platform.isIOS || Platform.isAndroid) {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger.log('NotificationService: User granted FCM permission');
      }
    }

    // Initialize Local Notifications
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        AppLogger.log('Notification clicked: ${response.payload}');
      },
    );

    // Request permissions for Android 13+
    if (Platform.isAndroid) {
      _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    AppLogger.log('NotificationService: Local notifications initialized.');
  }

  /// Shows a high-priority notification for an incoming trip request.
  Future<void> showIncomingTripNotification({
    required String tripId,
    required String pickupAddress,
    required String price,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'incoming_trip_channel',
          'Nuevo Viaje Disponible',
          channelDescription:
              'Alerta de viaje entrante para conductores TinCars',
          importance: Importance.max,
          priority: Priority.max,
          ticker: 'Nuevo viaje disponible',
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound('alerta'),
          fullScreenIntent: true,
          ongoing: false,
          autoCancel: true,
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          timeoutAfter: 30000,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'alerta.mp3',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: 1001,
      title: '🚗 ¡Nuevo viaje disponible!',
      body: '\$$price — Recogida: $pickupAddress',
      notificationDetails: platformDetails,
      payload: tripId,
    );

    AppLogger.log(
      'NotificationService: Incoming trip notification shown for trip $tripId',
    );
  }

  Future<void> cancelIncomingTripNotification() async {
    await _notificationsPlugin.cancel(id: 1001);
  }

  Future<void> showTripStatusNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'trip_status_channel',
          'Trip Status Updates',
          channelDescription: 'Notifications about your trip status changes',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          playSound: true,
          enableVibration: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: payload,
    );
  }

  Future<void> showChatMessageNotification({
    required String senderName,
    required String messageText,
    String? tripId,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'chat_messages_channel',
          'Mensajes de Chat',
          channelDescription:
              'Notificaciones de nuevos mensajes del chat del viaje',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: 1002, // Unique ID for chat notifications (can overwrite previous chat alert)
      title: 'Nuevo mensaje de $senderName',
      body: messageText,
      notificationDetails: platformDetails,
      payload: tripId,
    );
  }

  Future<String?> getToken() async {
    try {
      if (kIsWeb) return null;

      // Force token refresh by deleting the old one first
      // This is necessary to clear stale tokens from previous project configurations
      await _fcm.deleteToken();

      String? token = await _fcm.getToken();
      return token;
    } catch (e) {
      AppLogger.error('Error getting FCM token', error: e);
      return null;
    }
  }
}
