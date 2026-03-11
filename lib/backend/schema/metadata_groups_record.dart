import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MetadataGroupsRecord extends FirestoreRecord {
  MetadataGroupsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "group_id" field.
  String? _groupId;
  String get groupId => _groupId ?? '';
  bool hasGroupId() => _groupId != null;

  // "display_name" field.
  String? _displayName;
  String get displayName => _displayName ?? '';
  bool hasDisplayName() => _displayName != null;

  // "min_age" field.
  int? _minAge;
  int get minAge => _minAge ?? 0;
  bool hasMinAge() => _minAge != null;

  // "max_age" field.
  int? _maxAge;
  int get maxAge => _maxAge ?? 0;
  bool hasMaxAge() => _maxAge != null;

  // "lsc_code" field.
  String? _lscCode;
  String get lscCode => _lscCode ?? '';
  bool hasLscCode() => _lscCode != null;

  // "order" field.
  int? _order;
  int get order => _order ?? 0;
  bool hasOrder() => _order != null;

  void _initializeFields() {
    _groupId = snapshotData['group_id'] as String?;
    _displayName = snapshotData['display_name'] as String?;
    _minAge = castToType<int>(snapshotData['min_age']);
    _maxAge = castToType<int>(snapshotData['max_age']);
    _lscCode = snapshotData['lsc_code'] as String?;
    _order = castToType<int>(snapshotData['order']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('metadata_groups');

  static Stream<MetadataGroupsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MetadataGroupsRecord.fromSnapshot(s));

  static Future<MetadataGroupsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => MetadataGroupsRecord.fromSnapshot(s));

  static MetadataGroupsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      MetadataGroupsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static MetadataGroupsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MetadataGroupsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MetadataGroupsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MetadataGroupsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createMetadataGroupsRecordData({
  String? groupId,
  String? displayName,
  int? minAge,
  int? maxAge,
  String? lscCode,
  int? order,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'group_id': groupId,
      'display_name': displayName,
      'min_age': minAge,
      'max_age': maxAge,
      'lsc_code': lscCode,
      'order': order,
    }.withoutNulls,
  );

  return firestoreData;
}

class MetadataGroupsRecordDocumentEquality
    implements Equality<MetadataGroupsRecord> {
  const MetadataGroupsRecordDocumentEquality();

  @override
  bool equals(MetadataGroupsRecord? e1, MetadataGroupsRecord? e2) {
    return e1?.groupId == e2?.groupId &&
        e1?.displayName == e2?.displayName &&
        e1?.minAge == e2?.minAge &&
        e1?.maxAge == e2?.maxAge &&
        e1?.lscCode == e2?.lscCode &&
        e1?.order == e2?.order;
  }

  @override
  int hash(MetadataGroupsRecord? e) => const ListEquality().hash(
      [e?.groupId, e?.displayName, e?.minAge, e?.maxAge, e?.lscCode, e?.order]);

  @override
  bool isValidKey(Object? o) => o is MetadataGroupsRecord;
}
