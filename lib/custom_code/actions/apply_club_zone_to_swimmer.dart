// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'refresh_swimmer_app_state.dart';

/// On signup / profile club pick: read `metadata_clubs` doc, merge `zone_id` /
/// `zone_display_name` onto the **existing** `swimmers` row (same doc FlutterFlow
/// created at signup — resolved by `owner_id` or `swimmers/{uid}`).
///
/// **Important:** Add this as a Custom Action on the same page / flow **after**
/// the swimmer document exists (e.g. after "Create Document" on signup), or zone
/// fields will never be written.
///
/// [metadataClubDocumentId] — document id in `metadata_clubs`.
/// [displayName] — optional; merges into Firestore `name` if non-empty.
Future applyClubZoneToSwimmer(
  String metadataClubDocumentId, {
  String? displayName,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    throw Exception('Not signed in');
  }

  final clubSnap = await MetadataClubsRecord.collection
      .doc(metadataClubDocumentId)
      .get();

  if (!clubSnap.exists) {
    throw Exception('Club not found in metadata_clubs');
  }

  final club = MetadataClubsRecord.fromSnapshot(clubSnap);
  final zoneId = club.zoneId;
  final zoneDisplay = club.zoneDisplayName;

  final swimmerRef = await SwimmerRecord.documentRefForAuthUid(uid);
  if (swimmerRef == null) {
    throw Exception(
      'No swimmers document found for this user. '
      'Run signup / create swimmer first, then apply club zone (or call this action after the swimmer doc exists).',
    );
  }

  final data = createSwimmerRecordData(
    name: (displayName != null && displayName.isNotEmpty) ? displayName : null,
    zoneId: zoneId.isNotEmpty ? zoneId : null,
    zoneDisplayName: zoneDisplay.isNotEmpty ? zoneDisplay : null,
    clubId: metadataClubDocumentId,
  );

  await swimmerRef.set(
    data,
    SetOptions(merge: true),
  );

  await refreshSwimmerAppState();
}
