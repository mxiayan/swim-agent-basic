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

/// After login, load the `swimmers` profile (`swimmers/{uid}` or `owner_id == uid`)
/// and populate FFAppState name / group / zone.
///
/// If the swimmer has **no** `zone_id` but has a **club code** (or similar), this
/// automatically looks up `metadata_clubs` and **merges** `zone_id` /
/// `zone_display_name` onto the swimmer doc — so Meets filtering works without
/// wiring `applyClubZoneToSwimmer` in FlutterFlow (as long as `metadata_clubs`
/// rows exist and include `zone_id`).
Future refreshSwimmerAppState() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return;
  }

  var s = await SwimmerRecord.getForAuthUid(uid);
  if (s == null) {
    return;
  }

  final zoneMissingOrPlaceholder =
      s.zoneId.isEmpty || isSwimmerZonePlaceholder(s.zoneId);
  final clubLookupKey =
      s.groupId.trim().isNotEmpty ? s.groupId.trim() : s.clubId.trim();
  if (zoneMissingOrPlaceholder && clubLookupKey.isNotEmpty) {
    final club = await MetadataClubsRecord.findByClubLookup(clubLookupKey);
    if (club != null && club.zoneId.isNotEmpty) {
      final ref = await SwimmerRecord.documentRefForAuthUid(uid);
      if (ref != null) {
        try {
          await ref.set(
            createSwimmerRecordData(
              zoneId: club.zoneId,
              zoneDisplayName: club.zoneDisplayName.isNotEmpty
                  ? club.zoneDisplayName
                  : null,
              clubId: club.reference.id,
            ),
            SetOptions(merge: true),
          );
        } catch (e, st) {
          debugPrint('hydrateSwimmerZone: merge failed: $e\n$st');
        }
      }
      s = await SwimmerRecord.getForAuthUid(uid);
    } else {
      debugPrint(
        'hydrateSwimmerZone: no metadata_clubs match for club key "$clubLookupKey" '
        'or club has empty zone_id. Check Firestore metadata_clubs docs and zone_id field.',
      );
    }
  }

  if (s == null) {
    return;
  }

  final profile = s;
  FFAppState().update(() {
    FFAppState().currentSwimmerName = profile.displayName;
    FFAppState().currentSwimmerGroup = profile.groupId;
    FFAppState().currentSwimmerZone = swimmerZoneStoredOrEmpty(profile.zoneId);
    FFAppState().currentSwimmerZoneDisplayName =
        isSwimmerZonePlaceholder(profile.zoneDisplayName)
            ? ''
            : profile.zoneDisplayName.trim();
  });
  await FFAppState().persistSwimmerContext();
}
