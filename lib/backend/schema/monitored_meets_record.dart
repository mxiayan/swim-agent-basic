import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MonitoredMeetsRecord extends FirestoreRecord {
  MonitoredMeetsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  /// Must match swimmer.zone_id / FFAppState.currentSwimmerZone (e.g. "Z1N").
  String? _meetZone;
  String get meetZone => _meetZone ?? '';
  bool hasMeetZone() => _meetZone != null;

  /// Host club / group id — compared to currentSwimmerGroup for prioritization.
  String? _hostGroup;
  String get hostGroup => _hostGroup ?? '';
  bool hasHostGroup() => _hostGroup != null;

  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  String? _subtitle;
  String get subtitle => _subtitle ?? '';
  bool hasSubtitle() => _subtitle != null;

  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;
  String? _meetSheetUrl;
  String get meetSheetUrl => _meetSheetUrl ?? '';
  bool hasMeetSheetUrl() => _meetSheetUrl != null;

  DateTime? _startTime;
  DateTime? get startTime => _startTime;
  bool hasStartTime() => _startTime != null;

  String? _imageUrl;
  String get imageUrl => _imageUrl ?? '';
  bool hasImageUrl() => _imageUrl != null;
  List<String>? _meetClasses;
  List<String> get meetClasses => _meetClasses ?? const <String>[];
  bool hasMeetClasses() => _meetClasses != null && _meetClasses!.isNotEmpty;
  List<String>? _eligibleZones;
  List<String> get eligibleZones => _eligibleZones ?? const <String>[];
  bool hasEligibleZones() => _eligibleZones != null && _eligibleZones!.isNotEmpty;

  /// USA Swimming / OME meet id when stored on the doc (`meet_id`); else doc id.
  String? _meetIdField;
  String? _entryUrlRaw;

  /// Business meet id for [entryUrl] (field `meet_id` or Firestore document id).
  String get meetId {
    final m = _meetIdField?.trim() ?? '';
    if (m.isNotEmpty) {
      return m;
    }
    return reference.id;
  }

  /// OME entry page, or explicit `entry_url` from Firestore when set.
  String get entryUrl {
    final raw = _entryUrlRaw?.trim() ?? '';
    if (raw.isNotEmpty) {
      return raw;
    }
    final id = meetId.trim();
    if (id.isEmpty) {
      return '';
    }
    return 'https://ome.fastswims.com/meets/$id/enter';
  }

  // ---- Legacy FlutterFlow UI aliases (m02 meet cards / lists) ----
  String get name => title;
  String get regionName => meetZone;
  String get location => subtitle;
  DateTime? get startDate => startTime;
  DateTime? get endDate => startTime;
  String get notes => description;
  bool get isApproved => false;

  void _initializeFields() {
    _meetZone = _firstNonEmptyString(snapshotData, const [
      'meet_zone',
      'meetZone',
      'MeetZone',
      'zone_id',
      'zoneId',
      'zone',
      'pacific_zone',
      'PacificZone',
    ]);
    _hostGroup = _firstNonEmptyString(snapshotData, const [
      'host_group',
      'hostGroup',
      'HostGroup',
      'hosting_club',
      'hostingClub',
      'host_club_code',
      'club_code',
    ]);
    _title = _firstNonEmptyString(snapshotData, const [
      'title',
      'meet_name',
      'meetName',
      'name',
    ]);
    _subtitle = _firstNonEmptyString(snapshotData, const [
      'location',
      'Location',
      'subtitle',
      'course',
      'location_name',
      'locationName',
    ]);
    _description = _firstNonEmptyString(snapshotData, const [
      'description',
      'details',
    ]);
    _status = _firstNonEmptyString(snapshotData, const [
      'status',
      'status_detail',
      'statusDetail',
    ]);
    _meetSheetUrl = _firstNonEmptyString(snapshotData, const [
      'meet_sheet_url',
      'meetSheetUrl',
      'meet_sheet',
      'meetSheet',
      'sheet_url',
      'sheetUrl',
    ]);
    _startTime = snapshotData['start_time'] as DateTime? ??
        snapshotData['startTime'] as DateTime? ??
        snapshotData['start_date'] as DateTime? ??
        snapshotData['startDate'] as DateTime? ??
        snapshotData['meet_date'] as DateTime? ??
        snapshotData['meetDate'] as DateTime?;
    _imageUrl = _firstNonEmptyString(snapshotData, const [
      'image_url',
      'imageUrl',
      'photo_url',
    ]);
    _meetIdField = _firstNonEmptyString(snapshotData, const [
      'meet_id',
      'meetId',
      'MeetId',
    ]);
    _entryUrlRaw = _firstNonEmptyString(snapshotData, const [
      'entry_url',
      'entryUrl',
      'EntryUrl',
    ]);
    _meetClasses = _stringListFromFirestore(
      snapshotData,
      const ['meet_classes', 'meetClasses', 'MeetClasses'],
    );
    _eligibleZones = _stringListFromFirestore(
      snapshotData,
      const ['eligible_zones', 'eligibleZones', 'EligibleZones'],
    );

    _meetZone ??= _deriveMeetZoneFromRegion(snapshotData);
  }

  /// When `meet_zone` is absent, infer from USA Swimming–style region fields.
  static String? _deriveMeetZoneFromRegion(Map<String, dynamic> data) {
    final rid = data['region_id'];
    if (rid != null) {
      final s = rid.toString().trim();
      if (RegExp(r'^Z\d+[NSEW]?$', caseSensitive: false).hasMatch(s)) {
        return s.toUpperCase();
      }
      final pc = RegExp(
        r'^PC[-_]?Z(\d+)([NSEW])?$',
        caseSensitive: false,
      ).firstMatch(s);
      if (pc != null) {
        final n = int.tryParse(pc.group(1)!);
        if (n != null) {
          final suf = pc.group(2) ?? '';
          return 'Z$n$suf'.toUpperCase();
        }
      }
    }

    final rn = data['region_name'];
    if (rn == null) {
      return null;
    }
    final text = rn.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    final m = RegExp(
      r'zone\s*(\d+)\s*(north|south|east|west|n|s|e|w)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) {
      return null;
    }
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

  static String? _firstNonEmptyString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final k in keys) {
      final v = data[k];
      if (v == null) {
        continue;
      }
      if (v is String) {
        final t = v.trim();
        if (t.isNotEmpty) {
          return t;
        }
      } else {
        final t = v.toString().trim();
        if (t.isNotEmpty && t != 'null') {
          return t;
        }
      }
    }
    return null;
  }

  static List<String>? _stringListFromFirestore(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final k in keys) {
      final v = data[k];
      if (v == null) {
        continue;
      }
      if (v is Iterable) {
        final out = <String>[];
        for (final item in v) {
          final t = item?.toString().trim() ?? '';
          if (t.isNotEmpty && t != 'null') {
            out.add(t);
          }
        }
        if (out.isNotEmpty) {
          return out;
        }
      }
    }
    return null;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('monitored_meets');

  static Stream<MonitoredMeetsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MonitoredMeetsRecord.fromSnapshot(s));

  static Future<MonitoredMeetsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => MonitoredMeetsRecord.fromSnapshot(s));

  static MonitoredMeetsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      MonitoredMeetsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static MonitoredMeetsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MonitoredMeetsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MonitoredMeetsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MonitoredMeetsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createMonitoredMeetsRecordData({
  String? meetZone,
  String? hostGroup,
  String? title,
  String? subtitle,
  String? description,
  DateTime? startTime,
  String? imageUrl,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'meet_zone': meetZone,
      'host_group': hostGroup,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'start_time': startTime,
      'image_url': imageUrl,
    }.withoutNulls,
  );

  return firestoreData;
}

class MonitoredMeetsRecordDocumentEquality
    implements Equality<MonitoredMeetsRecord> {
  const MonitoredMeetsRecordDocumentEquality();

  @override
  bool equals(MonitoredMeetsRecord? e1, MonitoredMeetsRecord? e2) {
    return e1?.meetZone == e2?.meetZone &&
        e1?.hostGroup == e2?.hostGroup &&
        e1?.title == e2?.title &&
        e1?.subtitle == e2?.subtitle &&
        e1?.description == e2?.description &&
        e1?.status == e2?.status &&
        e1?.meetSheetUrl == e2?.meetSheetUrl &&
        e1?.startTime == e2?.startTime &&
        const ListEquality<String>().equals(e1?.meetClasses, e2?.meetClasses) &&
        e1?.imageUrl == e2?.imageUrl &&
        const ListEquality<String>().equals(e1?.eligibleZones, e2?.eligibleZones);
  }

  @override
  int hash(MonitoredMeetsRecord? e) => const ListEquality().hash([
        e?.meetZone,
        e?.hostGroup,
        e?.title,
        e?.subtitle,
        e?.description,
        e?.status,
        e?.meetSheetUrl,
        e?.startTime,
        const ListEquality<String>().hash(e?.meetClasses ?? const <String>[]),
        e?.imageUrl,
        const ListEquality<String>().hash(e?.eligibleZones ?? const <String>[]),
      ]);

  @override
  bool isValidKey(Object? o) => o is MonitoredMeetsRecord;
}
