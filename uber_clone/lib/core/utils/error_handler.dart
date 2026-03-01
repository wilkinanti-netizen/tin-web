import 'package:flutter/material.dart';
import 'package:tincars/core/utils/app_logger.dart';

/// Global error handler for uncaught Flutter and Dart exceptions.
/// Wrap your app with [AppErrorHandler.init] in main().
class AppErrorHandler {
  AppErrorHandler._();

  static void init() {
    // Catch Flutter framework errors (widget build errors, etc.)
    FlutterError.onError = (FlutterErrorDetails details) {
      AppLogger.error(
        'Flutter Error: ${details.exceptionAsString()}',
        error: details.exception,
        stack: details.stack,
      );
      // In production: FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    // Catch all other async/isolate errors
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      AppLogger.error('Uncaught Error: $error', error: error, stack: stack);
      // In production: FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
}
