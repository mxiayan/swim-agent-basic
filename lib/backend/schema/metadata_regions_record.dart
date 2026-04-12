import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Maps swimmer/app zone (`Z2`, `Z1N`) to [MetadataRegionsRecord.region_id] (`PC_Z2`, `PC_Z1N`).
String? pacificCatalogRegionIdFromGranular(String? raw) {
  if (raw == null) {
    return null;
  }
  final t = raw.trim();
  if (!RegExp(r'^Z\d+[NSEW]?$', caseSensitive: false).hasMatch(t)) {
    return null;
  }
  final m = RegExp(r'^Z(\d+)([NSEW])?$', caseSensitive: false).firstMatch(t);
  if (m == null) {
    return null;
  }
  final n = m.group(1)!;
  final suf = (m.group(2) ?? '').toUpperCase();
  return 'PC_Z$n$suf'.toUpperCase();
}

/// Firestore may store `order` as int, double, or string (e.g. catalog rows like `SN_ALL`).
int? orderFieldFromFirestore(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    final t = value.trim();
    if (t.isEmpty) {
      return null;
    }
    return int.tryParse(t);
  }
  return null;
}

class MetadataRegionsRecord extends FirestoreRecord {
  MetadataRegionsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "region_id" field.
  String? _regionId;
  String get regionId => _regionId ?? '';
  bool hasRegionId() => _regionId != null;

  // "display_name" field.
  String? _displayName;
  String get displayName => _displayName ?? '';
  bool hasDisplayName() => _displayName != null;

  // "lsc_code" field.
  String? _lscCode;
  String get lscCode => _lscCode ?? '';
  bool hasLscCode() => _lscCode != null;

  // "lsc_name" field.
  String? _lscName;
  String get lscName => _lscName ?? '';
  bool hasLscName() => _lscName != null;

  // "type" field.
  String? _type;
  String get type => _type ?? '';
  bool hasType() => _type != null;

  // "order" field.
  int? _order;
  int get order => _order ?? 0;
  bool hasOrder() => _order != null;

  void _initializeFields() {
    _regionId = snapshotData['region_id'] as String?;
    _displayName = snapshotData['display_name'] as String?;
    _lscCode = snapshotData['lsc_code'] as String?;
    _lscName = snapshotData['lsc_name'] as String?;
    _type = snapshotData['type'] as String?;
    _order = orderFieldFromFirestore(snapshotData['order']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('metadata_regions');

  /// Resolves catalog row for a granular Pacific zone (see [pacificCatalogRegionIdFromGranular]).
  static Future<MetadataRegionsRecord?> findByGranularPacificZone(
    String granularZone,
  ) async {
    final rid = pacificCatalogRegionIdFromGranular(granularZone);
    if (rid == null || rid.isEmpty) {
      return null;
    }
    final snap =
        await collection.where('region_id', isEqualTo: rid).limit(1).get();
    if (snap.docs.isEmpty) {
      return null;
    }
    return MetadataRegionsRecord.fromSnapshot(snap.docs.first);
  }

  static Stream<MetadataRegionsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MetadataRegionsRecord.fromSnapshot(s));

  static Future<MetadataRegionsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => MetadataRegionsRecord.fromSnapshot(s));

  static MetadataRegionsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      MetadataRegionsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static MetadataRegionsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MetadataRegionsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MetadataRegionsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MetadataRegionsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createMetadataRegionsRecordData({
  String? regionId,
  String? displayName,
  String? lscCode,
  String? lscName,
  String? type,
  int? order,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'region_id': regionId,
      'display_name': displayName,
      'lsc_code': lscCode,
      'lsc_name': lscName,
      'type': type,
      'order': order,
    }.withoutNulls,
  );

  return firestoreData;
}

class MetadataRegionsRecordDocumentEquality
    implements Equality<MetadataRegionsRecord> {
  const MetadataRegionsRecordDocumentEquality();

  @override
  bool equals(MetadataRegionsRecord? e1, MetadataRegionsRecord? e2) {
    return e1?.regionId == e2?.regionId &&
        e1?.displayName == e2?.displayName &&
        e1?.lscCode == e2?.lscCode &&
        e1?.lscName == e2?.lscName &&
        e1?.type == e2?.type &&
        e1?.order == e2?.order;
  }

  @override
  int hash(MetadataRegionsRecord? e) => const ListEquality().hash(
      [e?.regionId, e?.displayName, e?.lscCode, e?.lscName, e?.type, e?.order]);

  @override
  bool isValidKey(Object? o) => o is MetadataRegionsRecord;
}
