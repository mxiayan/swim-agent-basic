import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/meet_preferences_api.dart';
import '/backend/schema/entered_meets_record.dart';
import '/backend/schema/meet_preferences_record.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

String? _trimUrl(String? s) {
  final t = (s ?? '').trim();
  return t.isEmpty ? null : t;
}

/// Host club and official links (typically from [MonitoredMeetsRecord]).
class MeetDetailExtras {
  const MeetDetailExtras({
    this.hostTeam,
    this.viewOnFastSwimsUrl,
    this.meetSheetUrl,
    this.psychSheetUrl,
    this.timelineUrl,
    this.heatSheetUrl,
  });

  final String? hostTeam;
  final String? viewOnFastSwimsUrl;
  final String? meetSheetUrl;
  final String? psychSheetUrl;
  final String? timelineUrl;
  final String? heatSheetUrl;

  bool get hasAnyLink {
    bool has(String? s) => (s ?? '').trim().isNotEmpty;
    return has(viewOnFastSwimsUrl) ||
        has(meetSheetUrl) ||
        has(psychSheetUrl) ||
        has(timelineUrl) ||
        has(heatSheetUrl);
  }
}

MeetDetailExtras meetDetailExtrasFromMonitoredMeet(MonitoredMeetsRecord m) {
  final entry = m.entryUrl.trim();
  String? viewFast;
  if (entry.isNotEmpty) {
    viewFast = entry.replaceAll(RegExp(r'/enter/?$'), '');
    if (viewFast.isEmpty) {
      viewFast = entry;
    }
  } else {
    final id = m.meetId.trim();
    if (RegExp(r'^\d+$').hasMatch(id)) {
      viewFast = 'https://ome.fastswims.com/meets/$id';
    }
  }
  final host = m.hostGroup.trim();
  return MeetDetailExtras(
    hostTeam: host.isEmpty ? null : host,
    viewOnFastSwimsUrl: _trimUrl(viewFast),
    meetSheetUrl: _trimUrl(m.meetSheetUrl),
    psychSheetUrl: _trimUrl(m.psychSheetUrl),
    timelineUrl: _trimUrl(m.timelineUrl),
    heatSheetUrl: _trimUrl(m.heatSheetUrl),
  );
}

class MeetDetailView extends StatefulWidget {
  const MeetDetailView({
    super.key,
    required this.activity,
    required this.meetId,
    required this.heroTag,
    this.preference,
    this.extras,
  });

  final ActivitiesRecord activity;
  final String meetId;
  final String heroTag;
  final MeetPreferencesRecord? preference;
  final MeetDetailExtras? extras;

  @override
  State<MeetDetailView> createState() => _MeetDetailViewState();
}

class _MeetDetailViewState extends State<MeetDetailView> {
  static const Color _bg = Color(0xFFF1F5F9);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate600 = Color(0xFF475569);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _enteredBg = Color(0xFFECFDF5);
  static const Color _enteredFg = Color(0xFF047857);
  static const Color _enteredBorder = Color(0xFFA7F3D0);
  static const int _notePreviewChars = 200;

  late final TextEditingController _noteController;
  bool _savingNote = false;
  bool _savingNotGoing = false;
  bool _parentNoteExpanded = false;
  bool _parentNoteEditing = false;

  bool get _isEntered =>
      widget.preference?.status == MeetPreferenceStatus.entered;

  String get _rawLocationLine =>
      widget.activity.details.locationName.trim();

  String get _displayTitle {
    final raw = _rawLocationLine;
    if (raw.contains(' · ')) {
      return raw.split(' · ').first.trim();
    }
    if (raw.isNotEmpty) {
      return raw;
    }
    return widget.activity.activityType.trim().isNotEmpty
        ? widget.activity.activityType.trim()
        : 'Swim meet';
  }

  /// Venue / secondary location when title is split from composite [locationName].
  String? get _venueSubtitle {
    final raw = _rawLocationLine;
    if (!raw.contains(' · ')) {
      return null;
    }
    final rest = raw.split(' · ').skip(1).join(' · ').trim();
    return rest.isEmpty ? null : rest;
  }

  String get _locationForMeetInfo {
    final sub = _venueSubtitle;
    if (sub != null) {
      return sub;
    }
    final raw = _rawLocationLine;
    if (raw.isNotEmpty) {
      return raw;
    }
    return '';
  }

  String get _signupUrl => widget.activity.details.signupUrl.trim();

  String get _noteSeed {
    final prefNotes = widget.preference?.notes.trim() ?? '';
    if (prefNotes.isNotEmpty) {
      return prefNotes;
    }
    return widget.activity.details.notes.trim();
  }

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: _noteSeed);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveParentNote() async {
    if (currentUserUid.isEmpty) {
      return;
    }
    setState(() => _savingNote = true);
    try {
      await mergeMeetPreference(
        currentUserUid,
        widget.meetId,
        notes: _noteController.text.trim(),
        isHidden: false,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved to your meet preferences.')),
      );
      setState(() => _parentNoteEditing = false);
    } finally {
      if (mounted) {
        setState(() => _savingNote = false);
      }
    }
  }

  Future<void> _markNotGoing() async {
    if (currentUserUid.isEmpty) {
      return;
    }
    setState(() => _savingNotGoing = true);
    try {
      await mergeMeetPreference(
        currentUserUid,
        widget.meetId,
        status: MeetPreferenceStatus.notGoing,
        skipSelected: true,
        hasAlert: false,
        isHidden: false,
        notes: _noteController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _savingNotGoing = false);
      }
    }
  }

  Future<void> _confirmWithdraw() async {
    if (_savingNotGoing) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Withdraw from this meet?',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'We’ll mark this meet as not going. You can always update again from your meet list if plans change.',
          style: GoogleFonts.sora(
            fontSize: 14.0,
            height: 1.35,
            color: _slate600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w600,
                color: _slate600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Withdraw',
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _markNotGoing();
    }
  }

  void _openInMaps(String query) {
    final q = Uri.encodeComponent(query);
    launchURL('https://www.google.com/maps/search/?api=1&query=$q');
  }

  String? _deadlineStateLine(DateTime? end, DateTime? start) {
    final d = end ?? start;
    if (d == null) {
      return null;
    }
    if (d.isBefore(DateTime.now())) {
      return 'Deadline passed';
    }
    return 'Deadline ${dateTimeFormat('MMM d', d)}';
  }

  String _dateRangeLabel(DateTime? start, DateTime? end) {
    if (start == null) {
      return 'Date TBD';
    }
    if (end == null || end == start) {
      return dateTimeFormat('EEE, MMM d, y', start);
    }
    return '${dateTimeFormat('MMM d', start)} – ${dateTimeFormat('MMM d, y', end)}';
  }

  Widget _sectionHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 10.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.sora(
          fontSize: 12.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: _slate500,
        ),
      ),
    );
  }

  Widget _softCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: _cardBorder.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _metaChip({required IconData icon, required String label}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15.0, color: _slate500),
          const SizedBox(width: 6.0),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _slate600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge({required bool entered}) {
    final label = entered ? 'Entered' : meetStatusLabel(
          widget.preference?.status ?? MeetPreferenceStatus.newStatus,
        );
    final color = entered ? _enteredFg : const Color(0xFF92400E);
    final bg = entered ? _enteredBg : const Color(0xFFFEF3C7);
    final border = entered ? _enteredBorder : const Color(0xFFFDE68A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999.0),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entered) ...[
            Icon(Icons.check_circle_rounded, size: 16.0, color: color),
            const SizedBox(width: 5.0),
          ],
          Text(
            entered ? 'Entry submitted' : label,
            style: GoogleFonts.sora(
              fontSize: 12.0,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required bool entered,
    required DateTime? start,
    required DateTime? end,
  }) {
    final headerBlue = FlutterFlowTheme.of(context).primary;
    final deadlineLine = _deadlineStateLine(
      widget.activity.details.endTime,
      start,
    );
    final locShort = _locationForMeetInfo;
    final metaLocation = (locShort.isNotEmpty ? locShort : '—');

    return Hero(
      tag: widget.heroTag,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20.0),
              bottomRight: Radius.circular(20.0),
            ),
            border: Border(
              bottom: BorderSide(
                color: _cardBorder.withValues(alpha: 0.7),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16.0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 18.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5.0,
                  height: 120.0,
                  decoration: BoxDecoration(
                    color: entered ? _enteredFg : headerBlue,
                    borderRadius: BorderRadius.circular(999.0),
                  ),
                ),
                const SizedBox(width: 14.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            tooltip: 'Back',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40.0,
                              minHeight: 40.0,
                            ),
                          ),
                          const Spacer(),
                          _statusBadge(entered: entered),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        _displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sora(
                          fontSize: 21.0,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (_venueSubtitle != null) ...[
                        const SizedBox(height: 6.0),
                        Text(
                          _venueSubtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            color: _slate600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12.0),
                      Wrap(
                        spacing: 14.0,
                        runSpacing: 8.0,
                        children: [
                          _metaChip(
                            icon: Icons.calendar_today_outlined,
                            label: _dateRangeLabel(start, end),
                          ),
                          _metaChip(
                            icon: Icons.place_outlined,
                            label: metaLocation,
                          ),
                          if (deadlineLine != null)
                            _metaChip(
                              icon: Icons.flag_outlined,
                              label: deadlineLine,
                            ),
                        ],
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

  Widget _buildEntryStatusCard({
    required String swimmerName,
    required MeetPreferencesRecord? pref,
  }) {
    Widget body(DateTime? submittedAt) {
      final lastUpdated = pref?.statusUpdatedAt;
      String? timeCaption;
      String? timeDetail;
      if (submittedAt != null) {
        timeCaption = 'Submitted on';
        timeDetail = dateTimeFormat('MMM d, y · h:mm a', submittedAt);
      } else if (lastUpdated != null) {
        timeCaption = 'Last updated';
        timeDetail = dateTimeFormat('MMM d, y · h:mm a', lastUpdated);
      }
      final events = pref?.eventsEntered;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: _enteredBg,
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(
                    color: _enteredBorder.withValues(alpha: 0.7),
                  ),
                ),
                child:
                    Icon(Icons.verified_rounded, color: _enteredFg, size: 22.0),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your entry',
                      style: GoogleFonts.sora(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: _slate500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      'Summary',
                      style: GoogleFonts.sora(
                        fontSize: 17.0,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20.0),
          Text(
            'Entered',
            style: GoogleFonts.sora(
              fontSize: 26.0,
              fontWeight: FontWeight.w800,
              height: 1.05,
              color: _enteredFg,
              letterSpacing: -0.5,
            ),
          ),
          if (swimmerName.isNotEmpty) ...[
            const SizedBox(height: 10.0),
            Text(
              swimmerName,
              style: GoogleFonts.sora(
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
                height: 1.2,
              ),
            ),
          ],
          if (events != null && events > 0) ...[
            const SizedBox(height: 12.0),
            Text(
              '$events ${events == 1 ? 'event' : 'events'} entered',
              style: GoogleFonts.sora(
                fontSize: 15.0,
                fontWeight: FontWeight.w700,
                color: _slate700,
              ),
            ),
          ],
          if (timeCaption != null && (timeDetail ?? '').isNotEmpty) ...[
            const SizedBox(height: 12.0),
            Text(
              timeCaption,
              style: GoogleFonts.sora(
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
                color: _slate500,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2.0),
            Text(
              timeDetail!,
              style: GoogleFonts.sora(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: _slate700,
              ),
            ),
          ],
          const SizedBox(height: 14.0),
          Text(
            'You’re all set. Use View entries below to open the meet site if you want to double-check events or warmups.',
            style: GoogleFonts.sora(
              fontSize: 12.0,
              height: 1.4,
              color: _slate500,
            ),
          ),
        ],
      );
    }

    if (currentUserUid.isEmpty) {
      return _softCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18.0, 18.0, 18.0, 18.0),
          child: body(null),
        ),
      );
    }

    return _softCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18.0, 18.0, 18.0, 18.0),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserUid)
              .collection('entered_meets')
              .doc(widget.meetId)
              .snapshots(),
          builder: (context, snap) {
            DateTime? submittedAt;
            if (snap.hasData && snap.data!.exists) {
              final rec = EnteredMeetsRecord.fromSnapshot(snap.data!);
              submittedAt = rec.enteredAt;
            }
            return body(submittedAt);
          },
        ),
      ),
    );
  }

  Widget _meetDayRow({
    required String label,
    required String value,
  }) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108.0,
            child: Text(
              label,
              style: GoogleFonts.sora(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _slate500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.sora(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: _slate700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetInfoSection({
    required DateTime? start,
    required DateTime? end,
    required DateTime? warmup,
    required String organizerNotes,
    required MeetDetailExtras? extras,
  }) {
    final loc = _locationForMeetInfo;
    final host = extras?.hostTeam?.trim() ?? '';
    final warmupLabel = warmup != null
        ? dateTimeFormat('EEE, MMM d · h:mm a', warmup)
        : '';
    final startLabel =
        start != null ? dateTimeFormat('EEE, MMM d · h:mm a', start) : '';
    final showMeetDay = warmupLabel.isNotEmpty ||
        startLabel.isNotEmpty ||
        loc.isNotEmpty ||
        host.isNotEmpty;

    return _softCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18.0, 16.0, 18.0, 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meet dates',
              style: GoogleFonts.sora(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: _slate500,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              _dateRangeLabel(start, end),
              style: GoogleFonts.sora(
                fontSize: 15.0,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            if (showMeetDay) ...[
              const SizedBox(height: 16.0),
              Text(
                'Meet day',
                style: GoogleFonts.sora(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: _slate500,
                ),
              ),
              const SizedBox(height: 8.0),
              _meetDayRow(label: 'Warm-up', value: warmupLabel),
              _meetDayRow(label: 'Meet start', value: startLabel),
              _meetDayRow(label: 'Facility', value: loc),
              _meetDayRow(label: 'Host team', value: host),
              if (loc.isNotEmpty) ...[
                const SizedBox(height: 4.0),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openInMaps(loc),
                    icon: Icon(
                      Icons.map_outlined,
                      size: 18.0,
                      color: FlutterFlowTheme.of(context).primary,
                    ),
                    label: Text(
                      'Open in Maps',
                      style: GoogleFonts.sora(
                        fontWeight: FontWeight.w700,
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 8.0),
            _buildCompactMapPreview(),
            if (organizerNotes.isNotEmpty) ...[
              const SizedBox(height: 16.0),
              Text(
                'Notes from organizer',
                style: GoogleFonts.sora(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: _slate500,
                ),
              ),
              const SizedBox(height: 6.0),
              Text(
                organizerNotes,
                style: GoogleFonts.sora(
                  fontSize: 14.0,
                  height: 1.45,
                  color: _slate700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Short map strip when geocoding works; otherwise a single compact line.
  Widget _buildCompactMapPreview() {
    final loc = _locationForMeetInfo;
    if (loc.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          'Add an address to the schedule to see a map preview.',
          style: GoogleFonts.sora(
            fontSize: 12.0,
            height: 1.3,
            color: _slate500,
          ),
        ),
      );
    }
    final q = Uri.encodeComponent(loc);
    final staticMapUrl =
        'https://staticmap.openstreetmap.de/staticmap.php?center=$q&zoom=13&size=640x200&markers=$q,red-pushpin';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Map preview',
          style: GoogleFonts.sora(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            color: _slate500,
          ),
        ),
        const SizedBox(height: 6.0),
        ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: SizedBox(
            height: 72.0,
            width: double.infinity,
            child: Image.network(
              staticMapUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Preview unavailable — use Open in Maps.',
                  style: GoogleFonts.sora(
                    fontSize: 12.0,
                    color: _slate500,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _normMeetBrowseUrl(String u) {
    return u.trim().replaceAll(RegExp(r'/enter/?$'), '');
  }

  Widget _buildOfficialResourcesCard(MeetDetailExtras? extras) {
    if (extras == null || !extras.hasAnyLink) {
      return const SizedBox.shrink();
    }
    final rows = <({String label, String url})>[];
    final signupNorm =
        _signupUrl.isNotEmpty ? _normMeetBrowseUrl(_signupUrl) : '';

    void add(String label, String? url) {
      var u = (url ?? '').trim();
      if (u.isEmpty) {
        return;
      }
      if (label == 'View on FastSwims' &&
          signupNorm.isNotEmpty &&
          _normMeetBrowseUrl(u) == signupNorm) {
        return;
      }
      if (rows.any((e) => e.url == u)) {
        return;
      }
      rows.add((label: label, url: u));
    }

    add('View on FastSwims', extras.viewOnFastSwimsUrl);
    add('Meet sheet', extras.meetSheetUrl);
    add('Psych sheet', extras.psychSheetUrl);
    add('Timeline', extras.timelineUrl);
    add('Heat sheet', extras.heatSheetUrl);

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return _softCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 6.0, 8.0, 6.0),
        child: Column(
          children: rows.map((r) {
            return ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0.0),
              leading: Icon(
                Icons.open_in_new_rounded,
                size: 20.0,
                color: FlutterFlowTheme.of(context).primary,
              ),
              title: Text(
                r.label,
                style: GoogleFonts.sora(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: _slate700,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: _slate500,
              ),
              onTap: () => launchURL(r.url),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Widget> _bulletedNoteLines(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return [
        Text(
          'No note yet.',
          style: GoogleFonts.sora(
            fontSize: 14.0,
            color: _slate500,
          ),
        ),
      ];
    }
    return lines.map((line) {
      var content = line;
      if (RegExp(r'^[-•*]\s*').hasMatch(line)) {
        content = line.replaceFirst(RegExp(r'^[-•*]\s*'), '');
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '•  ',
              style: GoogleFonts.sora(
                fontSize: 14.0,
                fontWeight: FontWeight.w700,
                color: _slate500,
                height: 1.45,
              ),
            ),
            Expanded(
              child: Text(
                content,
                style: GoogleFonts.sora(
                  fontSize: 14.0,
                  height: 1.45,
                  color: _slate700,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildParentNoteSection() {
    final text = _noteController.text.trim();
    final long = text.length > _notePreviewChars;
    final showCollapsed = long && !_parentNoteExpanded && !_parentNoteEditing;

    return _softCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parent note',
                        style: GoogleFonts.sora(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        'Private reminders — only your family sees this in the app.',
                        style: GoogleFonts.sora(
                          fontSize: 12.5,
                          height: 1.3,
                          color: _slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_parentNoteEditing && text.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _parentNoteEditing = true),
                    child: Text(
                      'Edit',
                      style: GoogleFonts.sora(
                        fontWeight: FontWeight.w700,
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12.0),
            if (_parentNoteEditing) ...[
              TextField(
                controller: _noteController,
                onChanged: (_) => setState(() {}),
                minLines: 4,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: 'One reminder per line — bullets are added when you save.',
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).primary,
                      width: 1.5,
                    ),
                  ),
                ),
                style: GoogleFonts.sora(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  TextButton(
                    onPressed: _savingNote
                        ? null
                        : () => setState(() {
                              _parentNoteEditing = false;
                              _noteController.text = _noteSeed;
                            }),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.sora(
                        fontWeight: FontWeight.w600,
                        color: _slate600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _savingNote ? null : _saveParentNote,
                    style: FilledButton.styleFrom(
                      backgroundColor: FlutterFlowTheme.of(context).primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 12.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: Text(
                      _savingNote ? 'Saving…' : 'Save note',
                      style: GoogleFonts.sora(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ] else ...[
              if (text.isEmpty)
                Text(
                  'Tap Edit to add reminders (practice times, parking, warmup).',
                  style: GoogleFonts.sora(
                    fontSize: 14.0,
                    color: _slate500,
                    height: 1.4,
                  ),
                )
              else ...[
                if (showCollapsed)
                  Text(
                    '${text.substring(0, _notePreviewChars)}…',
                    style: GoogleFonts.sora(
                      fontSize: 14.0,
                      height: 1.45,
                      color: _slate700,
                    ),
                  )
                else
                  ..._bulletedNoteLines(text),
                if (long) ...[
                  const SizedBox(height: 4.0),
                  TextButton(
                    onPressed: () => setState(
                      () => _parentNoteExpanded = !_parentNoteExpanded,
                    ),
                    child: Text(
                      _parentNoteExpanded ? 'Show less' : 'Show full note',
                      style: GoogleFonts.sora(
                        fontWeight: FontWeight.w700,
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                    ),
                  ),
                ],
              ],
              if (text.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _parentNoteEditing = true),
                    icon: const Icon(Icons.edit_outlined, size: 18.0),
                    label: Text(
                      'Add a note',
                      style: GoogleFonts.sora(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar({
    required bool entered,
    required bool canOpenSignup,
  }) {
    if (entered) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18.0, 10.0, 18.0, 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      canOpenSignup ? () => launchURL(_signupUrl) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: canOpenSignup
                        ? FlutterFlowTheme.of(context).primary
                        : const Color(0xFF94A3B8),
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: _slate500,
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 0.0,
                  ),
                  child: Text(
                    canOpenSignup ? 'View entries' : 'Entries on file',
                    style: GoogleFonts.sora(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 6.0),
              TextButton(
                onPressed: _savingNotGoing ? null : _confirmWithdraw,
                style: TextButton.styleFrom(
                  foregroundColor: _slate500,
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  minimumSize: const Size(0.0, 36.0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _savingNotGoing ? 'Updating…' : 'Withdraw from meet',
                  style: GoogleFonts.sora(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                canOpenSignup
                    ? 'Opens the meet site in your browser.'
                    : 'No entry link on file for this meet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(
                  fontSize: 11.0,
                  color: _slate500,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18.0, 10.0, 18.0, 12.0),
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: canOpenSignup ? () => launchURL(_signupUrl) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: FlutterFlowTheme.of(context).primary,
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 0.0,
                ),
                child: Text(
                  'Submit entries',
                  style: GoogleFonts.sora(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: OutlinedButton(
                onPressed: _savingNotGoing ? null : _markNotGoing,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  side: const BorderSide(color: _cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: Text(
                  _savingNotGoing ? 'Saving…' : 'Not going',
                  style: GoogleFonts.sora(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final swimmerName = FFAppState().currentSwimmerName.trim();
    final details = widget.activity.details;
    final start = widget.activity.startTime;
    final end = details.endTime;
    final entered = _isEntered;
    final canOpenSignup = _signupUrl.isNotEmpty;
    final organizerNotes = details.notes.trim();

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(entered: entered, start: start, end: end),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  18.0,
                  20.0,
                  18.0,
                  16.0 + bottomInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entered) ...[
                      _sectionHeading('Your entry status'),
                      _buildEntryStatusCard(
                        swimmerName: swimmerName,
                        pref: widget.preference,
                      ),
                      const SizedBox(height: 26.0),
                    ],
                    _sectionHeading('Meet info'),
                    _buildMeetInfoSection(
                      start: start,
                      end: end,
                      warmup: details.warmupTime,
                      organizerNotes: organizerNotes,
                      extras: widget.extras,
                    ),
                    if (widget.extras != null &&
                        widget.extras!.hasAnyLink) ...[
                      const SizedBox(height: 26.0),
                      _sectionHeading('Official resources'),
                      _buildOfficialResourcesCard(widget.extras),
                    ],
                    const SizedBox(height: 26.0),
                    _sectionHeading('Parent note'),
                    _buildParentNoteSection(),
                    // Space above sticky footer
                    SizedBox(height: entered ? 100.0 : 88.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 0.0,
        color: Colors.white,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: _cardBorder.withValues(alpha: 0.85),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10.0,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: _buildBottomBar(
            entered: entered,
            canOpenSignup: canOpenSignup,
          ),
        ),
      ),
    );
  }
}

/// Minimal [ActivitiesRecord] for [MeetDetailView] when only a [MonitoredMeetsRecord] exists.
ActivitiesRecord activitiesRecordFromMonitoredMeet(MonitoredMeetsRecord m) {
  final title = m.name.trim();
  final loc = m.location.trim();
  final locationLine = [title, loc].where((s) => s.isNotEmpty).join(' · ');
  final noteText = m.notes.trim().isNotEmpty ? m.notes : m.apiNotes;
  final details = ActivityDetailsStruct(
    locationName: locationLine,
    signupUrl: m.entryUrl,
    notes: noteText.trim(),
    endTime: m.endTime ?? m.startTime,
  );
  return ActivitiesRecord.getDocumentFromData(
    <String, dynamic>{
      'start_time': m.startTime,
      'activity_type': 'Meet',
      'team_id': '',
      'group_ids': <String>[],
      'sports_type': '',
      'details': details,
    },
    m.reference,
  );
}
