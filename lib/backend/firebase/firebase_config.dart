import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyCmpGL2YGZ_ojVQOmPftU5Fie1JcGRsOkw",
            authDomain: "swimagentbasic-da546.firebaseapp.com",
            projectId: "swimagentbasic-da546",
            storageBucket: "swimagentbasic-da546.firebasestorage.app",
            messagingSenderId: "619843743622",
            appId: "1:619843743622:web:dc87801bcb7838b4d50607"));
  } else {
    await Firebase.initializeApp();
  }
}
