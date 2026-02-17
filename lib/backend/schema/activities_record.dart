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

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "type" field.
  String? _type;
  String get type => _type ?? '';
  bool hasType() => _type != null;

  // "group_id" field.
  String? _groupId;
  String get groupId => _groupId ?? '';
  bool hasGroupId() => _groupId != null;

  // "team_id" field.
  String? _teamId;
  String get teamId => _teamId ?? '';
  bool hasTeamId() => _teamId != null;

  // "start_time" field.
  DateTime? _startTime;
  DateTime? get startTime => _startTime;
  bool hasStartTime() => _startTime != null;

  // "end_time" field.
  DateTime? _endTime;
  DateTime? get endTime => _endTime;
  bool hasEndTime() => _endTime != null;

  // "location_name" field.
  String? _locationName;
  String get locationName => _locationName ?? '';
  bool hasLocationName() => _locationName != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "activity_type" field.
  String? _activityType;
  String get activityType => _activityType ?? '';
  bool hasActivityType() => _activityType != null;

  // "signup_url" field.
  String? _signupUrl;
  String get signupUrl => _signupUrl ?? '';
  bool hasSignupUrl() => _signupUrl != null;

  // "deadline" field.
  DateTime? _deadline;
  DateTime? get deadline => _deadline;
  bool hasDeadline() => _deadline != null;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
    _type = snapshotData['type'] as String?;
    _groupId = snapshotData['group_id'] as String?;
    _teamId = snapshotData['team_id'] as String?;
    _startTime = snapshotData['start_time'] as DateTime?;
    _endTime = snapshotData['end_time'] as DateTime?;
    _locationName = snapshotData['location_name'] as String?;
    _description = snapshotData['description'] as String?;
    _activityType = snapshotData['activity_type'] as String?;
    _signupUrl = snapshotData['signup_url'] as String?;
    _deadline = snapshotData['deadline'] as DateTime?;
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
  String? title,
  String? type,
  String? groupId,
  String? teamId,
  DateTime? startTime,
  DateTime? endTime,
  String? locationName,
  String? description,
  String? activityType,
  String? signupUrl,
  DateTime? deadline,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'type': type,
      'group_id': groupId,
      'team_id': teamId,
      'start_time': startTime,
      'end_time': endTime,
      'location_name': locationName,
      'description': description,
      'activity_type': activityType,
      'signup_url': signupUrl,
      'deadline': deadline,
    }.withoutNulls,
  );

  return firestoreData;
}

class ActivitiesRecordDocumentEquality implements Equality<ActivitiesRecord> {
  const ActivitiesRecordDocumentEquality();

  @override
  bool equals(ActivitiesRecord? e1, ActivitiesRecord? e2) {
    return e1?.title == e2?.title &&
        e1?.type == e2?.type &&
        e1?.groupId == e2?.groupId &&
        e1?.teamId == e2?.teamId &&
        e1?.startTime == e2?.startTime &&
        e1?.endTime == e2?.endTime &&
        e1?.locationName == e2?.locationName &&
        e1?.description == e2?.description &&
        e1?.activityType == e2?.activityType &&
        e1?.signupUrl == e2?.signupUrl &&
        e1?.deadline == e2?.deadline;
  }

  @override
  int hash(ActivitiesRecord? e) => const ListEquality().hash([
        e?.title,
        e?.type,
        e?.groupId,
        e?.teamId,
        e?.startTime,
        e?.endTime,
        e?.locationName,
        e?.description,
        e?.activityType,
        e?.signupUrl,
        e?.deadline
      ]);

  @override
  bool isValidKey(Object? o) => o is ActivitiesRecord;
}
