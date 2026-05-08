import '/backend/schema/meet_preferences_record.dart';
import '/backend/schema/monitored_meets_record.dart';
import '/components/m02_meet/meet_list_quick_filter.dart';

/// Aggregated counts for the Meets overview card (Option B).
class MeetOverviewCounts {
  const MeetOverviewCounts({
    required this.entered,
    required this.pending,
    required this.notEntered,
    required this.toReview,
  });

  final int entered;
  final int pending;
  final int notEntered;
  final int toReview;
}

bool _isUpcomingMeet(MonitoredMeetsRecord m, DateTime midnight) {
  final meetEnd = m.endDate ?? m.startDate;
  if (meetEnd == null) {
    return true;
  }
  return !meetEnd.isBefore(midnight);
}

/// Computes overview buckets from the same filtered meet list used by the tab.
MeetOverviewCounts computeMeetOverviewCounts({
  required List<MonitoredMeetsRecord> meets,
  required Map<String, MeetPreferencesRecord> prefs,
}) {
  final today = DateTime.now();
  final midnight = DateTime(today.year, today.month, today.day);

  var entered = 0;
  var pending = 0;
  var notEntered = 0;
  var toReview = 0;

  for (final m in meets) {
    if (!_isUpcomingMeet(m, midnight)) {
      continue;
    }
    final p = prefs[m.reference.id];
    final status = p?.status ?? MeetPreferenceStatus.newStatus;

    if (MeetListQuickFilter.isNotGoingCategory(p)) {
      notEntered++;
      continue;
    }
    if (status == MeetPreferenceStatus.entered || m.coachApproved) {
      entered++;
      continue;
    }
    if (p == null || status == MeetPreferenceStatus.newStatus) {
      toReview++;
      continue;
    }
    if (status == MeetPreferenceStatus.needEntry ||
        MeetListQuickFilter.meetNeedsAction(m, p)) {
      pending++;
      continue;
    }
    toReview++;
  }

  return MeetOverviewCounts(
    entered: entered,
    pending: pending,
    notEntered: notEntered,
    toReview: toReview,
  );
}
