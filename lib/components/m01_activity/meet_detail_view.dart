import 'dart:io';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/local/local_meet_media_store.dart';
import '/backend/meet_preferences_api.dart';
import '/components/m01_activity/fastswim_entry_browser.dart';
import '/backend/push_notifications.dart';
import '/backend/schema/entered_meets_record.dart';
import '/backend/schema/meet_preferences_record.dart';
import '/backend/schema/personal_meet_resources.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/theme/obsidian_volt_tokens.dart';
import '/theme/swim_ui_tokens.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

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

  /// Team-hosted browse link only (meet sheet is surfaced in Meet info).
  bool get hasOfficialBrowseLink =>
      (viewOnFastSwimsUrl ?? '').trim().isNotEmpty;
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

class _MeetDetailViewState extends State<MeetDetailView>
    with WidgetsBindingObserver {
  static const Color _bg = ObsidianVoltTokens.bgBase;
  static Color get _cardBorder => ObsidianVoltTokens.borderDefault;
  static const Color _slate700 = ObsidianVoltTokens.textPrimary;
  static const Color _slate600 = ObsidianVoltTokens.textPrimary;
  static const Color _slate500 = ObsidianVoltTokens.textSecondary;
  static const Color _enteredBg = Color(0xFFECFDF5);
  static const Color _enteredFg = Color(0xFF047857);
  static const Color _enteredBorder = Color(0xFFA7F3D0);
  static const int _notePreviewChars = 200;

  late final TextEditingController _noteController;
  bool _savingNote = false;
  bool _savingNotGoing = false;
  bool _savingDecision = false;
  MeetPreferenceStatus? _statusOverride;
  bool? _hasAlertOverride;
  MonitoredMeetsRecord? _monitoredMeet;
  String? _pendingEntryPromptMeetId;
  bool _showingReturnPrompt = false;
  bool _parentNoteExpanded = false;
  bool _parentNoteEditing = false;

  /// After a successful user save, drives map preview until parent rebuilds.
  String _mapAddressOverride = '';
  bool _savingLocationAddress = false;
  final Map<String, Future<_GeoPointLite?>> _previewGeocodeCache = {};
  final ImagePicker _mediaPicker = ImagePicker();
  int _resourceMediaRevision = 0;
  bool _loadingSwimVideos = false;
  bool _savingSwimVideo = false;
  List<LocalSwimVideoEntry> _swimVideos = const <LocalSwimVideoEntry>[];
  List<String> _strokePresets = const <String>[];
  List<_MeetEventOption> _meetEventOptions = const <_MeetEventOption>[];
  List<String> _enteredEventOrderKeys = <String>[];
  final Map<String, Future<String?>> _videoThumbCache = {};
  bool _syncingFastSwimEntries = false;
  int? _syncedEventsCount;
  String? _savedOrderToken;
  // FastSwim's own numeric meet ID (e.g. "10796") — may differ from the
  // Firestore document ID stored in widget.meetId.
  String? _fastSwimMeetId;
  // Full JSON response body captured from the WebView — used directly for
  // sync so we never need an unauthenticated Dart HTTP call.
  String? _cachedFastSwimResponse;

  static const String _locationSourceUserVerified = 'user_verified';

  bool get _isEntered => _effectiveStatus == MeetPreferenceStatus.entered;

  MeetPreferenceStatus get _effectiveStatus =>
      _statusOverride ??
      widget.preference?.status ??
      MeetPreferenceStatus.newStatus;
  bool get _effectiveHasAlert =>
      _hasAlertOverride ?? widget.preference?.hasAlert ?? false;

  String get _rawLocationLine => widget.activity.details.locationName.trim();

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

  String get _mapPreviewAddress {
    final o = _mapAddressOverride.trim();
    if (o.isNotEmpty) {
      return o;
    }
    return _locationForMeetInfo;
  }

  String get _signupUrl => widget.activity.details.signupUrl.trim();
  String get _entryUrl =>
      _monitoredMeet != null ? buildEntryUrl(_monitoredMeet!) : _signupUrl;
  bool get _fastSwimSignupNotOpen {
    final meet = _monitoredMeet;
    if (meet != null) {
      final status = meet.status.trim().toLowerCase();
      return status == 'pending' || meet.entryUrl.trim().isEmpty;
    }
    return _signupUrl.isEmpty;
  }

  String get _noteSeed {
    final prefNotes = widget.preference?.notes.trim() ?? '';
    if (prefNotes.isNotEmpty) {
      return prefNotes;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _noteController = TextEditingController(text: _noteSeed);
    _primeMapAddressOverrideFromMonitored();
    _loadMonitoredMeet();
    _loadLocalSwimMedia();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingEntryConfirmationPrompt();
    }
  }

  /// Resolves `monitored_meets/{id}` when this detail was opened from a meet list row.
  Future<DocumentReference?> _monitoredMeetRef() async {
    final ref = widget.activity.reference;
    if (ref.path.startsWith('monitored_meets/')) {
      return ref;
    }
    final direct = FirebaseFirestore.instance
        .collection('monitored_meets')
        .doc(widget.meetId);
    final directSnap = await direct.get();
    if (directSnap.exists) {
      return direct;
    }
    final q = await FirebaseFirestore.instance
        .collection('monitored_meets')
        .where('meet_id', isEqualTo: widget.meetId)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) {
      return q.docs.first.reference;
    }
    return null;
  }

  Future<void> _primeMapAddressOverrideFromMonitored() async {
    try {
      final mref = await _monitoredMeetRef();
      if (mref == null) {
        return;
      }
      final snap = await mref.get();
      final data = snap.data() as Map<String, dynamic>?;
      if (!mounted || data == null) {
        return;
      }
      final addr = (data['location_address'] as String?)?.trim() ?? '';
      if (addr.isNotEmpty) {
        setState(() => _mapAddressOverride = addr);
      }
    } catch (_) {}
  }

  /// Tokens for keyword match (city, street, venue words). Max 10 for Firestore.
  List<String> _venueQuerySearchTokens(String raw) {
    return raw
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .map((t) => t.trim())
        .where((t) => t.length >= 3)
        .take(10)
        .toList();
  }

  List<QueryDocumentSnapshot> _mergeVenueSuggestionDocs(
    List<QueryDocumentSnapshot> a,
    List<QueryDocumentSnapshot> b,
  ) {
    final byId = <String, QueryDocumentSnapshot>{};
    for (final d in [...a, ...b]) {
      byId[d.id] = d;
    }
    final out = byId.values.toList();
    out.sort((x, y) {
      final mx = x.data() as Map<String, dynamic>?;
      final my = y.data() as Map<String, dynamic>?;
      final nx = (mx?['name'] as String? ?? '').toLowerCase();
      final ny = (my?['name'] as String? ?? '').toLowerCase();
      return nx.compareTo(ny);
    });
    return out.length > 8 ? out.sublist(0, 8) : out;
  }

  /// Prefix on [search_name] matches typed venue names; [keywords] matches city / address.
  Stream<List<QueryDocumentSnapshot>> _venueSuggestionDocs(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    final col = FirebaseFirestore.instance.collection('venues');
    if (q.isEmpty) {
      return col.orderBy('name').limit(8).snapshots().map((s) => s.docs);
    }
    final end = '$q\uf8ff';
    final prefixStream = col
        .where('search_name', isGreaterThanOrEqualTo: q)
        .where('search_name', isLessThanOrEqualTo: end)
        .orderBy('search_name')
        .limit(8)
        .snapshots();
    final tokens = _venueQuerySearchTokens(rawQuery);
    if (tokens.isEmpty) {
      return prefixStream.map((s) => s.docs);
    }
    final kwStream =
        col.where('keywords', arrayContainsAny: tokens).limit(24).snapshots();
    return Rx.combineLatest2<QuerySnapshot, QuerySnapshot,
        List<QueryDocumentSnapshot>>(
      prefixStream,
      kwStream,
      (prefixSnap, kwSnap) =>
          _mergeVenueSuggestionDocs(prefixSnap.docs, kwSnap.docs),
    );
  }

  Future<void> _openLocationAddressEditor() async {
    if (currentUserUid.isEmpty) {
      return;
    }
    var draftAddress = _mapPreviewAddress.trim().isNotEmpty
        ? _mapPreviewAddress.trim()
        : _locationForMeetInfo;
    var selectedVenueId = '';
    final saved = await showModalBottomSheet<_VenueSelectionResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ObsidianVoltTokens.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (sheetContext) {
        var query = draftAddress;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit venue address',
                    style: GoogleFonts.sora(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    initialValue: draftAddress,
                    onChanged: (v) {
                      setSheetState(() => query = v.trimLeft());
                      draftAddress = v;
                      selectedVenueId = '';
                    },
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Search venue or enter full address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  SizedBox(
                    height: 180.0,
                    child: StreamBuilder<List<QueryDocumentSnapshot>>(
                      stream: _venueSuggestionDocs(query),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Text(
                            'Could not load venue suggestions. Deploy Firestore '
                            'rules for `venues` or check your connection.',
                            style: GoogleFonts.sora(
                              fontSize: 12.0,
                              color: _slate500,
                            ),
                          );
                        }
                        if (snap.connectionState == ConnectionState.waiting &&
                            !snap.hasData) {
                          return const Center(
                            child: SizedBox(
                              width: 28.0,
                              height: 28.0,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.0),
                            ),
                          );
                        }
                        final docs =
                            snap.data ?? const <QueryDocumentSnapshot>[];
                        if (docs.isEmpty) {
                          return Text(
                            'No venue suggestions yet. Try the pool or street '
                            'name, or save your typed address as-is.',
                            style: GoogleFonts.sora(
                              fontSize: 12.0,
                              color: _slate500,
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1.0),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>?;
                            final name =
                                (data?['name'] as String? ?? '').trim();
                            final address =
                                (data?['address'] as String? ?? '').trim();
                            final zone =
                                (data?['zone'] as String? ?? '').trim();
                            return ListTile(
                              dense: true,
                              title: Text(
                                name,
                                style: GoogleFonts.sora(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '$address${zone.isNotEmpty ? " · Zone $zone" : ""}',
                                style: GoogleFonts.sora(
                                  fontSize: 11.5,
                                  color: _slate500,
                                ),
                              ),
                              onTap: () {
                                setSheetState(() {
                                  draftAddress = address;
                                  query = address;
                                  selectedVenueId = doc.id;
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (selectedVenueId.isNotEmpty) ...[
                    const SizedBox(height: 8.0),
                    Text(
                      'Selected venue will lock this address for scraper updates.',
                      style: GoogleFonts.sora(
                        fontSize: 11.5,
                        color: _slate500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12.0),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(
                        _VenueSelectionResult(
                          address: draftAddress.trim(),
                          venueId: selectedVenueId.trim(),
                        ),
                      ),
                      child: const Text('Save Location'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (saved == null || saved.address.trim().isEmpty) {
      return;
    }

    setState(() => _savingLocationAddress = true);
    try {
      final mref = await _monitoredMeetRef();
      if (mref == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cloud Sync Error'),
            ),
          );
        }
        return;
      }

      try {
        await mref.set(
          <String, dynamic>{
            'location_address': saved.address.trim(),
            'venue_id': saved.venueId.isEmpty ? null : saved.venueId,
            'location_source': _locationSourceUserVerified,
          },
          SetOptions(merge: true),
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cloud Sync Error'),
            ),
          );
        }
        return;
      }

      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      setState(() => _mapAddressOverride = saved.address.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venue location saved.')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingLocationAddress = false);
      }
    }
  }

  Future<_GeoPointLite?> _resolvePreviewPoint(String address) {
    final key = address.trim().toLowerCase();
    if (key.isEmpty) {
      return Future.value(null);
    }
    return _previewGeocodeCache.putIfAbsent(
      key,
      () async {
        try {
          final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
            'format': 'jsonv2',
            'limit': '1',
            'q': address,
          });
          final res = await http.get(
            uri,
            headers: const {'User-Agent': 'swim-agent-basic/1.0'},
          );
          if (res.statusCode != 200) {
            return null;
          }
          final arr = jsonDecode(res.body);
          if (arr is! List || arr.isEmpty) {
            return null;
          }
          final first = arr.first;
          if (first is! Map) {
            return null;
          }
          final lat = double.tryParse((first['lat'] ?? '').toString());
          final lon = double.tryParse((first['lon'] ?? '').toString());
          if (lat == null || lon == null) {
            return null;
          }
          return _GeoPointLite(lat: lat, lon: lon);
        } catch (_) {
          return null;
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadMonitoredMeet() async {
    try {
      final mref = await _monitoredMeetRef();
      if (mref == null) {
        return;
      }
      final snap = await mref.get();
      if (!mounted || !snap.exists) {
        return;
      }
      setState(() {
        _monitoredMeet = MonitoredMeetsRecord.fromSnapshot(snap);
      });
    } catch (_) {}
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
      await setMeetStatus(
        currentUserUid,
        widget.meetId,
        status: MeetPreferenceStatus.notGoing,
        skipSelected: true,
        hasAlert: false,
        isHidden: false,
        pendingEntryConfirmation: false,
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

  Future<void> _setMeetDecision({required bool going}) async {
    if (currentUserUid.isEmpty || _savingDecision) {
      return;
    }
    setState(() => _savingDecision = true);
    final nextStatus =
        going ? MeetPreferenceStatus.needEntry : MeetPreferenceStatus.notGoing;
    try {
      if (going) {
        await startEntry(
          currentUserUid,
          widget.meetId,
          notes: _noteController.text.trim(),
        );
      } else {
        await setMeetStatus(
          currentUserUid,
          widget.meetId,
          status: MeetPreferenceStatus.notGoing,
          skipSelected: true,
          hasAlert: false,
          isHidden: false,
          pendingEntryConfirmation: false,
          notes: _noteController.text.trim(),
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _statusOverride = nextStatus;
        _hasAlertOverride = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            going
                ? 'Marked as going. You can update entries next.'
                : 'Marked as not going. You can change this anytime.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingDecision = false);
      }
    }
  }

  Future<void> _setSignupOpenReminder({required bool enabled}) async {
    if (currentUserUid.isEmpty || _savingDecision) {
      return;
    }
    setState(() => _savingDecision = true);
    try {
      if (enabled) {
        final registered = await ensurePushNotificationsRegistered();
        if (!registered) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Notifications are not enabled for this device yet.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
      await setMeetStatus(
        currentUserUid,
        widget.meetId,
        status: MeetPreferenceStatus.needEntry,
        skipSelected: false,
        hasAlert: enabled,
        isHidden: false,
        pendingEntryConfirmation: false,
        notes: _noteController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _statusOverride = MeetPreferenceStatus.needEntry;
        _hasAlertOverride = enabled;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Reminder set. We’ll let you know when FastSwim opens for this meet.'
                : 'Reminder removed.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingDecision = false);
      }
    }
  }

  Future<void> _markEntriesSubmitted() async {
    if (currentUserUid.isEmpty || _savingDecision) {
      return;
    }
    setState(() => _savingDecision = true);
    try {
      await markEntrySubmitted(
        currentUserUid,
        widget.meetId,
        notes: _noteController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() => _statusOverride = MeetPreferenceStatus.entered);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Great. Marked as entered.'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingDecision = false);
      }
    }
  }

  Future<void> _openFastSwimEntry() async {
    if (_savingDecision || currentUserUid.isEmpty) {
      return;
    }

    final entryUrl = _entryUrl;
    if (entryUrl.isEmpty) return;

    setState(() => _savingDecision = true);
    try {
      // Save Firestore status before opening so the "needEntry" card is shown
      // immediately when the user returns to this screen.
      final existing =
          await getMeetPreferenceOnce(currentUserUid, widget.meetId);
      await setMeetStatus(
        currentUserUid,
        widget.meetId,
        status: MeetPreferenceStatus.needEntry,
        skipSelected: false,
        hasAlert: false,
        isHidden: false,
        pendingEntryConfirmation: true,
        notes: _noteController.text.trim(),
        extra: <String, dynamic>{
          if (existing == null)
            'entry_started_at': FieldValue.serverTimestamp(),
          'entry_started_from_app': true,
          'last_opened_entry_url_at': FieldValue.serverTimestamp(),
        },
      );
      _pendingEntryPromptMeetId = widget.meetId;
      setState(() => _statusOverride = MeetPreferenceStatus.needEntry);
    } finally {
      if (mounted) setState(() => _savingDecision = false);
    }

    if (!mounted) return;

    // Open FastSwim in an in-app browser.  The browser intercepts every
    // network request, captures the entry data, and shows a sync button
    // directly on the browser screen — no need to return to the app first.
    final result = await Navigator.of(context).push<FastSwimCaptureResult?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FastSwimEntryBrowser(
          entryUrl: entryUrl,
          firestoreMeetId: widget.meetId,
          uid: currentUserUid,
          hasExistingEvents: _meetEventOptions.isNotEmpty,
          onCaptured: (r) {
            if (mounted) {
              setState(() {
                _savedOrderToken = r.orderToken;
                if (r.fastSwimMeetId.isNotEmpty) _fastSwimMeetId = r.fastSwimMeetId;
                if (r.responseBody.isNotEmpty) _cachedFastSwimResponse = r.responseBody;
              });
            }
          },
          onSync: (r) async {
            // Update cached state first so _syncFastSwimEntries uses fresh data.
            if (mounted) {
              setState(() {
                _savedOrderToken = r.orderToken;
                if (r.fastSwimMeetId.isNotEmpty) _fastSwimMeetId = r.fastSwimMeetId;
                if (r.responseBody.isNotEmpty) _cachedFastSwimResponse = r.responseBody;
              });
            }
            await _syncFastSwimEntries();
          },
        ),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _savedOrderToken = result.orderToken;
        if (result.fastSwimMeetId.isNotEmpty) {
          _fastSwimMeetId = result.fastSwimMeetId;
        }
        if (result.responseBody.isNotEmpty) {
          _cachedFastSwimResponse = result.responseBody;
        }
      });
    }
  }

  Future<void> _checkPendingEntryConfirmationPrompt() async {
    if (!mounted || _showingReturnPrompt) {
      return;
    }
    final pendingMeetId = _pendingEntryPromptMeetId;
    if (pendingMeetId == null || pendingMeetId != widget.meetId) {
      return;
    }
    final pref = await getMeetPreferenceOnce(currentUserUid, pendingMeetId);
    if (!mounted || pref == null) {
      return;
    }
    final refSnap = await pref.reference.get();
    if (!mounted || !refSnap.exists) {
      return;
    }
    final data = mapFromFirestore(refSnap.data() as Map<String, dynamic>);
    final pending = data['pending_entry_confirmation'] as bool? ?? false;
    if (!(pending && pref.status == MeetPreferenceStatus.needEntry)) {
      return;
    }
    _showingReturnPrompt = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ObsidianVoltTokens.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.0)),
      ),
      builder: (ctx) {
        final title = _monitoredMeet?.title.trim().isNotEmpty == true
            ? _monitoredMeet!.title
            : _displayTitle;
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.help_outline_rounded,
                      color: Color(0xFF334155)),
                  const SizedBox(width: 8),
                  Text(
                    'Did you finish submitting entries?',
                    style: GoogleFonts.sora(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'For $title',
                style: GoogleFonts.sora(fontSize: 13, color: _slate500),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await _markEntriesSubmitted();
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Yes, mark as entered'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await clearPendingEntryConfirmation(
                        currentUserUid, widget.meetId);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Not yet'),
                ),
              ),
            ],
          ),
        );
      },
    );
    _showingReturnPrompt = false;
    _pendingEntryPromptMeetId = null;
  }

  Future<void> _openChangeStatusSheet() async {
    final current = _effectiveStatus;
    final choice = await showModalBottomSheet<MeetPreferenceStatus>(
      context: context,
      backgroundColor: ObsidianVoltTokens.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.0)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text('Change meet status',
                style: GoogleFonts.sora(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Entry needed'),
              selected: current == MeetPreferenceStatus.needEntry,
              onTap: () => Navigator.pop(ctx, MeetPreferenceStatus.needEntry),
            ),
            ListTile(
              title: const Text('Mark as entered'),
              selected: current == MeetPreferenceStatus.entered,
              onTap: () => Navigator.pop(ctx, MeetPreferenceStatus.entered),
            ),
            ListTile(
              title: const Text('Not going'),
              selected: current == MeetPreferenceStatus.notGoing,
              onTap: () => Navigator.pop(ctx, MeetPreferenceStatus.notGoing),
            ),
            ListTile(
              title: const Text('Not decided'),
              selected: current == MeetPreferenceStatus.newStatus,
              onTap: () => Navigator.pop(ctx, MeetPreferenceStatus.newStatus),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
    if (choice == null) {
      return;
    }
    if (choice == MeetPreferenceStatus.entered) {
      await _markEntriesSubmitted();
      return;
    }
    if (choice == MeetPreferenceStatus.needEntry) {
      await startEntry(currentUserUid, widget.meetId,
          notes: _noteController.text.trim());
    } else if (choice == MeetPreferenceStatus.notGoing) {
      await setMeetStatus(
        currentUserUid,
        widget.meetId,
        status: MeetPreferenceStatus.notGoing,
        skipSelected: true,
        hasAlert: false,
        isHidden: false,
        pendingEntryConfirmation: false,
        notes: _noteController.text.trim(),
      );
    } else {
      await setMeetStatus(
        currentUserUid,
        widget.meetId,
        status: MeetPreferenceStatus.newStatus,
        skipSelected: false,
        hasAlert: false,
        isHidden: false,
        pendingEntryConfirmation: false,
        notes: _noteController.text.trim(),
      );
    }
    if (!mounted) {
      return;
    }
    setState(() => _statusOverride = choice);
  }

  Widget _buildMeetDecisionCard() {
    final status = _effectiveStatus;
    final signupNotOpen = _fastSwimSignupNotOpen;
    final reminderOn = signupNotOpen &&
        status == MeetPreferenceStatus.needEntry &&
        _effectiveHasAlert;
    final isGoing = status == MeetPreferenceStatus.needEntry ||
        status == MeetPreferenceStatus.entered;
    final isNotGoing = status == MeetPreferenceStatus.notGoing;
    ButtonStyle decisionStyle({
      required bool selected,
      required bool primary,
    }) {
      if (primary) {
        return FilledButton.styleFrom(
          backgroundColor: selected
              ? FlutterFlowTheme.of(context).primary
              : FlutterFlowTheme.of(context).primary.withValues(alpha: 0.88),
          foregroundColor: ObsidianVoltTokens.bgBase,
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(11.0)),
          elevation: selected ? 1.0 : 0.0,
        );
      }
      return OutlinedButton.styleFrom(
        foregroundColor: selected ? const Color(0xFF0F172A) : _slate600,
        side: BorderSide(
          color: selected ? const Color(0xFF94A3B8) : const Color(0xFFE2E8F0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(11.0)),
      );
    }

    Widget reminderActionButton() {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _savingDecision
              ? null
              : () => _setSignupOpenReminder(enabled: !reminderOn),
          style: decisionStyle(selected: reminderOn, primary: true),
          icon: Icon(
            reminderOn
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            size: 18.0,
          ),
          label: Text(
            _savingDecision
                ? 'Updating…'
                : reminderOn
                    ? 'Reminder on'
                    : 'Remind me when FastSwim opens',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return _softCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              signupNotOpen &&
                      (status == MeetPreferenceStatus.newStatus ||
                          status == MeetPreferenceStatus.needEntry)
                  ? 'FastSwim is not open yet'
                  : status == MeetPreferenceStatus.newStatus
                      ? 'Are you attending this meet?'
                      : status == MeetPreferenceStatus.needEntry
                          ? 'Entry needed'
                          : status == MeetPreferenceStatus.entered
                              ? 'Entered'
                              : 'Not going',
              style: GoogleFonts.sora(
                fontSize: 14.0,
                fontWeight: FontWeight.w700,
                color: _slate700,
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              signupNotOpen &&
                      (status == MeetPreferenceStatus.newStatus ||
                          status == MeetPreferenceStatus.needEntry)
                  ? 'This meet is not open for sign-up on FastSwim yet. Set a reminder and we’ll notify you when entries open.'
                  : status == MeetPreferenceStatus.newStatus
                      ? 'This helps us show the right next steps.'
                      : status == MeetPreferenceStatus.needEntry
                          ? 'Submit your entries on FastSwim, then come back here.'
                          : status == MeetPreferenceStatus.entered
                              ? 'You marked this meet as submitted. We’ll keep tracking updates for you.'
                              : 'You’re not attending this meet.',
              style: GoogleFonts.sora(
                fontSize: 12.0,
                height: 1.35,
                color: _slate500,
              ),
            ),
            if (status == MeetPreferenceStatus.newStatus) ...[
              const SizedBox(height: 12.0),
              if (signupNotOpen)
                reminderActionButton()
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _savingDecision
                        ? null
                        : () => _setMeetDecision(going: true),
                    style: decisionStyle(selected: isGoing, primary: true),
                    child: Text(
                      _savingDecision ? 'Updating…' : 'Yes, start entry',
                      style: GoogleFonts.sora(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _savingDecision
                      ? null
                      : () => _setMeetDecision(going: false),
                  style: decisionStyle(selected: isNotGoing, primary: false),
                  child: const Text('No, skip this meet'),
                ),
              ),
              const SizedBox(height: 6),
              if (!signupNotOpen)
                TextButton(
                  onPressed: _savingDecision ? null : _markEntriesSubmitted,
                  child:
                      const Text('Already submitted? I submitted my entries'),
                ),
            ] else if (status == MeetPreferenceStatus.needEntry) ...[
              const SizedBox(height: 12.0),
              if (signupNotOpen) ...[
                reminderActionButton(),
                const SizedBox(height: 8.0),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _savingDecision
                        ? null
                        : () => _setMeetDecision(going: false),
                    style: decisionStyle(selected: isNotGoing, primary: false),
                    child: const Text('No, skip this meet'),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _savingDecision ? null : _openFastSwimEntry,
                    style: decisionStyle(selected: true, primary: true),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open FastSwim'),
                  ),
                ),
                const SizedBox(height: 8.0),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed:
                        _savingDecision ? null : () => _markEntriesSubmitted(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _slate700,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 11.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11.0),
                      ),
                    ),
                    child:
                        const Text('Already submitted? I submitted my entries'),
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _openChangeStatusSheet,
                  child: const Text('Change status'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openInMaps(String query) async {
    final q = Uri.encodeComponent(query);
    final webUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$q',
    );
    if (kIsWeb) {
      launchURL(webUrl.toString());
      return;
    }

    // iOS: prefer Google Maps app if installed, otherwise Apple Maps.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final googleMapsApp = Uri.parse('comgooglemaps://?q=$q');
      final appleMaps = Uri.parse('http://maps.apple.com/?q=$q');
      if (await canLaunchUrl(googleMapsApp)) {
        await launchUrl(
          googleMapsApp,
          mode: LaunchMode.externalApplication,
        );
        return;
      }
      await launchUrl(
        appleMaps,
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    // Android: open native map intent when possible.
    final geo = Uri.parse('geo:0,0?q=$q');
    if (await canLaunchUrl(geo)) {
      await launchUrl(
        geo,
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    await launchUrl(
      webUrl,
      mode: LaunchMode.externalApplication,
    );
  }

  String _urlHostPreview(String raw) {
    final t = raw.trim();
    if (t.isEmpty) {
      return '';
    }
    final withScheme =
        t.startsWith('http://') || t.startsWith('https://') ? t : 'https://$t';
    final uri = Uri.tryParse(withScheme);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host;
    }
    return t;
  }

  /// Expands long note previews in My meet resources rows.

  Future<void> _openPersonalResourceEditor({
    PersonalMeetResourceEntry? initial,
  }) async {
    if (currentUserUid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in to save meet resources.'),
          ),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ObsidianVoltTokens.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: _PersonalResourceEditorSheet(
            initial: initial,
            meetId: widget.meetId,
            onSaved: () {
              if (mounted) {
                setState(() => _resourceMediaRevision++);
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _loadLocalSwimMedia() async {
    if (currentUserUid.isEmpty || !mounted) {
      return;
    }
    setState(() => _loadingSwimVideos = true);
    try {
      final swimmerName = FFAppState().currentSwimmerName.trim();
      final videos =
          await LocalMeetMediaStore.listVideos(currentUserUid, widget.meetId);
      final orderKeys = await LocalMeetMediaStore.getEnteredEventOrder(
        currentUserUid,
        widget.meetId,
      );
      final strokes = await LocalMeetMediaStore.getStrokePresets(
        currentUserUid,
        swimmerName,
      );
      final eventOptions = await _loadMeetEventOptions();
      if (!mounted) {
        return;
      }
      setState(() {
        _swimVideos = videos;
        _enteredEventOrderKeys = orderKeys;
        _strokePresets = strokes;
        _meetEventOptions = eventOptions;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSwimVideos = false);
      }
    }
  }

  Future<List<_MeetEventOption>> _loadMeetEventOptions() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .collection('entered_meets')
          .doc(widget.meetId)
          .get();
      final data = snap.data() ?? <String, dynamic>{};

      // Cache the stored order token and FastSwim meet ID so repeat syncs
      // are fully automatic with no user input.
      final storedToken = (data['order_token'] as String? ?? '').trim();
      final storedFsMeetId =
          (data['fastswim_meet_id'] as String? ?? '').trim();
      if ((storedToken.isNotEmpty || storedFsMeetId.isNotEmpty) && mounted) {
        setState(() {
          if (storedToken.isNotEmpty) _savedOrderToken = storedToken;
          if (storedFsMeetId.isNotEmpty) _fastSwimMeetId = storedFsMeetId;
        });
      }

      final candidates = <String>[
        'events',
        'event_list',
        'events_entered',
        'entered_events',
      ];
      dynamic rawList;
      for (final k in candidates) {
        if (data.containsKey(k)) {
          rawList = data[k];
          break;
        }
      }
      if (rawList is! List) {
        return const <_MeetEventOption>[];
      }
      final out = <_MeetEventOption>[];
      for (final item in rawList) {
        if (item is String) {
          final txt = item.trim();
          if (txt.isNotEmpty) {
            out.add(_MeetEventOption(label: txt));
          }
          continue;
        }
        if (item is Map) {
          final m = item.cast<String, dynamic>();
          final label =
              (m['label'] ?? m['event'] ?? m['name'] ?? '').toString().trim();
          if (label.isEmpty) {
            continue;
          }
          // `strokeCode` is what the FastSwim sync saves; `stroke` is the
          // legacy field name for manually added events.
          final rawStroke =
              (m['stroke'] ?? m['strokeCode'] ?? '').toString().trim();
          final stroke = rawStroke.length == 1
              ? _strokeName(rawStroke) // convert numeric code → name
              : rawStroke;

          // entryCourse: "LCM" = long course, "SCY"/"SCM" = short course.
          final entryCourse =
              (m['entryCourse'] ?? m['entry_course'] ?? '').toString().trim().toUpperCase();
          final isLongCourse = m['is_long_course'] as bool? ??
              entryCourse == 'LCM' ||
              entryCourse == 'LM';

          final entryTimeFormatted =
              (m['entryTimeFormatted'] ?? m['entry_time_formatted'] ?? '')
                  .toString()
                  .trim();
          final displayLabel = entryTimeFormatted.isNotEmpty
              ? '$label  ($entryTimeFormatted)'
              : label;

          out.add(
            _MeetEventOption(
              label: displayLabel,
              stroke: stroke,
              distance: (m['distance'] as num?)?.toInt() ?? 0,
              unit: (m['unit'] ?? 'Y').toString().trim().toUpperCase(),
              isLongCourse: isLongCourse,
              heat: (m['heat'] ?? '').toString().trim(),
              lane: (m['lane'] ?? '').toString().trim(),
            ),
          );
        }
      }
      return out;
    } catch (_) {
      return const <_MeetEventOption>[];
    }
  }

  // ── FastSwim entry sync ─────────────────────────────────────────────────

  // USA Swimming SDIF stroke codes (used by FastSwim):
  // 1=Freestyle, 2=Backstroke, 3=Breaststroke, 4=Butterfly, 5=IM
  static String _strokeName(String? code) {
    switch (code) {
      case '1':
        return 'Freestyle';
      case '2':
        return 'Backstroke';
      case '3':
        return 'Breaststroke';
      case '4':
        return 'Butterfly';
      case '5':
        return 'IM';
      default:
        return code ?? '';
    }
  }

  static String _formatEventLabel(Map<String, dynamic> ev, String sessionName) {
    final num = ev['eventNumber'] ?? '';
    final dist = ev['distance'] ?? '';
    final stroke = _strokeName(ev['strokeCode']?.toString());
    return 'Event $num – $dist ${stroke.isEmpty ? '' : stroke} ($sessionName)'.trim();
  }

  static String _formatEntryTime(int ms) {
    final totalSec = ms ~/ 1000;
    final frac = (ms % 1000) ~/ 10;
    if (totalSec < 60) {
      return '$totalSec.${frac.toString().padLeft(2, '0')}';
    }
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}.${frac.toString().padLeft(2, '0')}';
  }

  Future<void> _syncFastSwimEntries() async {
    if (currentUserUid.isEmpty) return;

    final cachedToken = _savedOrderToken?.trim() ?? '';
    if (cachedToken.isEmpty) {
      // Token not yet captured — the user needs to open FastSwim via the
      // in-app browser so the token can be intercepted automatically.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Open FastSwim first — your entries will sync automatically '
            'when you return.',
          ),
        ),
      );
      return;
    }

    // Use the FastSwim numeric meet ID captured from the intercepted URL.
    // Fall back to the monitored meet's meetId field (if it is numeric), then
    // to widget.meetId as a last resort.
    setState(() => _syncingFastSwimEntries = true);
    try {
      final cached = _cachedFastSwimResponse?.trim() ?? '';
      if (cached.isNotEmpty) {
        // Use the response body captured by the WebView — no HTTP call needed,
        // and no 401 risk because the browser already fetched it authenticated.
        await _processFastSwimResponseBody(cached, cachedToken, widget.meetId);
      } else {
        // Fallback: attempt a direct HTTP call.  May fail with 401 if
        // FastSwim requires session cookies.  If so the user should re-open
        // FastSwim via the in-app browser to refresh the cached response.
        final fsMeetId = _fastSwimMeetId?.trim().isNotEmpty == true
            ? _fastSwimMeetId!.trim()
            : (_monitoredMeet?.meetId.trim() ?? '').isNotEmpty &&
                    RegExp(r'^\d+$').hasMatch(_monitoredMeet!.meetId.trim())
                ? _monitoredMeet!.meetId.trim()
                : widget.meetId;
        final apiUrl =
            'https://api2.fastswims.com/api/v1/meets/$fsMeetId/enter?orderToken=$cachedToken';
        await _doSyncFastSwimEntries(apiUrl, widget.meetId);
      }
    } finally {
      if (mounted) setState(() => _syncingFastSwimEntries = false);
    }
  }

  /// Fetches from the FastSwim API then delegates to [_parseAndSaveEvents].
  Future<void> _doSyncFastSwimEntries(String apiUrl, String meetId) async {
    String orderToken = '';
    try {
      orderToken = Uri.parse(apiUrl).queryParameters['orderToken'] ?? '';
    } catch (_) {}

    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode != 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'FastSwim request failed: ${response.statusCode}')),
      );
      return;
    }
    await _parseAndSaveEvents(
        response.body, orderToken, meetId, apiUrl: apiUrl);
  }

  /// Uses the response body captured by the in-app WebView — no HTTP call,
  /// no auth issues.
  Future<void> _processFastSwimResponseBody(
      String jsonBody, String orderToken, String meetId) async {
    await _parseAndSaveEvents(jsonBody, orderToken, meetId);
  }

  /// Shared parse-and-persist logic used by both sync paths.
  Future<void> _parseAndSaveEvents(
    String jsonBody,
    String orderToken,
    String meetId, {
    String apiUrl = '',
  }) async {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(jsonBody) as Map<String, dynamic>;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not parse FastSwim response.')),
      );
      return;
    }

    final meetData = body['meet'] as Map<String, dynamic>?;
    final sessions =
        (meetData?['meetSessions'] as List?)?.cast<Map<String, dynamic>>() ??
            [];

    final List<Map<String, dynamic>> myEvents = [];
    for (final session in sessions) {
      final sessionName = session['name'] as String? ?? 'Session';
      final availableEvents =
          (session['availableEvents'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
      for (final ev in availableEvents) {
        final entries =
            (ev['enteredIndividualEvents'] as List?)?.cast<Map<String, dynamic>>() ??
                [];
        for (final entry in entries) {
          if (entry['enteredByMe'] == true) {
            myEvents.add({
              'eventId': ev['id'],
              'eventNumber': ev['eventNumber'],
              'distance': ev['distance'],
              'strokeCode': ev['strokeCode'],
              'entryCourse': entry['entryCourse'],
              'entryTimeMs': entry['entryTimeMs'],
              'entryId': entry['id'],
              'swimmerId': entry['swimmerId'],
              'sessionName': sessionName,
              'label': _formatEventLabel(ev, sessionName),
              'entryTimeFormatted': _formatEntryTime(
                  (entry['entryTimeMs'] as num?)?.toInt() ?? 0),
            });
            break;
          }
        }
      }
    }

    // Extract FastSwim numeric meet ID from URL path if available.
    String fsMeetIdFromUrl = _fastSwimMeetId?.trim() ?? '';
    if (fsMeetIdFromUrl.isEmpty && apiUrl.isNotEmpty) {
      try {
        final match =
            RegExp(r'/meets/(\d+)/').firstMatch(Uri.parse(apiUrl).path);
        fsMeetIdFromUrl = match?.group(1) ?? '';
      } catch (_) {}
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserUid)
        .collection('entered_meets')
        .doc(meetId);

    await docRef.set({
      'meet_id': meetId,
      if (fsMeetIdFromUrl.isNotEmpty) 'fastswim_meet_id': fsMeetIdFromUrl,
      'entered_at': FieldValue.serverTimestamp(),
      'events': myEvents,
      'events_count': myEvents.length,
      if (orderToken.isNotEmpty) 'order_token': orderToken,
    }, SetOptions(merge: true));

    await setMeetStatus(
      currentUserUid,
      meetId,
      status: MeetPreferenceStatus.entered,
      extra: {'events_entered': myEvents.length},
    );

    if (!mounted) return;
    setState(() {
      _syncedEventsCount = myEvents.length;
      if (orderToken.isNotEmpty) _savedOrderToken = orderToken;
      if (fsMeetIdFromUrl.isNotEmpty) _fastSwimMeetId = fsMeetIdFromUrl;
      _statusOverride = MeetPreferenceStatus.entered;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          myEvents.isEmpty
              ? 'No events with "enteredByMe" found. Check your entry on FastSwim.'
              : 'Saved ${myEvents.length} entered event${myEvents.length == 1 ? '' : 's'}!',
        ),
      ),
    );

    // Refresh the Entered Events section with the newly saved data.
    await _reloadMeetEventOptions();
  }

  Future<void> _reloadMeetEventOptions() async {
    if (!mounted || currentUserUid.isEmpty) return;
    final options = await _loadMeetEventOptions();
    if (!mounted) return;
    setState(() => _meetEventOptions = options);
  }

  // ── Swim video ───────────────────────────────────────────────────────────

  Future<void> _addSwimVideo() async {
    if (currentUserUid.isEmpty || _savingSwimVideo) {
      return;
    }
    await _openAddSwimVideoSheet();
  }

  Future<String?> _ensureVideoThumbnail(String videoPath) {
    final key = videoPath.trim();
    if (key.isEmpty) {
      return Future.value(null);
    }
    return _videoThumbCache.putIfAbsent(
      key,
      () async {
        try {
          final out = await VideoThumbnail.thumbnailFile(
            video: key,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 420,
            quality: 75,
          );
          return out;
        } catch (_) {
          return null;
        }
      },
    );
  }

  String _shortStroke(String stroke) {
    final s = stroke.trim().toLowerCase();
    if (s.startsWith('free')) return 'Free';
    if (s.startsWith('back')) return 'Back';
    if (s.startsWith('breast')) return 'Breast';
    if (s.startsWith('butter')) return 'Fly';
    if (s == 'im') return 'IM';
    return stroke.trim().isEmpty ? 'Race' : stroke.trim();
  }

  Future<void> _openAddSwimVideoSheet({
    LocalSwimVideoEntry? existingEntry,
    String? initialStroke,
    int initialDistance = 0,
    String initialUnit = 'Y',
    bool initialIsLongCourse = false,
    String initialHeat = '',
    String initialLane = '',
    String initialEventLabel = '',
    String initialNote = '',
    bool quickRecordFirst = false,
  }) async {
    final seed = existingEntry;
    final eventController = TextEditingController(
      text: seed?.eventLabel.trim().isNotEmpty == true
          ? seed!.eventLabel
          : initialEventLabel,
    );
    final noteController = TextEditingController(
      text: seed?.note ?? initialNote,
    );
    _MeetEventOption? selectedEvent;
    int selectedDistance = seed?.distance ?? initialDistance;
    String selectedUnit = (seed?.unit ?? initialUnit).trim().toUpperCase();
    bool selectedLongCourse = seed?.isLongCourse ?? initialIsLongCourse;
    String selectedHeat = (seed?.heat ?? initialHeat).trim();
    String selectedLane = (seed?.lane ?? initialLane).trim();
    var selectedStroke = (seed?.stroke ?? initialStroke ?? '').trim().isNotEmpty
        ? (seed?.stroke ?? initialStroke!).trim()
        : (_strokePresets.isNotEmpty ? _strokePresets.first : 'Freestyle');
    XFile? picked;
    var capturedFromCamera = false;

    if (quickRecordFirst) {
      picked = await _mediaPicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );
      capturedFromCamera = picked != null;
      if (picked == null) {
        return;
      }
      if (eventController.text.trim().isEmpty) {
        eventController.text =
            'Started ${dateTimeFormat('h:mm a', DateTime.now())}';
      }
    }
    if (!mounted) {
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ObsidianVoltTokens.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16.0,
            12.0,
            16.0,
            16.0 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                seed == null ? 'Add Event' : 'Edit Event',
                style: GoogleFonts.sora(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10.0),
              if (_meetEventOptions.isNotEmpty && seed == null) ...[
                Text(
                  'Event mapping',
                  style: GoogleFonts.sora(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                    color: _slate500,
                  ),
                ),
                const SizedBox(height: 6.0),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: [
                    ..._meetEventOptions.map(
                      (e) => ChoiceChip(
                        label: Text(
                          e.label,
                          style: GoogleFonts.sora(fontSize: 11.5),
                        ),
                        selected: selectedEvent?.label == e.label,
                        onSelected: (_) {
                          setSheetState(() {
                            selectedEvent = e;
                            if (e.stroke.trim().isNotEmpty) {
                              selectedStroke = e.stroke.trim();
                            }
                            if (e.distance > 0) {
                              selectedDistance = e.distance;
                            }
                            if (e.unit.trim().isNotEmpty) {
                              selectedUnit = e.unit.trim();
                            }
                            selectedLongCourse = e.isLongCourse;
                            selectedHeat = e.heat.trim();
                            selectedLane = e.lane.trim();
                            eventController.text = e.label;
                          });
                        },
                      ),
                    ),
                    ActionChip(
                      label: Text(
                        'Custom',
                        style: GoogleFonts.sora(fontSize: 11.5),
                      ),
                      onPressed: () async {
                        final custom = await _openCustomEventBuilder(
                          stroke: selectedStroke,
                          distance:
                              selectedDistance == 0 ? 50 : selectedDistance,
                          unit: selectedUnit,
                          isLongCourse: selectedLongCourse,
                        );
                        if (custom == null) return;
                        setSheetState(() {
                          selectedStroke = custom.stroke;
                          selectedDistance = custom.distance;
                          selectedUnit = custom.unit;
                          selectedLongCourse = custom.isLongCourse;
                          selectedHeat = custom.heat.trim();
                          selectedLane = custom.lane.trim();
                          selectedEvent = custom;
                          eventController.text = custom.label;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
              ],
              DropdownButtonFormField<String>(
                initialValue: selectedStroke,
                style: GoogleFonts.sora(
                  fontSize: 14.0,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  labelText: 'Stroke',
                  labelStyle: GoogleFonts.sora(color: const Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                items: _strokePresets
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s, style: GoogleFonts.sora()),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setSheetState(() => selectedStroke = v);
                },
              ),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(
                        text: selectedDistance <= 0
                            ? ''
                            : selectedDistance.toString(),
                      ),
                      onChanged: (v) {
                        final parsed = int.tryParse(v.trim()) ?? 0;
                        selectedDistance = parsed;
                      },
                      style: GoogleFonts.sora(
                        fontSize: 14.0,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Distance',
                        labelStyle:
                            GoogleFonts.sora(color: const Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  SizedBox(
                    width: 96.0,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedUnit,
                      style: GoogleFonts.sora(
                        fontSize: 14.0,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        labelStyle:
                            GoogleFonts.sora(color: const Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      items: const ['Y', 'M']
                          .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setSheetState(() => selectedUnit = v);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedHeat.isEmpty ? null : selectedHeat,
                      style: GoogleFonts.sora(
                        fontSize: 14.0,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Heat',
                        labelStyle:
                            GoogleFonts.sora(color: const Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      items: List<String>.generate(20, (i) => '${i + 1}')
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(v, style: GoogleFonts.sora()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setSheetState(() => selectedHeat = v ?? ''),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedLane.isEmpty ? null : selectedLane,
                      style: GoogleFonts.sora(
                        fontSize: 14.0,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Lane',
                        labelStyle:
                            GoogleFonts.sora(color: const Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      items: List<String>.generate(10, (i) => '${i + 1}')
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(v, style: GoogleFonts.sora()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setSheetState(() => selectedLane = v ?? ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              TextField(
                controller: eventController,
                style: GoogleFonts.sora(
                  fontSize: 14.0,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  labelText: 'Event label (optional)',
                  labelStyle: GoogleFonts.sora(color: const Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
              const SizedBox(height: 8.0),
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: GoogleFonts.sora(
                  fontSize: 14.0,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  labelStyle: GoogleFonts.sora(color: const Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
              const SizedBox(height: 10.0),
              Wrap(
                spacing: 8.0,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final v = await _mediaPicker.pickVideo(
                        source: ImageSource.camera,
                        maxDuration: const Duration(minutes: 5),
                      );
                      if (v != null) {
                        capturedFromCamera = true;
                        setSheetState(() => picked = v);
                      }
                    },
                    icon: const Icon(Icons.videocam_rounded),
                    label: const Text('Record'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final v = await _mediaPicker.pickVideo(
                        source: ImageSource.gallery,
                      );
                      if (v != null) {
                        capturedFromCamera = false;
                        setSheetState(() => picked = v);
                      }
                    },
                    icon: const Icon(Icons.video_library_rounded),
                    label: const Text('Choose video'),
                  ),
                ],
              ),
              if (picked != null) ...[
                const SizedBox(height: 6.0),
                Text(
                  picked!.name,
                  style: GoogleFonts.sora(fontSize: 12.0, color: _slate500),
                ),
              ],
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: FilledButton(
                      onPressed: _savingSwimVideo
                          ? null
                          : () => Navigator.pop(ctx, true),
                      child: Text(seed == null ? 'Save Event' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != true) {
      return;
    }
    setState(() => _savingSwimVideo = true);
    try {
      final normalizedEventLabel = eventController.text.trim().isNotEmpty
          ? eventController.text.trim()
          : (selectedDistance > 0
              ? '$selectedDistance${selectedUnit.trim().toUpperCase()} ${_shortStroke(selectedStroke)}'
              : (_shortStroke(selectedStroke).trim().isEmpty
                  ? 'Race'
                  : _shortStroke(selectedStroke)));
      var copied = seed?.path ?? '';
      var thumb = seed?.thumbnailPath ?? '';
      if (picked != null) {
        copied = await LocalMeetMediaStore.copyIntoLocalMedia(
          picked!.path,
          'videos',
        );
        if (capturedFromCamera) {
          try {
            await GallerySaver.saveVideo(copied, albumName: 'Swim Agent');
          } catch (_) {}
        }
        thumb = await _ensureVideoThumbnail(copied) ?? '';
      }
      final item = LocalSwimVideoEntry(
        id: seed?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        path: copied,
        thumbnailPath: thumb,
        stroke: selectedStroke,
        distance: selectedDistance,
        unit: selectedUnit,
        isLongCourse: selectedLongCourse,
        createdAt: DateTime.now(),
        eventLabel: normalizedEventLabel,
        heat: selectedHeat,
        lane: selectedLane,
        note: noteController.text.trim(),
      );
      final next = <LocalSwimVideoEntry>[
        ..._swimVideos.where((e) => e.id != item.id),
        item,
      ];
      await LocalMeetMediaStore.saveVideos(currentUserUid, widget.meetId, next);
      if (!mounted) return;
      final oldKey = seed == null
          ? ''
          : _enteredEventKeyFromFields(
              label: seed.eventLabel,
              heat: seed.heat,
              lane: seed.lane,
            );
      final newKey = _enteredEventKeyFromFields(
        label: item.eventLabel,
        heat: item.heat,
        lane: item.lane,
      );
      setState(() {
        _swimVideos = next;
        final order = _enteredEventOrderKeys.toList();
        final oldIndex = oldKey.isEmpty ? -1 : order.indexOf(oldKey);
        if (oldIndex >= 0) {
          order[oldIndex] = newKey;
        } else if (!order.contains(newKey)) {
          order.add(newKey);
        }
        _enteredEventOrderKeys = order;
      });
      _persistEnteredEventOrder();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copied.isEmpty
                ? 'Event saved. You can record video later from this row.'
                : (seed == null
                    ? 'Event and video saved on this device.'
                    : 'Event updated.'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save video locally.')),
      );
    } finally {
      if (mounted) setState(() => _savingSwimVideo = false);
    }
  }

  String _normalizedEventKey(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _enteredEventKeyFromFields({
    required String label,
    String heat = '',
    String lane = '',
  }) {
    return '${_normalizedEventKey(label)}|${heat.trim()}|${lane.trim()}';
  }

  String _enteredEventKey(_MeetEventOption event) {
    return _enteredEventKeyFromFields(
      label: event.label,
      heat: event.heat,
      lane: event.lane,
    );
  }

  Future<void> _persistEnteredEventOrder() async {
    if (currentUserUid.isEmpty) {
      return;
    }
    await LocalMeetMediaStore.saveEnteredEventOrder(
      currentUserUid,
      widget.meetId,
      _enteredEventOrderKeys,
    );
  }

  LocalSwimVideoEntry? _videoForMeetEvent(_MeetEventOption event) {
    final eventKey = _normalizedEventKey(event.label);
    LocalSwimVideoEntry? matchedWithoutVideo;
    for (final video in _swimVideos) {
      if (_normalizedEventKey(video.eventLabel) == eventKey) {
        if (video.path.trim().isNotEmpty) {
          return video;
        }
        matchedWithoutVideo ??= video;
      }
    }
    if (matchedWithoutVideo != null) {
      return matchedWithoutVideo;
    }
    final stroke = event.stroke.trim().toLowerCase();
    if (stroke.isEmpty) {
      return null;
    }
    LocalSwimVideoEntry? strokeMatchedWithoutVideo;
    for (final video in _swimVideos) {
      if (video.stroke.trim().toLowerCase() != stroke) {
        continue;
      }
      if (event.distance > 0 &&
          video.distance > 0 &&
          video.distance != event.distance) {
        continue;
      }
      final unit = event.unit.trim().toUpperCase();
      if (event.distance > 0 &&
          video.unit.trim().toUpperCase().isNotEmpty &&
          unit.isNotEmpty &&
          video.unit.trim().toUpperCase() != unit) {
        continue;
      }
      if (video.path.trim().isNotEmpty) {
        return video;
      }
      strokeMatchedWithoutVideo ??= video;
    }
    return strokeMatchedWithoutVideo;
  }

  Future<void> _editEvent(_MeetEventOption event) async {
    await _openAddSwimVideoSheet(
      existingEntry: _videoForMeetEvent(event),
      initialStroke:
          event.stroke.trim().isNotEmpty ? event.stroke.trim() : null,
      initialDistance: event.distance,
      initialUnit:
          event.unit.trim().isEmpty ? 'Y' : event.unit.trim().toUpperCase(),
      initialIsLongCourse: event.isLongCourse,
      initialHeat: event.heat.trim(),
      initialLane: event.lane.trim(),
      initialEventLabel: event.label,
      quickRecordFirst: false,
    );
  }

  Future<void> _openQuickVideoSourcePicker(_MeetEventOption event) async {
    if (_savingSwimVideo) {
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      backgroundColor: ObsidianVoltTokens.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add video',
              style: GoogleFonts.sora(
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              event.label,
              style: GoogleFonts.sora(
                fontSize: 12.5,
                color: _slate500,
              ),
            ),
            const SizedBox(height: 8.0),
            ListTile(
              leading: const Icon(Icons.videocam_rounded),
              title: const Text('Record now'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_rounded),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }
    await _quickAttachVideoForEvent(event, source);
  }

  Future<void> _quickAttachVideoForEvent(
    _MeetEventOption event,
    ImageSource source,
  ) async {
    final picked = await _mediaPicker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _savingSwimVideo = true);
    try {
      final existing = _videoForMeetEvent(event);
      final copied = await LocalMeetMediaStore.copyIntoLocalMedia(
        picked.path,
        'videos',
      );
      if (source == ImageSource.camera) {
        try {
          await GallerySaver.saveVideo(copied, albumName: 'Swim Agent');
        } catch (_) {}
      }
      final thumb = await _ensureVideoThumbnail(copied) ?? '';
      final item = LocalSwimVideoEntry(
        id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        path: copied,
        thumbnailPath: thumb,
        stroke: event.stroke.trim(),
        distance: event.distance,
        unit: event.unit.trim().isEmpty ? 'Y' : event.unit.trim().toUpperCase(),
        isLongCourse: event.isLongCourse,
        createdAt: existing?.createdAt ?? DateTime.now(),
        eventLabel: event.label.trim(),
        heat: event.heat.trim(),
        lane: event.lane.trim(),
        note: existing?.note ?? '',
      );
      final next = <LocalSwimVideoEntry>[
        ..._swimVideos.where((e) => e.id != item.id),
        item,
      ];
      await LocalMeetMediaStore.saveVideos(currentUserUid, widget.meetId, next);
      if (!mounted) {
        return;
      }
      setState(() {
        _swimVideos = next;
        final key = _enteredEventKey(event);
        if (!_enteredEventOrderKeys.contains(key)) {
          _enteredEventOrderKeys = [..._enteredEventOrderKeys, key];
        }
      });
      _persistEnteredEventOrder();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video added to event.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add video. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingSwimVideo = false);
      }
    }
  }

  List<_MeetEventOption> _enteredEventsForDisplay() {
    final out = <_MeetEventOption>[];
    final seen = <String>{};
    for (final event in _meetEventOptions) {
      final key = _normalizedEventKey(event.label);
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      // Override heat/lane from the locally-saved video entry so edits made
      // in the sheet are reflected immediately in the list.
      final video = _videoForMeetEvent(event);
      final heat =
          (video?.heat.trim().isNotEmpty == true) ? video!.heat.trim() : event.heat;
      final lane =
          (video?.lane.trim().isNotEmpty == true) ? video!.lane.trim() : event.lane;
      out.add(heat == event.heat && lane == event.lane
          ? event
          : _MeetEventOption(
              label: event.label,
              stroke: event.stroke,
              distance: event.distance,
              unit: event.unit,
              isLongCourse: event.isLongCourse,
              heat: heat,
              lane: lane,
            ));
    }
    for (final video in _swimVideos) {
      var label = video.eventLabel.trim();
      var heat = video.heat.trim();
      var lane = video.lane.trim();
      if (heat.isEmpty || lane.isEmpty) {
        final m =
            RegExp(r'^\s*(\d{1,2})\s*[/-]\s*(\d{1,2})\s*$').firstMatch(label);
        if (m != null) {
          heat = heat.isEmpty ? (m.group(1) ?? '').trim() : heat;
          lane = lane.isEmpty ? (m.group(2) ?? '').trim() : lane;
          if (video.distance > 0 || video.stroke.trim().isNotEmpty) {
            final stroke = _shortStroke(video.stroke).trim();
            label = video.distance > 0
                ? '${video.distance}${video.unit.trim().toUpperCase()} ${stroke.isEmpty ? 'Race' : stroke}'
                : (stroke.isEmpty ? 'Race' : stroke);
          }
        }
      }
      if (label.isEmpty) {
        final stroke = _shortStroke(video.stroke).trim();
        if (video.distance > 0) {
          final unit =
              video.unit.trim().isEmpty ? 'Y' : video.unit.trim().toUpperCase();
          label = '${video.distance}$unit ${stroke.isEmpty ? 'Race' : stroke}';
        } else {
          label = stroke.isEmpty ? 'Race' : stroke;
        }
      }
      final key = _normalizedEventKey(label);
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      out.add(
        _MeetEventOption(
          label: label,
          stroke: video.stroke,
          distance: video.distance,
          unit: video.unit,
          isLongCourse: video.isLongCourse,
          heat: heat,
          lane: lane,
        ),
      );
    }
    final rank = <String, int>{};
    for (var i = 0; i < _enteredEventOrderKeys.length; i++) {
      rank[_enteredEventOrderKeys[i]] = i;
    }
    out.sort((a, b) {
      final ar = rank[_enteredEventKey(a)] ?? 1 << 20;
      final br = rank[_enteredEventKey(b)] ?? 1 << 20;
      if (ar != br) {
        return ar.compareTo(br);
      }
      // Both events have no custom order — sort by event number from label
      // (e.g. "Event 3 – 100 Freestyle" → 3).
      return _eventNumberFromLabel(a.label)
          .compareTo(_eventNumberFromLabel(b.label));
    });
    return out;
  }

  /// Extracts the numeric event number from a label like "Event 3 – 100 Free".
  /// Returns [double.maxFinite.toInt()] when no number is found so unlabelled
  /// events sort to the end.
  static int _eventNumberFromLabel(String label) {
    final m = RegExp(r'Event\s+(\d+)', caseSensitive: false).firstMatch(label);
    if (m != null) {
      return int.tryParse(m.group(1)!) ?? (1 << 20);
    }
    return 1 << 20;
  }

  Future<_MeetEventOption?> _openCustomEventBuilder({
    required String stroke,
    required int distance,
    required String unit,
    required bool isLongCourse,
  }) async {
    var d = distance;
    var u = unit;
    var s = stroke.trim().isEmpty ? 'Freestyle' : stroke.trim();
    var lc = isLongCourse;
    return showModalBottomSheet<_MeetEventOption>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Custom event',
                style: GoogleFonts.sora(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8.0),
              NumberPicker(
                minValue: 25,
                maxValue: 1650,
                step: 25,
                value: d <= 0 ? 50 : d,
                onChanged: (v) => setSheet(() => d = v),
              ),
              const SizedBox(height: 4.0),
              DropdownButtonFormField<String>(
                initialValue: u,
                style: GoogleFonts.sora(
                  fontSize: 14.0,
                  color: const Color(0xFF0F172A),
                ),
                items: const ['Y', 'M']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setSheet(() => u = v);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Unit',
                  labelStyle: GoogleFonts.sora(color: const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 8.0),
              DropdownButtonFormField<String>(
                initialValue: s,
                style: GoogleFonts.sora(
                  fontSize: 14.0,
                  color: const Color(0xFF0F172A),
                ),
                items: _strokePresets
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setSheet(() => s = v);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Stroke',
                  labelStyle: GoogleFonts.sora(color: const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 6.0),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: lc,
                onChanged: (v) => setSheet(() => lc = v),
                title: Text(
                  'Long course',
                  style: GoogleFonts.sora(fontSize: 13.0),
                ),
              ),
              FilledButton(
                onPressed: () {
                  final label = '$d$u ${_shortStroke(s)}';
                  Navigator.pop(
                    ctx,
                    _MeetEventOption(
                      label: label,
                      stroke: s,
                      distance: d,
                      unit: u,
                      isLongCourse: lc,
                    ),
                  );
                },
                child: const Text('Use event'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _playVideoInApp(LocalSwimVideoEntry video) async {
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LocalVideoPlayerPage(video: video),
      ),
    );
  }

  Future<void> _deleteSwimVideo(LocalSwimVideoEntry video) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ObsidianVoltTokens.bgSurface,
        title: Text('Delete video?',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        content: Text(
          'This removes the local video reference from this meet.',
          style: GoogleFonts.sora(fontSize: 14.0, color: _slate600),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final next = _swimVideos.where((e) => e.id != video.id).toList();
    await LocalMeetMediaStore.saveVideos(currentUserUid, widget.meetId, next);
    try {
      final f = File(video.path);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _swimVideos = next;
      final active = _enteredEventsForDisplay().map(_enteredEventKey).toSet();
      _enteredEventOrderKeys =
          _enteredEventOrderKeys.where((k) => active.contains(k)).toList();
    });
    _persistEnteredEventOrder();
  }

  Future<void> _deletePersonalResourceFromList(
      PersonalMeetResourceEntry entry) async {
    if (entry.id.trim().isEmpty) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ObsidianVoltTokens.bgSurface,
        title: Text(
          'Delete resource?',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will remove this resource from your meet resources.',
          style: GoogleFonts.sora(fontSize: 14.0, color: _slate600),
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
              'Delete',
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      await deletePersonalMeetResource(
        currentUserUid,
        widget.meetId,
        entry.id,
      );
      await LocalMeetMediaStore.clearPhotos(
        currentUserUid,
        widget.meetId,
        entry.id,
      );
      if (!mounted) return;
      setState(() => _resourceMediaRevision++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resource deleted.')),
      );
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloud Sync Error')),
      );
    }
  }

  Widget _buildMyMeetResourcesSection() {
    if (currentUserUid.isEmpty) {
      return _softCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Sign in to save personal links and notes for this meet.',
            style: GoogleFonts.sora(
              fontSize: 13.0,
              color: _slate500,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<List<PersonalMeetResourceEntry>>(
      stream: streamPersonalMeetResources(currentUserUid, widget.meetId),
      builder: (context, snap) {
        final resources = snap.data ?? const <PersonalMeetResourceEntry>[];

        return _softCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Private links, photos, and notes for this meet.',
                        style: GoogleFonts.sora(
                          fontSize: 12.0,
                          height: 1.35,
                          color: _slate500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    _sectionAddPill(
                      label: 'Add Resource',
                      onPressed: () => _openPersonalResourceEditor(),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    ),
                  )
                else if (snap.hasError)
                  Text(
                    'Could not load meet resources. Please try again.',
                    style: GoogleFonts.sora(
                      fontSize: 12.5,
                      color: _slate500,
                    ),
                  )
                else if (resources.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No resources yet.',
                          style: GoogleFonts.sora(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Add links, photos, volunteer jobs, reminders, or notes for this meet.',
                          style: GoogleFonts.sora(
                            fontSize: 12.0,
                            color: _slate500,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFCFF),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: SwimUiTokens.cardSurfaceEdgeBorder,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < resources.length; i++) ...[
                          _personalResourceRow(resources[i]),
                          if (i != resources.length - 1)
                            const Divider(
                              height: 1.0,
                              thickness: 1.0,
                              color: Color(0xFFE2E8F0),
                            ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _personalResourceRow(PersonalMeetResourceEntry entry) {
    final photosFuture = LocalMeetMediaStore.listPhotos(
      currentUserUid,
      widget.meetId,
      entry.id,
      fallbackResourceIds: <String>[
        entry.kind.firestoreValue,
        entry.resourceLabel.trim().toLowerCase().replaceAll(' ', '_'),
      ],
    );
    return FutureBuilder<List<LocalResourcePhoto>>(
      future: photosFuture,
      key: ValueKey('${entry.id}::$_resourceMediaRevision'),
      builder: (context, snap) {
        final photos = snap.data ?? const <LocalResourcePhoto>[];
        final photoCount = photos.length;
        final firstPhoto = photoCount > 0 ? photos.first : null;
        final formatted = _formatPersonalResourceContent(entry);
        final hasUrlOrText = formatted.url.isNotEmpty ||
            formatted.main.isNotEmpty ||
            formatted.secondary.isNotEmpty;
        final metadataParts = <String>[];
        if (photoCount > 0) {
          metadataParts.add(
            '$photoCount photo${photoCount == 1 ? '' : 's'} attached',
          );
        }
        if (entry.updatedAt != null) {
          metadataParts.add(
            'Updated ${dateTimeFormat('MMM d · h:mm a', entry.updatedAt)}',
          );
        }
        final metadata = metadataParts.join(' · ');

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openPersonalResourceEditor(initial: entry),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 10.0, 8.0, 10.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _resourceLeadingPreview(
                    kind: entry.kind,
                    firstPhoto: firstPhoto,
                    photoCount: photoCount,
                    hasUrlOrText: hasUrlOrText,
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 230.0;
                        final titleLines = isNarrow ? 1 : 1;
                        final mainLines = isNarrow ? 1 : 2;
                        final secondaryLines = isNarrow ? 1 : 2;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatted.title,
                              maxLines: titleLines,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.sora(
                                fontSize: isNarrow ? 13.0 : 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            if (formatted.main.isNotEmpty) ...[
                              const SizedBox(height: 2.0),
                              _resourceDetailLine(
                                formatted.main,
                                isMain: true,
                                maxLines: mainLines,
                              ),
                            ],
                            if (formatted.secondary.isNotEmpty) ...[
                              const SizedBox(height: 2.0),
                              _resourceDetailLine(
                                formatted.secondary,
                                maxLines: secondaryLines,
                              ),
                            ],
                            if (formatted.url.isNotEmpty) ...[
                              const SizedBox(height: 3.0),
                              _resourceLinkLine(
                                formatted.url,
                                maxLines: isNarrow ? 1 : 2,
                              ),
                            ],
                            if (metadata.isNotEmpty) ...[
                              const SizedBox(height: 4.0),
                              Text(
                                metadata,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sora(
                                  fontSize: isNarrow ? 10.5 : 10.8,
                                  color: _slate500,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More actions',
                    color: ObsidianVoltTokens.bgSurface,
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openPersonalResourceEditor(initial: entry);
                      } else if (value == 'delete') {
                        _deletePersonalResourceFromList(entry);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 20.0,
                      color: _slate500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  ({String title, String main, String secondary, String url})
      _formatPersonalResourceContent(
    PersonalMeetResourceEntry entry,
  ) {
    final notes = entry.notes.trim();
    final url = entry.normalizedUrl;
    switch (entry.kind) {
      case PersonalResourceKind.psychSheet:
      case PersonalResourceKind.timeline:
        return (
          title: entry.kind.uiTitle,
          main: '',
          secondary: notes,
          url: url,
        );
      case PersonalResourceKind.heatSheet:
        return (
          title: entry.kind.uiTitle,
          main: url.isEmpty ? notes : '',
          secondary: url.isEmpty ? '' : notes,
          url: url,
        );
      case PersonalResourceKind.volunteerJob:
        final range = _formatTimeRange(entry.startTime, entry.endTime);
        final secondary = [
          if (range.isNotEmpty) range,
          if (entry.location.trim().isNotEmpty) entry.location.trim(),
        ].join(' · ');
        return (
          title: entry.kind.uiTitle,
          main: entry.title.trim(),
          secondary: secondary,
          url: '',
        );
      case PersonalResourceKind.warmupInfo:
        final dateTime = _formatDateTimeLine(entry.date, entry.time);
        return (
          title: entry.kind.uiTitle,
          main: dateTime,
          secondary:
              entry.location.trim().isNotEmpty ? entry.location.trim() : notes,
          url: '',
        );
      case PersonalResourceKind.parkingInfo:
        return (
          title: entry.kind.uiTitle,
          main: entry.address.trim(),
          secondary: notes,
          url: url,
        );
      case PersonalResourceKind.reminder:
        return (
          title: entry.kind.uiTitle,
          main: entry.title.trim(),
          secondary: _formatDateTimeLine(entry.date, entry.time),
          url: '',
        );
      case PersonalResourceKind.otherNote:
        final title = entry.title.trim();
        return (
          title: entry.kind.uiTitle,
          main: title.isNotEmpty ? title : notes,
          secondary: title.isNotEmpty ? notes : '',
          url: url,
        );
    }
  }

  String _formatTimeRange(String start, String end) {
    final s = start.trim();
    final e = end.trim();
    if (s.isNotEmpty && e.isNotEmpty) {
      return '$s-$e'.replaceFirst('-', '–');
    }
    return s.isNotEmpty ? s : e;
  }

  String _formatDateTimeLine(String date, String time) {
    final d = date.trim();
    final t = time.trim();
    if (d.isNotEmpty && t.isNotEmpty) {
      return '$d · $t';
    }
    if (t.isNotEmpty) {
      return 'Warmup at $t';
    }
    return d;
  }

  Widget _resourceDetailLine(
    String text, {
    bool isMain = false,
    int maxLines = 2,
  }) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.sora(
        fontSize: isMain ? 12.6 : 12.2,
        height: 1.3,
        color: isMain ? _slate700 : _slate600,
        fontWeight: isMain ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }

  Widget _resourceLeadingPreview({
    required PersonalResourceKind kind,
    required LocalResourcePhoto? firstPhoto,
    required int photoCount,
    required bool hasUrlOrText,
  }) {
    final size = 48.0;
    if (firstPhoto == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: SwimUiTokens.cardSurfaceEdgeBorder,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          hasUrlOrText
              ? _resourceTypeIcon(kind)
              : Icons.insert_drive_file_outlined,
          size: 18.0,
          color: _slate500,
        ),
      );
    }
    return GestureDetector(
      onTap: () => _openResourcePhotoFullscreen(firstPhoto.path),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: Image.file(
                  File(firstPhoto.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFE2E8F0),
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, size: 16.0),
                  ),
                ),
              ),
            ),
            if (photoCount > 1)
              Positioned(
                right: 3.0,
                bottom: 3.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4.0, vertical: 1.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999.0),
                  ),
                  child: Text(
                    '+${photoCount - 1}',
                    style: GoogleFonts.sora(
                      fontSize: 9.0,
                      fontWeight: FontWeight.w700,
                      color: ObsidianVoltTokens.textPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resourceLinkLine(String normalizedUrl, {int maxLines = 1}) {
    return InkWell(
      onTap: () => launchURL(normalizedUrl),
      borderRadius: BorderRadius.circular(6.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _urlHostPreview(normalizedUrl),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: FlutterFlowTheme.of(context).primary,
                  decoration: TextDecoration.underline,
                  decorationColor: FlutterFlowTheme.of(context)
                      .primary
                      .withValues(alpha: 0.35),
                ),
              ),
            ),
            const SizedBox(width: 4.0),
            Icon(
              Icons.open_in_new_rounded,
              size: 13.0,
              color: FlutterFlowTheme.of(context).primary,
            ),
          ],
        ),
      ),
    );
  }

  IconData _resourceTypeIcon(PersonalResourceKind kind) {
    switch (kind) {
      case PersonalResourceKind.psychSheet:
        return Icons.psychology_alt_outlined;
      case PersonalResourceKind.timeline:
        return Icons.schedule_rounded;
      case PersonalResourceKind.heatSheet:
        return Icons.table_chart_outlined;
      case PersonalResourceKind.volunteerJob:
        return Icons.volunteer_activism_outlined;
      case PersonalResourceKind.warmupInfo:
        return Icons.directions_run_rounded;
      case PersonalResourceKind.parkingInfo:
        return Icons.local_parking_outlined;
      case PersonalResourceKind.reminder:
        return Icons.notifications_active_outlined;
      case PersonalResourceKind.otherNote:
        return Icons.notes_rounded;
    }
  }

  Widget _buildSwimVideosSection() {
    final displayEvents = _enteredEventsForDisplay();
    final hasEvents = displayEvents.isNotEmpty;
    return _softCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Each event can have one race clip on this device.',
                    style: GoogleFonts.sora(
                      fontSize: 12.0,
                      height: 1.35,
                      color: _slate500,
                    ),
                  ),
                ),
                _sectionAddPill(
                  label: 'Add Event',
                  onPressed: _savingSwimVideo ? null : _addSwimVideo,
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            if (_loadingSwimVideos)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                ),
              )
            else if (!hasEvents)
              SizedBox(
                height: 132.0,
                child: _DashedPlaceholderCard(
                  text: 'No entered events yet.',
                  subtitle:
                      'Once entries sync, each event will get a row for quick recording.',
                  onTap: _addSwimVideo,
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayEvents.length,
                onReorder: (oldIndex, newIndex) {
                  final orderedKeys =
                      displayEvents.map(_enteredEventKey).toList();
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final moved = orderedKeys.removeAt(oldIndex);
                  orderedKeys.insert(newIndex, moved);
                  final remaining = _enteredEventOrderKeys
                      .where((k) => !orderedKeys.contains(k))
                      .toList();
                  setState(() =>
                      _enteredEventOrderKeys = [...orderedKeys, ...remaining]);
                  _persistEnteredEventOrder();
                },
                itemBuilder: (context, index) {
                  final event = displayEvents[index];
                  final video = _videoForMeetEvent(event);
                  final hasHeatLane = event.heat.trim().isNotEmpty ||
                      event.lane.trim().isNotEmpty;
                  final heatLaneLine = [
                    if (event.heat.trim().isNotEmpty)
                      'Heat ${event.heat.trim()}',
                    if (event.lane.trim().isNotEmpty)
                      'Lane ${event.lane.trim()}',
                  ].join(' · ');
                  final hasVideo =
                      video != null && video.path.trim().isNotEmpty;
                  return Container(
                    key: ValueKey('entered_event_${_enteredEventKey(event)}'),
                    margin: EdgeInsets.only(
                        bottom: index == displayEvents.length - 1 ? 0.0 : 2.0),
                    padding: const EdgeInsets.fromLTRB(4.0, 10.0, 4.0, 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.sora(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3.0),
                                  Text(
                                    hasHeatLane
                                        ? heatLaneLine
                                        : 'Heat and lane not set',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.sora(
                                      fontSize: 11.0,
                                      color: _slate500,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10.0),
                            _videoStatusBadge(hasVideo: hasVideo),
                            const SizedBox(width: 2.0),
                            ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                size: 18.0,
                                color: _slate500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        const Divider(
                            height: 1.0,
                            thickness: 1.0,
                            color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 2.0),
                        SizedBox(
                          height: 36.0,
                          child: Row(
                            children: [
                              if (hasVideo)
                                TextButton.icon(
                                  onPressed: () => _playVideoInApp(video),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    minimumSize: const Size(0.0, 30.0),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6.0),
                                  ),
                                  icon: const Icon(
                                    Icons.play_circle_fill_rounded,
                                    size: 16.0,
                                  ),
                                  label: const Text('View video'),
                                )
                              else
                                TextButton.icon(
                                  onPressed: _savingSwimVideo
                                      ? null
                                      : () =>
                                          _openQuickVideoSourcePicker(event),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    minimumSize: const Size(0.0, 30.0),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6.0),
                                  ),
                                  icon: const Icon(
                                    Icons.videocam_rounded,
                                    size: 16.0,
                                  ),
                                  label: const Text('Add video'),
                                ),
                              const Spacer(),
                              TextButton(
                                onPressed: _savingSwimVideo
                                    ? null
                                    : () => _editEvent(event),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  minimumSize: const Size(0.0, 30.0),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                ),
                                child: const Text('Edit'),
                              ),
                              if (hasVideo)
                                PopupMenuButton<String>(
                                  tooltip: 'More actions',
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _deleteSwimVideo(video);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('Delete video'),
                                    ),
                                  ],
                                  icon: const Icon(Icons.more_horiz_rounded,
                                      size: 18.0),
                                  color: ObsidianVoltTokens.bgSurface,
                                ),
                            ],
                          ),
                        ),
                        if (index != displayEvents.length - 1)
                          const Padding(
                            padding: EdgeInsets.only(top: 6.0),
                            child: Divider(
                                height: 1.0,
                                thickness: 1.0,
                                color: Color(0xFFE2E8F0)),
                          ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 10.0),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 9.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: SwimUiTokens.cardSurfaceEdgeBorder,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15.0, color: _slate500),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'Videos are stored only on this device and won’t be shared.',
                      style: GoogleFonts.sora(
                        fontSize: 11.0,
                        color: _slate500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoStatusBadge({required bool hasVideo}) {
    final bg = hasVideo ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9);
    final fg = hasVideo ? const Color(0xFF047857) : const Color(0xFF64748B);
    return Container(
      height: 24.0,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999.0),
        border: Border.all(
          color: hasVideo ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasVideo ? Icons.check_circle_rounded : Icons.videocam_off_rounded,
            size: 12.0,
            color: fg,
          ),
          const SizedBox(width: 4.0),
          Text(
            hasVideo ? 'Video saved' : 'No video yet',
            style: GoogleFonts.sora(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionAddPill({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFFEFF6FF),
        minimumSize: const Size(0.0, 32.0),
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999.0),
        ),
      ),
      icon: Icon(
        Icons.add_rounded,
        size: 16.0,
        color: FlutterFlowTheme.of(context).primary,
      ),
      label: Text(
        label,
        style: GoogleFonts.sora(
          fontWeight: FontWeight.w700,
          color: FlutterFlowTheme.of(context).primary,
        ),
      ),
    );
  }

  Future<void> _openResourcePhotoFullscreen(String path) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Image.file(
                    File(path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(
                      'Could not load photo.',
                      style: GoogleFonts.sora(
                          color: ObsidianVoltTokens.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 44.0,
              right: 12.0,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded),
                color: ObsidianVoltTokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
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
        color: ObsidianVoltTokens.bgSurface,
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
    final label = entered
        ? 'Entered'
        : meetStatusLabel(
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

    return Hero(
      tag: widget.heroTag,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: ObsidianVoltTokens.bgSurface,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20.0),
              bottomRight: Radius.circular(20.0),
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
            padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 18.0),
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
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Color(0xFF0F172A),
                            ),
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
                      const SizedBox(height: 12.0),
                      Wrap(
                        spacing: 14.0,
                        runSpacing: 8.0,
                        children: [
                          _metaChip(
                            icon: Icons.calendar_today_outlined,
                            label: _dateRangeLabel(start, end),
                          ),
                          if (!entered && deadlineLine != null)
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
      final canOpenSignup = _signupUrl.isNotEmpty;
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
      final updatedLine = (timeCaption != null && (timeDetail ?? '').isNotEmpty)
          ? '$timeCaption $timeDetail'
          : '';
      final events = pref?.eventsEntered;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: _enteredBg,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: _enteredBorder.withValues(alpha: 0.7),
                  ),
                ),
                child: Icon(Icons.assignment_turned_in_rounded,
                    color: _enteredFg, size: 18.0),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entry Summary',
                      style: GoogleFonts.sora(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w700,
                        color: _slate500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                decoration: BoxDecoration(
                  color: _enteredBg,
                  borderRadius: BorderRadius.circular(999.0),
                  border: Border.all(color: _enteredBorder, width: 0.7),
                ),
                child: Text(
                  'Entered',
                  style: GoogleFonts.sora(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    color: _enteredFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          if (swimmerName.isNotEmpty) ...[
            Text(
              swimmerName,
              style: GoogleFonts.sora(
                fontSize: 20.0,
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
          if (updatedLine.isNotEmpty) ...[
            const SizedBox(height: 12.0),
            Text(
              updatedLine,
              style: GoogleFonts.sora(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: _slate500,
              ),
            ),
          ],
          const SizedBox(height: 14.0),
          Text(
            'You are all set. Use View Entries to open the meet site if you want to double-check events or warmups.',
            style: GoogleFonts.sora(
              fontSize: 12.0,
              height: 1.4,
              color: _slate500,
            ),
          ),
          const SizedBox(height: 16.0),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canOpenSignup ? () => launchURL(_signupUrl) : null,
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
                canOpenSignup ? 'View Entries' : 'Entries On File',
                style: GoogleFonts.sora(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          const SizedBox(height: 10.0),
          Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10.0),
            child: InkWell(
              onTap: _savingNotGoing ? null : _confirmWithdraw,
              borderRadius: BorderRadius.circular(10.0),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 9.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _savingNotGoing
                                ? 'Updating…'
                                : 'Withdraw From Meet',
                            style: GoogleFonts.sora(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                              color: _slate600,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            canOpenSignup
                                ? 'Opens the meet site in your browser.'
                                : 'No entry link on file for this meet.',
                            style: GoogleFonts.sora(
                              fontSize: 11.0,
                              color: _slate500,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16.0,
                      color: _slate500,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (currentUserUid.isEmpty) {
      return _softCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 16.0),
          child: body(null),
        ),
      );
    }

    return _softCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 16.0),
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
    required MeetDetailExtras? extras,
  }) {
    final loc = _locationForMeetInfo;
    final fullAddress = _mapPreviewAddress.trim();
    final venueLabel = loc.isNotEmpty ? loc : _displayTitle;
    final showFullAddress = fullAddress.isNotEmpty &&
        fullAddress.toLowerCase() != venueLabel.toLowerCase();
    final host = extras?.hostTeam?.trim() ?? '';
    final warmupLabel =
        warmup != null ? dateTimeFormat('EEE, MMM d · h:mm a', warmup) : '';
    final startLabel =
        start != null ? dateTimeFormat('EEE, MMM d · h:mm a', start) : '';
    final showMeetDay = warmupLabel.isNotEmpty ||
        startLabel.isNotEmpty ||
        loc.isNotEmpty ||
        host.isNotEmpty;
    final meetSheetUrl = (extras?.meetSheetUrl ?? '').trim();

    return _softCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 16.0),
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
            if (meetSheetUrl.isNotEmpty) ...[
              const SizedBox(height: 14.0),
              Text(
                'Official meet sheet',
                style: GoogleFonts.sora(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: _slate500,
                ),
              ),
              const SizedBox(height: 6.0),
              Material(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10.0),
                child: InkWell(
                  onTap: () => launchURL(meetSheetUrl),
                  borderRadius: BorderRadius.circular(10.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 10.0,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 20.0,
                          color: FlutterFlowTheme.of(context).primary,
                        ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Text(
                            _urlHostPreview(meetSheetUrl),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sora(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _slate700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 18.0,
                          color: _slate500,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (showMeetDay) ...[
              const SizedBox(height: 16.0),
              Text(
                'Schedule details',
                style: GoogleFonts.sora(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: _slate500,
                ),
              ),
              const SizedBox(height: 8.0),
              _meetDayRow(label: 'Warm-up', value: warmupLabel),
              _meetDayRow(label: 'Meet start', value: startLabel),
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 108.0,
                      child: Text(
                        'Venue',
                        style: GoogleFonts.sora(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _slate500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            venueLabel,
                            style: GoogleFonts.sora(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                              color: _slate700,
                              height: 1.3,
                            ),
                          ),
                          if (showFullAddress) ...[
                            const SizedBox(height: 2.0),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    fullAddress,
                                    style: GoogleFonts.sora(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w500,
                                      color: _slate500,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copy address',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 24.0,
                                    height: 24.0,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: fullAddress),
                                    );
                                    if (!mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Address copied'),
                                        duration: Duration(milliseconds: 1200),
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.copy_rounded,
                                    size: 15.0,
                                    color: FlutterFlowTheme.of(context).primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_isEntered && currentUserUid.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 28.0,
                            height: 28.0,
                          ),
                          alignment: Alignment.topCenter,
                          tooltip: 'Edit venue address',
                          onPressed: _savingLocationAddress
                              ? null
                              : _openLocationAddressEditor,
                          icon: _savingLocationAddress
                              ? const SizedBox(
                                  width: 16.0,
                                  height: 16.0,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.0),
                                )
                              : Icon(
                                  Icons.edit_outlined,
                                  size: 18.0,
                                  color: FlutterFlowTheme.of(context).primary,
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              _meetDayRow(label: 'Host team', value: host),
              if (_mapPreviewAddress.isNotEmpty) ...[
                const SizedBox(height: 4.0),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openInMaps(_mapPreviewAddress),
                    borderRadius: BorderRadius.circular(8.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 6.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 18.0,
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                          const SizedBox(width: 6.0),
                          Text(
                            'Open in Maps',
                            style: GoogleFonts.sora(
                              fontWeight: FontWeight.w700,
                              color: FlutterFlowTheme.of(context).primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 8.0),
            _buildCompactMapPreview(),
          ],
        ),
      ),
    );
  }

  /// Short map strip when geocoding works; otherwise a single compact line.
  Widget _buildCompactMapPreview() {
    final loc = _mapPreviewAddress;
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
    return FutureBuilder<_GeoPointLite?>(
      future: _resolvePreviewPoint(loc),
      builder: (context, snap) {
        final point = snap.data;
        final staticMapUrl = point == null
            ? null
            : 'https://static-maps.yandex.ru/1.x/'
                '?lang=en_US&ll=${point.lon},${point.lat}'
                '&z=14&size=650,220&l=map&pt=${point.lon},${point.lat},pm2rdm';
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
                child: staticMapUrl == null
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          color: const Color(0xFFF8FAFC),
                          child: Row(
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 16.0,
                                color: _slate500,
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  snap.connectionState ==
                                          ConnectionState.waiting
                                      ? 'Loading map preview...'
                                      : 'Could not locate this address. Open in Maps for navigation.',
                                  style: GoogleFonts.sora(
                                    fontSize: 12.0,
                                    color: _slate500,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Image.network(
                        staticMapUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 8.0,
                            ),
                            color: const Color(0xFFF8FAFC),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  size: 16.0,
                                  color: _slate500,
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: Text(
                                    'Map preview unavailable. Open in Maps for navigation.',
                                    style: GoogleFonts.sora(
                                      fontSize: 12.0,
                                      color: _slate500,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        );
      },
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
        padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 14.0),
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
                cursorColor: const Color(0xFF0F172A),
                decoration: InputDecoration(
                  hintText: 'Add parent notes for your family (optional).',
                  hintStyle: GoogleFonts.sora(
                    color: const Color(0xFF94A3B8),
                    fontSize: 14.0,
                  ),
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
                  color: const Color(0xFF0F172A),
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

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final swimmerName = FFAppState().currentSwimmerName.trim();
    final details = widget.activity.details;
    final start = widget.activity.startTime;
    final end = details.endTime;
    final entered = _isEntered;
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
                  16.0,
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
                      extras: widget.extras,
                    ),
                    if (!entered) ...[
                      const SizedBox(height: 24.0),
                      _buildMeetDecisionCard(),
                    ],
                    if (entered) ...[
                      const SizedBox(height: 26.0),
                      _sectionHeading('My meet resources'),
                      _buildMyMeetResourcesSection(),
                      const SizedBox(height: 26.0),
                      _sectionHeading('Entered events'),
                      _buildSwimVideosSection(),
                      const SizedBox(height: 26.0),
                      _buildParentNoteSection(),
                    ],
                    SizedBox(height: 20.0 + bottomInset),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalResourceEditorSheet extends StatefulWidget {
  const _PersonalResourceEditorSheet({
    required this.initial,
    required this.meetId,
    required this.onSaved,
  });

  final PersonalMeetResourceEntry? initial;
  final String meetId;
  final VoidCallback onSaved;

  @override
  State<_PersonalResourceEditorSheet> createState() =>
      _PersonalResourceEditorSheetState();
}

class _PersonalResourceEditorSheetState
    extends State<_PersonalResourceEditorSheet> {
  late PersonalResourceKind _kind;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _errors = {};
  final Set<String> _activeFields = <String>{};
  final ImagePicker _picker = ImagePicker();
  bool _saving = false;
  bool _loadingPhotos = false;
  List<LocalResourcePhoto> _photos = const <LocalResourcePhoto>[];
  bool _savedNewResource = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initial?.kind ?? PersonalResourceKind.psychSheet;
    for (final key in _allFormKeys) {
      _controllers[key] = TextEditingController(
        text: _initialValueFor(key),
      );
    }
    if (widget.initial != null) {
      final base = _defaultFieldsByType[_kind] ?? const <String>['notes'];
      _activeFields
        ..clear()
        ..addAll(base);
      for (final key in _allFormKeys) {
        if ((_controllers[key]?.text ?? '').trim().isNotEmpty) {
          _activeFields.add(key);
        }
      }
    } else {
      _activeFields.clear();
    }
    _loadPhotos();
  }

  @override
  void dispose() {
    if (widget.initial == null && !_savedNewResource) {
      // User cancelled Add flow after selecting local photos; best-effort cleanup.
      for (final p in _photos) {
        try {
          final f = File(p.path);
          if (f.existsSync()) {
            f.deleteSync();
          }
        } catch (_) {}
      }
    }
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _initialValueFor(String key) {
    final i = widget.initial;
    if (i == null) {
      return '';
    }
    switch (key) {
      case 'title':
        return i.title;
      case 'url':
        return i.url;
      case 'date':
        return i.date;
      case 'time':
        return i.time;
      case 'start_time':
        return i.startTime;
      case 'end_time':
        return i.endTime;
      case 'location':
        return i.location;
      case 'address':
        return i.address;
      case 'notes':
        return i.notes;
      default:
        return '';
    }
  }

  static const List<String> _allFormKeys = <String>[
    'title',
    'url',
    'date',
    'time',
    'start_time',
    'end_time',
    'location',
    'address',
    'notes',
  ];

  static const Map<PersonalResourceKind, List<String>> _fieldsByType =
      <PersonalResourceKind, List<String>>{
    PersonalResourceKind.psychSheet: ['url', 'notes'],
    PersonalResourceKind.timeline: ['url', 'notes'],
    PersonalResourceKind.heatSheet: ['url', 'notes'],
    PersonalResourceKind.volunteerJob: [
      'title',
      'date',
      'start_time',
      'end_time',
      'location',
      'notes',
    ],
    PersonalResourceKind.warmupInfo: ['date', 'time', 'location', 'notes'],
    PersonalResourceKind.parkingInfo: ['url', 'address', 'notes'],
    PersonalResourceKind.reminder: ['title', 'date', 'time', 'notes'],
    PersonalResourceKind.otherNote: ['title', 'url', 'notes'],
  };

  static const Map<PersonalResourceKind, List<String>> _defaultFieldsByType =
      <PersonalResourceKind, List<String>>{
    PersonalResourceKind.psychSheet: ['url', 'notes'],
    PersonalResourceKind.timeline: ['url', 'notes'],
    PersonalResourceKind.heatSheet: ['url', 'notes'],
    PersonalResourceKind.volunteerJob: ['title', 'date', 'start_time'],
    PersonalResourceKind.warmupInfo: ['date', 'time', 'location'],
    PersonalResourceKind.parkingInfo: ['address', 'url'],
    PersonalResourceKind.reminder: ['title', 'date'],
    PersonalResourceKind.otherNote: ['title', 'notes'],
  };

  bool _hasAnySavableContent() {
    final hasText = _allFormKeys
        .map((k) => (_controllers[k]?.text ?? '').trim())
        .any((v) => v.isNotEmpty);
    return hasText || _photos.isNotEmpty;
  }

  bool _validateUrlField() {
    final raw = (_controllers['url']?.text ?? '').trim();
    if (raw.isEmpty) {
      setState(() => _errors['url'] = null);
      return true;
    }
    final norm = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';
    final uri = Uri.tryParse(norm);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      setState(() => _errors['url'] =
          'That doesn’t look like a valid web link. Try https://…');
      return false;
    }
    setState(() => _errors['url'] = null);
    return true;
  }

  Future<void> _loadPhotos() async {
    final resourceId = widget.initial?.id.trim() ?? '';
    if (resourceId.isEmpty || currentUserUid.isEmpty) {
      return;
    }
    setState(() => _loadingPhotos = true);
    try {
      final photos = await LocalMeetMediaStore.listPhotos(
        currentUserUid,
        widget.meetId,
        resourceId,
        fallbackResourceIds: <String>[
          (widget.initial?.kind.firestoreValue ?? ''),
          (widget.initial?.resourceLabel ?? '')
              .trim()
              .toLowerCase()
              .replaceAll(' ', '_'),
        ],
      );
      if (!mounted) return;
      setState(() => _photos = photos);
    } finally {
      if (mounted) {
        setState(() => _loadingPhotos = false);
      }
    }
  }

  Future<void> _addPhoto(ImageSource source) async {
    final resourceId = widget.initial?.id.trim() ?? '';
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2200,
    );
    if (picked == null) {
      return;
    }
    final localPath = await LocalMeetMediaStore.copyIntoLocalMedia(
      picked.path,
      'photos',
    );
    final next = <LocalResourcePhoto>[
      LocalResourcePhoto(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        path: localPath,
        createdAt: DateTime.now(),
      ),
      ..._photos,
    ];
    if (resourceId.isNotEmpty) {
      await LocalMeetMediaStore.savePhotos(
        currentUserUid,
        widget.meetId,
        resourceId,
        next,
      );
    }
    if (!mounted) return;
    setState(() => _photos = next);
    if (resourceId.isNotEmpty) {
      widget.onSaved();
    }
  }

  Future<void> _removePhoto(LocalResourcePhoto photo) async {
    final resourceId = widget.initial?.id.trim() ?? '';
    if (resourceId.isEmpty) {
      return;
    }
    final next = _photos.where((e) => e.id != photo.id).toList();
    await LocalMeetMediaStore.savePhotos(
      currentUserUid,
      widget.meetId,
      resourceId,
      next,
    );
    try {
      final f = File(photo.path);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _photos = next);
    widget.onSaved();
  }

  Future<void> _openPhotoFullscreen(LocalResourcePhoto photo) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Image.file(
                    File(photo.path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(
                      'Could not load photo.',
                      style:
                          GoogleFonts.sora(color: ObsidianVoltTokens.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 44.0,
              right: 12.0,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded),
                color: ObsidianVoltTokens.textPrimary,
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_validateUrlField()) {
      return;
    }
    if (!_hasAnySavableContent()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a property (plus), enter text, or attach a photo before saving.',
          ),
        ),
      );
      return;
    }
    final fields = <String, String>{};
    for (final key in _allFormKeys) {
      var out = (_controllers[key]?.text ?? '').trim();
      if (key == 'url' && out.isNotEmpty) {
        out = out.startsWith('http://') || out.startsWith('https://')
            ? out
            : 'https://$out';
      }
      fields[key] = out;
    }
    setState(() => _saving = true);
    try {
      final savedId = await upsertPersonalMeetResource(
        currentUserUid,
        widget.meetId,
        resourceId: widget.initial?.id ?? '',
        kind: _kind,
        fields: fields,
        createdAt: widget.initial?.createdAt,
      );
      if (widget.initial == null && savedId.isNotEmpty) {
        await LocalMeetMediaStore.savePhotos(
          currentUserUid,
          widget.meetId,
          savedId,
          _photos,
        );
        _savedNewResource = true;
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_kind.uiTitle} saved.')),
      );
      Navigator.pop(context);
      widget.onSaved();
    } on FirebaseException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloud Sync Error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final initial = widget.initial;
    if (initial == null || initial.id.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ObsidianVoltTokens.bgSurface,
        title: Text(
          'Delete resource?',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will remove this resource from your meet resources.',
          style:
              GoogleFonts.sora(fontSize: 14.0, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w700,
                color: Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      await deletePersonalMeetResource(
        currentUserUid,
        widget.meetId,
        initial.id,
      );
      await LocalMeetMediaStore.clearPhotos(
        currentUserUid,
        widget.meetId,
        initial.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resource deleted.')),
      );
      Navigator.pop(context);
      widget.onSaved();
    } on FirebaseException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloud Sync Error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _fieldLabel(String key) {
    switch (key) {
      case 'title':
        return _kind == PersonalResourceKind.volunteerJob
            ? 'Job title'
            : 'Title';
      case 'url':
        return 'URL';
      case 'date':
        return 'Date';
      case 'time':
        return 'Time';
      case 'start_time':
        return 'Start time';
      case 'end_time':
        return 'End time';
      case 'location':
        return 'Location';
      case 'address':
        return 'Address';
      case 'notes':
      default:
        return 'Notes';
    }
  }

  Widget _buildField(String key) {
    final c = _controllers[key]!;
    final multiline = key == 'notes';
    final keyboard = key == 'url'
        ? TextInputType.url
        : (multiline ? TextInputType.multiline : TextInputType.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _fieldLabel(key),
          style: GoogleFonts.sora(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6.0),
        TextField(
          controller: c,
          keyboardType: keyboard,
          autocorrect: !multiline,
          minLines: multiline ? 3 : 1,
          maxLines: multiline ? 8 : 1,
          textInputAction:
              multiline ? TextInputAction.newline : TextInputAction.done,
          onChanged: (_) {
            if (key == 'url' && _errors['url'] != null) {
              setState(() => _errors['url'] = null);
            } else {
              setState(() {});
            }
          },
          decoration: InputDecoration(
            hintText: key == 'url' ? 'https://…' : '',
            errorText: key == 'url' ? _errors['url'] : null,
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
          ),
          style: GoogleFonts.sora(
            fontSize: 14.0,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final editing = widget.initial != null;
    final fields = _fieldsByType[_kind] ?? const <String>['url', 'notes'];
    final canSave = !_saving && _hasAnySavableContent();
    return Padding(
      padding: EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 16.0 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999.0),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Text(
              editing ? 'Edit meet resource' : 'Add meet resource',
              style: GoogleFonts.sora(
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6.0),
            DropdownButtonFormField<PersonalResourceKind>(
              initialValue: _kind,
              isExpanded: true,
              style: GoogleFonts.sora(
                fontSize: 14.0,
                color: const Color(0xFF0F172A),
              ),
              dropdownColor: ObsidianVoltTokens.bgSurface,
              iconEnabledColor: const Color(0xFF64748B),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFFAFAFA),
                labelStyle: GoogleFonts.sora(
                  color: const Color(0xFF64748B),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              items: PersonalResourceKind.values
                  .map(
                    (kind) => DropdownMenuItem(
                      value: kind,
                      child: Text(
                        kind.uiTitle,
                        style: GoogleFonts.sora(fontSize: 14.0),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v == null) {
                        return;
                      }
                      setState(() {
                        _kind = v;
                        if (widget.initial == null) {
                          _activeFields.clear();
                        } else {
                          _activeFields
                            ..clear()
                            ..addAll(
                              _defaultFieldsByType[_kind] ??
                                  const <String>['notes'],
                            );
                          for (final key in _allFormKeys) {
                            if ((_controllers[key]?.text ?? '')
                                .trim()
                                .isNotEmpty) {
                              _activeFields.add(key);
                            }
                          }
                        }
                      });
                    },
            ),
            const SizedBox(height: 14.0),
            ...fields
                .where((k) => _activeFields.contains(k))
                .expand((k) => [_buildField(k), const SizedBox(height: 14.0)]),
            Row(
              children: [
                PopupMenuButton<String>(
                  onSelected: (k) {
                    if (k == '__none__') {
                      return;
                    }
                    setState(() => _activeFields.add(k));
                  },
                  itemBuilder: (context) {
                    final candidates = fields
                        .where((k) => !_activeFields.contains(k))
                        .toList();
                    if (candidates.isEmpty) {
                      return <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          enabled: false,
                          value: '__none__',
                          child: Text('All properties already added'),
                        ),
                      ];
                    }
                    return candidates
                        .map(
                          (k) => PopupMenuItem<String>(
                            value: k,
                            child: Text(_fieldLabel(k)),
                          ),
                        )
                        .toList();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          size: 18.0,
                          color: FlutterFlowTheme.of(context).primary,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          'Add property',
                          style: GoogleFonts.sora(
                            fontWeight: FontWeight.w700,
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ...[
              Text(
                'Photos (local only)',
                style: GoogleFonts.sora(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6.0),
              Wrap(
                spacing: 8.0,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _saving ? null : () => _addPhoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_rounded, size: 16.0),
                    label: const Text('Take photo'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _saving ? null : () => _addPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded, size: 16.0),
                    label: const Text('Choose photo'),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              if (_loadingPhotos)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                )
              else if (_photos.isEmpty)
                Text(
                  'No photos attached yet.',
                  style: GoogleFonts.sora(
                      fontSize: 12.0, color: const Color(0xFF64748B)),
                )
              else
                SizedBox(
                  height: 116.0,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final p = _photos[index];
                      return Stack(
                        children: [
                          GestureDetector(
                            onTap: () => _openPhotoFullscreen(p),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10.0),
                              child: Image.file(
                                File(p.path),
                                width: 116.0,
                                height: 116.0,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 116.0,
                                  height: 116.0,
                                  color: const Color(0xFFE2E8F0),
                                  alignment: Alignment.center,
                                  child:
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: InkWell(
                              onTap: () => _removePhoto(p),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xCC0F172A),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(3.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 12.0,
                                  color: ObsidianVoltTokens.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8.0),
                    itemCount: _photos.length,
                  ),
                ),
              const SizedBox(height: 12.0),
            ],
            const SizedBox(height: 6.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.sora(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: FilledButton(
                    onPressed: canSave ? _save : null,
                    child: Text(
                      _saving ? 'Saving…' : 'Save Resource',
                      style: GoogleFonts.sora(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            if (editing) ...[
              const SizedBox(height: 8.0),
              OutlinedButton(
                onPressed: _saving ? null : _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB91C1C),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: Text(
                  'Delete Resource',
                  style: GoogleFonts.sora(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VenueSelectionResult {
  const _VenueSelectionResult({
    required this.address,
    required this.venueId,
  });

  final String address;
  final String venueId;
}

class _MeetEventOption {
  const _MeetEventOption({
    required this.label,
    this.stroke = '',
    this.distance = 0,
    this.unit = 'Y',
    this.isLongCourse = false,
    this.heat = '',
    this.lane = '',
  });

  final String label;
  final String stroke;
  final int distance;
  final String unit;
  final bool isLongCourse;
  final String heat;
  final String lane;
}

class _DashedPlaceholderCard extends StatelessWidget {
  const _DashedPlaceholderCard({
    required this.text,
    required this.subtitle,
    required this.onTap,
  });

  final String text;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.0),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: const Color(0xFF7DD3FC),
          radius: 14.0,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14.0),
          ),
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text,
                style: GoogleFonts.sora(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0C4A6E),
                ),
              ),
              const SizedBox(height: 6.0),
              Text(
                subtitle,
                style: GoogleFonts.sora(
                  fontSize: 12.0,
                  color: const Color(0xFF0369A1),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _GeoPointLite {
  const _GeoPointLite({
    required this.lat,
    required this.lon,
  });

  final double lat;
  final double lon;
}

class _LocalVideoPlayerPage extends StatefulWidget {
  const _LocalVideoPlayerPage({
    required this.video,
  });

  final LocalSwimVideoEntry video;

  @override
  State<_LocalVideoPlayerPage> createState() => _LocalVideoPlayerPageState();
}

class _LocalVideoPlayerPageState extends State<_LocalVideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _slowMotion = false;
  bool _immersiveUiApplied = false;
  static const Duration _frameStep = Duration(milliseconds: 33);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.file(File(widget.video.path));
      await c.initialize();
      c.setLooping(true);
      c.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
      if (!mounted) {
        await c.dispose();
        return;
      }
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _immersiveUiApplied = true;
      setState(() {
        _controller = c;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    if (_immersiveUiApplied) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleSlowMotion() async {
    final c = _controller;
    if (c == null) return;
    _slowMotion = !_slowMotion;
    await c.setPlaybackSpeed(_slowMotion ? 0.5 : 1.0);
    if (mounted) setState(() {});
  }

  Future<void> _stepFrame(int direction) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position;
    final total = c.value.duration;
    var next = pos + (_frameStep * direction);
    if (next < Duration.zero) {
      next = Duration.zero;
    }
    if (next > total) {
      next = total;
    }
    await c.pause();
    await c.seekTo(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final caption = [
      widget.video.eventLabel.trim(),
      widget.video.note.trim(),
    ].where((e) => e.isNotEmpty).join('\n');
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ObsidianVoltTokens.textPrimary),
        title: Text(
          widget.video.stroke,
          style: GoogleFonts.sora(
            color: ObsidianVoltTokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : (c == null || !c.value.isInitialized)
                ? Text(
                    'Could not open this video.',
                    style: GoogleFonts.sora(color: ObsidianVoltTokens.textSecondary),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final vs = c.value.size;
                            if (vs.width == 0 || vs.height == 0) {
                              return const Center(
                                child: CircularProgressIndicator(
                                    color: ObsidianVoltTokens.textSecondary),
                              );
                            }
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRect(
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    height: constraints.maxHeight,
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center,
                                      child: SizedBox(
                                        width: vs.width,
                                        height: vs.height,
                                        child: VideoPlayer(c),
                                      ),
                                    ),
                                  ),
                                ),
                                if (caption.isNotEmpty)
                                  Positioned(
                                    left: 8.0,
                                    right: 8.0,
                                    bottom: 8.0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8.0),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.45),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      child: Text(
                                        caption,
                                        style: GoogleFonts.sora(
                                          color: ObsidianVoltTokens.textPrimary,
                                          fontSize: 12.0,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Slider(
                              value: c.value.position.inMilliseconds
                                  .clamp(0, c.value.duration.inMilliseconds)
                                  .toDouble(),
                              max: c.value.duration.inMilliseconds
                                  .toDouble()
                                  .clamp(1, double.infinity),
                              min: 0,
                              onChanged: (v) async {
                                await c
                                    .seekTo(Duration(milliseconds: v.toInt()));
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  12.0, 0, 12.0, 14.0),
                              child: Row(
                                children: [
                                  IconButton(
                                    color: ObsidianVoltTokens.textPrimary,
                                    onPressed: () => _stepFrame(-1),
                                    icon:
                                        const Icon(Icons.skip_previous_rounded),
                                    tooltip: 'Previous frame',
                                  ),
                                  IconButton(
                                    iconSize: 42.0,
                                    color: ObsidianVoltTokens.textPrimary,
                                    onPressed: () {
                                      if (c.value.isPlaying) {
                                        c.pause();
                                      } else {
                                        c.play();
                                      }
                                    },
                                    icon: Icon(
                                      c.value.isPlaying
                                          ? Icons.pause_circle_filled_rounded
                                          : Icons.play_circle_fill_rounded,
                                    ),
                                  ),
                                  IconButton(
                                    color: ObsidianVoltTokens.textPrimary,
                                    onPressed: () => _stepFrame(1),
                                    icon: const Icon(Icons.skip_next_rounded),
                                    tooltip: 'Next frame',
                                  ),
                                  const Spacer(),
                                  FilterChip(
                                    label: Text(
                                      'Slow Motion 0.5x',
                                      style: GoogleFonts.sora(
                                        color: _slowMotion
                                            ? ObsidianVoltTokens.textPrimary
                                            : ObsidianVoltTokens.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    selected: _slowMotion,
                                    selectedColor: const Color(0xFF1D4ED8),
                                    backgroundColor: const Color(0x331E293B),
                                    onSelected: (_) => _toggleSlowMotion(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

/// Minimal [ActivitiesRecord] for [MeetDetailView] when only a [MonitoredMeetsRecord] exists.
ActivitiesRecord activitiesRecordFromMonitoredMeet(MonitoredMeetsRecord m) {
  final title = m.name.trim();
  final loc = m.locationAddress.trim().isNotEmpty
      ? m.locationAddress.trim()
      : m.location.trim();
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
