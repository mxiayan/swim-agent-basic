import 'package:intl/intl.dart';

import '/backend/schema/meet_preferences_record.dart';
import '/backend/schema/monitored_meets_record.dart';

/// Deadline and signup helpers shared with [M02MeetEnteredWidget] card logic.
abstract final class MeetListQuickFilter {
  MeetListQuickFilter._();

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _isMeetLive(MonitoredMeetsRecord m) {
    final today = _dayOnly(DateTime.now());
    final s = m.startTime;
    final e = m.endTime ?? m.startTime;
    if (s == null && e == null) {
      return false;
    }
    final sd = s != null ? _dayOnly(s) : _dayOnly(e!);
    final ed = e != null ? _dayOnly(e) : sd;
    return !sd.isAfter(today) && !ed.isBefore(today);
  }

  static DateTime? entryDeadline(MonitoredMeetsRecord m) {
    final end = m.endTime ?? m.startTime;
    if (end != null) {
      return _dayOnly(end).subtract(const Duration(days: 7));
    }
    final blob = m.apiNotes.isNotEmpty ? m.apiNotes : m.description;
    return _parseDeadlineFromNotes(blob);
  }

  static DateTime? _parseDeadlineFromNotes(String text) {
    if (text.trim().isEmpty) {
      return null;
    }
    final re = RegExp(
      r'(Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday),?\s+'
      r'([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})',
      caseSensitive: false,
    );
    final m = re.firstMatch(text);
    if (m == null) {
      return null;
    }
    try {
      final s = '${m.group(1)}, ${m.group(2)} ${m.group(3)}, ${m.group(4)}';
      return DateFormat('EEEE, MMMM d, y').parse(s);
    } catch (_) {
      return null;
    }
  }

  static DateTime? entryDeadlineEnd(MonitoredMeetsRecord m) {
    final d = entryDeadline(m);
    if (d == null) {
      return null;
    }
    return DateTime(d.year, d.month, d.day, 23, 59, 59);
  }

  static bool _entryDeadlineHasPassed(MonitoredMeetsRecord m) {
    final end = entryDeadlineEnd(m);
    if (end == null) {
      return false;
    }
    return DateTime.now().isAfter(end);
  }

  static bool _meetSignupsClosedByStatus(MonitoredMeetsRecord m) {
    final s = m.status.trim().toLowerCase();
    if (s.isEmpty) {
      return false;
    }
    return s.contains('closed') ||
        s.contains('cancel') ||
        s.contains('canceled');
  }

  static bool signupsClosedContext(MonitoredMeetsRecord m) {
    return _isMeetLive(m) ||
        _meetSignupsClosedByStatus(m) ||
        _entryDeadlineHasPassed(m);
  }

  static bool _isPreferenceEntered(MeetPreferencesRecord? pref) {
    return pref != null && pref.status == MeetPreferenceStatus.entered;
  }

  /// Same as the tune-menu “Not Going” bucket.
  static bool isNotGoingCategory(MeetPreferencesRecord? pref) {
    if (pref == null) {
      return false;
    }
    return pref.skipSelected && pref.status == MeetPreferenceStatus.skipped;
  }

  /// Same as the tune-menu “Pending entries” bucket.
  static bool isPendingEntriesCategory(MeetPreferencesRecord? pref) {
    if (pref == null) {
      return false;
    }
    final status = pref.status;
    final hasAlert = pref.hasAlert;
    return status == MeetPreferenceStatus.planning ||
        (status == MeetPreferenceStatus.interested && !hasAlert);
  }

  /// Registration still actionable and swimmer is in a pending / planning state.
  static bool meetNeedsAction(
    MonitoredMeetsRecord m,
    MeetPreferencesRecord? pref,
  ) {
    if (signupsClosedContext(m)) {
      return false;
    }
    if (_isPreferenceEntered(pref)) {
      return false;
    }
    return isPendingEntriesCategory(pref);
  }

  /// Entry deadline (end of deadline day) falls Mon–Sun this week, local time.
  static bool entryDeadlineThisCalendarWeek(
    MonitoredMeetsRecord m,
    MeetPreferencesRecord? pref,
  ) {
    if (_isPreferenceEntered(pref)) {
      return false;
    }
    if (isNotGoingCategory(pref)) {
      return false;
    }
    if (signupsClosedContext(m)) {
      return false;
    }
    final end = entryDeadlineEnd(m);
    if (end == null) {
      return false;
    }
    final now = DateTime.now();
    if (now.isAfter(end)) {
      return false;
    }
    final today = _dayOnly(now);
    final weekStart =
        today.subtract(Duration(days: today.weekday - DateTime.monday));
    final weekEndDay = weekStart.add(const Duration(days: 6));
    final deadlineDay = _dayOnly(end);
    return !deadlineDay.isBefore(weekStart) && !deadlineDay.isAfter(weekEndDay);
  }
}
