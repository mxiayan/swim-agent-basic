import 'dart:async';

import 'package:collection/collection.dart';
import 'package:firebase_core/firebase_core.dart';

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

  /// Practice tier / age-group override chosen on the profile screen (`practice_tier_label`).
  String? _practiceTierLabel;
  String get practiceTierLabel => _practiceTierLabel ?? '';

  /// Custom profile photo persisted as base64 (`profile_avatar_base64`).
  String? _profileAvatarBase64;
  String get profileAvatarBase64 => _profileAvatarBase64 ?? '';

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

  /// Parses common Firestore field shapes (avoids `as String?` throws on numbers).
  static String? swimDisplayNameFromMap(Map<String, dynamic> m) {
    final direct = _firstNonEmptyString(m, const [
      'name',
      'Name',
      'display_name',
      'displayName',
      'DisplayName',
      'swimmer_name',
      'swimmerName',
      'full_name',
      'fullName',
      'legal_name',
      'legalName',
    ]);
    if (direct != null) {
      return direct;
    }
    final fn =
        _stringFromFirestore(m['first_name'] ?? m['firstName'])?.trim() ?? '';
    final ln =
        _stringFromFirestore(m['last_name'] ?? m['lastName'])?.trim() ?? '';
    if (fn.isNotEmpty && ln.isNotEmpty) {
      return '$fn $ln';
    }
    if (fn.isNotEmpty) {
      return fn;
    }
    if (ln.isNotEmpty) {
      return ln;
    }
    return null;
  }

  /// Loads a display name from `swimmers` when [getForAuthUid] returns null or the
  /// doc has no readable name fields (extra queries, same owner patterns as
  /// [documentRefForAuthUid]).
  static Future<String?> fetchDisplayNameFromFirestoreForUid(String uid) async {
    final col = collection;

    String? fromSnap(DocumentSnapshot s) {
      if (!s.exists) {
        return null;
      }
      final raw = s.data();
      if (raw is! Map<String, dynamic>) {
        return null;
      }
      return swimDisplayNameFromMap(mapFromFirestore(raw));
    }

    Future<String?> fromQuery(Query q) async {
      final qs = await _tryQuery(q.limit(10));
      if (qs == null) {
        return null;
      }
      for (final doc in qs.docs) {
        final n = fromSnap(doc);
        if (n != null && n.isNotEmpty) {
          return n;
        }
      }
      return null;
    }

    final byId = await _tryGetDoc(col.doc(uid));
    if (byId != null) {
      final n0 = fromSnap(byId);
      if (n0 != null && n0.isNotEmpty) {
        return n0;
      }
    }

    final n1 = await fromQuery(col.where('owner_id', isEqualTo: uid));
    if (n1 != null) {
      return n1;
    }

    final n2 = await fromQuery(col.where('uid', isEqualTo: uid));
    if (n2 != null) {
      return n2;
    }

    final n2b = await fromQuery(col.where('user_id', isEqualTo: uid));
    if (n2b != null) {
      return n2b;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final n3 = await fromQuery(col.where('owner_id', isEqualTo: userRef));
    if (n3 != null) {
      return n3;
    }

    final userRefAlt = FirebaseFirestore.instance.collection('Users').doc(uid);
    final n4 = await fromQuery(col.where('owner_id', isEqualTo: userRefAlt));
    return n4;
  }

  void _initializeFields() {
    final parsed = swimDisplayNameFromMap(snapshotData);
    _displayName = (parsed != null && parsed.isNotEmpty) ? parsed : null;
    _groupId = snapshotData['club_code'] as String? ??
        snapshotData['lsc_club_code'] as String? ??
        snapshotData['usa_swimming_club_code'] as String? ??
        snapshotData['group_id'] as String? ??
        snapshotData['group'] as String?;
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
    _practiceTierLabel = _firstNonEmptyString(snapshotData, const [
      'practice_tier_label',
      'practiceTierLabel',
    ]);
    final rawAvatar = snapshotData['profile_avatar_base64'] ??
        snapshotData['profileAvatarBase64'];
    if (rawAvatar is String) {
      _profileAvatarBase64 = rawAvatar;
    } else {
      _profileAvatarBase64 = null;
    }
  }

  /// FlutterFlow / Pacific Swimming app collection name.
  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('swimmers');

  static Future<DocumentSnapshot?> _tryGetDoc(DocumentReference ref) async {
    try {
      return await ref.get();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }

  static Future<QuerySnapshot?> _tryQuery(Query query) async {
    try {
      return await query.get();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }

  /// Resolves the profile: `swimmers/{uid}`, `owner_id` as string uid, or
  /// **FlutterFlow** `owner_id` as [DocumentReference] to `users/{uid}`.
  static Future<DocumentReference?> documentRefForAuthUid(String uid) async {
    final col = collection;
    final byId = await _tryGetDoc(col.doc(uid));
    if (byId != null && byId.exists) {
      return byId.reference;
    }
    final qString = await _tryQuery(
        col.where('owner_id', isEqualTo: uid).limit(1));
    if (qString != null && qString.docs.isNotEmpty) {
      return qString.docs.first.reference;
    }

    final qUidField = await _tryQuery(col.where('uid', isEqualTo: uid).limit(1));
    if (qUidField != null && qUidField.docs.isNotEmpty) {
      return qUidField.docs.first.reference;
    }

    final qUserId =
        await _tryQuery(col.where('user_id', isEqualTo: uid).limit(1));
    if (qUserId != null && qUserId.docs.isNotEmpty) {
      return qUserId.docs.first.reference;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final qRef = await _tryQuery(
        col.where('owner_id', isEqualTo: userRef).limit(1));
    if (qRef != null && qRef.docs.isNotEmpty) {
      return qRef.docs.first.reference;
    }

    final userRefAlt = FirebaseFirestore.instance.collection('Users').doc(uid);
    final qRefAlt = await _tryQuery(
        col.where('owner_id', isEqualTo: userRefAlt).limit(1));
    if (qRefAlt != null && qRefAlt.docs.isNotEmpty) {
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
  /// Age-group / practice tier label from profile UI (`practice_tier_label`).
  String? practiceTierLabel,
  /// Custom avatar as base64 JPEG/PNG (`profile_avatar_base64`). Pass `''` to clear.
  String? profileAvatarBase64,
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
      if (practiceTierLabel != null) 'practice_tier_label': practiceTierLabel,
      if (profileAvatarBase64 != null)
        'profile_avatar_base64': profileAvatarBase64,
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
