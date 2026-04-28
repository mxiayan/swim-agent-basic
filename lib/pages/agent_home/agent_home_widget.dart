import '/app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/theme/swim_ui_tokens.dart';
import 'agent_home_data.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Agent-first home: briefing, timeline, insights, and updates — mock data for now.
class AgentHomeWidget extends StatefulWidget {
  const AgentHomeWidget({
    super.key,
    this.userDisplayName,
  });

  /// Parent display name from Firestore; first token used in greeting.
  final String? userDisplayName;

  @override
  State<AgentHomeWidget> createState() => _AgentHomeWidgetState();
}

class _AgentHomeWidgetState extends State<AgentHomeWidget> {
  late TextEditingController _askController;

  static const double _bottomInset = 88.0;

  @override
  void initState() {
    super.initState();
    _askController = TextEditingController();
  }

  @override
  void dispose() {
    _askController.dispose();
    super.dispose();
  }

  String _firstName() {
    final raw = widget.userDisplayName?.trim();
    if (raw == null || raw.isEmpty) {
      return 'there';
    }
    final parts = raw.split(RegExp(r'\s+'));
    return parts.first;
  }

  String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _placeholderChip(String label) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Coming soon: “$label”',
          style: GoogleFonts.sora(fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _placeholderAskSubmit() {
    final q = _askController.text.trim();
    _placeholderChip(q.isEmpty ? 'Ask SwimAgent' : q);
  }

  void _routeFromTarget(AgentNavTargetType type, {String? targetId}) {
    switch (type) {
      case AgentNavTargetType.meet:
        FFAppState().update(() => FFAppState().activeTab = 2);
        break;
      case AgentNavTargetType.job:
        FFAppState().update(() => FFAppState().activeTab = 3);
        break;
      case AgentNavTargetType.schedule:
      case AgentNavTargetType.practice:
      case AgentNavTargetType.deadline:
        FFAppState().update(() => FFAppState().activeTab = 1);
        break;
      case AgentNavTargetType.swimmer:
        FFAppState().update(() => FFAppState().activeTab = 4);
        break;
      case AgentNavTargetType.announcement:
        FFAppState().update(() => FFAppState().activeTab = 1);
        break;
      case AgentNavTargetType.unknown:
        break;
    }
    final id = targetId != null ? ' ($targetId)' : '';
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Opened related tab · detail route placeholder$id',
          style: GoogleFonts.sora(fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _priorityAccent(AgentBriefingPriority p) {
    switch (p) {
      case AgentBriefingPriority.urgent:
        return const Color(0xFFE11D48);
      case AgentBriefingPriority.deadlineSoon:
        return const Color(0xFFF59E0B);
      case AgentBriefingPriority.informational:
        return FlutterFlowTheme.of(context).primary;
      case AgentBriefingPriority.aiInsight:
        return const Color(0xFF7C3AED);
    }
  }

  Color _priorityTint(AgentBriefingPriority p) {
    switch (p) {
      case AgentBriefingPriority.urgent:
        return const Color(0xFFFFF1F2);
      case AgentBriefingPriority.deadlineSoon:
        return const Color(0xFFFFFBEB);
      case AgentBriefingPriority.informational:
        return const Color(0xFFEFF6FF);
      case AgentBriefingPriority.aiInsight:
        return const Color(0xFFF5F3FF);
    }
  }

  IconData _timelineDotIcon(AgentTimelineKind t) {
    switch (t) {
      case AgentTimelineKind.practice:
        return Icons.pool_outlined;
      case AgentTimelineKind.deadline:
        return Icons.event_busy_outlined;
      case AgentTimelineKind.meet:
        return Icons.emoji_events_outlined;
      case AgentTimelineKind.announcement:
        return Icons.campaign_outlined;
      case AgentTimelineKind.other:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    final primary = theme.primary;

    final briefing = AgentHomeMockData.briefingItems();
    final timeline = AgentHomeMockData.timelineItems();
    final insights = AgentHomeMockData.insights();
    final updates = AgentHomeMockData.recentUpdates();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8FAFC),
            Color(0xFFF1F5F9),
          ],
        ),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, _bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SmartHeader(
              greeting: '${_timeGreeting()}, ${_firstName()}',
              subtitle: 'Here’s what needs your attention this week',
              statusLine: 'SwimAgent checked OAPB updates 12 minutes ago',
              primaryBlue: primary,
            ),
            const SizedBox(height: 18),
            _PriorityBriefingSection(
              count: briefing.length,
              items: briefing,
              priorityAccent: _priorityAccent,
              priorityTint: _priorityTint,
              onItemTap: (item) =>
                  _routeFromTarget(item.targetType, targetId: item.targetId),
            ),
            const SizedBox(height: 18),
            _AskSwimAgentSection(
              controller: _askController,
              primaryBlue: primary,
              onSubmit: _placeholderAskSubmit,
              onChip: _placeholderChip,
            ),
            const SizedBox(height: 20),
            Text(
              'Coming Up',
              style: GoogleFonts.sora(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: SwimUiTokens.textTitle,
              ),
            ),
            const SizedBox(height: 10),
            _ComingUpTimeline(
              items: timeline,
              dotIcon: _timelineDotIcon,
              onLineTap: (item) {
                switch (item.type) {
                  case AgentTimelineKind.meet:
                    _routeFromTarget(AgentNavTargetType.meet,
                        targetId: item.targetId);
                    break;
                  case AgentTimelineKind.deadline:
                    _routeFromTarget(AgentNavTargetType.deadline,
                        targetId: item.targetId);
                    break;
                  case AgentTimelineKind.practice:
                    _routeFromTarget(AgentNavTargetType.practice);
                    break;
                  case AgentTimelineKind.announcement:
                    _routeFromTarget(AgentNavTargetType.announcement);
                    break;
                  case AgentTimelineKind.other:
                    _placeholderChip(item.title);
                    break;
                }
              },
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: primary),
                const SizedBox(width: 8),
                Text(
                  'SwimAgent noticed',
                  style: GoogleFonts.sora(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: SwimUiTokens.textTitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Short reads based on your meet and team signals.',
              style: GoogleFonts.sora(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w400,
                color: SwimUiTokens.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            ...insights.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InsightCard(
                  item: e,
                  primaryBlue: primary,
                  onTap: () => _placeholderChip(e.title),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Recent Updates',
              style: GoogleFonts.sora(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: SwimUiTokens.textTitle,
              ),
            ),
            const SizedBox(height: 10),
            ...updates.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecentUpdateTile(
                  item: e,
                  onTap: () =>
                      _routeFromTarget(e.targetType, targetId: e.targetId),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartHeader extends StatelessWidget {
  const _SmartHeader({
    required this.greeting,
    required this.subtitle,
    required this.statusLine,
    required this.primaryBlue,
  });

  final String greeting;
  final String subtitle;
  final String statusLine;
  final Color primaryBlue;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: GoogleFonts.sora(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: SwimUiTokens.textTitle,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: GoogleFonts.sora(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                  color: SwimUiTokens.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SwimUiTokens.borderSubtle),
                  boxShadow: SwimUiTokens.shadowCard,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded,
                        size: 16, color: primaryBlue.withValues(alpha: 0.9)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        statusLine,
                        style: GoogleFonts.sora(
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: SwimUiTokens.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _AgentOrb(primaryBlue: primaryBlue),
      ],
    );
  }
}

class _AgentOrb extends StatelessWidget {
  const _AgentOrb({required this.primaryBlue});

  final Color primaryBlue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            primaryBlue.withValues(alpha: 0.35),
            primaryBlue.withValues(alpha: 0.08),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 2,
        ),
      ),
      child: Icon(
        Icons.psychology_rounded,
        color: primaryBlue,
        size: 28,
      ),
    );
  }
}

class _PriorityBriefingSection extends StatelessWidget {
  const _PriorityBriefingSection({
    required this.count,
    required this.items,
    required this.priorityAccent,
    required this.priorityTint,
    required this.onItemTap,
  });

  final int count;
  final List<AgentBriefingItem> items;
  final Color Function(AgentBriefingPriority) priorityAccent;
  final Color Function(AgentBriefingPriority) priorityTint;
  final void Function(AgentBriefingItem) onItemTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: SwimUiTokens.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: SwimUiTokens.shadowCardLift,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 1
                ? '1 thing needs attention'
                : '$count things need attention',
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SwimUiTokens.textBannerTitle,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(items.length, (i) {
            final item = items[i];
            final accent = priorityAccent(item.priority);
            final tint = priorityTint(item.priority);
            return Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onItemTap(item),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: GoogleFonts.sora(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                        color: SwimUiTokens.textTitle,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.summary,
                                      style: GoogleFonts.sora(
                                        fontSize: 13,
                                        height: 1.35,
                                        fontWeight: FontWeight.w400,
                                        color: SwimUiTokens.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => onItemTap(item),
                              style: TextButton.styleFrom(
                                foregroundColor: accent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.ctaLabel,
                                    style: GoogleFonts.sora(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded,
                                      size: 16, color: accent),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AskSwimAgentSection extends StatelessWidget {
  const _AskSwimAgentSection({
    required this.controller,
    required this.primaryBlue,
    required this.onSubmit,
    required this.onChip,
  });

  final TextEditingController controller;
  final Color primaryBlue;
  final VoidCallback onSubmit;
  final void Function(String) onChip;

  static const List<String> _chips = [
    'What do I need to do this week?',
    'Any deadlines?',
    'Show my next meet',
    'What changed recently?',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SwimUiTokens.borderSubtle),
            boxShadow: SwimUiTokens.shadowCard,
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 20, color: primaryBlue.withValues(alpha: 0.85)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    color: SwimUiTokens.textTitle,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask SwimAgent anything…',
                    hintStyle: GoogleFonts.sora(
                      fontSize: 14,
                      color: SwimUiTokens.textFaint,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              IconButton(
                onPressed: onSubmit,
                icon: Icon(Icons.send_rounded, color: primaryBlue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _chips
              .map(
                (c) => ActionChip(
                  label: Text(
                    c,
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: SwimUiTokens.textTitle,
                    ),
                  ),
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: BorderSide(color: SwimUiTokens.borderSubtle),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: () => onChip(c),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ComingUpTimeline extends StatelessWidget {
  const _ComingUpTimeline({
    required this.items,
    required this.dotIcon,
    required this.onLineTap,
  });

  final List<AgentTimelineItem> items;
  final IconData Function(AgentTimelineKind) dotIcon;
  final void Function(AgentTimelineItem) onLineTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SwimUiTokens.borderSubtle),
        boxShadow: SwimUiTokens.shadowCard,
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final last = i == items.length - 1;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onLineTap(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 36,
                    child: Column(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: SwimUiTokens.borderSubtle,
                            ),
                          ),
                          child: Icon(
                            dotIcon(item.type),
                            size: 16,
                            color: SwimUiTokens.accentBlueSheet,
                          ),
                        ),
                        if (!last)
                          Container(
                            width: 2,
                            height: 44,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  SwimUiTokens.borderSubtle,
                                  SwimUiTokens.borderSubtle
                                      .withValues(alpha: 0.2),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.dateLabel,
                          style: GoogleFonts.sora(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: SwimUiTokens.textFaint,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.title,
                          style: GoogleFonts.sora(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: SwimUiTokens.textTitle,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.summary,
                          style: GoogleFonts.sora(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w400,
                            color: SwimUiTokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.item,
    required this.primaryBlue,
    required this.onTap,
  });

  final AgentInsightItem item;
  final Color primaryBlue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF8F5FF),
                primaryBlue.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFC4B5FD).withValues(alpha: 0.45),
            ),
            boxShadow: SwimUiTokens.shadowCard,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 20,
                  color: const Color(0xFF7C3AED),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SwimUiTokens.textTitle,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.summary,
                        style: GoogleFonts.sora(
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w400,
                          color: SwimUiTokens.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.sourceType,
                        style: GoogleFonts.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              const Color(0xFF7C3AED).withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentUpdateTile extends StatelessWidget {
  const _RecentUpdateTile({
    required this.item,
    required this.onTap,
  });

  final AgentRecentUpdateItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SwimUiTokens.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: SwimUiTokens.textTitle,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.summary,
                style: GoogleFonts.sora(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                  color: SwimUiTokens.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SwimUiTokens.borderSubtle),
                    ),
                    child: Text(
                      'Detected from ${item.source}',
                      style: GoogleFonts.sora(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: SwimUiTokens.textMuted,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.detectedAt,
                    style: GoogleFonts.sora(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: SwimUiTokens.textFaint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
