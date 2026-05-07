import '/app_state.dart';
import '/backend/schema/monitored_meets_record.dart';

import 'agent_feed_item.dart';

/// Practice-group tier used to filter meets (junior vs senior squads).
enum SwimTrainingTier {
  junior,
  senior,
  unknown,
}

/// Rule-based urgency for Agent feed + monitored meets (Firestore-ready).
///
/// Signups that need a parent action rank highest; coach-approved meets that
/// just opened for entry rank with volunteer openings from coach email.
abstract final class AgentPriorityEngine {
  AgentPriorityEngine._();

  static SwimTrainingTier tierFromSwimmerGroup(String? groupLabel) {
    final g = groupLabel?.trim().toLowerCase() ?? '';
    if (g.isEmpty) return SwimTrainingTier.unknown;
    if (g.contains('senior')) return SwimTrainingTier.senior;
    if (g.contains('junior') ||
        g.contains('age group') ||
        g.contains('age-group')) {
      return SwimTrainingTier.junior;
    }
    return SwimTrainingTier.unknown;
  }

  /// Uses [FFAppState.swimmerPracticeTierLabel] when set; otherwise club/group text.
  static SwimTrainingTier trainingTierForApp(FFAppState app) {
    final hint = app.swimmerPracticeTierLabel.trim();
    if (hint.isNotEmpty) {
      return tierFromSwimmerGroup(hint);
    }
    return tierFromSwimmerGroup(app.currentSwimmerGroup);
  }

  static bool _classContains(MonitoredMeetsRecord meet, String token) {
    final t = token.trim().toLowerCase();
    if (t.isEmpty) return false;
    for (final raw in meet.meetClasses) {
      final c = raw.trim().toLowerCase();
      if (c.isEmpty) continue;
      if (c == t || c.contains(t)) return true;
    }
    return false;
  }

  /// Mirrors Meets tab semantics: junior swimmers ignore senior-only meets and vice versa.
  ///
  /// Unknown tier keeps every meet that passes the loose “has classification” bar so the
  /// UI stays populated until `SwimmersRecord.group` is populated.
  static bool monitoredMeetMatchesTrainingTier(
    MonitoredMeetsRecord meet,
    SwimTrainingTier tier,
  ) {
    if (tier == SwimTrainingTier.unknown) return true;
    if (meet.meetClasses.isEmpty) return false;

    final seniorish = _classContains(meet, 'senior');
    final juniorish = _classContains(meet, 'age group') ||
        _classContains(meet, 'junior') ||
        _classContains(meet, '10-under') ||
        _classContains(meet, '10 & under');

    switch (tier) {
      case SwimTrainingTier.junior:
        return !(seniorish && !juniorish);
      case SwimTrainingTier.senior:
        return !(juniorish && !seniorish);
      case SwimTrainingTier.unknown:
        return true;
    }
  }

  /// Same logic as Cloud Function `signupIsOpen` — entry flow is live for parents.
  static bool monitoredMeetSignupIsOpen(MonitoredMeetsRecord meet) {
    final status = meet.status.trim().toLowerCase();
    if (status == 'pending') return false;
    return meet.hasEntryPage;
  }

  static bool feedItemVisibleForAudience(
    AgentFeedItem item,
    SwimTrainingTier swimmerTier,
  ) {
    switch (item.audienceTier) {
      case AgentFeedAudienceTier.all:
        return true;
      case AgentFeedAudienceTier.junior:
        return swimmerTier != SwimTrainingTier.senior;
      case AgentFeedAudienceTier.senior:
        return swimmerTier != SwimTrainingTier.junior;
    }
  }

  static bool volunteerJobIsSignupUrgent(AgentFeedItem item) {
    if (item.type != AgentFeedItemType.volunteerJob) return false;
    if (item.signupOpen) return true;
    final src = item.sourceType?.trim().toLowerCase() ?? '';
    return src == 'coach_email';
  }

  static bool coachApprovedMeetSignupIsUrgent(AgentFeedItem item) {
    return item.type == AgentFeedItemType.upcomingMeet &&
        item.coachApproved &&
        item.signupOpen;
  }

  static bool coachApprovedUpcomingMeet(AgentFeedItem item) {
    return item.type == AgentFeedItemType.upcomingMeet && item.coachApproved;
  }

  /// Meet listing tier → feed audience (mirrors Meets tab classification).
  static AgentFeedAudienceTier audienceTierFromMonitoredMeet(
    MonitoredMeetsRecord meet,
  ) {
    final seniorish = _classContains(meet, 'senior');
    final juniorish = _classContains(meet, 'age group') ||
        _classContains(meet, 'junior') ||
        _classContains(meet, '10-under') ||
        _classContains(meet, '10 & under');
    if (seniorish && !juniorish) {
      return AgentFeedAudienceTier.senior;
    }
    if (juniorish && !seniorish) {
      return AgentFeedAudienceTier.junior;
    }
    return AgentFeedAudienceTier.all;
  }

  static bool _deadlineSoon(AgentFeedItem item, DateTime now,
      {required Duration within}) {
    final raw = item.dueTime ?? item.eventTime;
    if (raw == null) return false;
    return !raw.isBefore(now) && raw.difference(now) <= within;
  }

  /// Lower band = sort earlier / more important.
  static int urgencyBand(AgentFeedItem item, DateTime now) {
    if (item.status != AgentFeedStatus.open) return 90;
    if (item.type == AgentFeedItemType.todayPlan) {
      return 45;
    }

    if (volunteerJobIsSignupUrgent(item) || coachApprovedMeetSignupIsUrgent(item)) {
      return 0;
    }

    if (coachApprovedUpcomingMeet(item)) {
      if (_deadlineSoon(item, now, within: const Duration(hours: 72))) {
        return 1;
      }
      return 2;
    }

    switch (item.type) {
      case AgentFeedItemType.actionRequired:
      case AgentFeedItemType.deadlineReminder:
        return 3;
      case AgentFeedItemType.scheduleChange:
      case AgentFeedItemType.missingResource:
        return 4;
      case AgentFeedItemType.volunteerJob:
        return 5;
      case AgentFeedItemType.upcomingMeet:
        return 7;
      case AgentFeedItemType.coachUpdate:
      case AgentFeedItemType.resultUpdate:
        return 8;
      case AgentFeedItemType.todayPlan:
        return 45;
      case AgentFeedItemType.swimmerProgress:
        return 9;
    }
  }

  /// Drives priority chips after rules (Firestore `priority` can still be a fallback signal).
  static AgentFeedPriority deriveChipPriority(AgentFeedItem item, DateTime now) {
    final b = urgencyBand(item, now);
    if (b <= 1) return AgentFeedPriority.high;
    if (coachApprovedUpcomingMeet(item) && item.status == AgentFeedStatus.open) {
      return AgentFeedPriority.high;
    }
    if (b <= 5) return AgentFeedPriority.medium;
    return AgentFeedPriority.low;
  }

  static AgentFeedItem withDerivedUiPriority(AgentFeedItem item, DateTime now) {
    return item.copyWith(priority: deriveChipPriority(item, now));
  }

  /// Featured “Next Best Action” ranking — lower is sooner in hero strip.
  static int nextBestHeroRank(AgentFeedItem item, DateTime now) {
    if (item.status != AgentFeedStatus.open) return 999;
    if (volunteerJobIsSignupUrgent(item)) return 0;
    if (coachApprovedMeetSignupIsUrgent(item)) return 0;
    if (coachApprovedUpcomingMeet(item)) return 1;
    switch (item.type) {
      case AgentFeedItemType.actionRequired:
        return 2;
      case AgentFeedItemType.deadlineReminder:
        return 3;
      case AgentFeedItemType.scheduleChange:
        return 4;
      case AgentFeedItemType.missingResource:
        return 5;
      case AgentFeedItemType.todayPlan:
        return 6;
      default:
        return 99;
    }
  }

  /// Builds [`AgentFeedItem`] rows from `monitored_meets` + swimmer display prefs.
  static AgentFeedItem feedStubFromMonitoredMeet({
    required MonitoredMeetsRecord meet,
    required String feedDocId,
    String? summaryFallback,
    String? swimmerDisplayFirstName,
  }) {
    final signupOpen = monitoredMeetSignupIsOpen(meet);
    final start = meet.startTime;
    final venue =
        meet.subtitle.trim().isNotEmpty ? meet.subtitle.trim() : null;

    String summaryText() {
      final fb = summaryFallback?.trim() ?? '';
      if (fb.isNotEmpty) return fb;
      final desc = meet.description.trim();
      if (desc.isNotEmpty) return desc;
      final notes = meet.apiNotes.trim();
      if (notes.isNotEmpty) return notes;

      final parts = <String>[];
      if (meet.coachApproved) parts.add('Coach approved');
      if (signupOpen) {
        parts.add('Entries open');
      } else if (meet.hasEntryPage) {
        parts.add('Entry link on file');
      }
      final hz = meet.hostGroup.trim();
      if (hz.isNotEmpty) parts.add('Host $hz');
      final zone = meet.meetZone.trim();
      if (zone.isNotEmpty) parts.add(zone);
      if (parts.isEmpty) {
        return 'Monitored Pacific meet on your calendar.';
      }
      return parts.join(' · ');
    }

    return AgentFeedItem(
      id: feedDocId,
      type: AgentFeedItemType.upcomingMeet,
      priority: AgentFeedPriority.medium,
      title: meet.title.trim().isEmpty ? meet.name : meet.title,
      summary: summaryText(),
      status: AgentFeedStatus.open,
      actionLabel: signupOpen ? 'Review entry' : 'View meet',
      targetType: 'meet',
      targetId: meet.reference.id,
      eventTime: start,
      dueTime: signupOpen ? start : null,
      createdTime: DateTime.now(),
      updatedTime: DateTime.now(),
      swimmerName: swimmerDisplayFirstName?.trim().isNotEmpty == true
          ? swimmerDisplayFirstName!.trim()
          : null,
      groupName: meet.hostGroup.trim().isNotEmpty ? meet.hostGroup : 'Meet',
      venueLabel: venue,
      coachApproved: meet.coachApproved,
      signupOpen: signupOpen,
      sourceType: 'monitored_meets',
      sourceId: meet.reference.id,
      audienceTier: audienceTierFromMonitoredMeet(meet),
    );
  }
}
