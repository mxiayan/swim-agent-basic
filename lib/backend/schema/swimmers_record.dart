import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class SwimmersRecord extends FirestoreRecord {
  SwimmersRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "group" field.
  String? _group;
  String get group => _group ?? '';
  bool hasGroup() => _group != null;

  // "owner_id" field.
  DocumentReference? _ownerId;
  DocumentReference? get ownerId => _ownerId;
  bool hasOwnerId() => _ownerId != null;

  // "is_active" field.
  bool? _isActive;
  bool get isActive => _isActive ?? false;
  bool hasIsActive() => _isActive != null;

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "club_code" field.
  String? _clubCode;
  String get clubCode => _clubCode ?? '';
  bool hasClubCode() => _clubCode != null;

  // "lsc_name" field.
  String? _lscName;
  String get lscName => _lscName ?? '';
  bool hasLscName() => _lscName != null;

  void _initializeFields() {
    _group = snapshotData['group'] as String?;
    _ownerId = snapshotData['owner_id'] as DocumentReference?;
    _isActive = snapshotData['is_active'] as bool?;
    _name = snapshotData['name'] as String?;
    _clubCode = snapshotData['club_code'] as String?;
    _lscName = snapshotData['lsc_name'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('swimmers');

  static Stream<SwimmersRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => SwimmersRecord.fromSnapshot(s));

  static Future<SwimmersRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => SwimmersRecord.fromSnapshot(s));

  static SwimmersRecord fromSnapshot(DocumentSnapshot snapshot) =>
      SwimmersRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static SwimmersRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      SwimmersRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'SwimmersRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is SwimmersRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createSwimmersRecordData({
  String? group,
  DocumentReference? ownerId,
  bool? isActive,
  String? name,
  String? clubCode,
  String? lscName,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'group': group,
      'owner_id': ownerId,
      'is_active': isActive,
      'name': name,
      'club_code': clubCode,
      'lsc_name': lscName,
    }.withoutNulls,
  );

  return firestoreData;
}

class SwimmersRecordDocumentEquality implements Equality<SwimmersRecord> {
  const SwimmersRecordDocumentEquality();

  @override
  bool equals(SwimmersRecord? e1, SwimmersRecord? e2) {
    return e1?.group == e2?.group &&
        e1?.ownerId == e2?.ownerId &&
        e1?.isActive == e2?.isActive &&
        e1?.name == e2?.name &&
        e1?.clubCode == e2?.clubCode &&
        e1?.lscName == e2?.lscName;
  }

  @override
  int hash(SwimmersRecord? e) => const ListEquality().hash(
      [e?.group, e?.ownerId, e?.isActive, e?.name, e?.clubCode, e?.lscName]);

  @override
  bool isValidKey(Object? o) => o is SwimmersRecord;
}
