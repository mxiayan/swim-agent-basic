import 'package:flutter/foundation.dart';

/// Aligns with planned `agent_feed` documents — use snake_case in Firestore.
enum AgentFeedItemType {
  actionRequired,
  todayPlan,
  scheduleChange,
  upcomingMeet,
  coachUpdate,
  missingResource,
  deadlineReminder,
  volunteerJob,
  resultUpdate,
  swimmerProgress,
}

enum AgentFeedPriority { high, medium, low }

enum AgentFeedStatus { open, done, dismissed }

/// Limits visibility by practice group when projecting meets → feed rows.
enum AgentFeedAudienceTier {
  all,
  junior,
  senior,
}

@immutable
class AgentFeedItem {
  const AgentFeedItem({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.summary,
    required this.status,
    this.actionLabel,
    this.secondaryActionLabel,
    this.targetType,
    this.targetId,
    this.swimmerId,
    this.swimmerName,
    this.groupName,
    this.eventTime,
    this.dueTime,
    required this.createdTime,
    required this.updatedTime,
    this.isReviewed = false,
    this.progressValue,
    this.progressLabel,
    this.sourceType,
    this.sourceId,
    this.avatarHintAssetPaths = const [],
    this.notes,
    this.venueLabel,
    this.coachApproved = false,
    this.signupOpen = false,
    this.audienceTier = AgentFeedAudienceTier.all,
  });

  final String id;
  final AgentFeedItemType type;
  final AgentFeedPriority priority;
  final String title;
  final String summary;
  final AgentFeedStatus status;
  final String? actionLabel;
  final String? secondaryActionLabel;

  /// Loose routing hint e.g. meet | schedule | job
  final String? targetType;
  final String? targetId;
  final String? swimmerId;
  final String? swimmerName;
  final String? groupName;
  final DateTime? eventTime;
  final DateTime? dueTime;
  final DateTime createdTime;
  final DateTime updatedTime;
  final bool isReviewed;

  /// 0–100 when shown with [progressLabel].
  final double? progressValue;
  final String? progressLabel;
  final String? sourceType;
  final String? sourceId;

  /// Optional avatar assets for brief rows (family has multiple swimmers).
  final List<String> avatarHintAssetPaths;

  /// Extra context e.g. swim plan notes.
  final String? notes;

  /// Optional venue line for practice cards (future `venue_label` field).
  final String? venueLabel;

  /// Coach pipeline tagged the linked meet (`coach_approved` on `monitored_meets`).
  final bool coachApproved;

  /// Entry or volunteer shift is open for parent signup (hourly job / email / status).
  final bool signupOpen;

  /// When not [all], rows hide for the opposite practice tier.
  final AgentFeedAudienceTier audienceTier;

  /// Deserialize from Firestore-style map (`type`, `priority`, `status` as strings).
  factory AgentFeedItem.fromFirestoreMap(Map<String, dynamic> m, String docId) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v);
      }
      return null;
    }

    String str(dynamic v, [String fallback = '']) =>
        v == null ? fallback : v.toString();

    AgentFeedItemType parseType(String raw) {
      switch (raw.trim()) {
        case 'action_required':
          return AgentFeedItemType.actionRequired;
        case 'today_plan':
          return AgentFeedItemType.todayPlan;
        case 'schedule_change':
          return AgentFeedItemType.scheduleChange;
        case 'upcoming_meet':
          return AgentFeedItemType.upcomingMeet;
        case 'coach_update':
          return AgentFeedItemType.coachUpdate;
        case 'missing_resource':
          return AgentFeedItemType.missingResource;
        case 'deadline_reminder':
          return AgentFeedItemType.deadlineReminder;
        case 'volunteer_job':
          return AgentFeedItemType.volunteerJob;
        case 'result_update':
          return AgentFeedItemType.resultUpdate;
        case 'swimmer_progress':
          return AgentFeedItemType.swimmerProgress;
        default:
          return AgentFeedItemType.actionRequired;
      }
    }

    AgentFeedPriority parsePriority(String raw) {
      switch (raw.trim()) {
        case 'high':
          return AgentFeedPriority.high;
        case 'low':
          return AgentFeedPriority.low;
        default:
          return AgentFeedPriority.medium;
      }
    }

    AgentFeedStatus parseStatus(String raw) {
      switch (raw.trim()) {
        case 'done':
          return AgentFeedStatus.done;
        case 'dismissed':
          return AgentFeedStatus.dismissed;
        default:
          return AgentFeedStatus.open;
      }
    }

    AgentFeedAudienceTier parseAudience(String raw) {
      switch (raw.trim()) {
        case 'junior':
          return AgentFeedAudienceTier.junior;
        case 'senior':
          return AgentFeedAudienceTier.senior;
        default:
          return AgentFeedAudienceTier.all;
      }
    }

    final id = str(m['id'], docId);
    return AgentFeedItem(
      id: id.isEmpty ? docId : id,
      type: parseType(str(m['type'], 'action_required')),
      priority: parsePriority(str(m['priority'], 'medium')),
      title: str(m['title'], 'Update'),
      summary: str(m['summary'], ''),
      status: parseStatus(str(m['status'], 'open')),
      actionLabel: m['action_label']?.toString(),
      secondaryActionLabel: m['secondary_action_label']?.toString(),
      targetType: m['target_type']?.toString(),
      targetId: m['target_id']?.toString(),
      swimmerId: m['swimmer_id']?.toString(),
      swimmerName: m['swimmer_name']?.toString(),
      groupName: m['group_name']?.toString(),
      eventTime: parseDt(m['event_time']),
      dueTime: parseDt(m['due_time']),
      createdTime: parseDt(m['created_time']) ?? DateTime.now(),
      updatedTime: parseDt(m['updated_time']) ?? DateTime.now(),
      isReviewed: m['is_reviewed'] == true,
      progressValue: (m['progress_value'] as num?)?.toDouble(),
      progressLabel: m['progress_label']?.toString(),
      sourceType: m['source_type']?.toString(),
      sourceId: m['source_id']?.toString(),
      notes: m['notes']?.toString(),
      venueLabel: m['venue_label']?.toString(),
      coachApproved:
          m['coach_approved'] == true || m['coachApproved'] == true,
      signupOpen: m['signup_open'] == true || m['signupOpen'] == true,
      audienceTier: parseAudience(str(m['audience_tier'], '')),
    );
  }

  AgentFeedItem copyWith({
    String? id,
    AgentFeedItemType? type,
    AgentFeedPriority? priority,
    String? title,
    String? summary,
    AgentFeedStatus? status,
    Object? actionLabel = _sentinel,
    Object? secondaryActionLabel = _sentinel,
    Object? targetType = _sentinel,
    Object? targetId = _sentinel,
    Object? swimmerId = _sentinel,
    Object? swimmerName = _sentinel,
    Object? groupName = _sentinel,
    Object? eventTime = _sentinel,
    Object? dueTime = _sentinel,
    DateTime? createdTime,
    DateTime? updatedTime,
    bool? isReviewed,
    Object? progressValue = _sentinel,
    Object? progressLabel = _sentinel,
    Object? sourceType = _sentinel,
    Object? sourceId = _sentinel,
    List<String>? avatarHintAssetPaths,
    Object? notes = _sentinel,
    Object? venueLabel = _sentinel,
    bool? coachApproved,
    bool? signupOpen,
    AgentFeedAudienceTier? audienceTier,
  }) {
    T? pick<T>(Object? s, T? current) {
      if (identical(s, _sentinel)) return current;
      return s as T?;
    }

    return AgentFeedItem(
      id: id ?? this.id,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      status: status ?? this.status,
      actionLabel: pick(actionLabel, this.actionLabel),
      secondaryActionLabel:
          pick(secondaryActionLabel, this.secondaryActionLabel),
      targetType: pick(targetType, this.targetType),
      targetId: pick(targetId, this.targetId),
      swimmerId: pick(swimmerId, this.swimmerId),
      swimmerName: pick(swimmerName, this.swimmerName),
      groupName: pick(groupName, this.groupName),
      eventTime: pick(eventTime, this.eventTime),
      dueTime: pick(dueTime, this.dueTime),
      createdTime: createdTime ?? this.createdTime,
      updatedTime: updatedTime ?? this.updatedTime,
      isReviewed: isReviewed ?? this.isReviewed,
      progressValue: pick(progressValue, this.progressValue),
      progressLabel: pick(progressLabel, this.progressLabel),
      sourceType: pick(sourceType, this.sourceType),
      sourceId: pick(sourceId, this.sourceId),
      avatarHintAssetPaths:
          avatarHintAssetPaths ?? this.avatarHintAssetPaths,
      notes: pick(notes, this.notes),
      venueLabel: pick(venueLabel, this.venueLabel),
      coachApproved: coachApproved ?? this.coachApproved,
      signupOpen: signupOpen ?? this.signupOpen,
      audienceTier: audienceTier ?? this.audienceTier,
    );
  }
}

const Object _sentinel = Object();

/// Parsed coach-email summary block (separate doc or aggregated read).
@immutable
class AgentCoachDigest {
  const AgentCoachDigest({
    required this.headline,
    required this.practiceChanges,
    required this.meetDeadlines,
    required this.socialEvents,
    required this.totalSignals,
  });

  final String headline;
  final int practiceChanges;
  final int meetDeadlines;
  final int socialEvents;
  final int totalSignals;
}

/// Smart stat strip counts derived from [AgentFeedItem] list + calendar hints.
@immutable
class AgentSmartStats {
  const AgentSmartStats({
    required this.needsAction,
    required this.today,
    required this.newUpdates,
  });

  final int needsAction;
  final int today;
  final int newUpdates;
}
