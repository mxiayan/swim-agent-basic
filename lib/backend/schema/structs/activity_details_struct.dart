// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ActivityDetailsStruct extends FFFirebaseStruct {
  ActivityDetailsStruct({
    String? locationName,
    DateTime? warmupTime,
    String? signupUrl,
    String? notes,
    DateTime? endTime,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _locationName = locationName,
        _warmupTime = warmupTime,
        _signupUrl = signupUrl,
        _notes = notes,
        _endTime = endTime,
        super(firestoreUtilData);

  // "location_name" field.
  String? _locationName;
  String get locationName => _locationName ?? '';
  set locationName(String? val) => _locationName = val;

  bool hasLocationName() => _locationName != null;

  // "warmup_time" field.
  DateTime? _warmupTime;
  DateTime? get warmupTime => _warmupTime;
  set warmupTime(DateTime? val) => _warmupTime = val;

  bool hasWarmupTime() => _warmupTime != null;

  // "signup_url" field.
  String? _signupUrl;
  String get signupUrl => _signupUrl ?? '';
  set signupUrl(String? val) => _signupUrl = val;

  bool hasSignupUrl() => _signupUrl != null;

  // "notes" field.
  String? _notes;
  String get notes => _notes ?? '';
  set notes(String? val) => _notes = val;

  bool hasNotes() => _notes != null;

  // "end_time" field.
  DateTime? _endTime;
  DateTime? get endTime => _endTime;
  set endTime(DateTime? val) => _endTime = val;

  bool hasEndTime() => _endTime != null;

  static ActivityDetailsStruct fromMap(Map<String, dynamic> data) =>
      ActivityDetailsStruct(
        locationName: data['location_name'] as String?,
        warmupTime: data['warmup_time'] as DateTime?,
        signupUrl: data['signup_url'] as String?,
        notes: data['notes'] as String?,
        endTime: data['end_time'] as DateTime?,
      );

  static ActivityDetailsStruct? maybeFromMap(dynamic data) => data is Map
      ? ActivityDetailsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'location_name': _locationName,
        'warmup_time': _warmupTime,
        'signup_url': _signupUrl,
        'notes': _notes,
        'end_time': _endTime,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'location_name': serializeParam(
          _locationName,
          ParamType.String,
        ),
        'warmup_time': serializeParam(
          _warmupTime,
          ParamType.DateTime,
        ),
        'signup_url': serializeParam(
          _signupUrl,
          ParamType.String,
        ),
        'notes': serializeParam(
          _notes,
          ParamType.String,
        ),
        'end_time': serializeParam(
          _endTime,
          ParamType.DateTime,
        ),
      }.withoutNulls;

  static ActivityDetailsStruct fromSerializableMap(Map<String, dynamic> data) =>
      ActivityDetailsStruct(
        locationName: deserializeParam(
          data['location_name'],
          ParamType.String,
          false,
        ),
        warmupTime: deserializeParam(
          data['warmup_time'],
          ParamType.DateTime,
          false,
        ),
        signupUrl: deserializeParam(
          data['signup_url'],
          ParamType.String,
          false,
        ),
        notes: deserializeParam(
          data['notes'],
          ParamType.String,
          false,
        ),
        endTime: deserializeParam(
          data['end_time'],
          ParamType.DateTime,
          false,
        ),
      );

  @override
  String toString() => 'ActivityDetailsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ActivityDetailsStruct &&
        locationName == other.locationName &&
        warmupTime == other.warmupTime &&
        signupUrl == other.signupUrl &&
        notes == other.notes &&
        endTime == other.endTime;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([locationName, warmupTime, signupUrl, notes, endTime]);
}

ActivityDetailsStruct createActivityDetailsStruct({
  String? locationName,
  DateTime? warmupTime,
  String? signupUrl,
  String? notes,
  DateTime? endTime,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    ActivityDetailsStruct(
      locationName: locationName,
      warmupTime: warmupTime,
      signupUrl: signupUrl,
      notes: notes,
      endTime: endTime,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

ActivityDetailsStruct? updateActivityDetailsStruct(
  ActivityDetailsStruct? activityDetails, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    activityDetails
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addActivityDetailsStructData(
  Map<String, dynamic> firestoreData,
  ActivityDetailsStruct? activityDetails,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (activityDetails == null) {
    return;
  }
  if (activityDetails.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && activityDetails.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final activityDetailsData =
      getActivityDetailsFirestoreData(activityDetails, forFieldValue);
  final nestedData =
      activityDetailsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = activityDetails.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getActivityDetailsFirestoreData(
  ActivityDetailsStruct? activityDetails, [
  bool forFieldValue = false,
]) {
  if (activityDetails == null) {
    return {};
  }
  final firestoreData = mapToFirestore(activityDetails.toMap());

  // Add any Firestore field values
  activityDetails.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getActivityDetailsListFirestoreData(
  List<ActivityDetailsStruct>? activityDetailss,
) =>
    activityDetailss
        ?.map((e) => getActivityDetailsFirestoreData(e, true))
        .toList() ??
    [];
