// File generated for manual Firebase configuration fallback.
// Native platforms use google-services.json / GoogleService-Info.plist or DefaultFirebaseOptions.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyATHDzbaHDWlOaDaBrbynNkzSiJmTAzLPY',
    appId: '1:138157406834:web:a8527c823aa630c2f560eb',
    messagingSenderId: '138157406834',
    projectId: 'udhar-khata-5527a',
    authDomain: 'udhar-khata-5527a.firebaseapp.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyATHDzbaHDWlOaDaBrbynNkzSiJmTAzLPY',
    appId: '1:138157406834:android:a8527c823aa630c2f560eb',
    messagingSenderId: '138157406834',
    projectId: 'udhar-khata-5527a',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyATHDzbaHDWlOaDaBrbynNkzSiJmTAzLPY',
    appId: '1:138157406834:ios:a8527c823aa630c2f560eb',
    messagingSenderId: '138157406834',
    projectId: 'udhar-khata-5527a',
    iosBundleId: 'com.example.udharKhata',
  );
}
