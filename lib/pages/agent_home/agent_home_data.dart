import 'package:flutter/foundation.dart';

/// Replace mock sections with Firestore-backed lists later.
enum AgentBriefingPriority {
  /// Critical / urgent — coral-red emphasis
  urgent,

  /// Deadline soon — amber
  deadlineSoon,

  /// Informational — blue
  informational,

  /// AI-style insight — purple
  aiInsight,
}

/// Where a tap should route when wired to real navigation.
enum AgentNavTargetType {
  meet,
  job,
  schedule,
  swimmer,
  deadline,
  announcement,

  /// Practice / pool calendar context
  practice,
  unknown,
}

@immutable
class AgentBriefingItem {
  const AgentBriefingItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.priority,
    required this.ctaLabel,
    required this.targetType,
    this.targetId,
  });

  final String id;
  final String title;
  final String summary;
  final AgentBriefingPriority priority;
  final String ctaLabel;
  final AgentNavTargetType targetType;
  final String? targetId;
}

enum AgentTimelineKind {
  practice,
  deadline,
  meet,
  announcement,
  other,
}

@immutable
class AgentTimelineItem {
  const AgentTimelineItem({
    required this.id,
    required this.dateLabel,
    required this.title,
    required this.summary,
    required this.type,
    this.targetId,
  });

  final String id;
  final String dateLabel;
  final String title;
  final String summary;
  final AgentTimelineKind type;
  final String? targetId;
}

enum AgentInsightSeverity {
  watch,
  headsUp,
  tip,
}

@immutable
class AgentInsightItem {
  const AgentInsightItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.severity,
    required this.sourceType,
  });

  final String id;
  final String title;
  final String summary;
  final AgentInsightSeverity severity;
  final String sourceType;
}

@immutable
class AgentRecentUpdateItem {
  const AgentRecentUpdateItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.detectedAt,
    required this.targetType,
    this.targetId,
  });

  final String id;
  final String title;
  final String summary;
  final String source;
  final String detectedAt;
  final AgentNavTargetType targetType;
  final String? targetId;
}

/// Mock dataset for UI review — swap with Firestore queries later.
abstract final class AgentHomeMockData {
  static List<AgentBriefingItem> briefingItems() => const [
        AgentBriefingItem(
          id: 'b1',
          title: 'Meet entry deadline tomorrow',
          summary: 'Age Group Championships entries close Apr 28.',
          priority: AgentBriefingPriority.deadlineSoon,
          ctaLabel: 'Review Entries',
          targetType: AgentNavTargetType.deadline,
          targetId: 'agc-2026',
        ),
        AgentBriefingItem(
          id: 'b2',
          title: 'Volunteer job not selected',
          summary:
              'You are entered in Saturday’s meet, but no job is assigned.',
          priority: AgentBriefingPriority.urgent,
          ctaLabel: 'Choose Job',
          targetType: AgentNavTargetType.job,
          targetId: 'sat-meet-job',
        ),
      ];

  static List<AgentTimelineItem> timelineItems() => const [
        AgentTimelineItem(
          id: 't1',
          dateLabel: 'Today',
          title: 'Practice',
          summary: '5:30 PM to 7:00 PM',
          type: AgentTimelineKind.practice,
        ),
        AgentTimelineItem(
          id: 't2',
          dateLabel: 'Tomorrow',
          title: 'Meet entry deadline',
          summary: 'Age Group Champs — don’t miss the cut-off.',
          type: AgentTimelineKind.deadline,
          targetId: 'agc-2026',
        ),
        AgentTimelineItem(
          id: 't3',
          dateLabel: 'Saturday',
          title: 'Brentwood Seawolves Meet',
          summary: '3 events entered',
          type: AgentTimelineKind.meet,
          targetId: 'brentwood-2026',
        ),
        AgentTimelineItem(
          id: 't4',
          dateLabel: 'Next week',
          title: 'Team picture day',
          summary: 'Bring team suit and smile.',
          type: AgentTimelineKind.announcement,
        ),
      ];

  static List<AgentInsightItem> insights() => const [
        AgentInsightItem(
          id: 'i1',
          title: 'Heat sheet isn’t posted yet',
          summary:
              'You entered the meet, but the heat sheet is not available yet. I’ll keep watching for it.',
          severity: AgentInsightSeverity.watch,
          sourceType: 'meet status',
        ),
        AgentInsightItem(
          id: 'i2',
          title: 'Parking may be tight',
          summary:
              'The meet sheet mentions parking may be limited — you may want to arrive ~20 minutes earlier.',
          severity: AgentInsightSeverity.headsUp,
          sourceType: 'meet sheet',
        ),
        AgentInsightItem(
          id: 'i3',
          title: 'Saturday session timing',
          summary:
              'Your swimmer has 3 events; the first is likely early in the session.',
          severity: AgentInsightSeverity.tip,
          sourceType: 'entry review',
        ),
      ];

  static List<AgentRecentUpdateItem> recentUpdates() => const [
        AgentRecentUpdateItem(
          id: 'r1',
          title: 'Practice time changed',
          summary: 'Senior group practice moved to 4:30 PM this Friday.',
          source: 'coach email',
          detectedAt: '2 hours ago',
          targetType: AgentNavTargetType.schedule,
        ),
        AgentRecentUpdateItem(
          id: 'r2',
          title: 'New meet resource added',
          summary: 'Psych sheet is now available for Brentwood Seawolves Meet.',
          source: 'meet resources',
          detectedAt: 'Yesterday',
          targetType: AgentNavTargetType.meet,
          targetId: 'brentwood-2026',
        ),
        AgentRecentUpdateItem(
          id: 'r3',
          title: 'Coach announcement',
          summary: 'Team photo order form due this week.',
          source: 'weekly email',
          detectedAt: 'Yesterday',
          targetType: AgentNavTargetType.announcement,
        ),
      ];
}
