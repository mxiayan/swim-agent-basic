import '/app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/theme/lavender_indigo_tokens.dart';
import '/theme/swim_ui_tokens.dart';
import '/theme/obsidian_volt_tokens.dart';
import 'agent_home_data.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Agent home — shared elevated shadow (Change 7).
final List<BoxShadow> _agentHomeElevatedShadow = [
  BoxShadow(
    color: const Color(0xFF6366F1).withValues(alpha: 0.10),
    offset: const Offset(0, 4),
    blurRadius: 16,
    spreadRadius: 0,
  ),
];

/// Exact page canvas for Agent tab (Change 1).
const Color _kAgentPageBackground = Color(0xFFECEFFE);

/// Side margins for Agent home scroll content (target ~24 vs legacy 18).
const double _kAgentHomeHInset = 24.0;

/// Next schedule hero — tighter radius than 24, thick white rim (matches task cards).
const double _kHeroCardRadius = 18.0;

/// Task overview cards — slightly smaller corners + white stroke.
const double _kTaskCardRadius = 15.0;

/// Upcoming activity rows — outer white frame corner radius.
const double _kUpcomingRowOuterRadius = 6.0;

/// Prominent white rim on Agent dashboard content cards.
const double _kAgentCardWhiteBorder = 10.0;

/// Inner lavender panel inset (white gutter painted via decoration fill).
const EdgeInsets _kUpcomingInnerFramePadding =
    EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0);

/// ListView cross-axis extent for task cards (content + vertical white border).
const double _kTaskCarouselViewportHeight = 268.0;

const BorderRadius _kTaskPreviewTopRadius = BorderRadius.only(
  topLeft: Radius.circular(16),
  topRight: Radius.circular(16),
);

String _taskThumbnailResolvedUri(AgentTaskOverviewItem item) {
  final raw = item.thumbnailUrl?.trim();
  if (raw != null && raw.isNotEmpty) {
    return raw;
  }
  return 'https://via.placeholder.com/300x120/818CF8/FFFFFF?text=${Uri.encodeComponent(item.title)}';
}

Widget _agentTaskThumbnailGradientBackdrop(AgentTaskOverviewItem item) {
  final cs = item.previewColors;
  final colors = cs.length >= 2
      ? <Color>[cs[0], cs[1]]
      : <Color>[const Color(0xFF818CF8), const Color(0xFF6366F1)];
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
    ),
  );
}

Widget _agentTaskPreviewTop(AgentTaskOverviewItem item) {
  final uri = _taskThumbnailResolvedUri(item);
  return ClipRRect(
    borderRadius: _kTaskPreviewTopRadius,
    child: SizedBox(
      height: 120,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: _agentTaskThumbnailGradientBackdrop(item),
          ),
          Image.network(
            uri,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 120,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return const SizedBox.shrink();
            },
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}

/// Agent-first home — lavender dashboard layout (mock sections until wired to backend).
class AgentHomeWidget extends StatefulWidget {
  const AgentHomeWidget({
    super.key,
    this.userDisplayName,
    this.avatarAssetPath = 'assets/images/mcroskey-headshot.jpg',
  });

  /// Parent display name from Firestore; first token used in greeting.
  final String? userDisplayName;

  /// Circular avatar image path for the greeting row (Change 2).
  final String avatarAssetPath;

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
        return ObsidianVoltTokens.dangerCta;
      case AgentBriefingPriority.deadlineSoon:
        return ObsidianVoltTokens.urgentCta;
      case AgentBriefingPriority.informational:
        return ObsidianVoltTokens.accent;
      case AgentBriefingPriority.aiInsight:
        return ObsidianVoltTokens.eventAdminDot;
    }
  }

  Color _priorityTint(AgentBriefingPriority p) {
    switch (p) {
      case AgentBriefingPriority.urgent:
        return ObsidianVoltTokens.dangerCardBg;
      case AgentBriefingPriority.deadlineSoon:
        return ObsidianVoltTokens.urgentCardBg;
      case AgentBriefingPriority.informational:
        return ObsidianVoltTokens.accentBg;
      case AgentBriefingPriority.aiInsight:
        return ObsidianVoltTokens.eventAdminCardTint;
    }
  }

  AgentTimelineItem? _pickHeroTimelineItem(List<AgentTimelineItem> items) {
    for (final t in items) {
      if (t.type == AgentTimelineKind.meet) {
        return t;
      }
    }
    for (final t in items) {
      if (t.type == AgentTimelineKind.practice) {
        return t;
      }
    }
    return items.isEmpty ? null : items.first;
  }

  void _handleTimelineTap(AgentTimelineItem item) {
    switch (item.type) {
      case AgentTimelineKind.meet:
        _routeFromTarget(AgentNavTargetType.meet, targetId: item.targetId);
        break;
      case AgentTimelineKind.deadline:
        _routeFromTarget(AgentNavTargetType.deadline, targetId: item.targetId);
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
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    final primary = theme.primary;

    final briefing = AgentHomeMockData.briefingItems();
    final timeline = AgentHomeMockData.timelineItems();
    final tasks = AgentHomeMockData.taskOverviewItems();
    final insights = AgentHomeMockData.insights();
    final updates = AgentHomeMockData.recentUpdates();
    final heroItem = _pickHeroTimelineItem(timeline);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _kAgentPageBackground,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(_kAgentHomeHInset, 8, _kAgentHomeHInset, _bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashboardHelloBar(
              firstName: _firstName(),
              avatarAssetPath: widget.avatarAssetPath,
              onBellTap: () => _placeholderChip('Notifications'),
            ),
            const SizedBox(height: 24),
            _NextScheduleHeroCard(
              item: heroItem,
              onTap: heroItem != null
                  ? () => _handleTimelineTap(heroItem)
                  : () => _routeFromTarget(AgentNavTargetType.schedule),
            ),
            const SizedBox(height: 22),
            _SectionTitleRow(
              title: 'Task overview',
              actionLabel: 'See All',
              onAction: () => _placeholderChip('Task overview'),
            ),
            const SizedBox(height: 12),
            _TaskOverviewCarousel(
              items: tasks,
              onCardTap: (id) => _placeholderChip('Open task $id'),
            ),
            const SizedBox(height: 24),
            _SectionTitleRow(
              title: 'Upcoming activity',
              actionLabel: 'See All',
              onAction: () => _routeFromTarget(AgentNavTargetType.schedule),
            ),
            const SizedBox(height: 12),
            _UpcomingActivityStripeList(
              items: timeline,
              onItemTap: _handleTimelineTap,
              onMenuTap: (item) => _placeholderChip('${item.title} · menu'),
            ),
            const SizedBox(height: 24),
            _PriorityBriefingSection(
              count: briefing.length,
              items: briefing,
              priorityAccent: _priorityAccent,
              priorityTint: _priorityTint,
              onItemTap: (item) =>
                  _routeFromTarget(item.targetType, targetId: item.targetId),
            ),
            const SizedBox(height: 24),
            _AskSwimAgentSection(
              controller: _askController,
              primaryBlue: primary,
              onSubmit: _placeholderAskSubmit,
              onChip: _placeholderChip,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: primary),
                const SizedBox(width: 8),
                Text(
                  'SwimAgent noticed',
                  style: GoogleFonts.sora(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
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
            const SizedBox(height: 24),
            Text(
              'Recent Updates',
              style: GoogleFonts.sora(
                fontSize: 17,
                fontWeight: FontWeight.w600,
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

class _DashboardHelloBar extends StatelessWidget {
  const _DashboardHelloBar({
    required this.firstName,
    required this.avatarAssetPath,
    this.onBellTap,
  });

  final String firstName;
  final String avatarAssetPath;
  final VoidCallback? onBellTap;

  static const Color _greetingText = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  avatarAssetPath,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 36,
                    height: 36,
                    color: LavenderIndigoTokens.primarySoft,
                    child: Icon(
                      Icons.person_rounded,
                      color: LavenderIndigoTokens.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hello $firstName! 👋',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _greetingText,
                  ),
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onBellTap,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 22,
                    color: _greetingText,
                  ),
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _kAgentPageBackground,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroMetaChip extends StatelessWidget {
  const _HeroMetaChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  static final Color _chipFg = Colors.white.withValues(alpha: 0.90);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _chipFg),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.sora(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: _chipFg,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextScheduleHeroCard extends StatelessWidget {
  const _NextScheduleHeroCard({
    required this.item,
    required this.onTap,
  });

  final AgentTimelineItem? item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item?.title ?? 'Nothing on deck yet';
    final subtitle = item?.summary ?? 'Pull full calendar from Schedule.';
    final when = item?.dateLabel ?? 'Soon';

    return Material(
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(_kHeroCardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_kHeroCardRadius),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LavenderIndigoTokens.heroGradient,
            borderRadius: BorderRadius.circular(_kHeroCardRadius),
            border: Border.all(
              color: Colors.white,
              width: _kAgentCardWhiteBorder,
            ),
            boxShadow: _agentHomeElevatedShadow,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 58, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next schedule',
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _HeroMetaChip(
                          icon: Icons.calendar_today_rounded,
                          text: when,
                        ),
                        const SizedBox(width: 8),
                        _HeroMetaChip(
                          icon: Icons.schedule_rounded,
                          text: subtitle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.push_pin_outlined,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitleRow extends StatelessWidget {
  const _SectionTitleRow({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.sora(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: SwimUiTokens.textTitle,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: LavenderIndigoTokens.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _TaskOverviewCarousel extends StatelessWidget {
  const _TaskOverviewCarousel({
    required this.items,
    required this.onCardTap,
  });

  final List<AgentTaskOverviewItem> items;
  final void Function(String id) onCardTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kTaskCarouselViewportHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final it = items[i];
          return _TaskOverviewCard(item: it, onTap: () => onCardTap(it.id));
        },
      ),
    );
  }
}

class _TaskOverviewCard extends StatelessWidget {
  const _TaskOverviewCard({
    required this.item,
    required this.onTap,
  });

  final AgentTaskOverviewItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(_kTaskCardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_kTaskCardRadius),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: LavenderIndigoTokens.bgSurface,
            borderRadius: BorderRadius.circular(_kTaskCardRadius),
            border: Border.all(
              color: Colors.white,
              width: _kAgentCardWhiteBorder,
            ),
            boxShadow: _agentHomeElevatedShadow,
          ),
          child: SizedBox(
            width: 218,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kTaskCardRadius),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _agentTaskPreviewTop(item),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.sora(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                      color: const Color(0xFF1A1A2E),
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {},
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(
                                  Icons.more_horiz,
                                  size: 18,
                                  color: Color(0xFFC5C8DC),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Row(
                        children: [
                          _TaskAvatarPhotoStack(
                            assetPaths: item.avatarPhotoAssets,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Progress',
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF8B8FA8),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: item.progressPercent / 100.0,
                                minHeight: 6,
                                backgroundColor:
                                    LavenderIndigoTokens.primarySoft,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  LavenderIndigoTokens.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${item.progressPercent}%',
                            style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: LavenderIndigoTokens.primary,
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
        ),
      ),
    );
  }
}

class _TaskAvatarPhotoStack extends StatelessWidget {
  const _TaskAvatarPhotoStack({required this.assetPaths});

  final List<String> assetPaths;

  static const double _size = 28;
  static const double _overlap = 8;

  @override
  Widget build(BuildContext context) {
    final paths = assetPaths.take(3).toList();
    if (paths.isEmpty) {
      return const SizedBox.shrink();
    }
    final step = _size - _overlap;
    final totalWidth = _size + (paths.length - 1) * step;
    return SizedBox(
      width: totalWidth,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < paths.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipOval(
                  child: Image.asset(
                    paths[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: LavenderIndigoTokens.primarySoft,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.person_rounded,
                        size: 14,
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

class _UpcomingActivityStripeList extends StatelessWidget {
  const _UpcomingActivityStripeList({
    required this.items,
    required this.onItemTap,
    required this.onMenuTap,
  });

  final List<AgentTimelineItem> items;
  final void Function(AgentTimelineItem item) onItemTap;
  final void Function(AgentTimelineItem item) onMenuTap;

  static final List<Color> _stripePalette = [
    LavenderIndigoTokens.primary,
    LavenderIndigoTokens.accentYellow,
    LavenderIndigoTokens.accentPink,
  ];

  Color _stripeAt(int i) => _stripePalette[i % _stripePalette.length];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final stripe = _stripeAt(i);
        final timeLine = '${item.dateLabel} · ${item.summary}';
        return Padding(
          padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(_kUpcomingRowOuterRadius),
              border: Border.all(
                color: Colors.white,
                width: _kAgentCardWhiteBorder,
              ),
              boxShadow: _agentHomeElevatedShadow,
            ),
            child: Padding(
              padding: _kUpcomingInnerFramePadding,
              child: ColoredBox(
                color: _kAgentPageBackground,
                child: Material(
                  color: Colors.transparent,
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.zero,
                    onTap: () => onItemTap(item),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: stripe),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 14, 4, 14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.title,
                                        style: GoogleFonts.sora(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: SwimUiTokens.textTitle,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        timeLine,
                                        style: GoogleFonts.sora(
                                          fontSize: 13,
                                          height: 1.35,
                                          fontWeight: FontWeight.w500,
                                          color: stripe.withValues(alpha: 0.88),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.more_horiz_rounded,
                                  color: SwimUiTokens.textMuted,
                                ),
                                onPressed: () => onMenuTap(item),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: SwimUiTokens.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white,
          width: _kAgentCardWhiteBorder,
        ),
        boxShadow: _agentHomeElevatedShadow,
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
              fontWeight: FontWeight.w600,
              color: SwimUiTokens.textBannerTitle,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(items.length, (i) {
            final item = items[i];
            final accent = priorityAccent(item.priority);
            final tint = priorityTint(item.priority);
            final isRiskStripe =
                item.priority == AgentBriefingPriority.deadlineSoon ||
                    item.priority == AgentBriefingPriority.urgent;
            final clipRadius = isRiskStripe
                ? const BorderRadius.only(
                    topRight: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  )
                : BorderRadius.circular(14);
            final Color leftStripeColor =
                item.priority == AgentBriefingPriority.urgent
                    ? ObsidianVoltTokens.dangerLeftBorder
                    : ObsidianVoltTokens.urgentLeftBorder;

            Widget cardBody(EdgeInsets pad) {
              return Padding(
                padding: pad,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.sora(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => onItemTap(item),
                        style: TextButton.styleFrom(
                          foregroundColor: accent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.ctaLabel,
                              style: GoogleFonts.sora(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
              child: ClipRRect(
                borderRadius: clipRadius,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: clipRadius,
                    onTap: () => onItemTap(item),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: Colors.white,
                          width: _kAgentCardWhiteBorder,
                        ),
                      ),
                      child: isRiskStripe
                          ? Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: 2.5,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: leftStripeColor,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 2.5),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: cardBody(
                                          const EdgeInsets.fromLTRB(
                                            14,
                                            14,
                                            14,
                                            12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(width: 14),
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Container(
                                      width: 4,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: accent,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: cardBody(
                                    const EdgeInsets.fromLTRB(0, 14, 14, 12),
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
            color: ObsidianVoltTokens.chatInputBg,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: ObsidianVoltTokens.chatInputBorder),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 20, color: ObsidianVoltTokens.chatSendIcon.withValues(alpha: 0.85)),
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
                      color: ObsidianVoltTokens.chatPlaceholder,
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
                icon: Icon(Icons.send_rounded,
                    color: ObsidianVoltTokens.chatSendIcon),
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
                      color: ObsidianVoltTokens.chipText,
                    ),
                  ),
                  backgroundColor: ObsidianVoltTokens.chipBg,
                  side: BorderSide(color: ObsidianVoltTokens.chipBorder),
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
            color: SwimUiTokens.surfaceCard,
            border: Border.all(
              color: Colors.white,
              width: _kAgentCardWhiteBorder,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 20,
                  color: ObsidianVoltTokens.accent,
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
                          fontWeight: FontWeight.w600,
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
                          color: ObsidianVoltTokens.eventAdminTagText,
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
      color: SwimUiTokens.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: Colors.white,
          width: _kAgentCardWhiteBorder,
        ),
      ),
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
                  fontWeight: FontWeight.w600,
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
                      color: ObsidianVoltTokens.bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: ObsidianVoltTokens.borderDefault, width: 0.5),
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
