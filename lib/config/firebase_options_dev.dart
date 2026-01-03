// File generated manually due to CLI failure.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCER1wjWTk4RJtgEmZ4tfIbjX4SlMh4WWA',
    appId:
        '1:90881218120:web:eb120f79ca6ab578c06a7d', // Guessed from Android pattern
    messagingSenderId: '90881218120',
    projectId: 'veil-dev-shubham',
    authDomain: 'veil-dev-shubham.firebaseapp.com',
    storageBucket: 'veil-dev-shubham.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCER1wjWTk4RJtgEmZ4tfIbjX4SlMh4WWA',
    appId: '1:90881218120:android:4f1ae317ca6ab578c06a7d',
    messagingSenderId: '90881218120',
    projectId: 'veil-dev-shubham',
    storageBucket: 'veil-dev-shubham.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCER1wjWTk4RJtgEmZ4tfIbjX4SlMh4WWA',
    appId: '1:90881218120:ios:4f1ae317ca6ab578c06a7d', // Placeholder
    messagingSenderId: '90881218120',
    projectId: 'veil-dev-shubham',
    storageBucket: 'veil-dev-shubham.firebasestorage.app',
    iosBundleId: 'com.veil.bluff.dev',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCER1wjWTk4RJtgEmZ4tfIbjX4SlMh4WWA',
    appId: '1:90881218120:ios:4f1ae317ca6ab578c06a7d', // Placeholder
    messagingSenderId: '90881218120',
    projectId: 'veil-dev-shubham',
    storageBucket: 'veil-dev-shubham.firebasestorage.app',
    iosBundleId: 'com.veil.bluff.dev',
  );
}
