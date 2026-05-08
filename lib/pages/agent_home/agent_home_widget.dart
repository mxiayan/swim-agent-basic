import 'dart:async';
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
import 'agent_urgency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Lavender accent chips — matches Agent screenshot pairing for priorities.
const Color _kChipHighAccent = Color(0xFF9B8AFB);
const Color _kChipMediumAccent = Color(0xFF269396);
const Color _kChipLowAccent = Color(0xFF607D8B);

const double _bottomInsetForNavAndFab = 120.0;
const double _fabBottomOffset = 88.0;

bool _agentReduceMotion(BuildContext context) {
  return MediaQuery.disableAnimationsOf(context) ||
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;
}

SwimBellDotKind _agentBellDotKind({
  required AgentSmartStats stats,
  required AgentUrgencyLevel needsMax,
  required AgentUrgencyLevel nextUrgency,
}) {
  final urgent = nextUrgency.showsPulse ||
      (needsMax.showsPulse && stats.needsAction > 0);
  if (urgent) return SwimBellDotKind.urgentRed;
  if (stats.newUpdates > 0) return SwimBellDotKind.updatesAmber;
  return SwimBellDotKind.none;
}

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

  void _handleNextBestNavigate(AgentFeedItem item) {
    _onFeedNavigateHints(item);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<FFAppState>();
    final now = DateTime.now();
    final reduceMotion = _agentReduceMotion(context);
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

        final needsMaxUrgency = maxNeedsActionUrgency(feed, now);
        final nextUrgency = next != null
            ? agentUrgencyForFeedItem(next, now)
            : AgentUrgencyLevel.none;
        final bellDot = _agentBellDotKind(
          stats: stats,
          needsMax: needsMaxUrgency,
          nextUrgency: nextUrgency,
        );

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
                    bellDotKind: bellDot,
                    topPadding: SwimDsTokens.smallGap,
                    bottomPadding: SwimDsTokens.sectionSpacing - 4,
                  )
                      .animate()
                      .fadeIn(
                        duration: 420.ms,
                        curve: Curves.easeOutCubic,
                      )
                      .slideY(
                        begin: 0.07,
                        duration: 420.ms,
                        curve: Curves.easeOutCubic,
                      ),
                  _AgentMetricStrip(
                    stats: stats,
                    needsMaxUrgency: needsMaxUrgency,
                    reduceMotion: reduceMotion,
                  ),
                  SizedBox(height: SwimDsTokens.sectionSpacing),
                  if (next != null)
                    _NextBestActionCard(
                      key: ValueKey(next.id),
                      item: next,
                      swimmerFirstName: _displayFirstName(),
                      urgency: nextUrgency,
                      reduceMotion: reduceMotion,
                      onPrimary: () => _handleNextBestNavigate(next),
                      onSecondary: () => _handleNextBestNavigate(next),
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
                    )
                        .animate()
                        .fadeIn(
                          delay: 880.ms,
                          duration: 460.ms,
                          curve: Curves.easeOutCubic,
                        )
                        .slideY(
                          begin: 0.06,
                          delay: 880.ms,
                          duration: 460.ms,
                          curve: Curves.easeOutCubic,
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

class _AgentMetricStrip extends StatefulWidget {
  const _AgentMetricStrip({
    required this.stats,
    required this.needsMaxUrgency,
    required this.reduceMotion,
  });

  final AgentSmartStats stats;
  final AgentUrgencyLevel needsMaxUrgency;
  final bool reduceMotion;

  @override
  State<_AgentMetricStrip> createState() => _AgentMetricStripState();
}

class _AgentMetricStripState extends State<_AgentMetricStrip> {
  static const double _cardHeight = 108;
  bool _startNeedsCount = false;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _startNeedsCount = true;
    } else {
      Future.delayed(const Duration(milliseconds: 780), () {
        if (mounted) setState(() => _startNeedsCount = true);
      });
    }
  }

  Color _needsAccent() {
    final u = widget.needsMaxUrgency;
    final n = widget.stats.needsAction;
    if (n == 0) return SwimDsTokens.textSecondary;
    switch (u) {
      case AgentUrgencyLevel.none:
      case AgentUrgencyLevel.normal:
        return SwimDsTokens.newUpdatePurple;
      case AgentUrgencyLevel.dueSoon:
        return SwimDsTokens.warningAmber;
      case AgentUrgencyLevel.urgent:
      case AgentUrgencyLevel.critical:
        return SwimDsTokens.dangerCoral;
    }
  }

  bool _needsPulse() {
    return !widget.reduceMotion &&
        widget.stats.needsAction > 0 &&
        widget.needsMaxUrgency.showsPulse;
  }

  bool _needsAlertDot() {
    return widget.stats.needsAction > 0 &&
        widget.needsMaxUrgency.showsPulse;
  }

  Widget _needsValue() {
    final target = widget.stats.needsAction;
    final accent = _needsAccent();
    if (!_startNeedsCount) {
      return Text(
        '0',
        style: GoogleFonts.sora(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: SwimDsTokens.textPrimary,
          height: 1,
        ),
      );
    }
    if (widget.reduceMotion || target == 0) {
      return Text(
        '$target',
        style: GoogleFonts.sora(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: target == 0 ? SwimDsTokens.textPrimary : accent,
          height: 1,
        ),
      );
    }
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: target),
      duration: const Duration(milliseconds: 880),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        '$v',
        style: GoogleFonts.sora(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: accent,
          height: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pulse = _needsPulse();
    final accent = _needsAccent();

    Widget needsCard = Semantics(
      label: 'Needs action, ${widget.stats.needsAction} items',
      child: _MetricMiniCard(
        height: _cardHeight,
        label: 'Needs Action',
        valueWidget: _needsValue(),
        accent: accent,
        calm: widget.stats.needsAction == 0,
        icon: Icons.flag_rounded,
        alertDot: _needsAlertDot(),
        shimmerDot: !widget.reduceMotion,
        reduceMotion: widget.reduceMotion,
        footerHint: 'Tap brief below',
      ),
    );

    if (pulse) {
      needsCard = _PulseRing(child: needsCard);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: needsCard
              .animate()
              .fadeIn(
                delay: 460.ms,
                duration: 340.ms,
                curve: Curves.easeOutCubic,
              )
              .slideY(
                begin: 0.1,
                delay: 460.ms,
                duration: 340.ms,
                curve: Curves.easeOutCubic,
              ),
        ),
        SizedBox(width: SwimDsTokens.cardSpacing),
        Expanded(
          child: Semantics(
            label: 'Today, ${widget.stats.today} items',
            child: _MetricMiniCard(
              height: _cardHeight,
              label: 'Today',
              valueWidget: Text(
                '${widget.stats.today}',
                style: GoogleFonts.sora(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: SwimDsTokens.infoBlueGray,
                  height: 1,
                ),
              ),
              accent: SwimDsTokens.infoBlueGray,
              calm: false,
              icon: Icons.today_rounded,
            ),
          )
              .animate()
              .fadeIn(
                delay: 560.ms,
                duration: 340.ms,
                curve: Curves.easeOutCubic,
              )
              .slideY(
                begin: 0.1,
                delay: 560.ms,
                duration: 340.ms,
                curve: Curves.easeOutCubic,
              ),
        ),
        SizedBox(width: SwimDsTokens.cardSpacing),
        Expanded(
          child: Semantics(
            label: 'New updates, ${widget.stats.newUpdates}',
            child: _MetricMiniCard(
              height: _cardHeight,
              label: 'New Updates',
              valueWidget: Text(
                '${widget.stats.newUpdates}',
                style: GoogleFonts.sora(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: widget.stats.newUpdates == 0
                      ? SwimDsTokens.textPrimary
                      : SwimDsTokens.newUpdatePurple,
                  height: 1,
                ),
              ),
              accent: SwimDsTokens.newUpdatePurple,
              calm: widget.stats.newUpdates == 0,
              icon: Icons.mark_chat_unread_rounded,
            ),
          )
              .animate()
              .fadeIn(
                delay: 660.ms,
                duration: 340.ms,
                curve: Curves.easeOutCubic,
              )
              .slideY(
                begin: 0.1,
                delay: 660.ms,
                duration: 340.ms,
                curve: Curves.easeOutCubic,
              ),
        ),
      ],
    );
  }
}

class _PulseRing extends StatefulWidget {
  const _PulseRing({required this.child});

  final Widget child;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = _c.value;
        return Container(
          padding: EdgeInsets.all(1 + v * 1.2),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(SwimDsTokens.cardRadius + 5),
            border: Border.all(
              width: 1 + v * 0.8,
              color: SwimDsTokens.dangerCoral.withValues(alpha: 0.28 + v * 0.22),
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _MetricMiniCard extends StatelessWidget {
  const _MetricMiniCard({
    required this.height,
    required this.label,
    required this.valueWidget,
    required this.accent,
    required this.calm,
    this.icon,
    this.alertDot = false,
    this.shimmerDot = false,
    this.reduceMotion = false,
    this.footerHint,
  });

  final double height;
  final String label;
  final Widget valueWidget;
  final Color accent;
  final bool calm;
  final IconData? icon;
  final bool alertDot;
  final bool shimmerDot;
  final bool reduceMotion;
  final String? footerHint;

  @override
  Widget build(BuildContext context) {
    final fg = calm ? SwimDsTokens.textSecondary : accent;
    return SizedBox(
      height: height,
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
            10,
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
                  if (alertDot)
                    _UrgentDot(shimmer: shimmerDot && !reduceMotion)
                  else if (icon != null)
                    Icon(icon, size: 18, color: fg.withValues(alpha: 0.85)),
                ],
              ),
              const Spacer(),
              valueWidget,
              if (footerHint != null)
                Text(
                  footerHint!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 9,
                    height: 1.1,
                    color:
                        SwimDsTokens.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small dot when Needs Action is urgent (optional shimmer).
class _UrgentDot extends StatefulWidget {
  const _UrgentDot({required this.shimmer});

  final bool shimmer;

  @override
  State<_UrgentDot> createState() => _UrgentDotState();
}

class _UrgentDotState extends State<_UrgentDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.shimmer) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.shimmer && _c != null
        ? (0.45 + _c!.value * 0.55)
        : 1.0;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: SizedBox(
        width: 10,
        height: 18,
        child: Align(
          alignment: Alignment.centerRight,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: SwimDsTokens.dangerCoral,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
            ),
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
    super.key,
    required this.item,
    required this.swimmerFirstName,
    required this.urgency,
    required this.reduceMotion,
    required this.onPrimary,
    required this.onSecondary,
  });

  final AgentFeedItem item;
  final String swimmerFirstName;
  final AgentUrgencyLevel urgency;
  final bool reduceMotion;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  State<_NextBestActionCard> createState() => _NextBestActionCardState();
}

class _NextBestActionCardState extends State<_NextBestActionCard> {
  String _subtitleSummary() {
    final item = widget.item;
    final fn = widget.swimmerFirstName;
    if (item.type == AgentFeedItemType.upcomingMeet) {
      return 'Review and confirm $fn\'s entry before the deadline.';
    }
    if (item.type == AgentFeedItemType.volunteerJob) {
      return 'Choose a volunteer job for this meet.';
    }
    if (item.type == AgentFeedItemType.coachUpdate) {
      return 'Read the latest coach update.';
    }
    if (item.type == AgentFeedItemType.todayPlan) {
      return 'Check today\'s workout time.';
    }
    final al = item.actionLabel?.trim();
    if (al != null && al.isNotEmpty) return al;
    final s = item.summary.trim();
    if (s.length <= 140) return s.isEmpty ? 'Review this item' : s;
    return '${s.substring(0, 137)}…';
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

  String _primaryLabel({required bool deadlinePassed}) {
    final item = widget.item;
    if (deadlinePassed) return 'View details';
    return item.actionLabel?.trim().isNotEmpty == true
        ? item.actionLabel!.trim()
        : 'Review entry';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final now = DateTime.now();
    final dl = item.dueTime;
    final expired = dl != null && !dl.isAfter(now);
    final eventDt = item.eventTime ?? item.dueTime;
    final dateStr =
        eventDt != null ? DateFormat.yMMMEd().format(eventDt) : '—';
    final loc = (item.venueLabel ?? '').trim();
    final group = (item.groupName ?? '').trim();

    TextStyle bodyMuted() => GoogleFonts.sora(
          fontSize: 13,
          height: 1.45,
          color: SwimDsTokens.textSecondary,
        );

    final chips = <Widget>[
      StatusPill(kind: SwimStatusPillKind.today, label: 'Date · $dateStr'),
      if (loc.isNotEmpty)
        StatusPill(kind: SwimStatusPillKind.neutral, label: 'Location · $loc'),
      if (group.isNotEmpty)
        StatusPill(kind: SwimStatusPillKind.neutral, label: 'Group · $group'),
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

    final breathe = !widget.reduceMotion &&
        (widget.urgency == AgentUrgencyLevel.urgent ||
            widget.urgency == AgentUrgencyLevel.critical);
    final amberBand =
        widget.urgency == AgentUrgencyLevel.dueSoon && !breathe;

    Widget core = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: SwimDsTokens.cardBackground,
        borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius + 4),
        border: Border.all(
          color: amberBand
              ? SwimDsTokens.warningAmber.withValues(alpha: 0.55)
              : LavenderIndigoTokens.primary.withValues(alpha: 0.28),
          width: amberBand ? 2 : 1.5,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StatusPill(
                    label: 'Next Best Action',
                    kind: SwimStatusPillKind.newUpdate,
                    icon: Icons.auto_awesome_rounded,
                  ),
                ),
                if (widget.urgency.showsUrgentBadge)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _UrgencyBadgePop(
                      level: widget.urgency,
                      reduceMotion: widget.reduceMotion,
                    ),
                  ),
              ],
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
            SizedBox(height: SwimDsTokens.smallGap),
            Text(
              _subtitleSummary(),
              style: bodyMuted(),
            ),
            SizedBox(height: SwimDsTokens.mediumGap),
            Text(
              'Details',
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
            if (dl != null) ...[
              SizedBox(height: SwimDsTokens.mediumGap),
              _AgentDeadlineCountdown(
                deadline: dl,
                urgency: widget.urgency,
                reduceMotion: widget.reduceMotion,
              ),
            ],
            SizedBox(height: SwimDsTokens.largeGap),
            Semantics(
              button: true,
              label: _primaryLabel(deadlinePassed: expired),
              child: _AgentPrimaryCta(
                label: _primaryLabel(deadlinePassed: expired),
                onPressed: widget.onPrimary,
              ),
            ),
            SwimSecondaryButton(
              label: 'View details',
              onPressed: widget.onSecondary,
            ),
          ],
        ),
      ),
    );

    if (amberBand) {
      core = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius + 6),
          border: Border(
            left: BorderSide(
              color: SwimDsTokens.warningAmber.withValues(alpha: 0.85),
              width: 4,
            ),
          ),
        ),
        child: core,
      );
    }

    if (breathe) {
      core = _BreathingActionShell(
        strong: widget.urgency == AgentUrgencyLevel.critical,
        reduceMotion: widget.reduceMotion,
        child: core,
      );
    }

    return Semantics(
      container: true,
      label: 'Next best action: ${item.title}',
      child: core,
    )
        .animate()
        .fadeIn(
          delay: 820.ms,
          duration: 460.ms,
          curve: Curves.easeOutCubic,
        )
        .slideY(
          begin: 0.08,
          delay: 820.ms,
          duration: 460.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _UrgencyBadgePop extends StatelessWidget {
  const _UrgencyBadgePop({
    required this.level,
    required this.reduceMotion,
  });

  final AgentUrgencyLevel level;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    if (!level.showsUrgentBadge) return const SizedBox.shrink();

    late Color bg;
    late Color fg;
    late String text;
    switch (level) {
      case AgentUrgencyLevel.dueSoon:
        bg = SwimDsTokens.warningAmber.withValues(alpha: 0.18);
        fg = const Color(0xFFB45309);
        text = 'Due soon';
        break;
      case AgentUrgencyLevel.urgent:
        bg = SwimDsTokens.dangerCoral.withValues(alpha: 0.16);
        fg = const Color(0xFFB91C1C);
        text = 'Urgent';
        break;
      case AgentUrgencyLevel.critical:
        bg = const Color(0xFFFECACA);
        fg = const Color(0xFF991B1B);
        text = 'Critical';
        break;
      default:
        return const SizedBox.shrink();
    }

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: level == AgentUrgencyLevel.critical
            ? Border.all(color: fg.withValues(alpha: 0.45))
            : null,
      ),
      child: Text(
        text,
        style: GoogleFonts.sora(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );

    if (reduceMotion) return pill;

    return pill
        .animate()
        .scale(
          delay: 1180.ms,
          duration: 320.ms,
          begin: const Offset(0.88, 0.88),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
        )
        .fadeIn(delay: 1180.ms, duration: 240.ms);
  }
}

class _BreathingActionShell extends StatefulWidget {
  const _BreathingActionShell({
    required this.child,
    required this.strong,
    required this.reduceMotion,
  });

  final Widget child;
  final bool strong;
  final bool reduceMotion;

  @override
  State<_BreathingActionShell> createState() => _BreathingActionShellState();
}

class _BreathingActionShellState extends State<_BreathingActionShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2750),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) return widget.child;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = _c.value;
        final alpha = 0.22 + v * (widget.strong ? 0.2 : 0.12);
        return Container(
          padding: EdgeInsets.all(1.2 + v * (widget.strong ? 1.4 : 0.9)),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(SwimDsTokens.cardRadius + 8),
            border: Border.all(
              color: SwimDsTokens.dangerCoral.withValues(alpha: alpha),
              width: 1.1 + v * 0.7,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _AgentDeadlineCountdown extends StatefulWidget {
  const _AgentDeadlineCountdown({
    required this.deadline,
    required this.urgency,
    required this.reduceMotion,
  });

  final DateTime deadline;
  final AgentUrgencyLevel urgency;
  final bool reduceMotion;

  @override
  State<_AgentDeadlineCountdown> createState() =>
      _AgentDeadlineCountdownState();
}

class _AgentDeadlineCountdownState extends State<_AgentDeadlineCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant _AgentDeadlineCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    void tick() {
      if (!mounted) return;
      setState(() {});
      final diff = widget.deadline.difference(DateTime.now());
      if (diff.isNegative) return;
      final next = diff.inDays > 7
          ? const Duration(minutes: 1)
          : const Duration(seconds: 1);
      _timer = Timer(next, tick);
    }

    tick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _title({required bool expired}) {
    if (expired) return 'DEADLINE';
    switch (widget.urgency) {
      case AgentUrgencyLevel.critical:
        return 'ENTRY DEADLINE · COUNTING DOWN';
      case AgentUrgencyLevel.urgent:
        return 'ACTION NEEDED BY';
      case AgentUrgencyLevel.dueSoon:
        return 'DUE SOON';
      default:
        return 'ENTRY DEADLINE';
    }
  }

  String _format(Duration d) {
    if (d.isNegative) return 'Deadline passed';
    final showSec = widget.urgency.showsPulse;
    final days = d.inDays;
    final hrs = d.inHours.remainder(24);
    final mins = d.inMinutes.remainder(60);
    final secs = d.inSeconds.remainder(60);
    if (days >= 1) {
      return '${days.toString().padLeft(2, '0')} DAYS · '
          '${hrs.toString().padLeft(2, '0')} HRS · '
          '${mins.toString().padLeft(2, '0')} MIN';
    }
    if (d.inHours >= 1) {
      return '${d.inHours} HRS · ${mins.toString().padLeft(2, '0')} MIN';
    }
    if (showSec) {
      return '${mins.toString().padLeft(2, '0')} MIN · '
          '${secs.toString().padLeft(2, '0')} SEC';
    }
    return '${mins.toString().padLeft(2, '0')} MIN';
  }

  @override
  Widget build(BuildContext context) {
    final diff = widget.deadline.difference(DateTime.now());
    final expired = diff.isNegative;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title(expired: expired),
          style: GoogleFonts.sora(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: SwimDsTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: expired ? 'Deadline has passed' : 'Time remaining until deadline',
          child: ExcludeSemantics(
            child: Text(
              _format(diff),
              style: GoogleFonts.sora(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: expired
                    ? SwimDsTokens.dangerCoral
                    : SwimDsTokens.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AgentPrimaryCta extends StatefulWidget {
  const _AgentPrimaryCta({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_AgentPrimaryCta> createState() => _AgentPrimaryCtaState();
}

class _AgentPrimaryCtaState extends State<_AgentPrimaryCta> {
  bool _pressed = false;

  String _labelWithArrow() {
    final t = widget.label.trim();
    if (t.endsWith('→')) return t;
    return '$t →';
  }

  @override
  Widget build(BuildContext context) {
    final base = SwimDsTokens.primaryPurple;
    final pressedColor =
        Color.lerp(base, Colors.black, _pressed ? 0.14 : 0)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: pressedColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: SwimDsTokens.cardShadowSoft,
            ),
            alignment: Alignment.center,
            child: Text(
              _labelWithArrow(),
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
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
