import 'package:cloud_firestore/cloud_firestore.dart';

enum PersonalResourceKind {
  psychSheet,
  timeline,
  heatSheet,
  volunteerJob,
  warmupInfo,
  parkingInfo,
  reminder,
  otherNote,
}

extension PersonalResourceKindX on PersonalResourceKind {
  String get firestoreValue => switch (this) {
        PersonalResourceKind.psychSheet => 'psych_sheet',
        PersonalResourceKind.timeline => 'timeline',
        PersonalResourceKind.heatSheet => 'heat_sheet',
        PersonalResourceKind.volunteerJob => 'volunteer_job',
        PersonalResourceKind.warmupInfo => 'warmup_info',
        PersonalResourceKind.parkingInfo => 'parking_info',
        PersonalResourceKind.reminder => 'reminder',
        PersonalResourceKind.otherNote => 'other_note',
      };

  String get uiTitle => switch (this) {
        PersonalResourceKind.psychSheet => 'Psych Sheet',
        PersonalResourceKind.timeline => 'Timeline',
        PersonalResourceKind.heatSheet => 'Heat Sheet',
        PersonalResourceKind.volunteerJob => 'Volunteer Job',
        PersonalResourceKind.warmupInfo => 'Warmup Info',
        PersonalResourceKind.parkingInfo => 'Parking Info',
        PersonalResourceKind.reminder => 'Reminder',
        PersonalResourceKind.otherNote => 'Other Note',
      };

  static PersonalResourceKind fromFirestoreValue(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'psych_sheet':
        return PersonalResourceKind.psychSheet;
      case 'timeline':
        return PersonalResourceKind.timeline;
      case 'heat_sheet':
        return PersonalResourceKind.heatSheet;
      case 'volunteer_job':
        return PersonalResourceKind.volunteerJob;
      case 'warmup_info':
        return PersonalResourceKind.warmupInfo;
      case 'parking_info':
        return PersonalResourceKind.parkingInfo;
      case 'reminder':
        return PersonalResourceKind.reminder;
      case 'other_note':
      default:
        return PersonalResourceKind.otherNote;
    }
  }
}

class PersonalMeetResourceEntry {
  const PersonalMeetResourceEntry({
    required this.id,
    required this.kind,
    this.resourceLabel = '',
    this.title = '',
    this.url = '',
    this.date = '',
    this.time = '',
    this.startTime = '',
    this.endTime = '',
    this.location = '',
    this.address = '',
    this.notes = '',
    this.source = 'manual',
    this.isPrivate = true,
    this.userId = '',
    this.meetId = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final PersonalResourceKind kind;
  final String resourceLabel;
  final String title;
  final String url;
  final String date;
  final String time;
  final String startTime;
  final String endTime;
  final String location;
  final String address;
  final String notes;
  final String source;
  final bool isPrivate;
  final String userId;
  final String meetId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isEmpty =>
      title.trim().isEmpty &&
      url.trim().isEmpty &&
      date.trim().isEmpty &&
      time.trim().isEmpty &&
      startTime.trim().isEmpty &&
      endTime.trim().isEmpty &&
      location.trim().isEmpty &&
      address.trim().isEmpty &&
      notes.trim().isEmpty;

  String get normalizedUrl {
    final raw = url.trim();
    if (raw.isEmpty) {
      return '';
    }
    return raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';
  }

  static DateTime? _toDateTime(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    return raw is DateTime ? raw : null;
  }

  static PersonalMeetResourceEntry fromSnapshot(DocumentSnapshot snap) {
    final data = (snap.data() as Map<String, dynamic>? ?? <String, dynamic>{});
    final kind = PersonalResourceKindX.fromFirestoreValue(
      (data['resource_type'] as String?) ?? '',
    );
    return PersonalMeetResourceEntry(
      id: snap.id,
      kind: kind,
      resourceLabel: (data['resource_label'] as String?)?.trim() ?? kind.uiTitle,
      title: (data['title'] as String?)?.trim() ?? '',
      url: (data['url'] as String?)?.trim() ?? '',
      date: (data['date'] as String?)?.trim() ?? '',
      time: (data['time'] as String?)?.trim() ?? '',
      startTime: (data['start_time'] as String?)?.trim() ?? '',
      endTime: (data['end_time'] as String?)?.trim() ?? '',
      location: (data['location'] as String?)?.trim() ?? '',
      address: (data['address'] as String?)?.trim() ?? '',
      notes: (data['notes'] as String?)?.trim() ?? '',
      source: (data['source'] as String?)?.trim() ?? 'manual',
      isPrivate: data['is_private'] as bool? ?? true,
      userId: (data['user_id'] as String?)?.trim() ?? '',
      meetId: (data['meet_id'] as String?)?.trim() ?? '',
      createdAt: _toDateTime(data['created_at']),
      updatedAt: _toDateTime(data['updated_at']),
    );
  }
}
