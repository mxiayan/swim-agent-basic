import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MetadataClubsRecord extends FirestoreRecord {
  MetadataClubsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "lsc_name" field.
  String? _lscName;
  String get lscName => _lscName ?? '';
  bool hasLscName() => _lscName != null;

  // "lsc_code" field.
  String? _lscCode;
  String get lscCode => _lscCode ?? '';
  bool hasLscCode() => _lscCode != null;

  // "club_name" field.
  String? _clubName;
  String get clubName => _clubName ?? '';
  bool hasClubName() => _clubName != null;

  // "club_code" field.
  String? _clubCode;
  String get clubCode => _clubCode ?? '';
  bool hasClubCode() => _clubCode != null;

  // "is_active" field.
  bool? _isActive;
  bool get isActive => _isActive ?? false;
  bool hasIsActive() => _isActive != null;

  // "zone_id" field.
  String? _zoneId;
  String get zoneId => _zoneId ?? '';
  bool hasZoneId() => _zoneId != null;

  // "zone_display" field.
  String? _zoneDisplay;
  String get zoneDisplay => _zoneDisplay ?? '';
  bool hasZoneDisplay() => _zoneDisplay != null;

  void _initializeFields() {
    _lscName = snapshotData['lsc_name'] as String?;
    _lscCode = snapshotData['lsc_code'] as String?;
    _clubName = snapshotData['club_name'] as String?;
    _clubCode = snapshotData['club_code'] as String?;
    _isActive = snapshotData['is_active'] as bool?;
    _zoneId = snapshotData['zone_id'] as String?;
    _zoneDisplay = snapshotData['zone_display'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('metadata_clubs');

  static Stream<MetadataClubsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MetadataClubsRecord.fromSnapshot(s));

  static Future<MetadataClubsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => MetadataClubsRecord.fromSnapshot(s));

  static MetadataClubsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      MetadataClubsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static MetadataClubsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MetadataClubsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MetadataClubsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MetadataClubsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createMetadataClubsRecordData({
  String? lscName,
  String? lscCode,
  String? clubName,
  String? clubCode,
  bool? isActive,
  String? zoneId,
  String? zoneDisplay,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'lsc_name': lscName,
      'lsc_code': lscCode,
      'club_name': clubName,
      'club_code': clubCode,
      'is_active': isActive,
      'zone_id': zoneId,
      'zone_display': zoneDisplay,
    }.withoutNulls,
  );

  return firestoreData;
}

class MetadataClubsRecordDocumentEquality
    implements Equality<MetadataClubsRecord> {
  const MetadataClubsRecordDocumentEquality();

  @override
  bool equals(MetadataClubsRecord? e1, MetadataClubsRecord? e2) {
    return e1?.lscName == e2?.lscName &&
        e1?.lscCode == e2?.lscCode &&
        e1?.clubName == e2?.clubName &&
        e1?.clubCode == e2?.clubCode &&
        e1?.isActive == e2?.isActive &&
        e1?.zoneId == e2?.zoneId &&
        e1?.zoneDisplay == e2?.zoneDisplay;
  }

  @override
  int hash(MetadataClubsRecord? e) => const ListEquality().hash([
        e?.lscName,
        e?.lscCode,
        e?.clubName,
        e?.clubCode,
        e?.isActive,
        e?.zoneId,
        e?.zoneDisplay
      ]);

  @override
  bool isValidKey(Object? o) => o is MetadataClubsRecord;
}
