import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

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
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'mappa-prezzi-benzina-demo',
    authDomain: 'mappa-prezzi-benzina-demo.firebaseapp.com',
    storageBucket: 'mappa-prezzi-benzina-demo.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'mappa-prezzi-benzina-demo',
    storageBucket: 'mappa-prezzi-benzina-demo.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'mappa-prezzi-benzina-demo',
    storageBucket: 'mappa-prezzi-benzina-demo.appspot.com',
    iosBundleId: 'com.example.mappaPrezziBenzina',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'mappa-prezzi-benzina-demo',
    storageBucket: 'mappa-prezzi-benzina-demo.appspot.com',
    iosBundleId: 'com.example.mappaPrezziBenzina',
  );
}
