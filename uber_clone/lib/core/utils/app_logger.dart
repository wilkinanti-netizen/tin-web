import 'package:flutter/foundation.dart';

/// Production-safe logger.
/// Only prints in debug mode – silent in release builds.
class AppLogger {
  AppLogger._();

  static void log(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('$prefix$message');
    }
  }

  static void error(String message, {Object? error, StackTrace? stack}) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) debugPrint('  → $error');
      if (stack != null) debugPrint(stack.toString());
    }
    // In production, pipe to Crashlytics / Sentry here:
    // FirebaseCrashlytics.instance.recordError(error, stack, reason: message);
  }
}
