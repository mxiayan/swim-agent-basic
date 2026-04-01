import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class HiddenMeetsRecord extends FirestoreRecord {
  HiddenMeetsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "meet_id" field.
  String? _meetId;
  String get meetId => _meetId ?? '';
  bool hasMeetId() => _meetId != null;

  // "hidden_at" field.
  DateTime? _hiddenAt;
  DateTime? get hiddenAt => _hiddenAt;
  bool hasHiddenAt() => _hiddenAt != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _meetId = snapshotData['meet_id'] as String?;
    _hiddenAt = snapshotData['hidden_at'] as DateTime?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('hidden_meets')
          : FirebaseFirestore.instance.collectionGroup('hidden_meets');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('hidden_meets').doc(id);

  static Stream<HiddenMeetsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => HiddenMeetsRecord.fromSnapshot(s));

  static Future<HiddenMeetsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => HiddenMeetsRecord.fromSnapshot(s));

  static HiddenMeetsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      HiddenMeetsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static HiddenMeetsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      HiddenMeetsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'HiddenMeetsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is HiddenMeetsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createHiddenMeetsRecordData({
  String? meetId,
  DateTime? hiddenAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'meet_id': meetId,
      'hidden_at': hiddenAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class HiddenMeetsRecordDocumentEquality implements Equality<HiddenMeetsRecord> {
  const HiddenMeetsRecordDocumentEquality();

  @override
  bool equals(HiddenMeetsRecord? e1, HiddenMeetsRecord? e2) {
    return e1?.meetId == e2?.meetId && e1?.hiddenAt == e2?.hiddenAt;
  }

  @override
  int hash(HiddenMeetsRecord? e) =>
      const ListEquality().hash([e?.meetId, e?.hiddenAt]);

  @override
  bool isValidKey(Object? o) => o is HiddenMeetsRecord;
}
