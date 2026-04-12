import 'package:flutter/material.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';

/// True for Pacific granular codes stored in `zone_id` / meets (`Z2`, `Z1N`, …).
bool isPacificGranularZoneId(String? raw) {
  if (raw == null) {
    return false;
  }
  return RegExp(r'^Z\d+[NSEW]?$', caseSensitive: false).hasMatch(raw.trim());
}

/// FlutterFlow often stores dropdown defaults like "Unknown Zone" in `zone_id` /
/// `zone_display_name`. Treat those as unset for UI and meet filtering.
bool isSwimmerZonePlaceholder(String? raw) {
  if (raw == null) {
    return true;
  }
  final t = raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
  if (t.isEmpty) {
    return true;
  }
  if (isPacificGranularZoneId(t)) {
    return false;
  }
  if (t.contains('unknown') ||
      t.contains('unkonw') ||
      t.contains('unkonwn') ||
      t.contains('unkown') ||
      t.contains('uknown') ||
      t.contains('unknw') ||
      t.contains('unknwon')) {
    return true;
  }
  // Typos / odd spacing: compare letters only (handles "Unkonwn Zone", etc.)
  final lettersOnly = t.replaceAll(RegExp(r'[^a-z]'), '');
  if (lettersOnly.contains('unkonwn') ||
      lettersOnly.contains('unknown') ||
      (lettersOnly.contains('unkn') && lettersOnly.contains('zone'))) {
    return true;
  }
  if (t == 'n/a' || t == 'na' || t == 'none' || t == 'tbd' || t == 'null') {
    return true;
  }
  if (t.startsWith('select')) {
    return true;
  }
  return false;
}

String swimmerZoneStoredOrEmpty(String raw) =>
    isSwimmerZonePlaceholder(raw) ? '' : raw.trim();

/// When `zone_id` is empty/placeholder but `zone_display_name` has a real label
/// (e.g. "Zone 2", "Z2 North"), derive canonical Pacific zone for meets.
String? pacificZoneIdFromLooseLabel(String? raw) {
  if (raw == null) {
    return null;
  }
  var text = raw.trim();
  if (text.isEmpty || isSwimmerZonePlaceholder(text)) {
    return null;
  }
  text = text.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
  final direct =
      RegExp(r'^Z(\d+)([NSEW])?$', caseSensitive: false).firstMatch(text);
  if (direct != null) {
    final n = int.tryParse(direct.group(1)!);
    if (n == null) {
      return null;
    }
    return 'Z$n${direct.group(2) ?? ''}'.toUpperCase();
  }
  final m = RegExp(
    r'zone\s*(\d+)\s*(north|south|east|west|n|s|e|w)?',
    caseSensitive: false,
  ).firstMatch(text);
  if (m != null) {
    final num = m.group(1)!;
    final q = (m.group(2) ?? '').toLowerCase();
    var suffix = '';
    if (q == 'north' || q == 'n') {
      suffix = 'N';
    } else if (q == 'south' || q == 's') {
      suffix = 'S';
    } else if (q == 'east' || q == 'e') {
      suffix = 'E';
    } else if (q == 'west' || q == 'w') {
      suffix = 'W';
    }
    return 'Z$num$suffix';
  }
  return null;
}

/// Banner text when [metadata_regions] has no row (e.g. "Pacific Swimming Zone 2").
String pacificSwimmingBannerFallbackForGranularZone(String granular) {
  final t = granular.trim();
  if (t.isEmpty) {
    return '';
  }
  if (!isPacificGranularZoneId(t)) {
    return isSwimmerZonePlaceholder(t) ? '' : t;
  }
  final m = RegExp(r'^Z(\d+)([NSEW])?$', caseSensitive: false).firstMatch(t);
  if (m == null) {
    return t.toUpperCase();
  }
  final num = m.group(1)!;
  final suf = (m.group(2) ?? '').toUpperCase();
  final suffixWord = switch (suf) {
    'N' => ' North',
    'S' => ' South',
    'E' => ' East',
    'W' => ' West',
    _ => '',
  };
  return 'Pacific Swimming Zone $num$suffixWord'.trimRight();
}

/// Normalizes catalog / Firestore labels for the Meets banner.
/// Handles "Pacific Swimming: Zone 2", plain "Zone 2", "Zone 1 North", etc.
String formatPacificSwimmingZoneBannerLabel(String raw) {
  final t = raw.trim();
  if (t.isEmpty) {
    return t;
  }

  final colon = RegExp(
    r'^Pacific\s+Swimming:\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(t);
  if (colon != null) {
    return 'Pacific Swimming ${colon.group(1)!.trim()}';
  }

  if (RegExp(r'^Pacific\s+Swimming\s+', caseSensitive: false).hasMatch(t)) {
    return t;
  }

  // metadata_regions / club often store just "Zone 2"
  if (RegExp(r'^Zone\s+\d+', caseSensitive: false).hasMatch(t)) {
    return 'Pacific Swimming $t';
  }

  return t;
}

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  static const _kSwimmerName = 'ff_currentSwimmerName';
  static const _kSwimmerGroup = 'ff_currentSwimmerGroup';
  static const _kSwimmerZone = 'ff_currentSwimmerZone';
  static const _kSwimmerZoneDisplay = 'ff_currentSwimmerZoneDisplayName';
  static const _kMeetFilterAge = 'ff_meetFilterShowAgeGroup';
  static const _kMeetFilterSenior = 'ff_meetFilterShowSenior';
  static const _kMeetFilterOther = 'ff_meetFilterShowOther';
  static const _kMeetFilterEnteredOnly = 'ff_meetFilterEnteredOnly';
  static const _kMeetFilterInterestedOnly = 'ff_meetFilterInterestedOnly';
  static const _kMeetTimeSegment = 'ff_meetTimeSegment';
  static const _kMeetsShowAllZones = 'ff_meetsShowAllZones';

  Future initializePersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    _currentSwimmerName = prefs.getString(_kSwimmerName) ?? '';
    _currentSwimmerGroup = prefs.getString(_kSwimmerGroup) ?? '';
    _currentSwimmerZone =
        swimmerZoneStoredOrEmpty(prefs.getString(_kSwimmerZone) ?? '');
    final rawDisp = prefs.getString(_kSwimmerZoneDisplay) ?? '';
    _currentSwimmerZoneDisplayName =
        isSwimmerZonePlaceholder(rawDisp) ? '' : rawDisp.trim();
    _meetFilterShowAgeGroup = prefs.getBool(_kMeetFilterAge) ?? true;
    _meetFilterShowSenior = prefs.getBool(_kMeetFilterSenior) ?? true;
    _meetFilterShowOther = prefs.getBool(_kMeetFilterOther) ?? true;
    _meetFilterEnteredOnly = prefs.getBool(_kMeetFilterEnteredOnly) ?? false;
    _meetFilterInterestedOnly =
        prefs.getBool(_kMeetFilterInterestedOnly) ?? false;
    final rawSeg = prefs.getInt(_kMeetTimeSegment) ?? 1;
    _meetTimeSegment = rawSeg < 0 ? 0 : (rawSeg > 2 ? 2 : rawSeg);
    _meetsShowAllZones = prefs.getBool(_kMeetsShowAllZones) ?? false;
    notifyListeners();
    await persistSwimmerContext();
    await persistMeetUiState();
  }

  Future<void> persistSwimmerContext() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSwimmerName, _currentSwimmerName);
    await prefs.setString(_kSwimmerGroup, _currentSwimmerGroup);
    await prefs.setString(_kSwimmerZone, _currentSwimmerZone);
    await prefs.setString(_kSwimmerZoneDisplay, _currentSwimmerZoneDisplayName);
  }

  Future<void> persistMeetUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMeetFilterAge, _meetFilterShowAgeGroup);
    await prefs.setBool(_kMeetFilterSenior, _meetFilterShowSenior);
    await prefs.setBool(_kMeetFilterOther, _meetFilterShowOther);
    await prefs.setBool(_kMeetFilterEnteredOnly, _meetFilterEnteredOnly);
    await prefs.setBool(_kMeetFilterInterestedOnly, _meetFilterInterestedOnly);
    await prefs.setInt(_kMeetTimeSegment, _meetTimeSegment);
    await prefs.setBool(_kMeetsShowAllZones, _meetsShowAllZones);
  }

  /// Call after sign-out so Home / Meets do not show stale data.
  Future<void> clearSwimmerContext() async {
    update(() {
      _currentSwimmerName = '';
      _currentSwimmerGroup = '';
      _currentSwimmerZone = '';
      _currentSwimmerZoneDisplayName = '';
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSwimmerName);
    await prefs.remove(_kSwimmerGroup);
    await prefs.remove(_kSwimmerZone);
    await prefs.remove(_kSwimmerZoneDisplay);
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  /// Logged-in swimmer display name (header, meets subtitle).
  String _currentSwimmerName = '';
  String get currentSwimmerName => _currentSwimmerName;
  set currentSwimmerName(String value) {
    _currentSwimmerName = value;
  }

  /// Club / group id aligned with monitored_meets.host_group.
  String _currentSwimmerGroup = '';
  String get currentSwimmerGroup => _currentSwimmerGroup;
  set currentSwimmerGroup(String value) {
    _currentSwimmerGroup = value;
  }

  /// Granular Pacific zone id — must match monitored_meets.meet_zone (e.g. Z1N).
  String _currentSwimmerZone = '';
  String get currentSwimmerZone => _currentSwimmerZone;
  set currentSwimmerZone(String value) {
    _currentSwimmerZone = value;
  }

  /// Optional UI label (e.g. "Zone 1 North"); falls back to [currentSwimmerZone].
  String _currentSwimmerZoneDisplayName = '';
  String get currentSwimmerZoneDisplayName => _currentSwimmerZoneDisplayName;
  set currentSwimmerZoneDisplayName(String value) {
    _currentSwimmerZoneDisplayName = value;
  }

  /// Human-readable zone for headers (skips "Unknown Zone"–style values).
  String get currentSwimmerZoneLabel {
    final z = _currentSwimmerZone.trim();
    final d = _currentSwimmerZoneDisplayName.trim();

    final dOk = d.isNotEmpty && !isSwimmerZonePlaceholder(d);
    if (dOk) {
      return formatPacificSwimmingZoneBannerLabel(d);
    }

    if (isPacificGranularZoneId(z)) {
      return pacificSwimmingBannerFallbackForGranularZone(z);
    }

    final zOk = z.isNotEmpty && !isSwimmerZonePlaceholder(z);
    if (zOk) {
      return z;
    }
    return '';
  }

  /// Zone id used for `monitored_meets` filter (empty if unset / placeholder).
  String get currentSwimmerZoneForMeets {
    final z = _currentSwimmerZone.trim();
    if (z.isNotEmpty && !isSwimmerZonePlaceholder(z)) {
      return z;
    }
    final derived =
        pacificZoneIdFromLooseLabel(_currentSwimmerZoneDisplayName.trim());
    return derived ?? '';
  }

  int _galleryHeight = 350;
  int get galleryHeight => _galleryHeight;
  set galleryHeight(int value) {
    _galleryHeight = value;
  }

  int _activeTab = 0;
  int get activeTab => _activeTab;
  set activeTab(int value) {
    _activeTab = value;
  }

  /// Meets tab: class filter chips (persisted).
  bool _meetFilterShowAgeGroup = true;
  bool get meetFilterShowAgeGroup => _meetFilterShowAgeGroup;
  set meetFilterShowAgeGroup(bool value) {
    _meetFilterShowAgeGroup = value;
  }

  bool _meetFilterShowSenior = true;
  bool get meetFilterShowSenior => _meetFilterShowSenior;
  set meetFilterShowSenior(bool value) {
    _meetFilterShowSenior = value;
  }

  bool _meetFilterShowOther = true;
  bool get meetFilterShowOther => _meetFilterShowOther;
  set meetFilterShowOther(bool value) {
    _meetFilterShowOther = value;
  }

  /// Meets tab: show only meets marked entered (persisted).
  bool _meetFilterEnteredOnly = false;
  bool get meetFilterEnteredOnly => _meetFilterEnteredOnly;
  set meetFilterEnteredOnly(bool value) {
    _meetFilterEnteredOnly = value;
  }

  /// Meets tab: show only meets marked interested (persisted).
  bool _meetFilterInterestedOnly = false;
  bool get meetFilterInterestedOnly => _meetFilterInterestedOnly;
  set meetFilterInterestedOnly(bool value) {
    _meetFilterInterestedOnly = value;
  }

  /// 0 = Past, 1 = Live, 2 = Upcoming (persisted).
  int _meetTimeSegment = 1;
  int get meetTimeSegment => _meetTimeSegment;
  set meetTimeSegment(int value) {
    if (value < 0) {
      _meetTimeSegment = 0;
    } else if (value > 2) {
      _meetTimeSegment = 2;
    } else {
      _meetTimeSegment = value;
    }
  }

  /// Meets tab: show all zones (persisted).
  bool _meetsShowAllZones = false;
  bool get meetsShowAllZones => _meetsShowAllZones;
  set meetsShowAllZones(bool value) {
    _meetsShowAllZones = value;
  }

  LatLng? _location = LatLng(43.552847, 7.017369);
  LatLng? get location => _location;
  set location(LatLng? value) {
    _location = value;
  }

  List<bool> _favorites = [true, false, false, true];
  List<bool> get favorites => _favorites;
  set favorites(List<bool> value) {
    _favorites = value;
  }

  void addToFavorites(bool value) {
    favorites.add(value);
  }

  void removeFromFavorites(bool value) {
    favorites.remove(value);
  }

  void removeAtIndexFromFavorites(int index) {
    favorites.removeAt(index);
  }

  void updateFavoritesAtIndex(
    int index,
    bool Function(bool) updateFn,
  ) {
    favorites[index] = updateFn(_favorites[index]);
  }

  void insertAtIndexInFavorites(int index, bool value) {
    favorites.insert(index, value);
  }

  bool _showDetails1 = false;
  bool get showDetails1 => _showDetails1;
  set showDetails1(bool value) {
    _showDetails1 = value;
  }

  bool _showDetails2 = false;
  bool get showDetails2 => _showDetails2;
  set showDetails2(bool value) {
    _showDetails2 = value;
  }

  bool _showDetails3 = false;
  bool get showDetails3 => _showDetails3;
  set showDetails3(bool value) {
    _showDetails3 = value;
  }

  bool _showDetails4 = false;
  bool get showDetails4 => _showDetails4;
  set showDetails4(bool value) {
    _showDetails4 = value;
  }

  List<String> _cooks = ['Michael', '', ''];
  List<String> get cooks => _cooks;
  set cooks(List<String> value) {
    _cooks = value;
  }

  void addToCooks(String value) {
    cooks.add(value);
  }

  void removeFromCooks(String value) {
    cooks.remove(value);
  }

  void removeAtIndexFromCooks(int index) {
    cooks.removeAt(index);
  }

  void updateCooksAtIndex(
    int index,
    String Function(String) updateFn,
  ) {
    cooks[index] = updateFn(_cooks[index]);
  }

  void insertAtIndexInCooks(int index, String value) {
    cooks.insert(index, value);
  }

  List<bool> _cookSelected = [true, false, false];
  List<bool> get cookSelected => _cookSelected;
  set cookSelected(List<bool> value) {
    _cookSelected = value;
  }

  void addToCookSelected(bool value) {
    cookSelected.add(value);
  }

  void removeFromCookSelected(bool value) {
    cookSelected.remove(value);
  }

  void removeAtIndexFromCookSelected(int index) {
    cookSelected.removeAt(index);
  }

  void updateCookSelectedAtIndex(
    int index,
    bool Function(bool) updateFn,
  ) {
    cookSelected[index] = updateFn(_cookSelected[index]);
  }

  void insertAtIndexInCookSelected(int index, bool value) {
    cookSelected.insert(index, value);
  }
}
