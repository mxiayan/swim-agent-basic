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

  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  String? _zoneId;
  String get zoneId => _zoneId ?? '';
  bool hasZoneId() => _zoneId != null;

  String? _zoneDisplayName;
  String get zoneDisplayName => _zoneDisplayName ?? '';
  bool hasZoneDisplayName() => _zoneDisplayName != null;

  /// LSC label (sign-up); falls back to zone display name.
  String? _lscName;
  String get lscName => (_lscName ?? _zoneDisplayName ?? '').trim();

  /// Club code for dropdowns; falls back to document id.
  String? _clubCode;
  String get clubCode => (_clubCode ?? reference.id).trim();

  /// Display name for club picker; falls back to [name].
  String? _clubName;
  String get clubName => (_clubName ?? _name ?? '').trim();

  /// Canonical home pool line for coach-email parsing (Pacific / any LSC).
  String? _homePoolLocation;
  String get homePoolLocation => (_homePoolLocation ?? '').trim();

  void _initializeFields() {
    _name = snapshotData['name'] as String?;
    _zoneId = _asString(snapshotData['zone_id']);
    _zoneDisplayName = _asString(snapshotData['zone_display_name']);
    _lscName = _asString(snapshotData['lsc_name']);
    _clubCode = _asString(
        snapshotData['club_code'] ?? snapshotData['code'] ?? snapshotData['club_id']);
    _clubName = _asString(snapshotData['club_name']);
    _homePoolLocation = _asString(snapshotData['home_pool_location']);
  }

  static String? _asString(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is String) {
      return v;
    }
    if (v is num || v is bool) {
      return v.toString();
    }
    return v.toString();
  }

  /// Match swimmer club keys to a metadata doc: by document id, then common field names.
  static Future<MetadataClubsRecord?> findByClubLookup(String raw) async {
    final key = raw.trim();
    if (key.isEmpty) {
      return null;
    }

    DocumentSnapshot? snap;

    var doc = await collection.doc(key).get();
    if (doc.exists) {
      snap = doc;
    }
    if (snap == null) {
      final upper = key.toUpperCase();
      if (upper != key) {
        doc = await collection.doc(upper).get();
        if (doc.exists) {
          snap = doc;
        }
      }
    }
    if (snap == null) {
      for (final field in [
        'club_code',
        'code',
        'lsc_club_code',
        'team_code',
        'club_id',
      ]) {
        final q = await collection.where(field, isEqualTo: key).limit(1).get();
        if (q.docs.isNotEmpty) {
          snap = q.docs.first;
          break;
        }
      }
    }
    if (snap == null) {
      final upper = key.toUpperCase();
      if (upper != key) {
        for (final field in ['club_code', 'code', 'lsc_club_code']) {
          final q =
              await collection.where(field, isEqualTo: upper).limit(1).get();
          if (q.docs.isNotEmpty) {
            snap = q.docs.first;
            break;
          }
        }
      }
    }

    if (snap == null || !snap.exists) {
      return null;
    }
    return fromSnapshot(snap);
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
  String? name,
  String? zoneId,
  String? zoneDisplayName,
  String? homePoolLocation,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name': name,
      'zone_id': zoneId,
      'zone_display_name': zoneDisplayName,
      'home_pool_location': homePoolLocation,
    }.withoutNulls,
  );

  return firestoreData;
}

class MetadataClubsRecordDocumentEquality
    implements Equality<MetadataClubsRecord> {
  const MetadataClubsRecordDocumentEquality();

  @override
  bool equals(MetadataClubsRecord? e1, MetadataClubsRecord? e2) {
    return e1?.name == e2?.name &&
        e1?.zoneId == e2?.zoneId &&
        e1?.zoneDisplayName == e2?.zoneDisplayName &&
        e1?.lscName == e2?.lscName &&
        e1?.clubCode == e2?.clubCode &&
        e1?.clubName == e2?.clubName &&
        e1?.homePoolLocation == e2?.homePoolLocation;
  }

  @override
  int hash(MetadataClubsRecord? e) => const ListEquality().hash([
        e?.name,
        e?.zoneId,
        e?.zoneDisplayName,
        e?.lscName,
        e?.clubCode,
        e?.clubName,
        e?.homePoolLocation,
      ]);

  @override
  bool isValidKey(Object? o) => o is MetadataClubsRecord;
}
