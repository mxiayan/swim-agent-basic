/// Keys under `users/{uid}/meet_preferences/{meetId}` → `personal_resources`.
enum PersonalResourceKind {
  psychSheet,
  timeline,
  heatSheet,
  additionalNotes,
}

extension PersonalResourceKindX on PersonalResourceKind {
  String get firestoreKey => switch (this) {
        PersonalResourceKind.psychSheet => 'psych_sheet',
        PersonalResourceKind.timeline => 'timeline',
        PersonalResourceKind.heatSheet => 'heat_sheet',
        PersonalResourceKind.additionalNotes => 'additional_notes',
      };

  String get uiTitle => switch (this) {
        PersonalResourceKind.psychSheet => 'Psych sheet',
        PersonalResourceKind.timeline => 'Timeline',
        PersonalResourceKind.heatSheet => 'Heat sheet',
        PersonalResourceKind.additionalNotes => 'Additional notes',
      };
}

/// One saved row (URL and/or note) for a [PersonalResourceKind].
class PersonalMeetResourceEntry {
  const PersonalMeetResourceEntry({
    this.url = '',
    this.note = '',
    this.updatedAt,
  });

  final String url;
  final String note;
  final DateTime? updatedAt;

  bool get isEmpty => url.trim().isEmpty && note.trim().isEmpty;

  static PersonalMeetResourceEntry fromMap(Map<String, dynamic> map) {
    final url = (map['url'] as String?)?.trim() ?? '';
    final note = (map['note'] as String?)?.trim() ?? '';
    final u = map['updated_at'] ?? map['updatedAt'];
    DateTime? updatedAt;
    if (u is DateTime) {
      updatedAt = u;
    }
    return PersonalMeetResourceEntry(
      url: url,
      note: note,
      updatedAt: updatedAt,
    );
  }
}

/// All personal resource slots parsed from Firestore `personal_resources`.
class PersonalMeetResources {
  const PersonalMeetResources({
    required this.psychSheet,
    required this.timeline,
    required this.heatSheet,
    required this.additionalNotes,
  });

  final PersonalMeetResourceEntry psychSheet;
  final PersonalMeetResourceEntry timeline;
  final PersonalMeetResourceEntry heatSheet;
  final PersonalMeetResourceEntry additionalNotes;

  static const PersonalMeetResources empty = PersonalMeetResources(
    psychSheet: PersonalMeetResourceEntry(),
    timeline: PersonalMeetResourceEntry(),
    heatSheet: PersonalMeetResourceEntry(),
    additionalNotes: PersonalMeetResourceEntry(),
  );

  static PersonalMeetResources fromFirestore(dynamic raw) {
    if (raw is! Map) {
      return PersonalMeetResources.empty;
    }
    final m = raw.cast<String, dynamic>();
    PersonalMeetResourceEntry read(String key) {
      final v = m[key];
      if (v is! Map) {
        return const PersonalMeetResourceEntry();
      }
      return PersonalMeetResourceEntry.fromMap(v.cast<String, dynamic>());
    }
    return PersonalMeetResources(
      psychSheet: read('psych_sheet'),
      timeline: read('timeline'),
      heatSheet: read('heat_sheet'),
      additionalNotes: read('additional_notes'),
    );
  }

  PersonalMeetResourceEntry entry(PersonalResourceKind kind) => switch (kind) {
        PersonalResourceKind.psychSheet => psychSheet,
        PersonalResourceKind.timeline => timeline,
        PersonalResourceKind.heatSheet => heatSheet,
        PersonalResourceKind.additionalNotes => additionalNotes,
      };
}
