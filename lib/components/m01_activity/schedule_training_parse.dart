import '/backend/schedule_baseline.dart';

/// Parsed presentation for the Training Schedule tab (from [ScheduleBaseline.body]).
enum TrainingSessionKind { inWater, dryland, other }

class TrainingSessionDisplayModel {
  const TrainingSessionDisplayModel({
    required this.kind,
    required this.label,
    required this.timeText,
    this.isOptional = false,
    this.rawLine = '',
  });

  final TrainingSessionKind kind;
  final String label;
  final String timeText;
  final bool isOptional;
  final String rawLine;
}

class TrainingDayDisplayModel {
  const TrainingDayDisplayModel({
    required this.dayOfWeek,
    required this.sessions,
  });

  final String dayOfWeek;
  final List<TrainingSessionDisplayModel> sessions;
}

class TrainingGroupDisplayModel {
  const TrainingGroupDisplayModel({
    required this.id,
    required this.name,
    required this.codePill,
    required this.daysPerWeek,
    required this.days,
  });

  final String id;
  final String name;
  final String codePill;
  final int daysPerWeek;
  final List<TrainingDayDisplayModel> days;
}

class SeasonTrainingScheduleParsed {
  const SeasonTrainingScheduleParsed({required this.groups});

  final List<TrainingGroupDisplayModel> groups;
}

DateTime? tryParseBaselineIsoDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw.trim());
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

bool baselineCoversDate(ScheduleBaseline b, DateTime day) {
  final from = tryParseBaselineIsoDate(b.validFrom);
  final to = tryParseBaselineIsoDate(b.validTo);
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

/// ACTIVE / UPCOMING / ENDED — derived from valid_from / valid_to vs today.
String baselineStatusLabel(ScheduleBaseline b, DateTime today) {
  final from = tryParseBaselineIsoDate(b.validFrom);
  final to = tryParseBaselineIsoDate(b.validTo);
  final d = DateTime(today.year, today.month, today.day);
  if (to != null) {
    final toD = DateTime(to.year, to.month, to.day);
    if (d.isAfter(toD)) return 'ENDED';
  }
  if (from != null) {
    final fromD = DateTime(from.year, from.month, from.day);
    if (d.isBefore(fromD)) return 'UPCOMING';
  }
  return 'ACTIVE';
}

const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatBaselineDateRangeUi(ScheduleBaseline b) {
  final from = tryParseBaselineIsoDate(b.validFrom);
  final to = tryParseBaselineIsoDate(b.validTo);
  if (from != null && to != null) {
    final sameYear = from.year == to.year;
    final left =
        '${_monthsShort[from.month - 1]} ${from.day}${sameYear ? '' : ', ${from.year}'}';
    final right = '${_monthsShort[to.month - 1]} ${to.day}, ${to.year}';
    return '$left – $right';
  }
  if (from != null) {
    return '${_monthsShort[from.month - 1]} ${from.day}, ${from.year}';
  }
  if (to != null) {
    return '${_monthsShort[to.month - 1]} ${to.day}, ${to.year}';
  }
  return '';
}

String? extractFirstHttpUrl(String text) {
  final m = RegExp(r'(https?://[^\s\]\)]+)').firstMatch(text);
  return m?.group(1);
}

final _groupHeaderPattern = RegExp(
  r'^[\s\*_]*((?:Senior|Junior)\s+\d+|Junior\s+\d+\s*(?:&|and)\s*\d+|Jr\.?\s+PM\b|Sr\.?\s+(?:PM|AM)\b|Senior\s+Group|Junior\s+Group|Age\s+Group\s*\d*|Pre-Senior)[^\n]*$',
  caseSensitive: false,
);

final _dayHeaderPattern = RegExp(
  r'^[\t ]*(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday):',
  caseSensitive: false,
);

String _stripMarkdownNoise(String line) {
  return line
      .trim()
      .replaceAll(RegExp(r'^[\*_]+|[\*_]+$'), '')
      .trim();
}

String _groupCodePill(String name) {
  final n = name.trim();
  if (n.isEmpty) return '';
  final senior = RegExp(r'Senior\s+(\d+)', caseSensitive: false).firstMatch(n);
  if (senior != null) return 'S${senior.group(1)}';
  final junior = RegExp(r'Junior\s+(\d+)', caseSensitive: false).firstMatch(n);
  if (junior != null) return 'J${junior.group(1)}';
  final jrPm = RegExp(r'Jr\.?\s*PM', caseSensitive: false).hasMatch(n);
  if (jrPm) return 'JR PM';
  final srPm = RegExp(r'Sr\.?\s*PM', caseSensitive: false).hasMatch(n);
  if (srPm) return 'SR PM';
  final srAm = RegExp(r'Sr\.?\s*AM', caseSensitive: false).hasMatch(n);
  if (srAm) return 'SR AM';
  if (RegExp(r'Junior\s+Group', caseSensitive: false).hasMatch(n)) {
    return 'JG';
  }
  if (RegExp(r'Senior\s+Group', caseSensitive: false).hasMatch(n)) return 'SG';
  final ag = RegExp(r'Age\s+Group\s*(\d*)', caseSensitive: false).firstMatch(n);
  if (ag != null) return 'AG${ag.group(1) ?? ''}'.trim();
  if (RegExp(r'Pre-Senior', caseSensitive: false).hasMatch(n)) return 'PRE-SR';
  final jj = RegExp(r'Junior\s+\d+\s*&\s*\d+', caseSensitive: false).hasMatch(n);
  if (jj) return 'J1–2';
  return n.length <= 10 ? n.toUpperCase() : '${n.substring(0, 8)}…'.toUpperCase();
}

String _slugId(String name, int index) =>
    '${name.hashCode.abs()}_$index'.replaceAll(' ', '_');

TrainingSessionDisplayModel? _parseSessionLine(String rawLine) {
  var line = rawLine.trim();
  if (line.isEmpty) return null;

  final optional =
      RegExp(r'\boptional\b', caseSensitive: false).hasMatch(line);
  if (optional) {
    line =
        line.replaceAll(RegExp(r'\boptional\b', caseSensitive: false), '').trim();
  }

  final lower = line.toLowerCase();
  if (lower.contains('dryland')) {
    final time = _extractTimeFragment(line) ?? '';
    return TrainingSessionDisplayModel(
      kind: TrainingSessionKind.dryland,
      label: 'Dryland',
      timeText: time,
      isOptional: optional,
      rawLine: rawLine,
    );
  }

  if (RegExp(r'^(PM|AM|Practice)\s*:', caseSensitive: false).hasMatch(line) ||
      RegExp(r'\d{1,2}:\d{2}\s+to\s+\d{1,2}:\d{2}').hasMatch(line)) {
    final time = _normalizeTimeLine(line);
    return TrainingSessionDisplayModel(
      kind: TrainingSessionKind.inWater,
      label: 'In-water',
      timeText: time,
      isOptional: optional,
      rawLine: rawLine,
    );
  }

  if (timeLike(line)) {
    return TrainingSessionDisplayModel(
      kind: TrainingSessionKind.inWater,
      label: 'In-water',
      timeText: line,
      isOptional: optional,
      rawLine: rawLine,
    );
  }

  return null;
}

bool timeLike(String line) =>
    RegExp(r'\d{1,2}:\d{2}').hasMatch(line) &&
    !line.toLowerCase().contains('dryland');

String? _extractTimeFragment(String line) {
  final m =
      RegExp(r'(\d{1,2}:\d{2}\s*(?:am|pm)?\s*[–-]\s*\d{1,2}:\d{2}\s*(?:am|pm)?)',
              caseSensitive: false)
          .firstMatch(line);
  if (m != null) return m.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();

  final range =
      RegExp(r'(\d{1,2}:\d{2})\s+to\s+(\d{1,2}:\d{2})').firstMatch(line);
  if (range != null) {
    return '${range.group(1)}–${range.group(2)}';
  }
  return null;
}

String _normalizeTimeLine(String line) {
  final frag = _extractTimeFragment(line);
  return frag ?? line;
}

const _weekOrder = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

List<TrainingDayDisplayModel> _daysFromChunk(String chunk) {
  final dayMap = <String, List<TrainingSessionDisplayModel>>{};

  void appendSession(String day, TrainingSessionDisplayModel s) {
    dayMap.putIfAbsent(day, () => []).add(s);
  }

  final lines = chunk.split('\n');
  String? currentDay;

  for (final raw in lines) {
    final trimmed = raw.trimRight();
    if (trimmed.trim().isEmpty) continue;

    final dm = _dayHeaderPattern.firstMatch(trimmed);
    if (dm != null) {
      final dayName = dm.group(1)!;
      currentDay = dayName;
      final inline = trimmed.substring(dm.end).trim();
      if (inline.isNotEmpty) {
        final sess = _parseSessionLine(inline);
        if (sess != null) appendSession(dayName, sess);
      }
      continue;
    }

    if (currentDay == null) continue;
    final sess = _parseSessionLine(trimmed);
    if (sess != null) appendSession(currentDay, sess);
  }

  final out = <TrainingDayDisplayModel>[];
  for (final day in _weekOrder) {
    final sessions = dayMap[day];
    if (sessions == null || sessions.isEmpty) continue;
    out.add(TrainingDayDisplayModel(dayOfWeek: day, sessions: sessions));
  }
  return out;
}

TrainingGroupDisplayModel _buildGroup(String name, String chunk, int index) {
  final cleanedName = _stripMarkdownNoise(name);
  final lines = chunk.split('\n').where((l) => l.trim().isNotEmpty).toList();
  var bodyLines = lines;
  if (lines.isNotEmpty &&
      _stripMarkdownNoise(lines.first).toLowerCase() ==
          cleanedName.toLowerCase()) {
    bodyLines = lines.sublist(1);
  }
  final body = bodyLines.join('\n');
  final days = _daysFromChunk(body);
  final dpw = days.length;
  return TrainingGroupDisplayModel(
    id: _slugId(cleanedName, index),
    name: cleanedName,
    codePill: _groupCodePill(cleanedName),
    daysPerWeek: dpw,
    days: days,
  );
}

SeasonTrainingScheduleParsed parseSeasonTrainingBody(String body) {
  final text = body.trim();
  if (text.isEmpty) {
    return const SeasonTrainingScheduleParsed(groups: []);
  }

  final lines = text.split('\n');
  final headerIndices = <int>[];

  for (var i = 0; i < lines.length; i++) {
    final t = lines[i].trim();
    if (t.isEmpty) continue;
    if (_dayHeaderPattern.hasMatch(t)) continue;
    if (_groupHeaderPattern.hasMatch(t)) {
      headerIndices.add(i);
    }
  }

  if (headerIndices.isEmpty) {
    final g = _buildGroup('Schedule', text, 0);
    return SeasonTrainingScheduleParsed(groups: [g]);
  }

  final groups = <TrainingGroupDisplayModel>[];
  for (var k = 0; k < headerIndices.length; k++) {
    final start = headerIndices[k];
    final end =
        k + 1 < headerIndices.length ? headerIndices[k + 1] : lines.length;
    final headerLine = lines[start];
    final chunk = lines.sublist(start, end).join('\n');
    groups.add(_buildGroup(headerLine, chunk, k));
  }

  return SeasonTrainingScheduleParsed(groups: groups);
}

bool groupLikelyMatchesSwimmerGroup(String groupName, String swimmerGroupRaw) {
  final g = groupName.toLowerCase();
  final s = swimmerGroupRaw.trim().toLowerCase();
  if (s.isEmpty) return false;
  if (g.contains(s) || s.contains(g)) return true;

  final jr =
      s.contains('junior') || RegExp(r'\bjr\b').hasMatch(s) || s.contains('jg');
  final sr = s.contains('senior') ||
      RegExp(r'\bsr\b').hasMatch(s) ||
      s.contains('pre-senior');

  if (jr && g.contains('junior')) return true;
  if (sr && g.contains('senior')) return true;
  if (jr && g.contains('jr')) return true;
  if (sr && g.contains('sr')) return true;

  final dg = RegExp(r'\d+').firstMatch(g)?.group(0);
  final ds = RegExp(r'\d+').firstMatch(s)?.group(0);
  if (dg != null && ds != null && dg == ds && (g.contains('senior') || g.contains('junior'))) {
    return true;
  }
  return false;
}

/// Summary text before first weekday heading — for Notes tab.
String baselineSummarySnippet(String body, {int maxLen = 360}) {
  final idx = body.split('\n').indexWhere((l) => _dayHeaderPattern.hasMatch(l));
  var snippet =
      idx <= 0 ? body.trim() : body.split('\n').take(idx).join('\n').trim();
  snippet = snippet.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  if (snippet.length <= maxLen) return snippet;
  return '${snippet.substring(0, maxLen).trim()}…';
}
