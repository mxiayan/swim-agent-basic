import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ActivitiesRecord extends FirestoreRecord {
  ActivitiesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "team_id" field.
  String? _teamId;
  String get teamId => _teamId ?? '';
  bool hasTeamId() => _teamId != null;

  // "start_time" field.
  DateTime? _startTime;
  DateTime? get startTime => _startTime;
  bool hasStartTime() => _startTime != null;

  // "activity_type" field.
  String? _activityType;
  String get activityType => _activityType ?? '';
  bool hasActivityType() => _activityType != null;

  // "group_ids" field.
  List<String>? _groupIds;
  List<String> get groupIds => _groupIds ?? const [];
  bool hasGroupIds() => _groupIds != null;

  // "sports_type" field.
  String? _sportsType;
  String get sportsType => _sportsType ?? '';
  bool hasSportsType() => _sportsType != null;

  // "details" field.
  ActivityDetailsStruct? _details;
  ActivityDetailsStruct get details => _details ?? ActivityDetailsStruct();
  bool hasDetails() => _details != null;

  void _initializeFields() {
    _teamId = snapshotData['team_id'] as String?;
    _startTime = snapshotData['start_time'] as DateTime?;
    _activityType = snapshotData['activity_type'] as String?;
    _groupIds = getDataList(snapshotData['group_ids']);
    _sportsType = snapshotData['sports_type'] as String?;
    _details = snapshotData['details'] is ActivityDetailsStruct
        ? snapshotData['details']
        : ActivityDetailsStruct.maybeFromMap(snapshotData['details']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('activities');

  static Stream<ActivitiesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ActivitiesRecord.fromSnapshot(s));

  static Future<ActivitiesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ActivitiesRecord.fromSnapshot(s));

  static ActivitiesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ActivitiesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ActivitiesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ActivitiesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ActivitiesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ActivitiesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createActivitiesRecordData({
  String? teamId,
  DateTime? startTime,
  String? activityType,
  String? sportsType,
  ActivityDetailsStruct? details,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'team_id': teamId,
      'start_time': startTime,
      'activity_type': activityType,
      'sports_type': sportsType,
      'details': ActivityDetailsStruct().toMap(),
    }.withoutNulls,
  );

  // Handle nested data for "details" field.
  addActivityDetailsStructData(firestoreData, details, 'details');

  return firestoreData;
}

class ActivitiesRecordDocumentEquality implements Equality<ActivitiesRecord> {
  const ActivitiesRecordDocumentEquality();

  @override
  bool equals(ActivitiesRecord? e1, ActivitiesRecord? e2) {
    const listEquality = ListEquality();
    return e1?.teamId == e2?.teamId &&
        e1?.startTime == e2?.startTime &&
        e1?.activityType == e2?.activityType &&
        listEquality.equals(e1?.groupIds, e2?.groupIds) &&
        e1?.sportsType == e2?.sportsType &&
        e1?.details == e2?.details;
  }

  @override
  int hash(ActivitiesRecord? e) => const ListEquality().hash([
        e?.teamId,
        e?.startTime,
        e?.activityType,
        e?.groupIds,
        e?.sportsType,
        e?.details
      ]);

  @override
  bool isValidKey(Object? o) => o is ActivitiesRecord;
}
