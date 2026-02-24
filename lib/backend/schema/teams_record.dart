import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class TeamsRecord extends FirestoreRecord {
  TeamsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "location" field.
  String? _location;
  String get location => _location ?? '';
  bool hasLocation() => _location != null;

  // "branding" field.
  BrandingStructStruct? _branding;
  BrandingStructStruct get branding => _branding ?? BrandingStructStruct();
  bool hasBranding() => _branding != null;

  // "groups" field.
  List<String>? _groups;
  List<String> get groups => _groups ?? const [];
  bool hasGroups() => _groups != null;

  // "sport" field.
  String? _sport;
  String get sport => _sport ?? '';
  bool hasSport() => _sport != null;

  void _initializeFields() {
    _name = snapshotData['name'] as String?;
    _createdAt = snapshotData['created_at'] as DateTime?;
    _location = snapshotData['location'] as String?;
    _branding = snapshotData['branding'] is BrandingStructStruct
        ? snapshotData['branding']
        : BrandingStructStruct.maybeFromMap(snapshotData['branding']);
    _groups = getDataList(snapshotData['groups']);
    _sport = snapshotData['sport'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('teams');

  static Stream<TeamsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => TeamsRecord.fromSnapshot(s));

  static Future<TeamsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => TeamsRecord.fromSnapshot(s));

  static TeamsRecord fromSnapshot(DocumentSnapshot snapshot) => TeamsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static TeamsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      TeamsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'TeamsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is TeamsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createTeamsRecordData({
  String? name,
  DateTime? createdAt,
  String? location,
  BrandingStructStruct? branding,
  String? sport,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name': name,
      'created_at': createdAt,
      'location': location,
      'branding': BrandingStructStruct().toMap(),
      'sport': sport,
    }.withoutNulls,
  );

  // Handle nested data for "branding" field.
  addBrandingStructStructData(firestoreData, branding, 'branding');

  return firestoreData;
}

class TeamsRecordDocumentEquality implements Equality<TeamsRecord> {
  const TeamsRecordDocumentEquality();

  @override
  bool equals(TeamsRecord? e1, TeamsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.name == e2?.name &&
        e1?.createdAt == e2?.createdAt &&
        e1?.location == e2?.location &&
        e1?.branding == e2?.branding &&
        listEquality.equals(e1?.groups, e2?.groups) &&
        e1?.sport == e2?.sport;
  }

  @override
  int hash(TeamsRecord? e) => const ListEquality().hash(
      [e?.name, e?.createdAt, e?.location, e?.branding, e?.groups, e?.sport]);

  @override
  bool isValidKey(Object? o) => o is TeamsRecord;
}
