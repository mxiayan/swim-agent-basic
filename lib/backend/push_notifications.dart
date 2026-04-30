import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

bool _tokenRefreshListenerStarted = false;

Future<bool> ensurePushNotificationsRegistered() async {
  if (kIsWeb) {
    return false;
  }

  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (uid.isEmpty) {
    return false;
  }

  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final status = settings.authorizationStatus.name;
    final allowed =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!allowed) {
      await _saveNotificationStatus(uid, status);
      return false;
    }

    final token = await messaging.getToken();
    if (token == null || token.trim().isEmpty) {
      await _saveNotificationStatus(uid, status, error: 'missing_fcm_token');
      return false;
    }

    await _saveFcmToken(uid, token, status: status);
    _startTokenRefreshListener();
    return true;
  } catch (e) {
    await _saveNotificationStatus(
      uid,
      'error',
      error: e.runtimeType.toString(),
    );
    return false;
  }
}

void _startTokenRefreshListener() {
  if (_tokenRefreshListenerStarted || kIsWeb) {
    return;
  }
  _tokenRefreshListenerStarted = true;
  FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty || token.trim().isEmpty) {
      return;
    }
    await _saveFcmToken(uid, token, status: 'authorized');
  });
}

Future<void> _saveFcmToken(
  String uid,
  String token, {
  required String status,
}) async {
  await _usersRef(uid).set(
    <String, dynamic>{
      'fcm_token': token.trim(),
      'fcm_token_updated_at': FieldValue.serverTimestamp(),
      'notification_permission_status': status,
      'notification_permission_updated_at': FieldValue.serverTimestamp(),
      'notification_registration_error': FieldValue.delete(),
    },
    SetOptions(merge: true),
  );
}

Future<void> _saveNotificationStatus(
  String uid,
  String status, {
  String? error,
}) async {
  await _usersRef(uid).set(
    <String, dynamic>{
      'notification_permission_status': status,
      'notification_permission_updated_at': FieldValue.serverTimestamp(),
      if (error != null) 'notification_registration_error': error,
    },
    SetOptions(merge: true),
  );
}

DocumentReference<Map<String, dynamic>> _usersRef(String uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid);
}
