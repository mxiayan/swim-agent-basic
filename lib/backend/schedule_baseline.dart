import 'package:cloud_firestore/cloud_firestore.dart';

/// One standing season template from ``teams/{teamId}.schedule_baselines``.
class ScheduleBaseline {
  const ScheduleBaseline({
    required this.id,
    required this.title,
    this.validFrom,
    this.validTo,
    this.notes = '',
    required this.body,
  });

  final String id;
  final String title;
  final String? validFrom;
  final String? validTo;
  final String notes;
  final String body;

  static ScheduleBaseline? tryParse(Map<String, dynamic> m) {
    final body = (m['body'] ?? '').toString();
    final title = (m['title'] ?? '').toString().trim();
    final id = (m['id'] ?? '').toString().trim();
    if (body.isEmpty && title.isEmpty) {
      return null;
    }
    return ScheduleBaseline(
      id: id.isEmpty ? title.hashCode.toString() : id,
      title: title.isEmpty ? 'Schedule' : title,
      validFrom: _strOrNull(m['valid_from']),
      validTo: _strOrNull(m['valid_to']),
      notes: (m['notes'] ?? '').toString().trim(),
      body: body,
    );
  }

  static String? _strOrNull(Object? v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  /// Reads Firestore ``schedule_baselines`` array on a team registry document.
  static List<ScheduleBaseline> listFromSnapshotData(
    Map<String, dynamic>? data,
  ) {
    if (data == null) {
      return const [];
    }
    final raw = data['schedule_baselines'];
    if (raw is! List) {
      return const [];
    }
    final out = <ScheduleBaseline>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        final b = tryParse(item);
        if (b != null) {
          out.add(b);
        }
      } else if (item is Map) {
        final b = tryParse(Map<String, dynamic>.from(item));
        if (b != null) {
          out.add(b);
        }
      }
    }
    return out;
  }
}

/// ``teams/{teamId}`` registry (parser config + optional ``schedule_baselines``).
Stream<DocumentSnapshot<Map<String, dynamic>>> streamTeamRegistryDocument(
  String teamId,
) {
  final id = teamId.trim();
  if (id.isEmpty) {
    throw ArgumentError.value(teamId, 'teamId', 'Cannot be empty');
  }
  return FirebaseFirestore.instance
      .collection('teams')
      .doc(id)
      .snapshots();
}
