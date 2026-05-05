import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

/// Polymorphic event types written by the `swim-coach-parser` Cloud Run
/// service when it ingests coach emails for a team.
enum TeamEventType { meet, training, social, admin, unknown }

TeamEventType teamEventTypeFromString(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'MEET':
      return TeamEventType.meet;
    case 'TRAINING':
      return TeamEventType.training;
    case 'SOCIAL':
      return TeamEventType.social;
    case 'ADMIN':
      return TeamEventType.admin;
    default:
      return TeamEventType.unknown;
  }
}

String teamEventTypeLabel(TeamEventType t) {
  switch (t) {
    case TeamEventType.meet:
      return 'Meet';
    case TeamEventType.training:
      return 'Training';
    case TeamEventType.social:
      return 'Social';
    case TeamEventType.admin:
      return 'Admin';
    case TeamEventType.unknown:
      return 'Other';
  }
}

/// Plain immutable view of a `team_events/{hash}` Firestore doc.
class TeamEventsRecord {
  TeamEventsRecord({
    required this.reference,
    required this.docId,
    required this.teamId,
    required this.eventType,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.startTimeLocal,
    required this.endTimeLocal,
    required this.timezone,
    required this.isRecurring,
    required this.recurrenceRule,
    required this.appliesToGroups,
    required this.location,
    required this.entryDeadline,
    required this.entryUrl,
    required this.status,
    required this.details,
    required this.parsingConfidence,
    required this.subject,
    required this.sender,
    required this.sourceSection,
    required this.processedAt,
    required this.parsedStart,
  });

  final DocumentReference reference;
  final String docId;
  final String teamId;
  final TeamEventType eventType;

  // event_data.*
  final String title;
  final String startDate;
  final String endDate;
  final String startTimeLocal;
  final String endTimeLocal;
  final String timezone;
  final bool isRecurring;
  final String recurrenceRule;
  final List<String> appliesToGroups;
  final String location;
  final String entryDeadline;
  final String entryUrl;
  final String status;
  final String details;

  // top-level
  final double parsingConfidence;

  // metadata.*
  final String subject;
  final String sender;
  final String sourceSection;
  final DateTime? processedAt;

  /// `start_date` (+ optional `start_time_local`) parsed into a real DateTime.
  /// Null when the source had no date — those items are still kept so the
  /// user can see them.
  final DateTime? parsedStart;

  static TeamEventsRecord fromSnapshot(DocumentSnapshot snap) {
    final raw = mapFromFirestore(snap.data() as Map<String, dynamic>);
    final data = Map<String, dynamic>.from(raw['event_data'] as Map? ?? {});
    final meta = Map<String, dynamic>.from(raw['metadata'] as Map? ?? {});

    final groupsRaw = data['applies_to_groups'];
    final groups = <String>[];
    if (groupsRaw is List) {
      for (final g in groupsRaw) {
        if (g is String && g.trim().isNotEmpty) {
          groups.add(g.trim());
        }
      }
    }

    final startDate = (data['start_date'] as String?)?.trim() ?? '';
    final startTimeLocal =
        (data['start_time_local'] as String?)?.trim() ?? '';
    final parsedStart = _parseLocalStart(startDate, startTimeLocal);

    DateTime? processedAt;
    final pt = raw['processed_at'];
    final pm = meta['processed_at'];
    if (pt is DateTime) {
      processedAt = pt;
    } else if (pm is DateTime) {
      processedAt = pm;
    }

    final confidenceRaw = raw['parsing_confidence'];
    final confidence = confidenceRaw is num ? confidenceRaw.toDouble() : 0.0;

    String readStr(dynamic v) {
      if (v == null) {
        return '';
      }
      if (v is String) {
        return v.trim();
      }
      return v.toString().trim();
    }

    return TeamEventsRecord(
      reference: snap.reference,
      docId: snap.id,
      teamId: readStr(raw['team_id']),
      eventType: teamEventTypeFromString(raw['event_type'] as String?),
      title: readStr(data['title']),
      startDate: startDate,
      endDate: (data['end_date'] as String?)?.trim() ?? '',
      startTimeLocal: startTimeLocal,
      endTimeLocal: (data['end_time_local'] as String?)?.trim() ?? '',
      timezone: (data['timezone'] as String?)?.trim() ?? '',
      isRecurring: data['is_recurring'] == true,
      recurrenceRule: (data['recurrence_rule'] as String?)?.trim() ?? '',
      appliesToGroups: groups,
      location: (data['location'] as String?)?.trim() ?? '',
      entryDeadline: (data['entry_deadline'] as String?)?.trim() ?? '',
      entryUrl: (data['entry_url'] as String?)?.trim() ?? '',
      status: (data['status'] as String?)?.trim() ?? '',
      details: (data['details'] as String?)?.trim() ?? '',
      parsingConfidence: confidence,
      subject: (meta['subject'] as String?)?.trim() ?? '',
      sender: (meta['sender'] as String?)?.trim() ?? '',
      sourceSection: (meta['source_section'] as String?)?.trim() ?? '',
      processedAt: processedAt,
      parsedStart: parsedStart,
    );
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('team_events');

  /// Combine `YYYY-MM-DD` + optional `HH:MM` (assume local; we do NOT shift
  /// to UTC because the team_events doc carries its own timezone string).
  static DateTime? _parseLocalStart(String dateStr, String timeStr) {
    final d = dateStr.trim();
    if (d.isEmpty) {
      return null;
    }
    final dateMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(d);
    if (dateMatch == null) {
      return null;
    }
    final year = int.parse(dateMatch.group(1)!);
    final month = int.parse(dateMatch.group(2)!);
    final day = int.parse(dateMatch.group(3)!);
    var hour = 0;
    var minute = 0;
    final t = timeStr.trim();
    final timeMatch = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(t);
    if (timeMatch != null) {
      hour = int.parse(timeMatch.group(1)!);
      minute = int.parse(timeMatch.group(2)!);
    }
    return DateTime(year, month, day, hour, minute);
  }
}
