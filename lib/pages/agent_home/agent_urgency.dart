import 'agent_feed_item.dart';
import 'agent_feed_logic.dart';
import 'agent_priority_engine.dart';

/// UX urgency for Agent metrics, badges, and pulse (deadline + inferred signals).
enum AgentUrgencyLevel {
  none,
  normal,
  dueSoon,
  urgent,
  critical;

  /// Higher index == more severe for ordering.
  static AgentUrgencyLevel maxOf(AgentUrgencyLevel a, AgentUrgencyLevel b) =>
      a.index >= b.index ? a : b;

  bool get showsPulse =>
      this == AgentUrgencyLevel.urgent || this == AgentUrgencyLevel.critical;

  bool get showsUrgentBadge =>
      this == AgentUrgencyLevel.dueSoon ||
      this == AgentUrgencyLevel.urgent ||
      this == AgentUrgencyLevel.critical;
}

/// Maps a future deadline to an urgency band (also used when deadline passed).
AgentUrgencyLevel agentUrgencyFromDeadline(DateTime deadline, DateTime now) {
  if (!deadline.isAfter(now)) {
    return AgentUrgencyLevel.critical;
  }
  final d = deadline.difference(now);
  if (d <= const Duration(hours: 24)) return AgentUrgencyLevel.critical;
  if (d <= const Duration(hours: 48)) return AgentUrgencyLevel.urgent;
  if (d <= const Duration(days: 7)) return AgentUrgencyLevel.dueSoon;
  return AgentUrgencyLevel.normal;
}

/// Derives urgency from [AgentFeedItem] using deadline first, then lightweight inference.
AgentUrgencyLevel agentUrgencyForFeedItem(AgentFeedItem item, DateTime now) {
  if (item.status != AgentFeedStatus.open) {
    return AgentUrgencyLevel.none;
  }

  final due = item.dueTime;
  if (due != null) {
    return agentUrgencyFromDeadline(due, now);
  }

  final ev = item.eventTime;
  switch (item.type) {
    case AgentFeedItemType.upcomingMeet:
      if (AgentPriorityEngine.coachApprovedMeetSignupIsUrgent(item)) {
        return ev != null
            ? agentUrgencyFromDeadline(ev, now)
            : AgentUrgencyLevel.urgent;
      }
      if (ev != null) {
        return agentUrgencyFromDeadline(ev, now);
      }
      return AgentUrgencyLevel.normal;

    case AgentFeedItemType.volunteerJob:
      if (AgentPriorityEngine.volunteerJobIsSignupUrgent(item)) {
        return ev != null
            ? agentUrgencyFromDeadline(ev, now)
            : AgentUrgencyLevel.dueSoon;
      }
      if (ev != null) return agentUrgencyFromDeadline(ev, now);
      return AgentUrgencyLevel.normal;

    case AgentFeedItemType.deadlineReminder:
    case AgentFeedItemType.actionRequired:
      return AgentUrgencyLevel.normal;

    case AgentFeedItemType.coachUpdate:
    case AgentFeedItemType.scheduleChange:
      return AgentUrgencyLevel.normal;

    default:
      return AgentUrgencyLevel.normal;
  }
}

/// Strongest urgency among items that count toward “Needs action”.
AgentUrgencyLevel maxNeedsActionUrgency(
  List<AgentFeedItem> items,
  DateTime now,
) {
  var max = AgentUrgencyLevel.none;
  for (final i in items) {
    if (!AgentFeedLogic.countsTowardNeedsAction(i)) continue;
    max = AgentUrgencyLevel.maxOf(max, agentUrgencyForFeedItem(i, now));
  }
  return max;
}
