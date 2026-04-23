// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyATxPJen0FDRcnm9OcJwpmCiWTWoFdxbKQ',
    appId: '1:132752752689:web:5d5e5f5g5h5i5j5k5l5m5n', // Placeholder, might fail on web
    messagingSenderId: '132752752689',
    projectId: 'tincars-b7d42',
    authDomain: 'tincars-b7d42.firebaseapp.com',
    storageBucket: 'tincars-b7d42.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyATxPJen0FDRcnm9OcJwpmCiWTWoFdxbKQ',
    appId: '1:132752752689:android:2ae60de369a457a3001510',
    messagingSenderId: '132752752689',
    projectId: 'tincars-b7d42',
    storageBucket: 'tincars-b7d42.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAg-tf4vh5Tzs0FCGwvYkp8BmPJ7A0DYYE',
    appId: '1:132752752689:ios:58697365b89abf56001510',
    messagingSenderId: '132752752689',
    projectId: 'tincars-b7d42',
    storageBucket: 'tincars-b7d42.firebasestorage.app',
    iosBundleId: 'com.Tincars.Tin',
  );
}
