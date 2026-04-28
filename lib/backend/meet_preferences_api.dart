import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '/backend/schema/meet_preferences_record.dart';
import '/backend/schema/monitored_meets_record.dart';
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

Future<MeetPreferencesRecord?> getMeetPreferenceOnce(
    String uid, String meetId) async {
  final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (authUid.isEmpty || meetId.isEmpty) {
    return null;
  }
  if (uid.isNotEmpty && uid != authUid) {
    return null;
  }
  final snap = await _meetPreferencesCol(authUid).doc(meetId).get();
  if (!snap.exists) {
    return null;
  }
  return MeetPreferencesRecord.fromSnapshot(snap);
}

Future<void> setMeetStatus(
  String uid,
  String meetId, {
  required MeetPreferenceStatus status,
  bool? skipSelected,
  bool? hasAlert,
  bool? isHidden,
  bool? pendingEntryConfirmation,
  String? notes,
  Map<String, dynamic> extra = const <String, dynamic>{},
}) async {
  final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (authUid.isEmpty || meetId.isEmpty) {
    return;
  }
  if (uid.isNotEmpty && uid != authUid) {
    return;
  }
  final data = <String, dynamic>{
    ...MeetPreferencesRecord.mergeData(
      status: status,
      hasAlert: hasAlert,
      isHidden: isHidden,
      skipSelected: skipSelected,
      notes: notes,
      statusUpdatedBy: authUid,
    ),
    'status_updated_at': FieldValue.serverTimestamp(),
    if (pendingEntryConfirmation != null)
      'pending_entry_confirmation': pendingEntryConfirmation,
    ...extra,
  };
  await _meetPreferencesCol(authUid).doc(meetId).set(
        data,
        SetOptions(merge: true),
      );
}

Future<void> startEntry(
  String uid,
  String meetId, {
  String? notes,
}) async {
  await setMeetStatus(
    uid,
    meetId,
    status: MeetPreferenceStatus.needEntry,
    skipSelected: false,
    hasAlert: false,
    isHidden: false,
    pendingEntryConfirmation: false,
    notes: notes,
    extra: <String, dynamic>{
      'entry_started_at': FieldValue.serverTimestamp(),
      'entry_started_from_app': true,
    },
  );
}

String buildEntryUrl(MonitoredMeetsRecord meet) => meet.entryUrl.trim();

Future<bool> startEntryInBrowser(
  String uid,
  MonitoredMeetsRecord meet, {
  String? notes,
}) async {
  final meetId = meet.reference.id;
  final url = buildEntryUrl(meet);
  if (url.isEmpty) {
    return false;
  }
  final existing = await getMeetPreferenceOnce(uid, meetId);
  await setMeetStatus(
    uid,
    meetId,
    status: MeetPreferenceStatus.needEntry,
    skipSelected: false,
    hasAlert: false,
    isHidden: false,
    pendingEntryConfirmation: true,
    notes: notes,
    extra: <String, dynamic>{
      if (existing == null) 'entry_started_at': FieldValue.serverTimestamp(),
      'entry_started_from_app': true,
      'last_opened_entry_url_at': FieldValue.serverTimestamp(),
    },
  );
  await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  return true;
}

Future<void> markEntrySubmitted(
  String uid,
  String meetId, {
  String? notes,
}) async {
  final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (authUid.isEmpty || meetId.isEmpty) {
    return;
  }
  if (uid.isNotEmpty && uid != authUid) {
    return;
  }
  await setMeetStatus(
    authUid,
    meetId,
    status: MeetPreferenceStatus.entered,
    skipSelected: false,
    hasAlert: false,
    isHidden: false,
    pendingEntryConfirmation: false,
    notes: notes,
    extra: <String, dynamic>{
      'submitted_at': FieldValue.serverTimestamp(),
    },
  );
  await FirebaseFirestore.instance
      .collection('users')
      .doc(authUid)
      .collection('entered_meets')
      .doc(meetId)
      .set(
    <String, dynamic>{
      'meet_id': meetId,
      'entered_at': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );
}

Future<void> clearPendingEntryConfirmation(
  String uid,
  String meetId,
) async {
  final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (authUid.isEmpty || meetId.isEmpty) {
    return;
  }
  if (uid.isNotEmpty && uid != authUid) {
    return;
  }
  await _meetPreferencesCol(authUid).doc(meetId).set(
    <String, dynamic>{
      'pending_entry_confirmation': false,
      'updated_time': FieldValue.serverTimestamp(),
    },
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

CollectionReference<Map<String, dynamic>> _personalResourcesCol(
  String uid,
  String meetId,
) =>
    _meetPreferencesCol(uid).doc(meetId).collection('personal_resources');

Stream<List<PersonalMeetResourceEntry>> streamPersonalMeetResources(
  String uid,
  String meetId,
) {
  if (uid.isEmpty || meetId.isEmpty) {
    return Stream.value(const <PersonalMeetResourceEntry>[]);
  }
  return _personalResourcesCol(uid, meetId).snapshots().map((snap) {
    final out = snap.docs
        .map((d) => PersonalMeetResourceEntry.fromSnapshot(d))
        .toList();
    final order =
        PersonalResourceKind.values.asMap().map((i, v) => MapEntry(v, i));
    out.sort((a, b) {
      final pa = order[a.kind] ?? 999;
      final pb = order[b.kind] ?? 999;
      if (pa != pb) {
        return pa.compareTo(pb);
      }
      final au = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bu = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bu.compareTo(au);
    });
    return out;
  });
}

Future<String> upsertPersonalMeetResource(
  String uid,
  String meetId, {
  String resourceId = '',
  required PersonalResourceKind kind,
  required Map<String, String> fields,
  DateTime? createdAt,
}) async {
  final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (authUid.isEmpty || meetId.isEmpty) {
    return '';
  }
  if (uid.isNotEmpty && uid != authUid) {
    return '';
  }

  final col = _personalResourcesCol(authUid, meetId);
  final doc =
      resourceId.trim().isEmpty ? col.doc() : col.doc(resourceId.trim());
  await doc.set({
    'resource_type': kind.firestoreValue,
    'resource_label': kind.uiTitle,
    'title': (fields['title'] ?? '').trim(),
    'url': (fields['url'] ?? '').trim(),
    'date': (fields['date'] ?? '').trim(),
    'time': (fields['time'] ?? '').trim(),
    'start_time': (fields['start_time'] ?? '').trim(),
    'end_time': (fields['end_time'] ?? '').trim(),
    'location': (fields['location'] ?? '').trim(),
    'address': (fields['address'] ?? '').trim(),
    'notes': (fields['notes'] ?? '').trim(),
    'source': 'manual',
    'is_private': true,
    'user_id': authUid,
    'meet_id': meetId,
    if (createdAt == null) 'created_at': FieldValue.serverTimestamp(),
    'updated_at': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  return doc.id;
}

Future<void> deletePersonalMeetResource(
  String uid,
  String meetId,
  String resourceId,
) async {
  final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (authUid.isEmpty || meetId.isEmpty || resourceId.trim().isEmpty) {
    return;
  }
  if (uid.isNotEmpty && uid != authUid) {
    return;
  }
  await _personalResourcesCol(authUid, meetId).doc(resourceId.trim()).delete();
}
