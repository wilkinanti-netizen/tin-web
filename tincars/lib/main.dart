import 'package:tincars/core/utils/app_logger.dart';
import 'package:tincars/core/utils/error_handler.dart';
import 'package:tincars/core/services/notification_service.dart';
import 'package:tincars/core/services/offline_queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tincars/firebase_options.dart';
import 'package:tincars/core/router/app_router.dart';
import 'package:tincars/core/theme/app_theme.dart';
import 'package:tincars/core/theme/theme_provider.dart';
import 'package:tincars/core/localization/locale_provider.dart';
import 'package:tincars/l10n/app_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:tincars/core/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tincars/core/providers/shared_prefs_provider.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/auth/data/auth_repository.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AppLogger.log("FCM Background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppErrorHandler.init();
  AppLogger.log('MAIN: WidgetsFlutterBinding inicializado');

  final sharedPrefs = await SharedPreferences.getInstance();

  // Inicializar Stripe
  Stripe.publishableKey =
      'pk_live_51T2Z3B05BF2Sot2zS4HFVtdTiFG4Sni2A7l7uKl5HJ4j1XqGIqAo89ryRcYBaaFVSDVXp23uOGONP05D2bbYVJ7N00mCalnHdU';
  await Stripe.instance.applySettings();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(sharedPrefs)],
      child: const InitializationWrapper(),
    ),
  );
}

class InitializationWrapper extends ConsumerStatefulWidget {
  const InitializationWrapper({super.key});
  @override
  ConsumerState<InitializationWrapper> createState() =>
      _InitializationWrapperState();
}

class _InitializationWrapperState extends ConsumerState<InitializationWrapper> {
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      AppLogger.log('MAIN: Iniciando Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      AppLogger.log('MAIN: Firebase inicializado con éxito');

      // Initialize Crashlytics
      if (!kIsWeb) {
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }

      // Initialize Analytics
      FirebaseAnalytics analytics = FirebaseAnalytics.instance;
      analytics.logAppOpen();

      // Register FCM Background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Initialize push notifications
      try {
        await NotificationService.instance.init();
      } catch (e) {
        AppLogger.error(
          'NotificationService init failed (non-fatal)',
          error: e,
        );
      }

      // Initialize offline queue service for connectivity-resilient operations
      try {
        await OfflineQueueService.instance.init();
      } catch (e) {
        AppLogger.error(
          'OfflineQueueService init failed (non-fatal)',
          error: e,
        );
      }

      // Refresh session device ID
      await SessionService.updateSessionInfo();

      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      AppLogger.log('MAIN ERROR: Fallo al inicializar Firebase: $e');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Error de Inicialización: $_error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.black),
                SizedBox(height: 20),
                Text(
                  'Iniciando App TinCars: Viajes y Confort...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return MyApp();
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

    // Detección de sesión única (Single Session Lock)
    ref.listen(sessionLockProvider, (previous, next) {
      next.whenData((isValid) {
        if (!isValid) {
          AppLogger.log(
            '[SESSION] Forzando cierre de sesión por vinculación de dispositivo',
          );
          ref.read(authRepositoryProvider).signOut();

          // Mostrar mensaje al usuario
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tu sesión se ha iniciado en otro dispositivo. Por seguridad, se ha cerrado aquí.',
              ),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 5),
            ),
          );
        }
      });
    });

    return MaterialApp.router(
      title: 'App TinCars: Viajes y Confort',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('es'), // Spanish
      ],
    );
  }
}
