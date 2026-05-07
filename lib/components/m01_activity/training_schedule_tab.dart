import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '/app_state.dart';
import '/backend/schedule_baseline.dart';
import '/components/m01_activity/schedule_training_parse.dart';
import '/components/m01_activity/team_events_schedule.dart'
    show readableScheduleBaselineBodyWidgets;
import '/theme/lavender_indigo_tokens.dart';
import '/theme/swim_design_tokens.dart';
import '/theme/swim_ui_tokens.dart';
import '/theme/obsidian_volt_tokens.dart';
import '/widgets/swim_ui_kit.dart';

final Color _kDrylandPurple = ObsidianVoltTokens.eventAdminDot;

const _weekDaysFull = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _weekDaysAbbr = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

Color _groupListAccent(int index) {
  final palette = <Color>[
    ObsidianVoltTokens.eventAdminDot,
    ObsidianVoltTokens.accent,
    ObsidianVoltTokens.eventMeetDot,
    ObsidianVoltTokens.eventTrainingDot,
    ObsidianVoltTokens.textSecondary,
  ];
  return palette[index % palette.length];
}

String _sessionCellForDay(
  TrainingGroupDisplayModel g,
  String fullDay,
  TrainingSessionKind kind,
) {
  TrainingDayDisplayModel? hit;
  for (final d in g.days) {
    if (d.dayOfWeek == fullDay) {
      hit = d;
      break;
    }
  }
  if (hit == null) return '—';
  final lines = <String>[];
  for (final s in hit.sessions) {
    if (s.kind != kind) continue;
    var line = s.timeText.trim().isEmpty ? '—' : s.timeText.trim();
    if (s.isOptional) line = '$line (Optional)';
    lines.add(line);
  }
  return lines.isEmpty ? '—' : lines.join('\n');
}

/// Heuristic AM/PM for schedule strings that omit meridiem (youth swim context).
bool _inferMeridiemPm(int h1, int h2, {required bool dryland}) {
  if (h1 >= 3 && h1 <= 4) return true;
  if (dryland) {
    if (h1 >= 10 && h1 <= 11) return false;
    if (h1 == 5 && h2 == 6) return true;
    if (h1 >= 5 && h1 <= 9) return true;
    return h1 >= 12;
  }
  if (h1 == 7 && h2 >= 10) return false;
  if (h1 >= 5 && h1 <= 8 && h2 <= 10) return false;
  return h1 >= 12;
}

String _formatClock12(int hour12, int minute, bool isPm) {
  var h = hour12 % 12;
  if (h == 0) h = 12;
  final ap = isPm ? 'PM' : 'AM';
  if (minute == 0) return '$h $ap';
  final mm = minute.toString().padLeft(2, '0');
  return '$h:$mm $ap';
}

String _formatSingleTimeRange(String rawRange, {required bool dryland}) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})\s*[–\-]\s*(\d{1,2}):(\d{2})$')
      .firstMatch(rawRange.trim());
  if (m == null) return rawRange;
  final h1 = int.parse(m.group(1)!);
  final mi1 = int.parse(m.group(2)!);
  final h2 = int.parse(m.group(3)!);
  final mi2 = int.parse(m.group(4)!);
  final isPm = _inferMeridiemPm(h1, h2, dryland: dryland);
  return '${_formatClock12(h1, mi1, isPm)}–${_formatClock12(h2, mi2, isPm)}';
}

String _formatLineWithAmPm(String line, {required bool dryland}) {
  final rx = RegExp(r'\d{1,2}:\d{2}\s*[–\-]\s*\d{1,2}:\d{2}');
  return line.replaceAllMapped(
    rx,
    (match) => _formatSingleTimeRange(match.group(0)!, dryland: dryland),
  );
}

String _formatScheduleCellWithAmPm(String raw, {required bool drylandColumn}) {
  if (raw.trim() == '—' || raw.isEmpty) return raw;
  final out = StringBuffer();
  final optRx = RegExp(r'\s*\(Optional\)\s*$');
  for (final line in raw.split('\n')) {
    if (out.isNotEmpty) out.writeln();
    final trimmed = line.trimRight();
    final hasOpt = optRx.hasMatch(trimmed);
    final core =
        hasOpt ? trimmed.replaceFirst(optRx, '').trim() : trimmed;
    out.write(_formatLineWithAmPm(core, dryland: drylandColumn));
    if (hasOpt) out.write(' (Optional)');
  }
  return out.toString();
}

/// Training Schedule tab: season documents + weekly-by-group layout.
class TrainingScheduleTabContent extends StatefulWidget {
  const TrainingScheduleTabContent({
    super.key,
    required this.baselines,
    required this.primary,
    required this.bottomPad,
  });

  final List<ScheduleBaseline> baselines;
  final Color primary;
  final double bottomPad;

  @override
  State<TrainingScheduleTabContent> createState() =>
      _TrainingScheduleTabContentState();
}

class _TrainingScheduleTabContentState extends State<TrainingScheduleTabContent> {
  late int _baselineIdx;
  int _segment = 0;
  bool _seasonNotesExpanded = true;
  Map<String, bool>? _expandedByGroupId;
  String? _expandedLayoutForSwimmerKey;

  @override
  void initState() {
    super.initState();
    _baselineIdx = _pickBaselineIdx(widget.baselines);
  }

  @override
  void didUpdateWidget(covariant TrainingScheduleTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_baselineListEq(oldWidget.baselines, widget.baselines)) {
      _baselineIdx = _pickBaselineIdx(widget.baselines);
      if (_baselineIdx >= widget.baselines.length) {
        _baselineIdx = widget.baselines.isEmpty ? 0 : widget.baselines.length - 1;
      }
      _expandedByGroupId = null;
      _expandedLayoutForSwimmerKey = null;
    }
    if (widget.baselines.isNotEmpty &&
        _baselineIdx >= widget.baselines.length) {
      _baselineIdx = _pickBaselineIdx(widget.baselines);
      _expandedByGroupId = null;
      _expandedLayoutForSwimmerKey = null;
    }
  }

  int _pickBaselineIdx(List<ScheduleBaseline> list) {
    if (list.isEmpty) return 0;
    final today = DateTime.now();
    for (var i = 0; i < list.length; i++) {
      if (baselineCoversDate(list[i], today)) return i;
    }
    return 0;
  }

  bool _baselineListEq(List<ScheduleBaseline> a, List<ScheduleBaseline> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].title != b[i].title ||
          a[i].body != b[i].body) {
        return false;
      }
    }
    return true;
  }

  void _ensureExpandedDefaults(List<TrainingGroupDisplayModel> groups) {
    if (groups.isEmpty) return;
    final swimmer = FFAppState().currentSwimmerGroup;
    if (_expandedByGroupId != null &&
        _expandedLayoutForSwimmerKey == swimmer &&
        _expandedByGroupId!.length == groups.length &&
        groups.every((g) => _expandedByGroupId!.containsKey(g.id))) {
      return;
    }
    final next = <String, bool>{};
    var matched = false;
    for (final g in groups) {
      final hit = groupLikelyMatchesSwimmerGroup(g.name, swimmer);
      final expand = hit && !matched;
      if (hit && !matched) matched = true;
      next[g.id] = expand;
    }
    if (!matched) {
      next[groups.first.id] = true;
      for (var i = 1; i < groups.length; i++) {
        next[groups[i].id] = false;
      }
    }
    _expandedByGroupId = next;
    _expandedLayoutForSwimmerKey = swimmer;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    if (widget.baselines.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              SwimDsTokens.pageHorizontalPadding,
              48,
              SwimDsTokens.pageHorizontalPadding,
              widget.bottomPad,
            ),
            sliver: const SliverToBoxAdapter(
              child: _TrainingEmpty(),
            ),
          ),
        ],
      );
    }

    final baseline = widget.baselines[_baselineIdx.clamp(0, widget.baselines.length - 1)];
    final parsed = parseSeasonTrainingBody(baseline.body);
    _ensureExpandedDefaults(parsed.groups);

    final today = DateTime.now();
    final status = baselineStatusLabel(baseline, today);
    final rangeUi = formatBaselineDateRangeUi(baseline);
    final combinedForUrl = '${baseline.notes}\n${baseline.body}';
    final docUrl = extractFirstHttpUrl(combinedForUrl);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (widget.baselines.length > 1)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 96,
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  SwimDsTokens.pageHorizontalPadding,
                  10,
                  SwimDsTokens.pageHorizontalPadding,
                  6,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: widget.baselines.length,
                separatorBuilder: (_, __) =>
                    SizedBox(width: SwimDsTokens.cardSpacing),
                itemBuilder: (ctx, i) {
                  final b = widget.baselines[i];
                  final sel = i == _baselineIdx;
                  final r = formatBaselineDateRangeUi(b);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _baselineIdx = i;
                        _expandedByGroupId = null;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 212,
                      padding: const EdgeInsets.all(SwimDsTokens.cardPadding - 2),
                      decoration: BoxDecoration(
                        color: sel
                            ? LavenderIndigoTokens.primarySoft
                                .withValues(alpha: 0.55)
                            : SwimDsTokens.cardBackground,
                        borderRadius:
                            BorderRadius.circular(SwimDsTokens.cardRadius),
                        border: Border.all(
                          color: sel
                              ? LavenderIndigoTokens.primary
                                  .withValues(alpha: 0.45)
                              : SwimDsTokens.borderSoft,
                          width: sel ? 1.5 : 1,
                        ),
                        boxShadow: SwimDsTokens.cardShadowSoft,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sora(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              color: SwimUiTokens.textBannerTitle,
                            ),
                          ),
                          const Spacer(),
                          if (r.isNotEmpty)
                            Text(
                              r,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.sora(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: SwimUiTokens.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            SwimDsTokens.pageHorizontalPadding,
            8,
            SwimDsTokens.pageHorizontalPadding,
            10,
          ),
          sliver: SliverToBoxAdapter(
            child: _SeasonScheduleHeroCard(
              title: baseline.title,
              dateRange: rangeUi,
              status: status,
              summaryNote: baseline.notes,
              primary: widget.primary,
              segment: _segment,
              notesExpanded: _seasonNotesExpanded,
              onToggleNotes: () => setState(
                () => _seasonNotesExpanded = !_seasonNotesExpanded,
              ),
              onSegmentChanged: (v) => setState(() => _segment = v),
            ),
          ),
        ),
        if (_segment == 0) ..._weeklySlivers(parsed),
        if (_segment == 1) ..._notesSlivers(baseline),
        if (docUrl != null)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              SwimDsTokens.pageHorizontalPadding,
              8,
              SwimDsTokens.pageHorizontalPadding,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _ScheduleDocumentLinkTile(
                primary: widget.primary,
                onTap: () => _openUrl(docUrl),
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.only(bottom: widget.bottomPad),
          sliver: const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ),
      ],
    );
  }

  List<Widget> _weeklySlivers(SeasonTrainingScheduleParsed parsed) {
    if (parsed.groups.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            SwimDsTokens.pageHorizontalPadding,
            12,
            SwimDsTokens.pageHorizontalPadding,
            16,
          ),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Weekly breakdown isn’t available for this schedule yet.',
              style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: SwimUiTokens.textMuted,
                height: 1.35,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          SwimDsTokens.pageHorizontalPadding,
          4,
          SwimDsTokens.pageHorizontalPadding,
          8,
        ),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Weekly schedule by group',
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: SwimUiTokens.textBannerTitle,
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          SwimDsTokens.pageHorizontalPadding,
          0,
          SwimDsTokens.pageHorizontalPadding,
          12,
        ),
        sliver: SliverToBoxAdapter(
          child: _SessionLegend(primary: widget.primary),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          SwimDsTokens.pageHorizontalPadding,
          0,
          SwimDsTokens.pageHorizontalPadding,
          12,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final g = parsed.groups[i];
              final expanded = _expandedByGroupId?[g.id] ?? false;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == parsed.groups.length - 1
                      ? 0
                      : SwimDsTokens.cardSpacing,
                ),
                child: _GroupWeeklyCard(
                  group: g,
                  groupIndex: i,
                  expanded: expanded,
                  primary: widget.primary,
                  onToggle: () {
                    setState(() {
                      _expandedByGroupId ??= {};
                      _expandedByGroupId![g.id] = !expanded;
                    });
                  },
                ),
              );
            },
            childCount: parsed.groups.length,
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          SwimDsTokens.pageHorizontalPadding,
          4,
          SwimDsTokens.pageHorizontalPadding,
          8,
        ),
        sliver: SliverToBoxAdapter(
          child: _BottomDisclaimerCard(primary: widget.primary),
        ),
      ),
    ];
  }

  List<Widget> _notesSlivers(ScheduleBaseline baseline) {
    final snippet = baselineSummarySnippet(baseline.body);
    final bodyWidgets = readableScheduleBaselineBodyWidgets(baseline.body);

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          SwimDsTokens.pageHorizontalPadding,
          0,
          SwimDsTokens.pageHorizontalPadding,
          12,
        ),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            if (snippet.trim().isNotEmpty)
              _NotesSectionCard(
                title: 'Schedule summary',
                child: Text(
                  snippet,
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    height: 1.42,
                    fontWeight: FontWeight.w500,
                    color: SwimUiTokens.textTitle,
                  ),
                ),
              ),
            if (baseline.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _NotesSectionCard(
                title: 'Important coach notes',
                child: Text(
                  baseline.notes,
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    height: 1.42,
                    fontWeight: FontWeight.w600,
                    color: SwimUiTokens.accentBlue,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _NotesSectionCard(
              title: 'Full schedule text',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...bodyWidgets.map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: w,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    ];
  }
}

class _TrainingEmpty extends StatelessWidget {
  const _TrainingEmpty();

  @override
  Widget build(BuildContext context) {
    return EmptyStateCard(
      title: 'No training schedule selected',
      message:
          'Season workout schedules will appear here once your team adds them.',
      icon: Icons.fitness_center_outlined,
    );
  }
}

class _SeasonScheduleHeroCard extends StatelessWidget {
  const _SeasonScheduleHeroCard({
    required this.title,
    required this.dateRange,
    required this.status,
    required this.summaryNote,
    required this.primary,
    required this.segment,
    required this.notesExpanded,
    required this.onToggleNotes,
    required this.onSegmentChanged,
  });

  final String title;
  final String dateRange;
  final String status;
  final String summaryNote;
  final Color primary;
  final int segment;
  final bool notesExpanded;
  final VoidCallback onToggleNotes;
  final ValueChanged<int> onSegmentChanged;

  SwimStatusPillKind _statusPillKind() {
    switch (status) {
      case 'ENDED':
        return SwimStatusPillKind.notDecided;
      case 'UPCOMING':
        return SwimStatusPillKind.deadlineSoon;
      default:
        return SwimStatusPillKind.active;
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = summaryNote.trim();

    return Container(
      decoration: BoxDecoration(
        color: SwimDsTokens.cardBackground,
        borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
        border: Border.all(color: SwimDsTokens.borderSoft, width: 1),
        boxShadow: SwimDsTokens.cardShadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.description_outlined, color: primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.sora(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          color: SwimUiTokens.textBannerTitle,
                        ),
                      ),
                      if (dateRange.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          dateRange,
                          style: GoogleFonts.sora(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: SwimUiTokens.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusPill(
                      label: status,
                      kind: _statusPillKind(),
                    ),
                    if (note.isNotEmpty)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        onPressed: onToggleNotes,
                        icon: Icon(
                          notesExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: SwimUiTokens.textMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (note.isNotEmpty)
            AnimatedCrossFade(
              firstCurve: Curves.easeOut,
              secondCurve: Curves.easeOut,
              sizeCurve: Curves.easeOut,
              duration: const Duration(milliseconds: 200),
              crossFadeState: notesExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                child: Text(
                  note,
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    height: 1.42,
                    fontWeight: FontWeight.w500,
                    color: SwimUiTokens.textTitle,
                  ),
                ),
              ),
            ),
          const Divider(height: 1),
          _TrainingInnerTabs(
            segment: segment,
            primary: primary,
            onSegmentChanged: onSegmentChanged,
          ),
        ],
      ),
    );
  }
}

class _TrainingInnerTabs extends StatelessWidget {
  const _TrainingInnerTabs({
    required this.segment,
    required this.primary,
    required this.onSegmentChanged,
  });

  final int segment;
  final Color primary;
  final ValueChanged<int> onSegmentChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab({
      required int value,
      required IconData icon,
      required String label,
    }) {
      final sel = segment == value;
      return Expanded(
        child: InkWell(
          onTap: () => onSegmentChanged(value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: sel ? primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: sel ? primary : SwimUiTokens.textMuted,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                      fontSize: 12.5,
                      fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                      color: sel ? primary : SwimUiTokens.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(
          value: 0,
          icon: Icons.calendar_month_rounded,
          label: 'Weekly Schedule',
        ),
        tab(
          value: 1,
          icon: Icons.article_outlined,
          label: 'Notes & Details',
        ),
      ],
    );
  }
}

class _ScheduleDocumentLinkTile extends StatelessWidget {
  const _ScheduleDocumentLinkTile({
    required this.primary,
    required this.onTap,
  });

  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SwimUiTokens.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SwimUiTokens.cardSurfaceEdgeBorder, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.description_outlined, color: primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Open full schedule document',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SwimUiTokens.textBannerTitle,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: SwimUiTokens.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupWeeklyTable extends StatelessWidget {
  const _GroupWeeklyTable({
    required this.group,
    required this.primary,
  });

  final TrainingGroupDisplayModel group;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    Widget headerCell(Widget child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: child,
        );

    Widget bodyCell(String text, {TextAlign align = TextAlign.left}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              text,
              textAlign: align,
              style: GoogleFonts.sora(
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: SwimUiTokens.textTitle,
              ),
            ),
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Table(
        border: TableBorder(
          horizontalInside:
              BorderSide(color: ObsidianVoltTokens.borderMuted),
        ),
        columnWidths: const {
          0: FixedColumnWidth(60),
          1: FlexColumnWidth(1.1),
          2: FlexColumnWidth(1.1),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: ObsidianVoltTokens.bgSurface),
            children: [
              headerCell(const SizedBox.shrink()),
              headerCell(
                Row(
                  children: [
                    Icon(
                      Icons.fitness_center_rounded,
                      size: 16,
                      color: _kDrylandPurple,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Dryland',
                      style: GoogleFonts.sora(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: SwimUiTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              headerCell(
                Row(
                  children: [
                    Icon(Icons.pool_rounded, size: 16, color: primary),
                    const SizedBox(width: 6),
                    Text(
                      'In-water',
                      style: GoogleFonts.sora(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: SwimUiTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          for (var i = 0; i < 7; i++)
            TableRow(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(6, 10, 6, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _weekDaysAbbr[i],
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: SwimUiTokens.textBannerTitle,
                      ),
                    ),
                  ),
                ),
                bodyCell(
                  _formatScheduleCellWithAmPm(
                    _sessionCellForDay(
                      group,
                      _weekDaysFull[i],
                      TrainingSessionKind.dryland,
                    ),
                    drylandColumn: true,
                  ),
                ),
                bodyCell(
                  _formatScheduleCellWithAmPm(
                    _sessionCellForDay(
                      group,
                      _weekDaysFull[i],
                      TrainingSessionKind.inWater,
                    ),
                    drylandColumn: false,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One compact row per weekday for mobile (replaces dense table by default).
class _GroupWeeklyMobileDays extends StatelessWidget {
  const _GroupWeeklyMobileDays({
    required this.group,
    required this.primary,
  });

  final TrainingGroupDisplayModel group;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 7; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: SwimDsTokens.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SwimDsTokens.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _weekDaysFull[i],
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: SwimUiTokens.textBannerTitle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.fitness_center_rounded,
                        size: 16,
                        color: _kDrylandPurple,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dryland: ${_formatScheduleCellWithAmPm(
                            _sessionCellForDay(
                              group,
                              _weekDaysFull[i],
                              TrainingSessionKind.dryland,
                            ),
                            drylandColumn: true,
                          )}',
                          style: GoogleFonts.sora(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: SwimUiTokens.textTitle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.pool_rounded, size: 16, color: primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'In-water: ${_formatScheduleCellWithAmPm(
                            _sessionCellForDay(
                              group,
                              _weekDaysFull[i],
                              TrainingSessionKind.inWater,
                            ),
                            drylandColumn: false,
                          )}',
                          style: GoogleFonts.sora(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: SwimUiTokens.textTitle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SessionLegend extends StatelessWidget {
  const _SessionLegend({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SwimUiTokens.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SwimUiTokens.cardSurfaceEdgeBorder, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fitness_center_rounded,
            size: 20,
            color: _kDrylandPurple,
          ),
          const SizedBox(width: 8),
          Text(
            'Dryland',
            style: GoogleFonts.sora(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SwimUiTokens.textTitle,
            ),
          ),
          const SizedBox(width: 22),
          Icon(Icons.pool_rounded, size: 20, color: primary),
          const SizedBox(width: 8),
          Text(
            'In-water',
            style: GoogleFonts.sora(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SwimUiTokens.textTitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupWeeklyCard extends StatefulWidget {
  const _GroupWeeklyCard({
    required this.group,
    required this.groupIndex,
    required this.expanded,
    required this.primary,
    required this.onToggle,
  });

  final TrainingGroupDisplayModel group;
  final int groupIndex;
  final bool expanded;
  final Color primary;
  final VoidCallback onToggle;

  @override
  State<_GroupWeeklyCard> createState() => _GroupWeeklyCardState();
}

class _GroupWeeklyCardState extends State<_GroupWeeklyCard> {
  bool _showFullTable = false;

  @override
  void didUpdateWidget(covariant _GroupWeeklyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.expanded) {
      _showFullTable = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _groupListAccent(widget.groupIndex);
    final freqLabel = widget.group.daysPerWeek > 0
        ? '${widget.group.daysPerWeek} days / week'
        : 'Schedule';

    return Material(
      color: SwimDsTokens.cardBackground,
      borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
          border: Border.all(color: SwimDsTokens.borderSoft, width: 1),
          boxShadow: SwimDsTokens.cardShadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: widget.onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(Icons.groups_rounded, color: accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.group.name,
                            style: GoogleFonts.sora(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: SwimUiTokens.textBannerTitle,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (widget.group.codePill.isNotEmpty)
                                _TinyPill(
                                  label: widget.group.codePill,
                                  fg: ObsidianVoltTokens.squadAllText,
                                  bg: ObsidianVoltTokens.squadAllBg,
                                ),
                              StatusPill(
                                label: freqLabel,
                                kind: SwimStatusPillKind.training,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      widget.expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: SwimUiTokens.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.expanded) ...[
              const Divider(height: 1),
              if (widget.group.days.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  child: Text(
                    'No weekday rows were parsed for this group.',
                    style: GoogleFonts.sora(
                      fontSize: 12.5,
                      color: SwimUiTokens.textMuted,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _GroupWeeklyMobileDays(
                        group: widget.group,
                        primary: widget.primary,
                      ),
                      TextButton(
                        onPressed: () => setState(
                          () => _showFullTable = !_showFullTable,
                        ),
                        child: Text(
                          _showFullTable ? 'Hide full table' : 'View full table',
                          style: GoogleFonts.sora(
                            fontWeight: FontWeight.w700,
                            color: SwimUiTokens.accentBlueSheet,
                          ),
                        ),
                      ),
                      if (_showFullTable)
                        _GroupWeeklyTable(
                          group: widget.group,
                          primary: widget.primary,
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomDisclaimerCard extends StatelessWidget {
  const _BottomDisclaimerCard({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ObsidianVoltTokens.accentBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ObsidianVoltTokens.accentBorder, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_rounded, color: primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Times listed are in-water times.',
                  style: GoogleFonts.sora(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: SwimUiTokens.textTitle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please arrive about 15 minutes prior to workout unless your coach says otherwise.',
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: SwimUiTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesSectionCard extends StatelessWidget {
  const _NotesSectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: SwimUiTokens.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SwimUiTokens.cardSurfaceEdgeBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.sora(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: SwimUiTokens.textBannerTitle,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({
    required this.label,
    required this.fg,
    required this.bg,
  });

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.sora(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );
  }
}
