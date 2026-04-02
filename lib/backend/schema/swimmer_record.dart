import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class SwimmerRecord extends FirestoreRecord {
  SwimmerRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  /// FlutterFlow uses `name`; legacy `display_name` still read if present.
  String? _displayName;
  String get displayName => _displayName ?? '';
  bool hasDisplayName() => _displayName != null;

  /// Meet host matching: FlutterFlow `club_code`, else `group_id`.
  String? _groupId;
  String get groupId => _groupId ?? '';
  bool hasGroupId() => _groupId != null;

  String? _zoneId;
  String get zoneId => _zoneId ?? '';
  bool hasZoneId() => _zoneId != null;

  String? _zoneDisplayName;
  String get zoneDisplayName => _zoneDisplayName ?? '';
  bool hasZoneDisplayName() => _zoneDisplayName != null;

  String? _clubId;
  String get clubId => _clubId ?? '';
  bool hasClubId() => _clubId != null;

  String? _ownerId;
  String get ownerId => _ownerId ?? '';
  bool hasOwnerId() => _ownerId != null;

  String? _lscName;
  String get lscName => _lscName ?? '';
  bool hasLscName() => _lscName != null;

  bool? _isActive;
  bool get isActive => _isActive ?? false;
  bool hasIsActive() => _isActive != null;

  static String? _firstNonEmptyString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final k in keys) {
      final v = _stringFromFirestore(data[k]);
      if (v != null && v.trim().isNotEmpty) {
        return v.trim();
      }
    }
    return null;
  }

  static String? _stringFromFirestore(dynamic v) {
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

  void _initializeFields() {
    _displayName =
        snapshotData['name'] as String? ?? snapshotData['display_name'] as String?;
    _groupId = snapshotData['club_code'] as String? ??
        snapshotData['lsc_club_code'] as String? ??
        snapshotData['usa_swimming_club_code'] as String? ??
        snapshotData['group_id'] as String?;
    _zoneId = _firstNonEmptyString(snapshotData, const [
      'zone_id',
      'ZoneId',
      'zoneId',
      'granular_zone',
      'pacific_zone',
    ]);
    _zoneDisplayName = _firstNonEmptyString(snapshotData, const [
      'zone_display_name',
      'zoneDisplayName',
      'ZoneDisplayName',
    ]);
    _clubId = snapshotData['club_id'] as String?;
    final rawOwner = snapshotData['owner_id'];
    if (rawOwner is DocumentReference) {
      _ownerId = rawOwner.id;
    } else {
      _ownerId = rawOwner as String?;
    }
    _lscName = snapshotData['lsc_name'] as String?;
    _isActive = snapshotData['is_active'] as bool?;
  }

  /// FlutterFlow / Pacific Swimming app collection name.
  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('swimmers');

  /// Resolves the profile: `swimmers/{uid}`, `owner_id` as string uid, or
  /// **FlutterFlow** `owner_id` as [DocumentReference] to `users/{uid}`.
  static Future<DocumentReference?> documentRefForAuthUid(String uid) async {
    final col = collection;
    final byId = await col.doc(uid).get();
    if (byId.exists) {
      return byId.reference;
    }
    final qString =
        await col.where('owner_id', isEqualTo: uid).limit(1).get();
    if (qString.docs.isNotEmpty) {
      return qString.docs.first.reference;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final qRef =
        await col.where('owner_id', isEqualTo: userRef).limit(1).get();
    if (qRef.docs.isNotEmpty) {
      return qRef.docs.first.reference;
    }

    final userRefAlt = FirebaseFirestore.instance.collection('Users').doc(uid);
    final qRefAlt =
        await col.where('owner_id', isEqualTo: userRefAlt).limit(1).get();
    if (qRefAlt.docs.isNotEmpty) {
      return qRefAlt.docs.first.reference;
    }

    return null;
  }

  static Future<SwimmerRecord?> getForAuthUid(String uid) async {
    final ref = await documentRefForAuthUid(uid);
    if (ref == null) {
      return null;
    }
    final snap = await ref.get();
    if (!snap.exists) {
      return null;
    }
    return fromSnapshot(snap);
  }

  static Stream<SwimmerRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => SwimmerRecord.fromSnapshot(s));

  static Future<SwimmerRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => SwimmerRecord.fromSnapshot(s));

  static SwimmerRecord fromSnapshot(DocumentSnapshot snapshot) =>
      SwimmerRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static SwimmerRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      SwimmerRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'SwimmerRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is SwimmerRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

/// Writes fields compatible with FlutterFlow `swimmers` documents.
Map<String, dynamic> createSwimmerRecordData({
  /// Maps to Firestore `name` (FlutterFlow swimmer name).
  String? name,
  /// Legacy key; if set, written only when [name] is null (avoid duplicate keys).
  String? displayName,
  String? clubCode,
  String? groupId,
  String? zoneId,
  String? zoneDisplayName,
  String? clubId,
}) {
  final effectiveName = name ?? displayName;
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name': effectiveName,
      'club_code': clubCode,
      'group_id': groupId,
      'zone_id': zoneId,
      'zone_display_name': zoneDisplayName,
      'club_id': clubId,
    }.withoutNulls,
  );

  return firestoreData;
}

class SwimmerRecordDocumentEquality implements Equality<SwimmerRecord> {
  const SwimmerRecordDocumentEquality();

  @override
  bool equals(SwimmerRecord? e1, SwimmerRecord? e2) {
    return e1?.displayName == e2?.displayName &&
        e1?.groupId == e2?.groupId &&
        e1?.zoneId == e2?.zoneId &&
        e1?.zoneDisplayName == e2?.zoneDisplayName &&
        e1?.clubId == e2?.clubId &&
        e1?.ownerId == e2?.ownerId;
  }

  @override
  int hash(SwimmerRecord? e) => const ListEquality().hash([
        e?.displayName,
        e?.groupId,
        e?.zoneId,
        e?.zoneDisplayName,
        e?.clubId,
        e?.ownerId,
      ]);

  @override
  bool isValidKey(Object? o) => o is SwimmerRecord;
}
