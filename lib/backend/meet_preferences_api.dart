import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '/backend/schema/meet_preferences_record.dart';
import '/backend/schema/personal_meet_resources.dart';

CollectionReference<Map<String, dynamic>> _meetPreferencesCol(String uid) =>
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meet_preferences');

/// All meet preference docs for the signed-in user, keyed by meet id (doc id).
Stream<Map<String, MeetPreferencesRecord>> streamMeetPreferencesMap(
  String uid,
) {
  if (uid.isEmpty) {
    return Stream.value(<String, MeetPreferencesRecord>{});
  }
  return _meetPreferencesCol(uid).snapshots().map((snap) {
    final out = <String, MeetPreferencesRecord>{};
    for (final d in snap.docs) {
      out[d.id] = MeetPreferencesRecord.fromSnapshot(d);
    }
    return out;
  });
}

Future<void> mergeMeetPreference(
  String uid,
  String meetId, {
  MeetPreferenceStatus? status,
  bool? hasAlert,
  bool? isHidden,
  bool? skipSelected,
  String? notes,
}) async {
  final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (authUid.isEmpty || meetId.isEmpty) {
    return;
  }
  if (uid.isNotEmpty && uid != authUid) {
    return;
  }
  await _meetPreferencesCol(authUid).doc(meetId).set(
        MeetPreferencesRecord.mergeData(
          status: status,
          hasAlert: hasAlert,
          isHidden: isHidden,
          skipSelected: skipSelected,
          notes: notes,
          statusUpdatedBy: status != null ? authUid : null,
        ),
        SetOptions(merge: true),
      );
}


Future<void> deleteMeetPreference(String uid, String meetId) async {
  final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (authUid.isEmpty || meetId.isEmpty) {
    return;
  }
  if (uid.isNotEmpty && uid != authUid) {
    return;
  }
  await _meetPreferencesCol(authUid).doc(meetId).delete();
}

/// Saves or removes one slot under `personal_resources` on the user’s meet doc.
Future<void> mergePersonalMeetResource(
  String uid,
  String meetId,
  PersonalResourceKind kind, {
  required String url,
  required String note,
  bool delete = false,
}) async {
  final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (authUid.isEmpty || meetId.isEmpty) {
    return;
  }
  if (uid.isNotEmpty && uid != authUid) {
    return;
  }

  final ref = _meetPreferencesCol(authUid).doc(meetId);
  final key = kind.firestoreKey;

  if (delete) {
    try {
      await ref.update({
        FieldPath(['personal_resources', key]): FieldValue.delete(),
        'updated_time': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        return;
      }
      rethrow;
    }
    return;
  }

  final u = url.trim();
  final n = note.trim();
  if (u.isEmpty && n.isEmpty) {
    try {
      await ref.update({
        FieldPath(['personal_resources', key]): FieldValue.delete(),
        'updated_time': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        return;
      }
      rethrow;
    }
    return;
  }

  await ref.set(
    {
      'personal_resources': {
        key: {
          'url': u,
          'note': n,
          'updated_at': FieldValue.serverTimestamp(),
        },
      },
      'updated_time': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );
}
