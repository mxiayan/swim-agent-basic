// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class PracticeStruct extends FFFirebaseStruct {
  PracticeStruct({
    String? day,
    String? time,
    String? location,

    /// Dryland or Swim
    String? type,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _day = day,
        _time = time,
        _location = location,
        _type = type,
        super(firestoreUtilData);

  // "day" field.
  String? _day;
  String get day => _day ?? '';
  set day(String? val) => _day = val;

  bool hasDay() => _day != null;

  // "time" field.
  String? _time;
  String get time => _time ?? '';
  set time(String? val) => _time = val;

  bool hasTime() => _time != null;

  // "location" field.
  String? _location;
  String get location => _location ?? '';
  set location(String? val) => _location = val;

  bool hasLocation() => _location != null;

  // "type" field.
  String? _type;
  String get type => _type ?? '';
  set type(String? val) => _type = val;

  bool hasType() => _type != null;

  static PracticeStruct fromMap(Map<String, dynamic> data) => PracticeStruct(
        day: data['day'] as String?,
        time: data['time'] as String?,
        location: data['location'] as String?,
        type: data['type'] as String?,
      );

  static PracticeStruct? maybeFromMap(dynamic data) =>
      data is Map ? PracticeStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'day': _day,
        'time': _time,
        'location': _location,
        'type': _type,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'day': serializeParam(
          _day,
          ParamType.String,
        ),
        'time': serializeParam(
          _time,
          ParamType.String,
        ),
        'location': serializeParam(
          _location,
          ParamType.String,
        ),
        'type': serializeParam(
          _type,
          ParamType.String,
        ),
      }.withoutNulls;

  static PracticeStruct fromSerializableMap(Map<String, dynamic> data) =>
      PracticeStruct(
        day: deserializeParam(
          data['day'],
          ParamType.String,
          false,
        ),
        time: deserializeParam(
          data['time'],
          ParamType.String,
          false,
        ),
        location: deserializeParam(
          data['location'],
          ParamType.String,
          false,
        ),
        type: deserializeParam(
          data['type'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'PracticeStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is PracticeStruct &&
        day == other.day &&
        time == other.time &&
        location == other.location &&
        type == other.type;
  }

  @override
  int get hashCode => const ListEquality().hash([day, time, location, type]);
}

PracticeStruct createPracticeStruct({
  String? day,
  String? time,
  String? location,
  String? type,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    PracticeStruct(
      day: day,
      time: time,
      location: location,
      type: type,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

PracticeStruct? updatePracticeStruct(
  PracticeStruct? practice, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    practice
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addPracticeStructData(
  Map<String, dynamic> firestoreData,
  PracticeStruct? practice,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (practice == null) {
    return;
  }
  if (practice.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && practice.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final practiceData = getPracticeFirestoreData(practice, forFieldValue);
  final nestedData = practiceData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = practice.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getPracticeFirestoreData(
  PracticeStruct? practice, [
  bool forFieldValue = false,
]) {
  if (practice == null) {
    return {};
  }
  final firestoreData = mapToFirestore(practice.toMap());

  // Add any Firestore field values
  mapToFirestore(practice.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getPracticeListFirestoreData(
  List<PracticeStruct>? practices,
) =>
    practices?.map((e) => getPracticeFirestoreData(e, true)).toList() ?? [];
