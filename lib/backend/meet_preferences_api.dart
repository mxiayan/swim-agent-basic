import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '/backend/schema/meet_preferences_record.dart';

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
