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

  // "provider" field.
  String? _provider;
  String get provider => _provider ?? '';
  bool hasProvider() => _provider != null;

  // "fastswim_url" field.
  String? _fastswimUrl;
  String get fastswimUrl => _fastswimUrl ?? '';
  bool hasFastswimUrl() => _fastswimUrl != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "watcher_ids" field.
  List<DocumentReference>? _watcherIds;
  List<DocumentReference> get watcherIds => _watcherIds ?? const [];
  bool hasWatcherIds() => _watcherIds != null;

  // "meet_id" field.
  String? _meetId;
  String get meetId => _meetId ?? '';
  bool hasMeetId() => _meetId != null;

  // "location" field.
  String? _location;
  String get location => _location ?? '';
  bool hasLocation() => _location != null;

  // "region_name" field.
  String? _regionName;
  String get regionName => _regionName ?? '';
  bool hasRegionName() => _regionName != null;

  // "notes" field.
  String? _notes;
  String get notes => _notes ?? '';
  bool hasNotes() => _notes != null;

  // "start_date" field.
  String? _startDate;
  String get startDate => _startDate ?? '';
  bool hasStartDate() => _startDate != null;

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "region_id" field.
  String? _regionId;
  String get regionId => _regionId ?? '';
  bool hasRegionId() => _regionId != null;

  // "is_approved" field.
  bool? _isApproved;
  bool get isApproved => _isApproved ?? false;
  bool hasIsApproved() => _isApproved != null;

  // "approved_groups" field.
  List<String>? _approvedGroups;
  List<String> get approvedGroups => _approvedGroups ?? const [];
  bool hasApprovedGroups() => _approvedGroups != null;

  void _initializeFields() {
    _provider = snapshotData['provider'] as String?;
    _fastswimUrl = snapshotData['fastswim_url'] as String?;
    _status = snapshotData['status'] as String?;
    _watcherIds = getDataList(snapshotData['watcher_ids']);
    _meetId = snapshotData['meet_id'] as String?;
    _location = snapshotData['location'] as String?;
    _regionName = snapshotData['region_name'] as String?;
    _notes = snapshotData['notes'] as String?;
    _startDate = snapshotData['start_date'] as String?;
    _name = snapshotData['name'] as String?;
    _regionId = snapshotData['region_id'] as String?;
    _isApproved = snapshotData['is_approved'] as bool?;
    _approvedGroups = getDataList(snapshotData['approved_groups']);
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
  String? provider,
  String? fastswimUrl,
  String? status,
  String? meetId,
  String? location,
  String? regionName,
  String? notes,
  String? startDate,
  String? name,
  String? regionId,
  bool? isApproved,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'provider': provider,
      'fastswim_url': fastswimUrl,
      'status': status,
      'meet_id': meetId,
      'location': location,
      'region_name': regionName,
      'notes': notes,
      'start_date': startDate,
      'name': name,
      'region_id': regionId,
      'is_approved': isApproved,
    }.withoutNulls,
  );

  return firestoreData;
}

class MonitoredMeetsRecordDocumentEquality
    implements Equality<MonitoredMeetsRecord> {
  const MonitoredMeetsRecordDocumentEquality();

  @override
  bool equals(MonitoredMeetsRecord? e1, MonitoredMeetsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.provider == e2?.provider &&
        e1?.fastswimUrl == e2?.fastswimUrl &&
        e1?.status == e2?.status &&
        listEquality.equals(e1?.watcherIds, e2?.watcherIds) &&
        e1?.meetId == e2?.meetId &&
        e1?.location == e2?.location &&
        e1?.regionName == e2?.regionName &&
        e1?.notes == e2?.notes &&
        e1?.startDate == e2?.startDate &&
        e1?.name == e2?.name &&
        e1?.regionId == e2?.regionId &&
        e1?.isApproved == e2?.isApproved &&
        listEquality.equals(e1?.approvedGroups, e2?.approvedGroups);
  }

  @override
  int hash(MonitoredMeetsRecord? e) => const ListEquality().hash([
        e?.provider,
        e?.fastswimUrl,
        e?.status,
        e?.watcherIds,
        e?.meetId,
        e?.location,
        e?.regionName,
        e?.notes,
        e?.startDate,
        e?.name,
        e?.regionId,
        e?.isApproved,
        e?.approvedGroups
      ]);

  @override
  bool isValidKey(Object? o) => o is MonitoredMeetsRecord;
}
