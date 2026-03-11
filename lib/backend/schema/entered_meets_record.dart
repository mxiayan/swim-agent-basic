import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class EnteredMeetsRecord extends FirestoreRecord {
  EnteredMeetsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "meet_id" field.
  String? _meetId;
  String get meetId => _meetId ?? '';
  bool hasMeetId() => _meetId != null;

  // "entered_at" field.
  DateTime? _enteredAt;
  DateTime? get enteredAt => _enteredAt;
  bool hasEnteredAt() => _enteredAt != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _meetId = snapshotData['meet_id'] as String?;
    _enteredAt = snapshotData['entered_at'] as DateTime?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('entered_meets')
          : FirebaseFirestore.instance.collectionGroup('entered_meets');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('entered_meets').doc(id);

  static Stream<EnteredMeetsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => EnteredMeetsRecord.fromSnapshot(s));

  static Future<EnteredMeetsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => EnteredMeetsRecord.fromSnapshot(s));

  static EnteredMeetsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      EnteredMeetsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static EnteredMeetsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      EnteredMeetsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'EnteredMeetsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is EnteredMeetsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createEnteredMeetsRecordData({
  String? meetId,
  DateTime? enteredAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'meet_id': meetId,
      'entered_at': enteredAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class EnteredMeetsRecordDocumentEquality
    implements Equality<EnteredMeetsRecord> {
  const EnteredMeetsRecordDocumentEquality();

  @override
  bool equals(EnteredMeetsRecord? e1, EnteredMeetsRecord? e2) {
    return e1?.meetId == e2?.meetId && e1?.enteredAt == e2?.enteredAt;
  }

  @override
  int hash(EnteredMeetsRecord? e) =>
      const ListEquality().hash([e?.meetId, e?.enteredAt]);

  @override
  bool isValidKey(Object? o) => o is EnteredMeetsRecord;
}
