import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

/// Stored under `users/{uid}/meet_preferences/{meetId}`.
enum MeetPreferenceStatus {
  interested,
  entered,
  skipped,
}

MeetPreferenceStatus meetPreferenceStatusFromString(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'interested':
      return MeetPreferenceStatus.interested;
    case 'entered':
      return MeetPreferenceStatus.entered;
    case 'skipped':
    default:
      return MeetPreferenceStatus.skipped;
  }
}

String meetPreferenceStatusToFirestore(MeetPreferenceStatus s) => s.name;

class MeetPreferencesRecord {
  MeetPreferencesRecord({
    required this.reference,
    required this.meetId,
    required this.status,
    required this.hasAlert,
    required this.isHidden,
    this.notes = '',
  });

  final DocumentReference reference;
  final String meetId;
  final MeetPreferenceStatus status;
  final bool hasAlert;
  final bool isHidden;

  /// Parent reminder text (`users/{uid}/meet_preferences/{meetId}` → `notes`).
  final String notes;

  static MeetPreferencesRecord fromSnapshot(DocumentSnapshot snapshot) {
    final data = mapFromFirestore(snapshot.data() as Map<String, dynamic>);
    return MeetPreferencesRecord(
      reference: snapshot.reference,
      meetId: snapshot.id,
      status: meetPreferenceStatusFromString(data['status'] as String?),
      hasAlert: data['has_alert'] as bool? ?? false,
      isHidden: data['is_hidden'] as bool? ?? false,
      notes: (data['notes'] as String?)?.trim() ?? '',
    );
  }

  static Map<String, dynamic> mergeData({
    MeetPreferenceStatus? status,
    bool? hasAlert,
    bool? isHidden,
    String? notes,
  }) {
    final m = <String, dynamic>{
      'updated_time': FieldValue.serverTimestamp(),
    };
    if (status != null) {
      m['status'] = meetPreferenceStatusToFirestore(status);
    }
    if (hasAlert != null) {
      m['has_alert'] = hasAlert;
    }
    if (isHidden != null) {
      m['is_hidden'] = isHidden;
    }
    if (notes != null) {
      m['notes'] = notes;
    }
    return m;
  }
}
