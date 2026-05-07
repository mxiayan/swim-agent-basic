import '/backend/schema/team_events_record.dart';
import '/backend/team_events_list_logic.dart';

import 'agent_home_data.dart';

/// Maps normalized `team_events` rows → Agent dashboard counts + recent cards.
abstract final class AgentScheduleProjection {
  static const int upcomingHorizonDays = 60;
  static const int recentCap = 10;

  static DateTime _todayDay() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime? _eventDay(TeamEventsRecord e) {
    final ps = e.parsedStart;
    if (ps != null) {
      return DateTime(ps.year, ps.month, ps.day);
    }
    return null;
  }

  /// Mirrors `_formatTimeLine` in team schedule UI (12h labels).
  static String formatTimeRange(TeamEventsRecord e) {
    String fmt(String hhmm) {
      final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm);
      if (m == null) return hhmm;
      var h = int.parse(m.group(1)!);
      final mins = m.group(2)!;
      final am = h < 12;
      var hh12 = h % 12;
      if (hh12 == 0) hh12 = 12;
      final suffix = am ? ' am' : ' pm';
      return mins == '00'
          ? '$hh12$suffix'
          : '$hh12:$mins$suffix';
    }

    final start = e.startTimeLocal.isNotEmpty ? fmt(e.startTimeLocal) : '';
    final end = e.endTimeLocal.isNotEmpty ? fmt(e.endTimeLocal) : '';
    if (start.isEmpty && end.isEmpty) {
      return 'All day';
    }
    if (end.isEmpty) {
      return start;
    }
    return '$start – $end';
  }

  static String _daysLeftLabel(DateTime eventDay, DateTime today) {
    final d = eventDay.difference(today).inDays;
    if (d < 0) return 'Past';
    if (d == 0) return 'Today';
    if (d == 1) return 'Tomorrow';
    return '$d Days Left';
  }

  /// Decorative progress for donut — nearer dates read “more complete”.
  static int pseudoProgressPercent(int daysUntil) {
    if (daysUntil <= 0) return 72;
    return (100 - (daysUntil * 9)).clamp(8, 96).toInt();
  }

  static AgentScreenshotTaskPriority priorityForEvent(TeamEventType t) {
    switch (t) {
      case TeamEventType.meet:
        return AgentScreenshotTaskPriority.high;
      case TeamEventType.training:
      case TeamEventType.social:
      case TeamEventType.admin:
      case TeamEventType.unknown:
        return AgentScreenshotTaskPriority.medium;
    }
  }

  static String rowId(TeamEventsRecord e) =>
      '${e.docId}|${e.startDate}|${e.startTimeLocal}';

  static ({
    AgentDashboardSummaryCounts counts,
    List<AgentScreenshotRecentTask> recentTasks,
  })
  fromNormalized(
    List<TeamEventsRecord> normalized,
  ) {
    final today = _todayDay();
    var todayC = 0;
    var upcomingC = 0;
    var completedC = 0;

    for (final e in normalized) {
      final day = _eventDay(e);
      if (day == null) continue;
      final daysDiff = day.difference(today).inDays;
      if (day.isBefore(today)) {
        completedC++;
      } else if (daysDiff == 0) {
        todayC++;
      } else if (daysDiff > 0 && daysDiff <= upcomingHorizonDays) {
        upcomingC++;
      }
    }

    final upcomingRows = <TeamEventsRecord>[];
    for (final e in normalized) {
      final day = _eventDay(e);
      if (day == null) continue;
      if (!day.isBefore(today)) {
        upcomingRows.add(e);
      }
    }
    upcomingRows.sort(compareTeamEventsStartAsc);

    final sliced = upcomingRows.take(recentCap).toList();

    final tasks = <AgentScreenshotRecentTask>[];
    for (final e in sliced) {
      final day = _eventDay(e)!;
      final daysUntil = day.difference(today).inDays;
      final title = e.title.trim().isEmpty
          ? teamEventTypeLabel(e.eventType)
          : e.title.trim();
      tasks.add(
        AgentScreenshotRecentTask(
          id: rowId(e),
          title: title,
          timeRange: formatTimeRange(e),
          priority: priorityForEvent(e.eventType),
          progressPercent: pseudoProgressPercent(daysUntil),
          avatarAssetPaths: const [
            'assets/images/mcroskey-headshot.jpg',
            'assets/images/mcroskey-headshot.jpg',
          ],
          daysLeftLabel: _daysLeftLabel(day, today),
          scheduleDocId: e.docId,
          scheduleStartDate: e.startDate.trim(),
        ),
      );
    }

    return (
      counts: AgentDashboardSummaryCounts(
        upcoming: upcomingC,
        today: todayC,
        completed: completedC,
      ),
      recentTasks: tasks,
    );
  }

  static ({
    AgentDashboardSummaryCounts counts,
    List<AgentScreenshotRecentTask> recentTasks,
  })
  fromRaw(
    List<TeamEventsRecord> raw,
  ) {
    return fromNormalized(normalizeTeamEventsList(raw));
  }
}
