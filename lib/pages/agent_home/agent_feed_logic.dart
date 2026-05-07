import 'package:flutter/material.dart';

import 'agent_feed_item.dart';
import 'agent_priority_engine.dart';

abstract final class AgentFeedLogic {
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isSameCalendarDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return _day(a) == _day(b);
  }

  static int _priorityRank(AgentFeedPriority p) {
    switch (p) {
      case AgentFeedPriority.high:
        return 0;
      case AgentFeedPriority.medium:
        return 1;
      case AgentFeedPriority.low:
        return 2;
    }
  }

  /// Rule engine band (when [now] set) → stored priority → due/event → created.
  static int compareFeedItems(
    AgentFeedItem a,
    AgentFeedItem b, {
    DateTime? now,
  }) {
    if (now != null) {
      final ba = AgentPriorityEngine.urgencyBand(a, now);
      final bb = AgentPriorityEngine.urgencyBand(b, now);
      if (ba != bb) return ba.compareTo(bb);
    } else {
      final pr = _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
      if (pr != 0) return pr;
    }

    final pr = _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
    if (pr != 0) return pr;

    final aTime = a.dueTime ?? a.eventTime;
    final bTime = b.dueTime ?? b.eventTime;
    if (aTime != null && bTime != null) {
      final c = aTime.compareTo(bTime);
      if (c != 0) return c;
    } else if (aTime != null) {
      return -1;
    } else if (bTime != null) {
      return 1;
    }

    return b.createdTime.compareTo(a.createdTime);
  }

  static bool countsTowardNeedsAction(AgentFeedItem i) {
    if (i.status != AgentFeedStatus.open) return false;
    if (AgentPriorityEngine.coachApprovedMeetSignupIsUrgent(i)) return true;
    if (AgentPriorityEngine.coachApprovedUpcomingMeet(i)) return true;
    if (AgentPriorityEngine.volunteerJobIsSignupUrgent(i)) return true;
    switch (i.type) {
      case AgentFeedItemType.actionRequired:
      case AgentFeedItemType.deadlineReminder:
      case AgentFeedItemType.missingResource:
      case AgentFeedItemType.volunteerJob:
        return true;
      default:
        return false;
    }
  }

  static bool countsTowardToday(AgentFeedItem i, DateTime now) {
    if (i.status != AgentFeedStatus.open) return false;
    if (i.type == AgentFeedItemType.todayPlan &&
        isSameCalendarDay(i.eventTime, now)) {
      return true;
    }
    if (i.eventTime != null && isSameCalendarDay(i.eventTime, now)) {
      switch (i.type) {
        case AgentFeedItemType.upcomingMeet:
        case AgentFeedItemType.volunteerJob:
          return true;
        default:
          return false;
      }
    }
    return false;
  }

  static bool countsTowardNewUpdates(AgentFeedItem i) {
    if (i.status != AgentFeedStatus.open) return false;
    if (i.isReviewed) return false;
    switch (i.type) {
      case AgentFeedItemType.coachUpdate:
      case AgentFeedItemType.scheduleChange:
      case AgentFeedItemType.resultUpdate:
        return true;
      default:
        return false;
    }
  }

  static AgentSmartStats computeSmartStats(List<AgentFeedItem> items, DateTime now) {
    var na = 0;
    var td = 0;
    var nu = 0;
    for (final i in items) {
      if (countsTowardNeedsAction(i)) na++;
      if (countsTowardToday(i, now)) td++;
      if (countsTowardNewUpdates(i)) nu++;
    }
    return AgentSmartStats(needsAction: na, today: td, newUpdates: nu);
  }

  /// Builds digest counts from live Agent rows (today: monitored meets → feed items).
  static AgentCoachDigest digestFromFeedItems(
    List<AgentFeedItem> items,
    DateTime now,
  ) {
    final open =
        items.where((i) => i.status == AgentFeedStatus.open).toList();
    final practiceChanges = open
        .where((i) => i.type == AgentFeedItemType.scheduleChange)
        .length;
    final meetDeadlines = open.where((i) {
      if (i.type != AgentFeedItemType.upcomingMeet) return false;
      return i.signupOpen || i.coachApproved;
    }).length;
    final socialEvents =
        open.where((i) => i.type == AgentFeedItemType.coachUpdate).length;
    final total = practiceChanges + meetDeadlines + socialEvents;
    final headline = total == 0
        ? ''
        : '$total tracked signal${total == 1 ? '' : 's'} from your monitored meets';
    return AgentCoachDigest(
      headline: headline.isEmpty ? 'Monitored meets overview' : headline,
      practiceChanges: practiceChanges,
      meetDeadlines: meetDeadlines,
      socialEvents: socialEvents,
      totalSignals: total,
    );
  }

  /// Picks highest-importance open item for featured strip (signup-first rules).
  static AgentFeedItem? pickNextBestAction(
    List<AgentFeedItem> items,
    DateTime now,
  ) {
    final open =
        items.where((i) => i.status == AgentFeedStatus.open).toList();
    if (open.isEmpty) return null;

    final ranked = open
        .where((i) => AgentPriorityEngine.nextBestHeroRank(i, now) < 99)
        .toList();
    final pool = ranked.isEmpty ? open : ranked;

    pool.sort((a, b) {
      final ta = AgentPriorityEngine.nextBestHeroRank(a, now);
      final tb = AgentPriorityEngine.nextBestHeroRank(b, now);
      if (ta != tb) return ta.compareTo(tb);
      return compareFeedItems(a, b, now: now);
    });

    return pool.first;
  }

  /// Next calendar deadline-style signal for Agent insights (meet entries, reminders).
  static AgentFeedItem? pickNextDeadlineHighlight(
    List<AgentFeedItem> items,
    DateTime now,
  ) {
    bool deadlineLike(AgentFeedItem i) {
      if (i.status != AgentFeedStatus.open) return false;
      if (i.dueTime == null) return false;
      switch (i.type) {
        case AgentFeedItemType.deadlineReminder:
        case AgentFeedItemType.upcomingMeet:
        case AgentFeedItemType.actionRequired:
          return true;
        default:
          return false;
      }
    }

    final pool = items.where(deadlineLike).toList();
    if (pool.isEmpty) return null;
    pool.sort((a, b) {
      final ad = a.dueTime!;
      final bd = b.dueTime!;
      final c = ad.compareTo(bd);
      if (c != 0) return c;
      return compareFeedItems(a, b, now: now);
    });
    return pool.first;
  }

  static AgentFeedItem? pickLatestCoachUpdate(List<AgentFeedItem> items) {
    final u = items
        .where(
          (i) =>
              i.status == AgentFeedStatus.open &&
              i.type == AgentFeedItemType.coachUpdate,
        )
        .toList();
    if (u.isEmpty) return null;
    u.sort((a, b) => b.updatedTime.compareTo(a.updatedTime));
    return u.first;
  }

  static AgentFeedItem? pickTodaySwimPlan(List<AgentFeedItem> items, DateTime now) {
    final fromTraining = items.where((i) {
      if (i.status != AgentFeedStatus.open) return false;
      if (i.type != AgentFeedItemType.todayPlan) return false;
      return isSameCalendarDay(i.eventTime, now);
    }).toList();
    if (fromTraining.isNotEmpty) {
      fromTraining.sort((a, b) => compareFeedItems(a, b, now: now));
      return fromTraining.first;
    }

    final meetsToday = items.where((i) {
      if (i.status != AgentFeedStatus.open) return false;
      if (i.type != AgentFeedItemType.upcomingMeet) return false;
      return isSameCalendarDay(i.eventTime, now);
    }).toList();
    if (meetsToday.isEmpty) return null;
    meetsToday.sort((a, b) => compareFeedItems(a, b, now: now));
    return meetsToday.first;
  }

  /// Brief feed: open items, minus featured hero & inline swim plan.
  static List<AgentFeedItem> agentBriefItems(
    List<AgentFeedItem> all,
    AgentFeedItem? nextBest,
    AgentFeedItem? todayPlan,
    DateTime now,
  ) {
    final skip = <String>{
      if (nextBest != null) nextBest.id,
      if (todayPlan != null) todayPlan.id,
    };
    final open = all.where((i) {
      if (skip.contains(i.id)) return false;
      if (i.status != AgentFeedStatus.open) return false;
      return true;
    }).toList();
    open.sort((a, b) => compareFeedItems(a, b, now: now));
    return open;
  }

  static String typeShortLabel(AgentFeedItemType t) {
    switch (t) {
      case AgentFeedItemType.actionRequired:
        return 'Action required';
      case AgentFeedItemType.todayPlan:
        return 'Today’s plan';
      case AgentFeedItemType.scheduleChange:
        return 'Schedule change';
      case AgentFeedItemType.upcomingMeet:
        return 'Upcoming meet';
      case AgentFeedItemType.coachUpdate:
        return 'Coach update';
      case AgentFeedItemType.missingResource:
        return 'Missing resource';
      case AgentFeedItemType.deadlineReminder:
        return 'Deadline';
      case AgentFeedItemType.volunteerJob:
        return 'Volunteer job';
      case AgentFeedItemType.resultUpdate:
        return 'Results';
      case AgentFeedItemType.swimmerProgress:
        return 'Swimmer progress';
    }
  }

  static String priorityChipLabel(AgentFeedPriority p) {
    switch (p) {
      case AgentFeedPriority.high:
        return 'High';
      case AgentFeedPriority.medium:
        return 'Medium';
      case AgentFeedPriority.low:
        return 'Low';
    }
  }

  /// Accent chip pairing aligned with Agent palette (lavender / teal / slate).
  static ({Color accent, Color pillBg}) priorityChipColors(
    AgentFeedPriority p,
    Color highTint,
    Color mediumTint,
    Color lowTint,
  ) {
    switch (p) {
      case AgentFeedPriority.high:
        return (accent: highTint, pillBg: highTint.withValues(alpha: 0.14));
      case AgentFeedPriority.medium:
        return (accent: mediumTint, pillBg: mediumTint.withValues(alpha: 0.14));
      case AgentFeedPriority.low:
        return (accent: lowTint, pillBg: lowTint.withValues(alpha: 0.14));
    }
  }
}
