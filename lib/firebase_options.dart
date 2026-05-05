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
    apiKey: 'AIzaSyAQcd83tU6mIA0ODokJN7JLo3bKbYMW_D4',
    appId: '1:350570687665:web:13cc1c8cc46b05e1378690',
    messagingSenderId: '350570687665',
    projectId: 'mappa-prezzi-benzina',
    authDomain: 'mappa-prezzi-benzina.firebaseapp.com',
    storageBucket: 'mappa-prezzi-benzina.firebasestorage.app',
    databaseURL: 'https://mappa-prezzi-benzina-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAQcd83tU6mIA0ODokJN7JLo3bKbYMW_D4',
    appId: '1:350570687665:android:13cc1c8cc46b05e1378690',
    messagingSenderId: '350570687665',
    projectId: 'mappa-prezzi-benzina',
    storageBucket: 'mappa-prezzi-benzina.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAQcd83tU6mIA0ODokJN7JLo3bKbYMW_D4',
    appId: '1:350570687665:ios:13cc1c8cc46b05e1378690',
    messagingSenderId: '350570687665',
    projectId: 'mappa-prezzi-benzina',
    storageBucket: 'mappa-prezzi-benzina.firebasestorage.app',
    iosBundleId: 'com.example.mappaPrezziBenzina',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAQcd83tU6mIA0ODokJN7JLo3bKbYMW_D4',
    appId: '1:350570687665:ios:13cc1c8cc46b05e1378690',
    messagingSenderId: '350570687665',
    projectId: 'mappa-prezzi-benzina',
    storageBucket: 'mappa-prezzi-benzina.firebasestorage.app',
    iosBundleId: 'com.example.mappaPrezziBenzina',
  );
}
