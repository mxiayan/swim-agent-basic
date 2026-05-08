import '/backend/schema/team_events_record.dart';

bool _titleLooksPracticeLike(String t) {
  return t.contains('practice') ||
      t.contains('workout') ||
      t.contains('regular') ||
      t.contains('schedule');
}

bool _isJuniorTrainingTitle(TeamEventsRecord e) {
  bool has(String s) {
    final t = s.toLowerCase();
    return t.contains('junior') ||
        RegExp(r'\bjr\.?\b').hasMatch(t) ||
        t.contains('jr group');
  }

  if (has(e.title)) return true;
  if (has(e.details)) return true;
  for (final g in e.appliesToGroups) {
    if (has(g)) return true;
  }
  return false;
}

bool _isSeniorTrainingTitle(TeamEventsRecord e) {
  bool has(String s) {
    final t = s.toLowerCase();
    return t.contains('senior') ||
        RegExp(r'\bsr\.?\b').hasMatch(t) ||
        t.contains('sr group');
  }

  if (has(e.title)) return true;
  if (has(e.details)) return true;
  for (final g in e.appliesToGroups) {
    if (has(g)) return true;
  }
  return false;
}

/// UI-only title normalization for schedule cards/timeline.
/// Keeps Firestore data untouched while making training naming consistent.
String scheduleEventTitleForUi(TeamEventsRecord e) {
  final raw = e.title.trim();
  if (raw.isEmpty) return raw;
  if (e.eventType != TeamEventType.training) return raw;

  final lower = raw.toLowerCase();
  if (!_titleLooksPracticeLike(lower)) return raw;

  final isJunior = _isJuniorTrainingTitle(e);
  final isSenior = _isSeniorTrainingTitle(e);
  if (isJunior && !isSenior) return 'Junior Group Practice';
  if (isSenior && !isJunior) return 'Senior Group Practice';
  return raw;
}
