import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC5KoU8YyrSwRIjuhMczS8mnEBgMfDlrzc',
    appId: '1:504614396126:web:2d526051d5c7503e21224f',
    messagingSenderId: '504614396126',
    projectId: 'plataforma-examenes-f2df9',
    authDomain: 'plataforma-examenes-f2df9.firebaseapp.com',
    storageBucket: 'plataforma-examenes-f2df9.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC5KoU8YyrSwRIjuhMczS8mnEBgMfDlrzc',
    appId: '1:504614396126:android:7acd6536849f059521224f',
    messagingSenderId: '504614396126',
    projectId: 'plataforma-examenes-f2df9',
    storageBucket: 'plataforma-examenes-f2df9.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC5KoU8YyrSwRIjuhMczS8mnEBgMfDlrzc',
    appId: '1:504614396126:web:2d526051d5c7503e21224f',
    messagingSenderId: '504614396126',
    projectId: 'plataforma-examenes-f2df9',
    storageBucket: 'plataforma-examenes-f2df9.firebasestorage.app',
    iosBundleId: 'com.example.appMovilSistemaExamenes',
  );
}