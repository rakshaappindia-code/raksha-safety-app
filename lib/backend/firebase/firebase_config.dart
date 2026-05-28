import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyDe1fllMZX_3kXudesC_GtJl7R4pRyF4BY",
            authDomain: "raksha-safety-app-e0baa.firebaseapp.com",
            projectId: "raksha-safety-app-e0baa",
            storageBucket: "raksha-safety-app-e0baa.firebasestorage.app",
            messagingSenderId: "527503896431",
            appId: "1:527503896431:web:6b9bb57dd13d2266e5429a",
            measurementId: "G-C3LSR74LD4"));
  } else {
    await Firebase.initializeApp();
  }
}
