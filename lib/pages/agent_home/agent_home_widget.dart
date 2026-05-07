import 'dart:math' as math;

import '/app_state.dart';
import '/backend/backend.dart';
import '/theme/lavender_indigo_tokens.dart';
import '/theme/swim_ui_tokens.dart';
import '/widgets/swim_ui_kit.dart';
import '/theme/swim_design_tokens.dart';
import 'agent_feed_item.dart';
import 'agent_feed_logic.dart';
import 'agent_meet_feed_bridge.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Lavender accent chips — matches Agent screenshot pairing for priorities.
const Color _kChipHighAccent = Color(0xFF9B8AFB);
const Color _kChipMediumAccent = Color(0xFF269396);
const Color _kChipLowAccent = Color(0xFF607D8B);

const double _bottomInsetForNavAndFab = 120.0;
const double _fabBottomOffset = 88.0;

/// Prioritized swim-agent dashboard (“what next?”), styled like existing Agent UI.
class AgentHomeWidget extends StatefulWidget {
  const AgentHomeWidget({
    super.key,
    this.userDisplayName,
    this.avatarAssetPath = 'assets/images/mcroskey-headshot.jpg',
    this.teamId = 'oapb',
    required this.onProfileTap,
  });

  final String? userDisplayName;
  final String avatarAssetPath;
  final String teamId;
  final VoidCallback onProfileTap;

  @override
  State<AgentHomeWidget> createState() => _AgentHomeWidgetState();
}

class _AgentHomeWidgetState extends State<AgentHomeWidget> {
  String _displayFirstName() {
    final swim = FFAppState().currentSwimmerName.trim();
    final raw =
        swim.isNotEmpty ? swim : widget.userDisplayName?.trim();
    if (raw == null || raw.isEmpty) return 'Swimmer';
    return raw.split(RegExp(r'\s+')).first;
  }

  static String _tod() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _toast(String label) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label, style: GoogleFonts.sora(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _debugAgent(String label) {
    debugPrint('[Agent] $label');
    _toast('Coming soon: $label');
  }

  void _openScheduleTab() {
    FFAppState().update(() => FFAppState().activeTab = 1);
  }

  void _onFeedNavigateHints(AgentFeedItem item) {
    switch (item.targetType?.trim().toLowerCase()) {
      case 'meet':
        FFAppState().update(() => FFAppState().activeTab = 2);
        break;
      case 'job':
        FFAppState().update(() => FFAppState().activeTab = 3);
        break;
      case 'schedule':
      default:
        _openScheduleTab();
        break;
    }
    final suffix =
        item.targetId != null ? ' (${item.targetId})' : '';
    _toast('Opened route hint$suffix');
  }

  void _showAddToAgentSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Add to Agent',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Train SwimAgent on new signals.',
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    height: 1.35,
                    color: const Color(0xFF8B8FA8),
                  ),
                ),
                const SizedBox(height: 14),
                ...[
                  (
                    Icons.mark_email_read_outlined,
                    'Parse coach email',
                  ),
                  (
                    Icons.picture_as_pdf_outlined,
                    'Upload meet PDF',
                  ),
                  (
                    Icons.link_rounded,
                    'Add meet link',
                  ),
                  (
                    Icons.pool_rounded,
                    'Add practice update',
                  ),
                  (
                    Icons.volunteer_activism_outlined,
                    'Add volunteer job',
                  ),
                  (
                    Icons.emoji_events_outlined,
                    'Add swimmer result',
                  ),
                ].map(
                  (e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(e.$1, color: const Color(0xFF269396)),
                    title: Text(
                      e.$2,
                      style: GoogleFonts.sora(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _debugAgent(e.$2);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _formatWhen(AgentFeedItem item) {
    final dt = item.dueTime ?? item.eventTime;
    if (dt == null) return '';
    final today = _day(DateTime.now());
    final d = _day(dt);
    final datePart = DateFormat.MMMd().format(dt);
    if (d == today) {
      return 'Today · ${DateFormat.jm().format(dt)}';
    }
    return '$datePart · ${DateFormat.jm().format(dt)}';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<FFAppState>();
    final now = DateTime.now();
    return StreamBuilder<List<MonitoredMeetsRecord>>(
      stream: streamMonitoredMeetsForSwimmer(
        zoneId: app.currentSwimmerZoneForMeets,
        priorityHostGroup: app.currentSwimmerGroup,
        showAll: app.meetsShowAllZones,
      ),
      builder: (context, meetSnap) {
        final meetFeedItems = meetSnap.hasData
            ? agentFeedItemsFromMonitoredMeets(
                meets: meetSnap.data!,
                app: app,
                now: now,
              )
            : <AgentFeedItem>[];

        final feed = List<AgentFeedItem>.from(meetFeedItems)
          ..sort((a, b) => AgentFeedLogic.compareFeedItems(a, b, now: now));

        final digest = AgentFeedLogic.digestFromFeedItems(feed, now);
        final stats = AgentFeedLogic.computeSmartStats(feed, now);
        final next = AgentFeedLogic.pickNextBestAction(feed, now);
        final todayPlan = AgentFeedLogic.pickTodaySwimPlan(feed, now);
        final brief =
            AgentFeedLogic.agentBriefItems(feed, next, todayPlan, now);

        final deadlineInsight =
            AgentFeedLogic.pickNextDeadlineHighlight(feed, now);
        final coachInsight = AgentFeedLogic.pickLatestCoachUpdate(feed);

        var scheduleInsightIncluded = false;
        final insightChildren = <Widget>[];
        if (todayPlan != null) {
          scheduleInsightIncluded = true;
          final tw = _formatPracticeWindow(todayPlan).trim();
          final sub =
              '${todayPlan.title.trim().isEmpty ? 'Calendar item' : todayPlan.title.trim()}'
              '${tw.isEmpty ? '' : ' · $tw'}';
          insightChildren.add(
            SwimInsightCard(
              title: 'Today\'s Schedule',
              subtitle: sub,
              ctaLabel: 'View Schedule',
              onTap: () {
                _openScheduleTab();
                _toast('Opening Schedule');
              },
            ),
          );
        }
        if (deadlineInsight != null && deadlineInsight.id != next?.id) {
          final dl = deadlineInsight.dueTime!;
          insightChildren.add(
            SwimInsightCard(
              title: 'Upcoming Deadline',
              subtitle:
                  '${deadlineInsight.title} · ${DateFormat.MMMd().format(dl)} · ${DateFormat.jm().format(dl)}',
              ctaLabel: 'Review Meet',
              onTap: () {
                FFAppState().update(() => FFAppState().activeTab = 2);
                _toast('Opening Meets');
              },
            ),
          );
        }
        if (coachInsight != null && coachInsight.id != next?.id) {
          var cs = coachInsight.summary.trim();
          if (cs.length > 140) {
            cs = '${cs.substring(0, 137)}…';
          }
          insightChildren.add(
            SwimInsightCard(
              title: 'Recent Coach Update',
              subtitle: cs.isEmpty ? 'New message from coach' : cs,
              ctaLabel: 'Read Update',
              onTap: () => _debugAgent('Coach update'),
            ),
          );
        }

        return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: SwimUiTokens.surfaceCanvasAgent),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                SwimDsTokens.pageHorizontalPadding,
                SwimDsTokens.smallGap,
                SwimDsTokens.pageHorizontalPadding,
                _bottomInsetForNavAndFab,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppPageHeader(
                    title: '${_tod()}, ${_displayFirstName()} 👋',
                    subtitle: 'Your swim day at a glance',
                    onBellTap: () => _toast('Notifications'),
                    onAvatarTap: widget.onProfileTap,
                    avatarAssetPath: widget.avatarAssetPath,
                    topPadding: SwimDsTokens.smallGap,
                    bottomPadding: SwimDsTokens.sectionSpacing - 4,
                  ),
                  _SmartAgentStatRow(stats: stats),
                  SizedBox(height: SwimDsTokens.sectionSpacing),
                  if (next != null)
                    _NextBestActionCard(
                      item: next,
                      swimmerFirstName: _displayFirstName(),
                      onPrimary: () => _debugAgent(next.actionLabel ?? 'Primary'),
                      onSecondaryAlt:
                          next.secondaryActionLabel != null &&
                                  next.secondaryActionLabel!.isNotEmpty
                              ? () => _debugAgent(next.secondaryActionLabel!)
                              : null,
                    )
                  else
                    EmptyStateCard(
                      title: 'You are all caught up',
                      message:
                          'No urgent swim tasks need your attention right now.',
                      icon: Icons.check_circle_outline_rounded,
                      ctaLabel: 'View Schedule',
                      onCta: () {
                        _openScheduleTab();
                        _toast('Opening Schedule');
                      },
                    ),
                  SizedBox(height: SwimDsTokens.sectionSpacing),
                  if (insightChildren.isNotEmpty) ...insightChildren,
                  if (!scheduleInsightIncluded) ...[
                    SizedBox(height: SwimDsTokens.sectionSpacing),
                    Text(
                      'Today’s Swim Plan',
                      style: GoogleFonts.sora(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: SwimDsTokens.textPrimary,
                      ),
                    ),
                    SizedBox(height: SwimDsTokens.sectionTitleToContentGap + 2),
                    if (todayPlan != null)
                      _TodaySwimPlanCard(
                        item: todayPlan,
                        timeWindow: _formatPracticeWindow(todayPlan),
                        onViewSchedule: () {
                          _openScheduleTab();
                          _toast('Opening Schedule');
                        },
                      )
                    else
                      EmptyStateCard(
                        title: 'No swim plan for today',
                        message:
                            'Check Schedule if something changed overnight.',
                        icon: Icons.calendar_today_outlined,
                        ctaLabel: 'View Schedule',
                        onCta: () {
                          _openScheduleTab();
                          _toast('Opening Schedule');
                        },
                      ),
                  ],
                  SizedBox(height: SwimDsTokens.largeGap + 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Agent Brief',
                          style: GoogleFonts.sora(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _openScheduleTab,
                        style: TextButton.styleFrom(
                          foregroundColor: _kChipMediumAccent,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Full brief',
                          style: GoogleFonts.sora(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (brief.isEmpty)
                    _WarmEmptyCard(
                      title: 'Brief is quiet.',
                      subtitle:
                          'Meet deadlines, missing resources, and coach highlights appear here as SwimAgent parses new signals.',
                    )
                  else
                    ...brief.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BriefFeedCard(
                          item: item,
                          formatWhen: _formatWhen,
                          onPrimary: () =>
                              item.actionLabel != null
                                  ? _debugAgent(item.actionLabel!)
                                  : _onFeedNavigateHints(item),
                          onTapCard: () => _onFeedNavigateHints(item),
                        ),
                      ),
                    ),
                  const SizedBox(height: 26),
                  Text(
                    'From Coach',
                    style: GoogleFonts.sora(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CoachDigestCard(
                    digest: digest,
                    onReview: () => _debugAgent('Review Updates'),
                  ),
                  const SizedBox(height: 26),
                  StreamBuilder<List<TeamEventsRecord>>(
                    stream: streamTeamEvents(widget.teamId),
                    builder: (context, snap) {
                      if (snap.hasError ||
                          !snap.hasData ||
                          snap.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final norm = normalizeTeamEventsList(snap.data!);
                      final today = _day(DateTime.now());
                      final upcoming = norm.where((e) {
                        final ps = e.parsedStart;
                        if (ps == null) return false;
                        return !_day(ps).isBefore(today);
                      }).toList()
                        ..sort(compareTeamEventsStartAsc);
                      final peek = upcoming.take(3).toList();
                      if (peek.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Soon on calendar',
                            style: GoogleFonts.sora(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...peek.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CalendarPeekTile(
                                event: e,
                                subtitle:
                                    e.startTimeLocal.isEmpty &&
                                            e.endTimeLocal.isEmpty
                                        ? DateFormat.MMMd().format(
                                            e.parsedStart ??
                                                DateTime.now(),
                                          )
                                        : '${DateFormat.MMMd().format(e.parsedStart ?? DateTime.now())} · ${e.startTimeLocal}',
                                onTap: () => FFAppState()
                                    .openScheduleWithAgentEvent(
                                  docId: e.docId,
                                  startDate: e.startDate.trim(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: SwimDsTokens.pageHorizontalPadding,
            bottom: _fabBottomOffset,
            child: Material(
              color: Colors.black,
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.35),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _showAddToAgentSheet,
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  static String _formatPracticeWindow(AgentFeedItem plan) {
    final s = plan.eventTime;
    if (s == null) return '';
    final start = DateFormat.jm().format(s);
    final end = DateTime(
      s.year,
      s.month,
      s.day,
      s.hour + 2,
      s.minute,
    );
    return '$start – ${DateFormat.jm().format(end)}';
  }
}

class _SmartAgentStatRow extends StatelessWidget {
  const _SmartAgentStatRow({required this.stats});

  final AgentSmartStats stats;

  static const double _cardHeight = 102;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _MiniStatCard(
            label: 'Needs Action',
            value: stats.needsAction,
            accent: SwimDsTokens.dangerCoral,
            icon: Icons.flag_rounded,
          ),
        ),
        SizedBox(width: SwimDsTokens.cardSpacing),
        Expanded(
          child: _MiniStatCard(
            label: 'Today',
            value: stats.today,
            accent: SwimDsTokens.infoBlueGray,
            icon: Icons.today_rounded,
          ),
        ),
        SizedBox(width: SwimDsTokens.cardSpacing),
        Expanded(
          child: _MiniStatCard(
            label: 'New Updates',
            value: stats.newUpdates,
            accent: SwimDsTokens.newUpdatePurple,
            icon: Icons.mark_chat_unread_rounded,
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.accent,
    this.icon,
  });

  final String label;
  final int value;
  final Color accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final calm = value == 0;
    final fg = calm ? SwimDsTokens.textSecondary : accent;
    return SizedBox(
      height: _SmartAgentStatRow._cardHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SwimDsTokens.cardBackground,
          borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
          border: Border.all(color: SwimDsTokens.borderSoft),
          boxShadow: SwimDsTokens.cardShadowSoft,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SwimDsTokens.cardPadding - 4,
            12,
            SwimDsTokens.cardPadding - 4,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color: SwimDsTokens.textSecondary,
                      ),
                    ),
                  ),
                  if (icon != null)
                    Icon(icon, size: 18, color: fg.withValues(alpha: 0.85)),
                ],
              ),
              const Spacer(),
              Text(
                '$value',
                style: GoogleFonts.sora(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: calm ? SwimDsTokens.textPrimary : fg,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarmEmptyCard extends StatelessWidget {
  const _WarmEmptyCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.sora(
              fontSize: 13,
              height: 1.4,
              color: const Color(0xFF8B8FA8),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextBestActionCard extends StatefulWidget {
  const _NextBestActionCard({
    required this.item,
    required this.swimmerFirstName,
    required this.onPrimary,
    this.onSecondaryAlt,
  });

  final AgentFeedItem item;
  final String swimmerFirstName;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondaryAlt;

  @override
  State<_NextBestActionCard> createState() => _NextBestActionCardState();
}

class _NextBestActionCardState extends State<_NextBestActionCard> {
  bool _detailsOpen = false;

  String _actionNeeded() {
    final item = widget.item;
    final fn = widget.swimmerFirstName;
    if (item.type == AgentFeedItemType.upcomingMeet) {
      return 'Review and confirm $fn\'s entry';
    }
    final al = item.actionLabel?.trim();
    if (al != null && al.isNotEmpty) return al;
    final s = item.summary.trim();
    if (s.length <= 160) return s.isEmpty ? 'Review this item' : s;
    return '${s.substring(0, 157)}…';
  }

  String _whyMatters() {
    final item = widget.item;
    if (item.coachApproved && item.type == AgentFeedItemType.upcomingMeet) {
      return 'Entry deadline is coming soon. Coach approved this meet for your swimmer.';
    }
    if (item.dueTime != null) {
      return 'This item has an approaching deadline.';
    }
    return 'This item may need parent attention.';
  }

  String _statusLabel() {
    switch (widget.item.status) {
      case AgentFeedStatus.open:
        return 'Open';
      case AgentFeedStatus.done:
        return 'Done';
      case AgentFeedStatus.dismissed:
        return 'Dismissed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final eventDt = item.eventTime ?? item.dueTime;
    final dateStr =
        eventDt != null ? DateFormat.yMMMEd().format(eventDt) : '—';
    final loc = (item.venueLabel ?? '').trim();
    final deadlineStr = item.dueTime != null
        ? '${DateFormat.yMMMEd().format(item.dueTime!)} · ${DateFormat.jm().format(item.dueTime!)}'
        : '—';

    TextStyle bodyMuted() => GoogleFonts.sora(
          fontSize: 13,
          height: 1.45,
          color: SwimDsTokens.textSecondary,
        );

    Widget section(String title, String body) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: SwimDsTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(body, style: bodyMuted()),
          ],
        );

    final chips = <Widget>[
      StatusPill(kind: SwimStatusPillKind.today, label: 'Date · $dateStr'),
      if (loc.isNotEmpty)
        StatusPill(kind: SwimStatusPillKind.neutral, label: 'Location · $loc'),
      if (item.dueTime != null)
        StatusPill(
          kind: SwimStatusPillKind.deadlineSoon,
          label: 'Entry deadline · $deadlineStr',
        ),
      StatusPill(
        kind: SwimStatusPillKind.active,
        label: 'Status · ${_statusLabel()}',
      ),
      if (item.coachApproved)
        StatusPill(
          kind: SwimStatusPillKind.coachApproved,
          label: 'Coach approved',
          icon: Icons.verified_rounded,
        ),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: SwimDsTokens.cardBackground,
        borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius + 4),
        border: Border.all(
          color: LavenderIndigoTokens.primary.withValues(alpha: 0.28),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: LavenderIndigoTokens.primary.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          ...SwimDsTokens.cardShadowSoft,
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(SwimDsTokens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusPill(
              label: 'Next Best Action',
              kind: SwimStatusPillKind.newUpdate,
              icon: Icons.auto_awesome_rounded,
            ),
            SizedBox(height: SwimDsTokens.mediumGap),
            Text(
              item.title.trim().isEmpty ? 'Swim item' : item.title.trim(),
              style: GoogleFonts.sora(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: SwimDsTokens.textPrimary,
                height: 1.25,
              ),
            ),
            SizedBox(height: SwimDsTokens.mediumGap),
            section('Action needed', _actionNeeded()),
            SizedBox(height: SwimDsTokens.smallGap + 2),
            section('Why it matters', _whyMatters()),
            SizedBox(height: SwimDsTokens.mediumGap),
            Text(
              'Key details',
              style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: SwimDsTokens.textPrimary,
              ),
            ),
            SizedBox(height: SwimDsTokens.smallGap),
            Wrap(
              spacing: SwimDsTokens.smallGap,
              runSpacing: SwimDsTokens.smallGap,
              children: chips,
            ),
            SizedBox(height: SwimDsTokens.largeGap),
            SwimPrimaryButton(
              label: item.actionLabel ?? 'Review Entry',
              onPressed: widget.onPrimary,
            ),
            if (item.summary.trim().isNotEmpty)
              SwimSecondaryButton(
                label: _detailsOpen ? 'Hide details' : 'View details',
                onPressed: () => setState(() => _detailsOpen = !_detailsOpen),
              ),
            if (widget.onSecondaryAlt != null)
              SwimSecondaryButton(
                label: item.secondaryActionLabel ?? 'View Meet Sheet',
                onPressed: widget.onSecondaryAlt,
              ),
            if (_detailsOpen && item.summary.trim().isNotEmpty) ...[
              SizedBox(height: SwimDsTokens.smallGap),
              Text(item.summary.trim(), style: bodyMuted()),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodaySwimPlanCard extends StatelessWidget {
  const _TodaySwimPlanCard({
    required this.item,
    required this.timeWindow,
    required this.onViewSchedule,
  });

  final AgentFeedItem item;
  final String timeWindow;
  final VoidCallback onViewSchedule;

  @override
  Widget build(BuildContext context) {
    final name = item.swimmerName ?? 'Swimmer';
    final group = item.groupName ?? 'Practice';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$group · $timeWindow',
            style: GoogleFonts.sora(
              fontSize: 13,
              height: 1.35,
              color: const Color(0xFF8B8FA8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title.trim().isNotEmpty ? item.title.trim() : 'Calendar item',
            style: GoogleFonts.sora(
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
          if ((item.venueLabel ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.venueLabel!.trim(),
              style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF269396),
              ),
            ),
          ],
          if ((item.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Notes · ${item.notes}',
              style: GoogleFonts.sora(
                fontSize: 12.5,
                height: 1.35,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kChipMediumAccent,
                side: const BorderSide(color: Color(0xFFBFE3E5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onViewSchedule,
              child: Text(
                'View Schedule',
                style: GoogleFonts.sora(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachDigestCard extends StatelessWidget {
  const _CoachDigestCard({
    required this.digest,
    required this.onReview,
  });

  final AgentCoachDigest digest;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final coachUpdatesEmpty = digest.totalSignals == 0 &&
        digest.practiceChanges == 0 &&
        digest.meetDeadlines == 0 &&
        digest.socialEvents == 0;
    if (coachUpdatesEmpty) {
      return _WarmEmptyCard(
        title: 'No digest signals yet.',
        subtitle:
            'When monitored meets need entries or coach approval lines up with signup, counts appear here. Open Meets for the full calendar.',
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            digest.headline,
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          _CoachBullet(
              label: 'Practice changes', value: digest.practiceChanges),
          _CoachBullet(label: 'Meet deadlines', value: digest.meetDeadlines),
          _CoachBullet(label: 'Social events', value: digest.socialEvents),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF269396),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onReview,
              child: Text(
                'Review Updates',
                style: GoogleFonts.sora(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachBullet extends StatelessWidget {
  const _CoachBullet({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF269396),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label: $value',
              style: GoogleFonts.sora(
                fontSize: 13,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BriefFeedCard extends StatelessWidget {
  const _BriefFeedCard({
    required this.item,
    required this.formatWhen,
    required this.onPrimary,
    required this.onTapCard,
  });

  final AgentFeedItem item;
  final String Function(AgentFeedItem) formatWhen;
  final VoidCallback onPrimary;
  final VoidCallback onTapCard;

  @override
  Widget build(BuildContext context) {
    final pc = AgentFeedLogic.priorityChipColors(
      item.priority,
      _kChipHighAccent,
      _kChipMediumAccent,
      _kChipLowAccent,
    );
    final accent = pc.accent;
    final pillBg = pc.pillBg;
    final chipHigh =
        AgentFeedLogic.priorityChipLabel(item.priority);
    final typeLab = AgentFeedLogic.typeShortLabel(item.type);
    final when = formatWhen(item);
    final pv = item.progressValue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTapCard,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: pillBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              chipHigh,
                              style: GoogleFonts.sora(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              typeLab,
                              style: GoogleFonts.sora(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          if (item.coachApproved &&
                              item.type ==
                                  AgentFeedItemType.upcomingMeet)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5F4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFBFE3E5),
                                ),
                              ),
                              child: Text(
                                'Coach approved',
                                style: GoogleFonts.sora(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _kChipMediumAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (pv != null && item.progressLabel != null) ...[
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${pv.round()}%',
                            style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _DonutMini(
                            fraction: (pv.clamp(0, 100)) / 100.0,
                            color: accent,
                            track: accent.withValues(alpha: 0.14),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 76,
                            child: Text(
                              item.progressLabel!,
                              textAlign: TextAlign.right,
                              style: GoogleFonts.sora(
                                fontSize: 10,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.summary,
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    height: 1.4,
                    color: const Color(0xFF8B8FA8),
                  ),
                ),
                if (when.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    when,
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF269396),
                    ),
                  ),
                ],
                if (item.actionLabel != null ||
                    item.avatarHintAssetPaths.isNotEmpty ||
                    (item.swimmerName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  if (item.actionLabel != null &&
                      item.avatarHintAssetPaths.isEmpty &&
                      (item.swimmerName ?? '').isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onPrimary,
                        style: TextButton.styleFrom(
                          foregroundColor: _kChipMediumAccent,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          item.actionLabel!,
                          style: GoogleFonts.sora(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (item.avatarHintAssetPaths.isNotEmpty)
                          _TinyAvatarStack(
                              paths: item.avatarHintAssetPaths),
                        if ((item.swimmerName ?? '').isNotEmpty) ...[
                          if (item.avatarHintAssetPaths.isNotEmpty)
                            const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.swimmerName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.sora(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ] else if (item.avatarHintAssetPaths.isNotEmpty)
                          const Spacer(),
                        if (item.actionLabel != null)
                          TextButton(
                            onPressed: onPrimary,
                            style: TextButton.styleFrom(
                              foregroundColor: _kChipMediumAccent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              item.actionLabel!,
                              style: GoogleFonts.sora(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyAvatarStack extends StatelessWidget {
  const _TinyAvatarStack({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    final use = paths.take(3).toList();
    if (use.isEmpty) return const SizedBox.shrink();
    const size = 26.0;
    const step = 14.0;
    final w = size + (use.length - 1) * step;
    return SizedBox(
      width: w,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < use.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipOval(
                  child: Image.asset(
                    use[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: LavenderIndigoTokens.primarySoft,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.person_rounded,
                        size: 12,
                        color: LavenderIndigoTokens.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DonutMini extends StatelessWidget {
  const _DonutMini({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(
        painter: _DonutPainter(
          progress: fraction.clamp(0.0, 1.0),
          color: color,
          trackColor: track,
          strokeWidth: 3,
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    const start = -math.pi / 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _CalendarPeekTile extends StatelessWidget {
  const _CalendarPeekTile({
    required this.event,
    required this.subtitle,
    required this.onTap,
  });

  final TeamEventsRecord event;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8ECF5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.event_rounded,
                    size: 20, color: Colors.grey.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title.trim().isEmpty
                            ? teamEventTypeLabel(event.eventType)
                            : event.title.trim(),
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.sora(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
