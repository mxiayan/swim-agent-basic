import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

/// Stored under `users/{uid}/meet_preferences/{meetId}`.
enum MeetPreferenceStatus {
  newStatus,
  needEntry,
  entered,
  notGoing,
}

/// Centralized normalization for all Firestore status reads.
String normalizeMeetStatus(String? rawValue) {
  final raw = (rawValue ?? '').trim().toLowerCase();
  switch (raw) {
    case 'entered':
    case 'submitted':
    case 'confirmed':
    case 'going':
      return 'entered';
    case 'need_entry':
    case 'pending':
    case 'pending_entry':
    case 'need action':
    case 'to_enter':
    case 'planning':
    case 'interested':
      return 'need_entry';
    case 'not_going':
    case 'not_attending':
    case 'skipped':
    case 'declined':
      return 'not_going';
    case 'new':
    case 'unknown':
    case '':
    default:
      return 'new';
  }
}

MeetPreferenceStatus meetPreferenceStatusFromString(String? rawValue) {
  switch (normalizeMeetStatus(rawValue)) {
    case 'need_entry':
      return MeetPreferenceStatus.needEntry;
    case 'entered':
      return MeetPreferenceStatus.entered;
    case 'not_going':
      return MeetPreferenceStatus.notGoing;
    case 'new':
    default:
      return MeetPreferenceStatus.newStatus;
  }
}

String meetPreferenceStatusToFirestore(MeetPreferenceStatus status) {
  switch (status) {
    case MeetPreferenceStatus.newStatus:
      return 'new';
    case MeetPreferenceStatus.needEntry:
      return 'need_entry';
    case MeetPreferenceStatus.entered:
      return 'entered';
    case MeetPreferenceStatus.notGoing:
      return 'not_going';
  }
}

String meetStatusLabel(MeetPreferenceStatus status) {
  switch (status) {
    case MeetPreferenceStatus.newStatus:
      return 'New';
    case MeetPreferenceStatus.needEntry:
      return 'Need Entry';
    case MeetPreferenceStatus.entered:
      return 'Entered';
    case MeetPreferenceStatus.notGoing:
      return 'Not Going';
  }
}

int meetStatusSortPriority(MeetPreferenceStatus status) {
  switch (status) {
    case MeetPreferenceStatus.needEntry:
      return 0;
    case MeetPreferenceStatus.newStatus:
      return 1;
    case MeetPreferenceStatus.entered:
      return 2;
    case MeetPreferenceStatus.notGoing:
      return 3;
  }
}

bool isMyMeetStatus(MeetPreferenceStatus status) {
  return status == MeetPreferenceStatus.needEntry ||
      status == MeetPreferenceStatus.entered ||
      status == MeetPreferenceStatus.notGoing;
}

class MeetPreferencesRecord {
  MeetPreferencesRecord({
    required this.reference,
    required this.meetId,
    required this.status,
    required this.hasAlert,
    required this.isHidden,
    required this.skipSelected,
    this.notes = '',
    this.statusUpdatedAt,
    this.eventsEntered,
  });

  final DocumentReference reference;
  final String meetId;
  final MeetPreferenceStatus status;
  final bool hasAlert;
  final bool isHidden;
  final bool skipSelected;

  /// Parent reminder text (`users/{uid}/meet_preferences/{meetId}` → `notes`).
  final String notes;

  /// When status last changed in Firestore, if present (`statusUpdatedAt` / `status_updated_at`).
  final DateTime? statusUpdatedAt;

  /// Optional count from backend (`events_entered` / `eventsEntered`).
  final int? eventsEntered;

  static int? _readEventsEntered(Map<String, dynamic> data) {
    final raw = data['events_entered'] ?? data['eventsEntered'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return null;
  }

  static DateTime? _readStatusUpdatedAt(Map<String, dynamic> data) {
    final raw = data['statusUpdatedAt'] ?? data['status_updated_at'];
    return raw is DateTime ? raw : null;
  }

  static MeetPreferencesRecord fromSnapshot(DocumentSnapshot snapshot) {
    final data = mapFromFirestore(snapshot.data() as Map<String, dynamic>);
    return MeetPreferencesRecord(
      reference: snapshot.reference,
      meetId: snapshot.id,
      status: meetPreferenceStatusFromString(data['status'] as String?),
      hasAlert: data['has_alert'] as bool? ?? false,
      isHidden: data['is_hidden'] as bool? ?? false,
      skipSelected: data['skip_selected'] as bool? ?? false,
      notes: (data['notes'] as String?)?.trim() ?? '',
      statusUpdatedAt: _readStatusUpdatedAt(data),
      eventsEntered: _readEventsEntered(data),
    );
  }

  static Map<String, dynamic> mergeData({
    MeetPreferenceStatus? status,
    bool? hasAlert,
    bool? isHidden,
    bool? skipSelected,
    String? notes,
    String? statusUpdatedBy,
  }) {
    final m = <String, dynamic>{
      'updated_time': FieldValue.serverTimestamp(),
    };
    if (status != null) {
      m['status'] = meetPreferenceStatusToFirestore(status);
      m['statusUpdatedAt'] = FieldValue.serverTimestamp();
      if ((statusUpdatedBy ?? '').trim().isNotEmpty) {
        m['statusUpdatedBy'] = statusUpdatedBy!.trim();
      }
    }
    if (hasAlert != null) {
      m['has_alert'] = hasAlert;
    }
    if (isHidden != null) {
      m['is_hidden'] = isHidden;
    }
    if (skipSelected != null) {
      m['skip_selected'] = skipSelected;
    }
    if (notes != null) {
      m['notes'] = notes;
    }
    return m;
  }
}
