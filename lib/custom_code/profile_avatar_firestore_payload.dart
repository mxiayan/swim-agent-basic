import 'package:flutter/foundation.dart';

import '/app_state.dart';

import 'profile_avatar_firestore_payload_stub.dart'
    if (dart.library.io) 'profile_avatar_firestore_payload_io.dart' as impl;

/// Base64 suitable for `swimmers.profile_avatar_base64` (empty string = no custom avatar).
Future<String> profileAvatarPayloadForFirestore() async {
  if (kIsWeb) {
    return FFAppState().profileAvatarWebBase64.trim();
  }
  return impl.encodeLocalAvatarToBase64(
    FFAppState().profileAvatarLocalPath.trim(),
  );
}
