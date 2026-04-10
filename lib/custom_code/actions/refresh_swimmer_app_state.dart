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

/// Last-resort label from the signed-in account (never prefer over swimmer / users doc).
String _accountHintName(User? user) {
  if (user == null) {
    return '';
  }
  var n = (user.displayName ?? '').trim();
  if (n.isEmpty) {
    final e = user.email;
    if (e != null && e.contains('@')) {
      n = e.split('@').first;
    }
  }
  return n;
}

Future<String> _clubCodeFromUsersDoc(String uid) async {
  try {
    final snap = await UsersRecord.collection.doc(uid).get();
    if (!snap.exists) {
      return '';
    }
    return UsersRecord.fromSnapshot(snap).clubCode.trim();
  } catch (_) {
    return '';
  }
}

/// Meets banner: prefer [metadata_regions] `display_name` (via `PC_Z*` id), else
/// swimmer `zone_display_name`, else [pacificSwimmingBannerFallbackForGranularZone].
Future<String> _resolveZoneBannerDisplay({
  required String granularZone,
  required String swimmerZoneDisplayRaw,
}) async {
  final g = swimmerZoneStoredOrEmpty(granularZone);
  if (g.isEmpty) {
    final sd = swimmerZoneDisplayRaw.trim();
    if (sd.isNotEmpty && !isSwimmerZonePlaceholder(sd)) {
      return formatPacificSwimmingZoneBannerLabel(sd);
    }
    return '';
  }

  try {
    final meta = await MetadataRegionsRecord.findByGranularPacificZone(g);
    final dn = (meta?.displayName ?? '').trim();
    if (dn.isNotEmpty) {
      return formatPacificSwimmingZoneBannerLabel(dn);
    }
  } catch (e, st) {
    debugPrint('refreshSwimmerAppState metadata_regions: $e\n$st');
  }

  final sd = swimmerZoneDisplayRaw.trim();
  if (sd.isNotEmpty && !isSwimmerZonePlaceholder(sd)) {
    return formatPacificSwimmingZoneBannerLabel(sd);
  }

  return formatPacificSwimmingZoneBannerLabel(
    pacificSwimmingBannerFallbackForGranularZone(g),
  );
}

/// When no `swimmers` row resolves via [SwimmerRecord.getForAuthUid], still load name
/// from broader Firestore queries and `users/{uid}` before using the email local part.
Future<void> _applyWhenSwimmerDocMissing(String uid, User? user) async {
  var name =
      (await SwimmerRecord.fetchDisplayNameFromFirestoreForUid(uid))?.trim() ??
          '';

  var clubKey = '';
  try {
    final snap = await UsersRecord.collection.doc(uid).get();
    if (snap.exists) {
      final ur = UsersRecord.fromSnapshot(snap);
      if (name.isEmpty && ur.displayName.trim().isNotEmpty) {
        name = ur.displayName.trim();
      }
      clubKey = ur.clubCode.trim();
    }
  } catch (e, st) {
    debugPrint('refreshSwimmerAppState users fallback: $e\n$st');
  }

  if (name.isEmpty) {
    name = _accountHintName(user);
  }

  if (clubKey.isNotEmpty) {
    final club = await MetadataClubsRecord.findByClubLookup(clubKey);
    if (club != null && club.zoneId.isNotEmpty) {
      final z = swimmerZoneStoredOrEmpty(club.zoneId);
      final banner = await _resolveZoneBannerDisplay(
        granularZone: club.zoneId,
        swimmerZoneDisplayRaw: club.zoneDisplayName,
      );
      FFAppState().update(() {
        FFAppState().currentSwimmerName = name;
        FFAppState().currentSwimmerGroup = clubKey;
        FFAppState().currentSwimmerZone = z;
        FFAppState().currentSwimmerZoneDisplayName = banner;
      });
      await FFAppState().persistSwimmerContext();
      return;
    }
  }

  if (name.isNotEmpty) {
    FFAppState().update(() {
      FFAppState().currentSwimmerName = name;
    });
    await FFAppState().persistSwimmerContext();
  }
}

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
  final user = FirebaseAuth.instance.currentUser;
  if (uid == null) {
    return;
  }

  try {
    await FirebaseAuth.instance.currentUser?.getIdToken();
  } catch (e, st) {
    debugPrint('refreshSwimmerAppState getIdToken: $e\n$st');
  }

  try {
    var s = await SwimmerRecord.getForAuthUid(uid);
    if (s == null) {
      await _applyWhenSwimmerDocMissing(uid, user);
      return;
    }

    final zoneMissingOrPlaceholder =
        s.zoneId.isEmpty || isSwimmerZonePlaceholder(s.zoneId);
    var clubLookupKey =
        s.groupId.trim().isNotEmpty ? s.groupId.trim() : s.clubId.trim();
    if (zoneMissingOrPlaceholder && clubLookupKey.isEmpty) {
      clubLookupKey = await _clubCodeFromUsersDoc(uid);
    }
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
      await _applyWhenSwimmerDocMissing(uid, user);
      return;
    }

    final profile = s;
    var name = profile.displayName.trim();
    if (name.isEmpty) {
      name =
          (await SwimmerRecord.fetchDisplayNameFromFirestoreForUid(uid))?.trim() ??
              '';
    }
    if (name.isEmpty) {
      try {
        final snap = await UsersRecord.collection.doc(uid).get();
        if (snap.exists) {
          final ur = UsersRecord.fromSnapshot(snap);
          if (ur.displayName.trim().isNotEmpty) {
            name = ur.displayName.trim();
          } else if (ur.email.isNotEmpty && ur.email.contains('@')) {
            name = ur.email.split('@').first;
          }
        }
      } catch (_) {}
    }
    if (name.isEmpty) {
      name = _accountHintName(user);
    }

    var groupOut = profile.groupId.trim();
    if (groupOut.isEmpty) {
      groupOut = profile.clubId.trim();
    }
    if (groupOut.isEmpty) {
      groupOut = await _clubCodeFromUsersDoc(uid);
    }

    final zoneOut = swimmerZoneStoredOrEmpty(profile.zoneId);
    final zoneBanner = await _resolveZoneBannerDisplay(
      granularZone: profile.zoneId,
      swimmerZoneDisplayRaw: profile.zoneDisplayName,
    );

    FFAppState().update(() {
      FFAppState().currentSwimmerName = name;
      FFAppState().currentSwimmerGroup = groupOut;
      FFAppState().currentSwimmerZone = zoneOut;
      FFAppState().currentSwimmerZoneDisplayName = zoneBanner;
    });
    await FFAppState().persistSwimmerContext();
  } catch (e, st) {
    debugPrint('refreshSwimmerAppState: $e\n$st');
    await _applyWhenSwimmerDocMissing(uid, user);
  }
}
