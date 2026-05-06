import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '/backend/backend.dart';
import '/theme/swim_ui_tokens.dart';
import '/theme/obsidian_volt_tokens.dart';

// ─── Display normalization (Firestore text may lag parser_hints / coach typos) ─

String normalizeCoachLocationForUi(String location) {
  if (location.isEmpty) return location;
  var s = location;
  if (!RegExp(r'soda', caseSensitive: false).hasMatch(s)) {
    return s;
  }
  s = s.replaceAll(
    RegExp(r"\bSaint Mary's College\b", caseSensitive: false),
    'Campolindo High School',
  );
  s = s.replaceAll(
    RegExp(r"\bSt\. Mary's College\b", caseSensitive: false),
    'Campolindo High School',
  );
  s = s.replaceAll(RegExp(r'\bMorga\b', caseSensitive: false), 'Moraga');
  return s;
}

DateTime? _tryParseBaselineDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw.trim());
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

bool _baselineActiveOn(ScheduleBaseline b, DateTime day) {
  final from = _tryParseBaselineDate(b.validFrom);
  final to = _tryParseBaselineDate(b.validTo);
  final d = DateTime(day.year, day.month, day.day);
  if (from != null) {
    final fromD = DateTime(from.year, from.month, from.day);
    if (d.isBefore(fromD)) return false;
  }
  if (to != null) {
    final toD = DateTime(to.year, to.month, to.day);
    if (d.isAfter(toD)) return false;
  }
  return true;
}

List<ScheduleBaseline> _baselinesForDisplayDay(
  List<ScheduleBaseline> all,
  DateTime day,
) {
  final hit = all.where((b) => _baselineActiveOn(b, day)).toList();
  return hit.isNotEmpty ? hit : all;
}

// ─── Training squad filter (coach-email cards) ──────────────────────────────

bool _trainingMentionsJunior(TeamEventsRecord e) {
  bool textHas(String s) {
    final t = s.toLowerCase();
    return t.contains('junior') ||
        RegExp(r'\bjr\.?\b').hasMatch(t) ||
        t.contains('jr pm') ||
        t.contains('jr group');
  }

  if (textHas(e.title)) return true;
  for (final g in e.appliesToGroups) {
    if (textHas(g)) return true;
  }
  if (textHas(e.details)) return true;
  return false;
}

bool _trainingMentionsSenior(TeamEventsRecord e) {
  bool textHas(String s) {
    final t = s.toLowerCase();
    return t.contains('senior') ||
        RegExp(r'\bsr\.?\b').hasMatch(t) ||
        t.contains('sr pm') ||
        t.contains('sr group');
  }

  if (textHas(e.title)) return true;
  for (final g in e.appliesToGroups) {
    if (textHas(g)) return true;
  }
  if (textHas(e.details)) return true;
  return false;
}

// ─── OAPB standing-grid hints (pool + dryland from schedule_baselines) ─────

enum _BaselineDaypartHint { h24, pm12, am12 }

class StandingGridBaselineHints {
  const StandingGridBaselineHints({this.scheduleSummary, this.drylandLine});
  final String? scheduleSummary;
  final String? drylandLine;
}

String _clockLabel12(int hour12, String mins, {required bool isPm}) {
  assert(hour12 >= 1 && hour12 <= 12);
  final mm = mins == '00' ? '' : ':$mins';
  final ap = isPm ? 'pm' : 'am';
  return '$hour12$mm $ap'.trim();
}

String _formatHmCompact(String hhmm, _BaselineDaypartHint hint) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm.trim());
  if (m == null) return hhmm;
  final hRaw = int.parse(m.group(1)!);
  final mins = m.group(2)!;

  switch (hint) {
    case _BaselineDaypartHint.h24:
      final am = hRaw < 12;
      var hh12 = hRaw % 12;
      if (hh12 == 0) hh12 = 12;
      return mins == '00'
          ? '$hh12${am ? 'am' : 'pm'}'
          : '$hh12:$mins${am ? 'am' : 'pm'}';
    case _BaselineDaypartHint.pm12:
      if (hRaw >= 13 && hRaw <= 23) {
        final h12 = hRaw - 12;
        return _clockLabel12(h12 == 0 ? 12 : h12, mins, isPm: true);
      }
      if (hRaw == 12) {
        return _clockLabel12(12, mins, isPm: true);
      }
      final hh = hRaw < 1 ? 1 : (hRaw > 12 ? 12 : hRaw);
      return _clockLabel12(hh, mins, isPm: true);
    case _BaselineDaypartHint.am12:
      if (hRaw >= 13 && hRaw <= 23) {
        final h12 = hRaw - 12;
        return _clockLabel12(h12 == 0 ? 12 : h12, mins, isPm: false);
      }
      if (hRaw == 12) {
        return _clockLabel12(12, mins, isPm: false);
      }
      final hh = hRaw < 1 ? 1 : (hRaw > 12 ? 12 : hRaw);
      return _clockLabel12(hh, mins, isPm: false);
  }
}

String _formatMatchedRange(RegExpMatch m, _BaselineDaypartHint hint) =>
    '${_formatHmCompact(m.group(1)!, hint)}–${_formatHmCompact(m.group(2)!, hint)}';

String? _extractWeekdayBlock(String body, String anchor, DateTime day) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final wd = names[day.weekday - 1];
  final anchorIdx = body.indexOf(anchor);
  if (anchorIdx < 0) return null;
  final tail = body.substring(anchorIdx);
  final hdr = RegExp(r'(^|\n)' + RegExp.escape(wd) + r':');
  final hm = hdr.firstMatch(tail);
  if (hm == null) return null;
  final afterColon = tail.substring(hm.end);
  final next = RegExp(
    r'\n(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday):',
  ).firstMatch(afterColon);
  return next != null ? afterColon.substring(0, next.start) : afterColon;
}

String? _poolLineFromDayBlock(
  String block, {
  required bool preferPmForAmbiguous,
}) {
  final amb = preferPmForAmbiguous
      ? _BaselineDaypartHint.pm12
      : _BaselineDaypartHint.am12;

  final pmRx =
      RegExp(r'^PM:\s*(\d{1,2}:\d{2})\s+to\s+(\d{1,2}:\d{2})');
  final amRx =
      RegExp(r'^AM:\s*(\d{1,2}:\d{2})\s+to\s+(\d{1,2}:\d{2})');
  final practiceRx = RegExp(
    r'^Practice:\s*(\d{1,2}:\d{2})\s+to\s+(\d{1,2}:\d{2})',
    caseSensitive: false,
  );

  final coreOrder = preferPmForAmbiguous
      ? <(RegExp, _BaselineDaypartHint)>[
          (pmRx, _BaselineDaypartHint.pm12),
          (amRx, _BaselineDaypartHint.am12),
          (practiceRx, _BaselineDaypartHint.am12),
        ]
      : [
          (amRx, _BaselineDaypartHint.am12),
          (practiceRx, _BaselineDaypartHint.am12),
          (pmRx, _BaselineDaypartHint.pm12),
        ];

  final tailPatterns = <(RegExp, _BaselineDaypartHint)>[
    (
      RegExp(
        r'^Jr All LC:\s*(\d{1,2}:\d{2})\s+to\s+(\d{1,2}:\d{2})',
        caseSensitive: false,
      ),
      _BaselineDaypartHint.pm12,
    ),
    (
      RegExp(
        r'^Jr All SC:\s*(\d{1,2}:\d{2})\s+to\s+(\d{1,2}:\d{2})',
        caseSensitive: false,
      ),
      _BaselineDaypartHint.am12,
    ),
    (
      RegExp(
        r'^LC:\s*(\d{1,2}:\d{2})\s+to\s+(\d{1,2}:\d{2})',
        caseSensitive: false,
      ),
      amb,
    ),
    (
      RegExp(
        r'^SC:\s*(\d{1,2}:\d{2})\s+to\s+(\d{1,2}:\d{2})',
        caseSensitive: false,
      ),
      amb,
    ),
    (
      RegExp(
        r'^Sr\s+.+LC:\s*(\d{1,2}:\d{2})\s+to\s+(\d{1,2}:\d{2})',
        caseSensitive: false,
      ),
      amb,
    ),
    (
      RegExp(
        r'^Sr\s+.+SC:\s*(\d{1,2}:\d{2})\s+to\s+(\d{1,2}:\d{2})',
        caseSensitive: false,
      ),
      amb,
    ),
    (
      RegExp(
        r'^Jr\s+\d.*LC:\s*(\d{1,2}:\d{2})\s+to\s+(\d{1,2}:\d{2})',
        caseSensitive: false,
      ),
      _BaselineDaypartHint.am12,
    ),
  ];

  for (final raw in block.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    for (final pair in [...coreOrder, ...tailPatterns]) {
      final m = pair.$1.firstMatch(line);
      if (m != null) return _formatMatchedRange(m, pair.$2);
    }

    final lower = line.toLowerCase();
    if (!lower.contains('dryland') &&
        !lower.contains('meeting') &&
        RegExp(r'LC|SC', caseSensitive: false).hasMatch(line)) {
      final m =
          RegExp(r'(\d{1,2}:\d{2})\s+to\s+(\d{1,2}:\d{2})').firstMatch(line);
      if (m != null) return _formatMatchedRange(m, amb);
    }
  }
  return null;
}

String? _drylandLineFromDayBlock(String block) {
  for (final raw in block.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || !line.toLowerCase().contains('dryland')) continue;
    final up = line.toUpperCase();
    if (up.contains('TBD')) {
      return 'Dryland TBD';
    }
    final m =
        RegExp(r'(\d{1,2}:\d{2})\s+to\s+(\d{1,2}:\d{2})').firstMatch(line);
    if (m == null) continue;
    final hint = up.contains('AM DRYLAND')
        ? _BaselineDaypartHint.am12
        : _BaselineDaypartHint.pm12;
    return 'Dryland ${_formatMatchedRange(m, hint)}';
  }
  return null;
}

bool _refersToStandingWorkoutGrid(TeamEventsRecord e) {
  final tl = e.title.toLowerCase();
  return e.isRecurring ||
      tl.contains('regular') ||
      ((tl.contains('junior') || tl.contains('senior')) &&
          (tl.contains('training') ||
              tl.contains('workout') ||
              tl.contains('practice')));
}

StandingGridBaselineHints standingGridBaselineHints(
  TeamEventsRecord e,
  List<ScheduleBaseline> baselines,
) {
  const none = StandingGridBaselineHints();
  if (e.teamId != 'oapb' || e.eventType != TeamEventType.training) {
    return none;
  }
  if (!_refersToStandingWorkoutGrid(e)) return none;

  final day = e.parsedStart ?? DateTime.now();
  final bodies = _baselinesForDisplayDay(baselines, day)
      .map((b) => b.body)
      .join('\n\n');
  if (bodies.trim().isEmpty) return none;

  final hasFirestoreTimes =
      e.startTimeLocal.isNotEmpty || e.endTimeLocal.isNotEmpty;

  final tl = e.title.toLowerCase();
  final isJunior =
      _trainingMentionsJunior(e) || tl.contains('junior');
  final isSenior =
      _trainingMentionsSenior(e) || tl.contains('senior');

  String? pool;
  String? dry;

  if (isJunior) {
    const anchors = [
      'Junior 1 & 2',
      'Junior 3',
      'Jr PM',
      'Junior Group',
    ];
    for (final a in anchors) {
      final block = _extractWeekdayBlock(bodies, a, day);
      if (block == null) continue;
      pool ??= _poolLineFromDayBlock(
        block,
        preferPmForAmbiguous: true,
      );
      dry ??= _drylandLineFromDayBlock(block);
      if (pool != null) break;
    }
    if (dry == null) {
      for (final a in anchors) {
        final block = _extractWeekdayBlock(bodies, a, day);
        if (block == null) continue;
        dry = _drylandLineFromDayBlock(block);
        if (dry != null) break;
      }
    }
  } else if (isSenior) {
    final seniorAnchors = <(String, bool)>[
      ('Senior 4', false),
      ('Senior 3', false),
      ('Senior 2', false),
      ('Sr PM', true),
      ('Sr AM', false),
      ('Senior Group', true),
    ];
    for (final pair in seniorAnchors) {
      final a = pair.$1;
      final preferPm = pair.$2;
      final block = _extractWeekdayBlock(bodies, a, day);
      if (block == null) continue;
      pool ??= _poolLineFromDayBlock(
        block,
        preferPmForAmbiguous: preferPm,
      );
      dry ??= _drylandLineFromDayBlock(block);
      if (pool != null) break;
    }
    if (dry == null) {
      for (final pair in seniorAnchors) {
        final block = _extractWeekdayBlock(bodies, pair.$1, day);
        if (block == null) continue;
        dry = _drylandLineFromDayBlock(block);
        if (dry != null) break;
      }
    }
  }

  if (dry == null && isJunior) {
    for (final da in ['Jr Dryland or Meeting', 'Jr Dryland']) {
      final block = _extractWeekdayBlock(bodies, da, day);
      if (block == null) continue;
      dry = _drylandLineFromDayBlock(block);
      if (dry != null) break;
    }
  } else if (dry == null && isSenior) {
    for (final da in ['Sr PM Dryland or Meeting', 'Sr AM Dryland']) {
      final block = _extractWeekdayBlock(bodies, da, day);
      if (block == null) continue;
      dry = _drylandLineFromDayBlock(block);
      if (dry != null) break;
    }
  }

  if (pool == null && dry == null) return none;

  final summary =
      !hasFirestoreTimes && pool != null
          ? 'Regular week · typical pool $pool (Season schedules)'
          : null;
  return StandingGridBaselineHints(
    scheduleSummary: summary,
    drylandLine: dry,
  );
}

/// Training rows only; non-training events always pass.
bool _matchesTrainingSquadFilter(
  TeamEventsRecord e,
  _TrainingSquadFilter squad,
) {
  if (e.eventType != TeamEventType.training) return true;
  if (squad == _TrainingSquadFilter.all) return true;
  final j = _trainingMentionsJunior(e);
  final s = _trainingMentionsSenior(e);
  if (j && s) return true;
  if (!j && !s) return true;
  if (squad == _TrainingSquadFilter.junior) return j;
  return s;
}

enum _TrainingSquadFilter { all, junior, senior }

/// Split standing-schedule body into blocks with optional inline headings.
List<String> _baselineParagraphChunks(String body) {
  var paragraphs = body
      .split(RegExp(r'\n\s*\n+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (paragraphs.length == 1 && paragraphs.single.length > 480) {
    final split = _splitDenseBaselineLines(paragraphs.single);
    if (split.length > 1) {
      paragraphs = split;
    }
  }
  return paragraphs;
}

/// When baselines are pasted as one paragraph, break on obvious group headers.
List<String> _splitDenseBaselineLines(String paragraph) {
  final lines = paragraph.split('\n');
  if (lines.length < 4) return [paragraph];

  final sectionStarter = RegExp(
    r'^\s*(\*{0,3})?\s*(Junior|Senior)\b'
    r'|^\s*(\*{0,3})?\s*(Jr\.|Sr\.)\s',
    caseSensitive: false,
  );

  final chunks = <String>[];
  final buf = StringBuffer();

  void flush() {
    final s = buf.toString().trim();
    if (s.isNotEmpty) chunks.add(s);
    buf.clear();
  }

  for (final line in lines) {
    final t = line.trim();
    if (t.isEmpty) {
      continue;
    }
    if (buf.isNotEmpty &&
        sectionStarter.hasMatch(t) &&
        buf.toString().trim().length > 24) {
      flush();
    }
    if (buf.isNotEmpty) {
      buf.writeln();
    }
    buf.write(line);
  }
  flush();
  return chunks.length > 1 ? chunks : [paragraph];
}

/// Widgets for baseline body copy (Notes tab, detail sheets).
List<Widget> readableScheduleBaselineBodyWidgets(String body) =>
    _readableBaselineBodyWidgets(body);

List<Widget> _readableBaselineBodyWidgets(String body) {
  final paragraphs = _baselineParagraphChunks(body);
  if (paragraphs.isEmpty) {
    return [
      SelectableText(
        body,
        style: GoogleFonts.sora(
          fontSize: 12.0,
          height: 1.42,
          color: SwimUiTokens.textTitle,
        ),
      ),
    ];
  }

  final timeLike = RegExp(r'\d{1,2}:\d{2}');
  final out = <Widget>[];
  for (var i = 0; i < paragraphs.length; i++) {
    final p = paragraphs[i];
    final lines = p.split('\n');
    String? heading;
    var content = p;
    if (lines.length >= 2) {
      final first = lines.first.trim();
      final looksLikeHeading = first.length <= 54 &&
          first.length >= 2 &&
          !timeLike.hasMatch(first);
      if (looksLikeHeading) {
        heading = first;
        content = lines.sublist(1).join('\n').trim();
        if (content.isEmpty) {
          content = first;
          heading = null;
        }
      }
    }

    out.add(
      Padding(
        padding: EdgeInsets.only(bottom: i == paragraphs.length - 1 ? 0 : 8.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: SwimUiTokens.surfaceCanvasSchedule,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: SwimUiTokens.borderSubtle, width: 1.0),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (heading != null) ...[
                  Text(
                    heading,
                    style: GoogleFonts.sora(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: 0.15,
                      color: SwimUiTokens.accentBlue,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                ],
                SelectableText(
                  content,
                  style: GoogleFonts.sora(
                    fontSize: 11.75,
                    fontWeight: FontWeight.w400,
                    height: 1.42,
                    color: SwimUiTokens.textTitle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  return out;
}

/// Renders the parser-produced `team_events` collection as a scannable list
/// for the Schedule tab. This is the user-facing replacement for poking at
/// raw Firestore JSON.
class TeamEventsScheduleList extends StatefulWidget {
  const TeamEventsScheduleList({super.key, required this.teamId});

  final String teamId;

  @override
  State<TeamEventsScheduleList> createState() => _TeamEventsScheduleListState();
}

class _TeamEventsScheduleListState extends State<TeamEventsScheduleList> {
  TeamEventType? _typeFilter;
  _TrainingSquadFilter _squadFilter = _TrainingSquadFilter.all;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SwimUiTokens.surfaceCanvasSchedule,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: streamTeamRegistryDocument(widget.teamId),
        builder: (context, registrySnap) {
          final baselines = (!registrySnap.hasError && registrySnap.hasData)
              ? ScheduleBaseline.listFromSnapshotData(
                  registrySnap.data!.data(),
                )
              : <ScheduleBaseline>[];
          return StreamBuilder<List<TeamEventsRecord>>(
            stream: streamTeamEvents(widget.teamId),
            builder: (context, snap) {
              if (snap.hasError) {
                return _ErrorState(message: snap.error.toString());
              }
              if (!snap.hasData) {
                return const _LoadingState();
              }
              final raw = snap.data!;
              final deduped = dedupeTeamEvents(raw);
              final all = expandScheduleList(deduped);
              final hasBaselines = baselines.isNotEmpty;

              final counts = <TeamEventType, int>{};
              for (final e in all) {
                counts[e.eventType] = (counts[e.eventType] ?? 0) + 1;
              }

              var filtered = (_typeFilter == null
                      ? all
                      : all.where((e) => e.eventType == _typeFilter).toList())
                  .toList();
              filtered = filtered
                  .where((e) => _matchesTrainingSquadFilter(e, _squadFilter))
                  .toList();

              final trainingTotal =
                  all.where((e) => e.eventType == TeamEventType.training).length;
              final trainingJunior = all
                  .where(
                    (e) =>
                        e.eventType == TeamEventType.training &&
                        _trainingMentionsJunior(e),
                  )
                  .length;
              final trainingSenior = all
                  .where(
                    (e) =>
                        e.eventType == TeamEventType.training &&
                        _trainingMentionsSenior(e),
                  )
                  .length;

              // Sort: dated upcoming asc → dated past desc → undated last.
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              int bucket(TeamEventsRecord e) {
                if (e.parsedStart == null) return 2;
                final eDay = DateTime(
                  e.parsedStart!.year,
                  e.parsedStart!.month,
                  e.parsedStart!.day,
                );
                return eDay.isBefore(today) ? 1 : 0;
              }

              filtered.sort((a, b) {
                final ba = bucket(a);
                final bb = bucket(b);
                if (ba != bb) return ba.compareTo(bb);
                if (a.parsedStart != null && b.parsedStart != null) {
                  if (ba == 0) {
                    return a.parsedStart!.compareTo(b.parsedStart!);
                  }
                  if (ba == 1) {
                    return b.parsedStart!.compareTo(a.parsedStart!);
                  }
                }
                return a.title.toLowerCase().compareTo(b.title.toLowerCase());
              });

              return CustomScrollView(
                slivers: [
                  if (hasBaselines) ...[
                    const SliverToBoxAdapter(
                      child: _SectionHeader(title: 'Season schedules'),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14.0, 2.0, 14.0, 6.0),
                      sliver: SliverList.separated(
                        itemCount: baselines.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8.0),
                        itemBuilder: (context, i) =>
                            SeasonScheduleBaselineCard(baseline: baselines[i]),
                      ),
                    ),
                  ],
                  if (deduped.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          14.0,
                          hasBaselines ? 12.0 : 0.0,
                          14.0,
                          6.0,
                        ),
                        child: const _SectionHeader(
                          title: 'From coach emails',
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FilterStrip(
                            totalCount: all.length,
                            counts: counts,
                            selected: _typeFilter,
                            onChanged: (t) => setState(() => _typeFilter = t),
                          ),
                          if (trainingTotal > 0)
                            _SquadFilterStrip(
                              trainingTotal: trainingTotal,
                              juniorCount: trainingJunior,
                              seniorCount: trainingSenior,
                              selected: _squadFilter,
                              onChanged: (s) =>
                                  setState(() => _squadFilter = s),
                            ),
                        ],
                      ),
                    ),
                    if (filtered.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyFilterState(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          14.0,
                          4.0,
                          14.0,
                          28.0,
                        ),
                        sliver: SliverList.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10.0),
                          itemBuilder: (context, i) => _TeamEventCard(
                            event: filtered[i],
                            baselines: baselines,
                          ),
                        ),
                      ),
                  ] else if (hasBaselines) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          24.0,
                          16.0,
                          24.0,
                          32.0,
                        ),
                        child: Text(
                          'No email updates yet. Weekly newsletters and reminders '
                          'from the coach will appear here.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.sora(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            color: SwimUiTokens.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (deduped.isEmpty && !hasBaselines) ...[
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Top filter strip ───────────────────────────────────────────────────────

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.totalCount,
    required this.counts,
    required this.selected,
    required this.onChanged,
  });

  final int totalCount;
  final Map<TeamEventType, int> counts;
  final TeamEventType? selected;
  final ValueChanged<TeamEventType?> onChanged;

  static const _orderedTypes = [
    TeamEventType.meet,
    TeamEventType.training,
    TeamEventType.social,
    TeamEventType.admin,
  ];

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _Chip(
        label: 'All',
        count: totalCount,
        selected: selected == null,
        onTap: () => onChanged(null),
        accent: SwimUiTokens.accentBlue,
      ),
    ];
    for (final t in _orderedTypes) {
      final c = counts[t] ?? 0;
      if (c == 0 && selected != t) continue;
      final visual = _typeVisual(t);
      chips.add(
        _Chip(
          label: teamEventTypeLabel(t),
          count: c,
          selected: selected == t,
          onTap: () => onChanged(t),
          accent: visual.accent,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14.0, 8.0, 14.0, 6.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 8.0),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _SquadFilterStrip extends StatelessWidget {
  const _SquadFilterStrip({
    required this.trainingTotal,
    required this.juniorCount,
    required this.seniorCount,
    required this.selected,
    required this.onChanged,
  });

  final int trainingTotal;
  final int juniorCount;
  final int seniorCount;
  final _TrainingSquadFilter selected;
  final ValueChanged<_TrainingSquadFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14.0, 0.0, 14.0, 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Training squad',
            style: GoogleFonts.sora(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.35,
              color: SwimUiTokens.textMuted,
            ),
          ),
          const SizedBox(height: 8.0),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(
                  label: 'All',
                  count: trainingTotal,
                  selected: selected == _TrainingSquadFilter.all,
                  onTap: () => onChanged(_TrainingSquadFilter.all),
                  accent: ObsidianVoltTokens.textSecondary,
                ),
                const SizedBox(width: 8.0),
                _Chip(
                  label: 'Junior',
                  count: juniorCount,
                  selected: selected == _TrainingSquadFilter.junior,
                  onTap: () => onChanged(_TrainingSquadFilter.junior),
                  accent: ObsidianVoltTokens.squadJuniorText,
                ),
                const SizedBox(width: 8.0),
                _Chip(
                  label: 'Senior',
                  count: seniorCount,
                  selected: selected == _TrainingSquadFilter.senior,
                  onTap: () => onChanged(_TrainingSquadFilter.senior),
                  accent: ObsidianVoltTokens.squadSeniorText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.accent,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bg =
        selected ? ObsidianVoltTokens.tabSelectedBg : SwimUiTokens.surfaceCard;
    final fg =
        selected ? ObsidianVoltTokens.textPrimary : SwimUiTokens.textTitle;
    final border =
        selected ? accent : SwimUiTokens.cardSurfaceEdgeBorder;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(999.0),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999.0),
            border: Border.all(color: border, width: 1.0),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.sora(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(width: 6.0),
              Text(
                '$count',
                style: GoogleFonts.sora(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? ObsidianVoltTokens.textSecondary
                      : SwimUiTokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14.0, 8.0, 14.0, 4.0),
      child: Text(
        title,
        style: GoogleFonts.sora(
          fontSize: 13.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: SwimUiTokens.textMuted,
        ),
      ),
    );
  }
}

class SeasonScheduleBaselineCard extends StatelessWidget {
  const SeasonScheduleBaselineCard({super.key, required this.baseline});

  final ScheduleBaseline baseline;

  @override
  Widget build(BuildContext context) {
    final range = [
      if (baseline.validFrom != null && baseline.validFrom!.isNotEmpty)
        baseline.validFrom,
      if (baseline.validTo != null && baseline.validTo!.isNotEmpty)
        baseline.validTo,
    ].join(' → ');

    return ClipRRect(
      borderRadius: BorderRadius.circular(SwimUiTokens.radiusCard),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SwimUiTokens.surfaceCard,
          borderRadius:
              BorderRadius.circular(SwimUiTokens.radiusCard),
          border: Border.all(
              color: SwimUiTokens.cardSurfaceEdgeBorder, width: 1.0),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: SwimUiTokens.accentBlue.withValues(alpha: 0.12),
            visualDensity: VisualDensity.compact,
          ),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
            childrenPadding:
                const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 10.0),
            title: Text(
              baseline.title,
              style: GoogleFonts.sora(
                fontSize: 13.25,
                fontWeight: FontWeight.w700,
                height: 1.22,
                color: SwimUiTokens.textBannerTitle,
              ),
            ),
            subtitle: range.isEmpty
                ? null
                : Text(
                    range,
                    style: GoogleFonts.sora(
                      fontSize: 10.75,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                      color: SwimUiTokens.textMuted,
                    ),
                  ),
            children: [
              if (baseline.notes.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Text(
                    baseline.notes,
                    style: GoogleFonts.sora(
                      fontSize: 11.25,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: SwimUiTokens.accentBlue,
                    ),
                  ),
                ),
              ],
              ..._readableBaselineBodyWidgets(baseline.body),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Per-event card ─────────────────────────────────────────────────────────

class _TeamEventCard extends StatelessWidget {
  const _TeamEventCard({
    required this.event,
    required this.baselines,
  });

  final TeamEventsRecord event;
  final List<ScheduleBaseline> baselines;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final visual = _typeVisual(event.eventType);
    final dateLine = _formatDateLine(event);
    final primaryTime = _formatTimeLine(event);
    final hints = standingGridBaselineHints(event, baselines);
    final timeLine =
        primaryTime.isNotEmpty ? primaryTime : (hints.scheduleSummary ?? '');
    final locationLine = normalizeCoachLocationForUi(event.location);
    final isPast = _isPast(event);

    final rAsymmetric = BorderRadius.only(
      topRight: Radius.circular(SwimUiTokens.radiusCard),
      bottomRight: Radius.circular(SwimUiTokens.radiusCard),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Material(
        color: ObsidianVoltTokens.bgSurface,
        elevation: 2,
        shadowColor: const Color.fromRGBO(99, 102, 241, 0.08),
        shape: RoundedRectangleBorder(borderRadius: rAsymmetric),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showEventSheet(context, event, baselines),
          borderRadius: rAsymmetric,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3.0,
                  color: visual.accent,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        12.0, 10.0, 12.0, 11.0),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(
                        color: SwimUiTokens.textTitle,
                        fontSize: 13.0,
                        height: 1.32,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title.isEmpty
                                ? '(untitled event)'
                                : event.title,
                            style: GoogleFonts.sora(
                              fontSize: 14.25,
                              fontWeight: FontWeight.w700,
                              height: 1.22,
                              color: isPast
                                  ? SwimUiTokens.textMuted
                                  : SwimUiTokens.textBannerTitle,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TypeBadge(visual: visual),
                              const SizedBox(width: 8.0),
                              if (event.appliesToGroups.isNotEmpty)
                                Expanded(
                                  child: Wrap(
                                    spacing: 5.0,
                                    runSpacing: 3.0,
                                    alignment: WrapAlignment.start,
                                    children: event.appliesToGroups
                                        .map((g) => _GroupChip(label: g))
                                        .toList(),
                                  ),
                                )
                              else
                                const Spacer(),
                              if (dateLine.isNotEmpty)
                                Text(
                                  dateLine,
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.sora(
                                    fontSize: 11.25,
                                    fontWeight: FontWeight.w600,
                                    color: isPast
                                        ? SwimUiTokens.textFaint
                                        : ObsidianVoltTokens.textSecondary,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                            ],
                          ),
                          if (timeLine.isNotEmpty ||
                              locationLine.isNotEmpty) ...[
                            const SizedBox(height: 6.0),
                            _IconLine(
                              icon: Icons.access_time_rounded,
                              text: [
                                if (timeLine.isNotEmpty) timeLine,
                                if (locationLine.isNotEmpty) locationLine,
                              ].join('  ·  '),
                            ),
                          ],
                          if (hints.drylandLine != null) ...[
                            const SizedBox(height: 4.0),
                            _IconLine(
                              icon: Icons.fitness_center_rounded,
                              text: hints.drylandLine!,
                            ),
                          ],
                          if (event.isRecurring &&
                              event.recurrenceRule.isNotEmpty) ...[
                            const SizedBox(height: 3.0),
                            _IconLine(
                              icon: Icons.repeat_rounded,
                              text: _humanRecurrence(event.recurrenceRule),
                            ),
                          ],
                          if (event.entryDeadline.isNotEmpty) ...[
                            const SizedBox(height: 3.0),
                            _IconLine(
                              icon: Icons.event_busy_rounded,
                              text:
                                  'Entry deadline: ${event.entryDeadline}',
                              emphasize: !isPast,
                            ),
                          ],
                          if (event.details.isNotEmpty) ...[
                            const SizedBox(height: 6.0),
                            Text(
                              event.details,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.sora(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                height: 1.38,
                                color: SwimUiTokens.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _isPast(TeamEventsRecord e) {
    final s = e.parsedStart;
    if (s == null) return false;
    final today = DateTime.now();
    final eDay = DateTime(s.year, s.month, s.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return eDay.isBefore(todayDay);
  }

  static String _formatDateLine(TeamEventsRecord e) {
    final s = e.parsedStart;
    if (s == null) {
      return e.startDate; // Show whatever raw value we have, even if odd.
    }
    final wd = _weekdays[(s.weekday - 1).clamp(0, 6)];
    final mo = _months[(s.month - 1).clamp(0, 11)];
    return '$wd, $mo ${s.day}';
  }

  static String _formatTimeLine(TeamEventsRecord e) {
    String fmt(String hhmm) {
      final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm);
      if (m == null) return hhmm;
      var h = int.parse(m.group(1)!);
      final mins = m.group(2)!;
      final am = h < 12;
      var hh12 = h % 12;
      if (hh12 == 0) hh12 = 12;
      return mins == '00'
          ? '$hh12${am ? 'a' : 'p'}'
          : '$hh12:$mins${am ? 'a' : 'p'}';
    }

    final start = e.startTimeLocal.isNotEmpty ? fmt(e.startTimeLocal) : '';
    final end = e.endTimeLocal.isNotEmpty ? fmt(e.endTimeLocal) : '';
    if (start.isEmpty && end.isEmpty) return '';
    if (end.isEmpty) return start;
    return '$start–$end';
  }

  static String _humanRecurrence(String rrule) {
    // Best-effort prettify: FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR → "Weekly · Mon-Fri"
    final freqMatch = RegExp(r'FREQ=([A-Z]+)').firstMatch(rrule);
    final byDayMatch = RegExp(r'BYDAY=([A-Z,]+)').firstMatch(rrule);
    final freq = freqMatch?.group(1) ?? '';
    final byDay = byDayMatch?.group(1) ?? '';
    final freqPart = switch (freq) {
      'DAILY' => 'Daily',
      'WEEKLY' => 'Weekly',
      'MONTHLY' => 'Monthly',
      'YEARLY' => 'Yearly',
      _ => 'Recurs',
    };
    if (byDay.isEmpty) return freqPart;
    const map = {
      'MO': 'Mon',
      'TU': 'Tue',
      'WE': 'Wed',
      'TH': 'Thu',
      'FR': 'Fri',
      'SA': 'Sat',
      'SU': 'Sun',
    };
    final pretty = byDay.split(',').map((d) => map[d] ?? d).join(', ');
    return '$freqPart · $pretty';
  }

  static Future<void> _showEventSheet(
    BuildContext context,
    TeamEventsRecord e,
    List<ScheduleBaseline> baselines,
  ) async {
    await showScheduleEventDetailSheet(context, event: e, baselines: baselines);
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({
    required this.icon,
    required this.text,
    this.emphasize = false,
  });

  final IconData icon;
  final String text;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 14.0,
          color: ObsidianVoltTokens.textSecondary,
        ),
        const SizedBox(width: 6.0),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.sora(
              fontSize: 12.5,
              fontWeight:
                  emphasize ? FontWeight.w600 : FontWeight.w500,
              color: ObsidianVoltTokens.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.visual});
  final _TypeVisual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: visual.fill,
        borderRadius: BorderRadius.circular(999.0),
        border: Border.all(color: visual.border, width: 0.6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: 12.0, color: visual.accent),
          const SizedBox(width: 4.0),
          Text(
            visual.label,
            style: GoogleFonts.sora(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: visual.accent,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ObsidianVoltTokens.squadAllBg,
        borderRadius: BorderRadius.circular(999.0),
        border:
            Border.all(color: ObsidianVoltTokens.borderDefault, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
      child: Text(
        label,
        style: GoogleFonts.sora(
          fontSize: 10.0,
          fontWeight: FontWeight.w700,
          color: ObsidianVoltTokens.squadAllText,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─── Detail bottom sheet ────────────────────────────────────────────────────

class _EventDetailSheet extends StatelessWidget {
  const _EventDetailSheet({
    required this.event,
    required this.baselines,
  });
  final TeamEventsRecord event;
  final List<ScheduleBaseline> baselines;

  @override
  Widget build(BuildContext context) {
    final visual = _typeVisual(event.eventType);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.88;
    final gridHints = standingGridBaselineHints(event, baselines);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: SwimUiTokens.borderSection,
                    borderRadius: BorderRadius.circular(999.0),
                  ),
                ),
              ),
              const SizedBox(height: 14.0),
              Row(
                children: [
                  _TypeBadge(visual: visual),
                  const Spacer(),
                  if (event.parsingConfidence > 0)
                    Text(
                      'Confidence: ${(event.parsingConfidence * 100).round()}%',
                      style: GoogleFonts.sora(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        color: SwimUiTokens.textMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10.0),
              Text(
                event.title.isEmpty ? '(untitled event)' : event.title,
                style: GoogleFonts.sora(
                  fontSize: 19.0,
                  fontWeight: FontWeight.w700,
                  color: SwimUiTokens.textBannerTitle,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14.0),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('Date', _kvDate(event)),
                      _kv('Time', _kvTime(event, baselines)),
                      if (gridHints.drylandLine != null)
                        _kv('Dryland', gridHints.drylandLine!),
                      if (event.appliesToGroups.isNotEmpty)
                        _kv('Groups', event.appliesToGroups.join(', ')),
                      if (event.location.isNotEmpty)
                        _kv(
                          'Location',
                          normalizeCoachLocationForUi(event.location),
                        ),
                      if (event.isRecurring)
                        _kv(
                          'Recurrence',
                          event.recurrenceRule.isNotEmpty
                              ? event.recurrenceRule
                              : 'recurring',
                        ),
                      if (event.entryDeadline.isNotEmpty)
                        _kv('Entry deadline', event.entryDeadline),
                      if (event.entryUrl.isNotEmpty)
                        _kvLink(context, 'Entry URL', event.entryUrl),
                      if (event.details.isNotEmpty) ...[
                        const SizedBox(height: 6.0),
                        Text(
                          'Details',
                          style: GoogleFonts.sora(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                            color: SwimUiTokens.textMuted,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        SelectableText(
                          event.details,
                          style: GoogleFonts.sora(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            color: SwimUiTokens.textTitle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _kvDate(TeamEventsRecord e) {
    if (e.startDate.isEmpty && e.endDate.isEmpty) {
      return '(none)';
    }
    if (e.endDate.isNotEmpty && e.endDate != e.startDate) {
      return '${e.startDate} → ${e.endDate}';
    }
    return e.startDate;
  }

  static String _kvTime(
    TeamEventsRecord e,
    List<ScheduleBaseline> baselines,
  ) {
    if (e.startTimeLocal.isEmpty && e.endTimeLocal.isEmpty) {
      final hints = standingGridBaselineHints(e, baselines);
      if (hints.scheduleSummary != null) return hints.scheduleSummary!;
      if (hints.drylandLine != null) {
        return 'Pool times in Season schedules';
      }
      return '(none)';
    }
    if (e.endTimeLocal.isEmpty) return e.startTimeLocal;
    return '${e.startTimeLocal} – ${e.endTimeLocal}';
  }

  static Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.0,
            child: Text(
              label,
              style: GoogleFonts.sora(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: SwimUiTokens.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.sora(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: SwimUiTokens.textTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _kvLink(BuildContext context, String label, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.0,
            child: Text(
              label,
              style: GoogleFonts.sora(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: SwimUiTokens.textMuted,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
              child: Text(
                url,
                style: GoogleFonts.sora(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                  color: SwimUiTokens.accentBlue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Visuals per event type ─────────────────────────────────────────────────

class _TypeVisual {
  _TypeVisual({
    required this.label,
    required this.icon,
    required this.accent,
    required this.fill,
    required this.border,
  });
  final String label;
  final IconData icon;
  final Color accent;
  final Color fill;
  final Color border;
}

_TypeVisual _typeVisual(TeamEventType t) {
  switch (t) {
    case TeamEventType.meet:
      return _TypeVisual(
        label: 'MEET',
        icon: Icons.pool_rounded,
        accent: ObsidianVoltTokens.eventMeetDot,
        fill: ObsidianVoltTokens.eventMeetCardTint,
        border: ObsidianVoltTokens.eventMeetCardBorder,
      );
    case TeamEventType.training:
      return _TypeVisual(
        label: 'TRAINING',
        icon: Icons.fitness_center_rounded,
        accent: ObsidianVoltTokens.eventTrainingDot,
        fill: ObsidianVoltTokens.eventTrainingCardTint,
        border: ObsidianVoltTokens.eventTrainingCardBorder,
      );
    case TeamEventType.social:
      return _TypeVisual(
        label: 'SOCIAL',
        icon: Icons.celebration_rounded,
        accent: ObsidianVoltTokens.eventSocialDot,
        fill: ObsidianVoltTokens.eventSocialCardTint,
        border: ObsidianVoltTokens.eventSocialCardBorder,
      );
    case TeamEventType.admin:
      return _TypeVisual(
        label: 'ADMIN',
        icon: Icons.assignment_outlined,
        accent: ObsidianVoltTokens.eventAdminDot,
        fill: ObsidianVoltTokens.eventAdminCardTint,
        border: ObsidianVoltTokens.eventAdminCardBorder,
      );
    case TeamEventType.unknown:
      return _TypeVisual(
        label: 'OTHER',
        icon: Icons.event_note_rounded,
        accent: ObsidianVoltTokens.textSecondary,
        fill: ObsidianVoltTokens.bgOverlay,
        border: ObsidianVoltTokens.borderSubtle,
      );
  }
}

// ─── States ─────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 38.0,
        height: 38.0,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(SwimUiTokens.accentBlue),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 36.0, color: ObsidianVoltTokens.dangerCta),
            const SizedBox(height: 10.0),
            Text(
              "Couldn't load schedule",
              style: GoogleFonts.sora(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: SwimUiTokens.textBannerTitle,
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: SwimUiTokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32.0, 24.0, 32.0, 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/vineyard.png',
              fit: BoxFit.contain,
              height: 140.0,
            ),
            const SizedBox(height: 18.0),
            Text(
              'Nothing on the schedule',
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: SwimUiTokens.textBannerTitle,
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              'Forward a coach email to the Postmark inbox; events will show up here once the parser ingests them.',
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: SwimUiTokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Text(
          'No events match this filter.',
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: SwimUiTokens.textMuted,
          ),
        ),
      ),
    );
  }
}

Future<void> showScheduleEventDetailSheet(
  BuildContext context, {
  required TeamEventsRecord event,
  required List<ScheduleBaseline> baselines,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: ObsidianVoltTokens.bgSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18.0)),
    ),
    builder: (_) => _EventDetailSheet(event: event, baselines: baselines),
  );
}
