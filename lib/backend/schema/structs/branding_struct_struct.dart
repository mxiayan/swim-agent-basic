// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class BrandingStructStruct extends FFFirebaseStruct {
  BrandingStructStruct({
    String? primaryColor,
    String? secondaryColor,
    String? logoUrl,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _primaryColor = primaryColor,
        _secondaryColor = secondaryColor,
        _logoUrl = logoUrl,
        super(firestoreUtilData);

  // "primary_color" field.
  String? _primaryColor;
  String get primaryColor => _primaryColor ?? '';
  set primaryColor(String? val) => _primaryColor = val;

  bool hasPrimaryColor() => _primaryColor != null;

  // "secondary_color" field.
  String? _secondaryColor;
  String get secondaryColor => _secondaryColor ?? '';
  set secondaryColor(String? val) => _secondaryColor = val;

  bool hasSecondaryColor() => _secondaryColor != null;

  // "logo_url" field.
  String? _logoUrl;
  String get logoUrl => _logoUrl ?? '';
  set logoUrl(String? val) => _logoUrl = val;

  bool hasLogoUrl() => _logoUrl != null;

  static BrandingStructStruct fromMap(Map<String, dynamic> data) =>
      BrandingStructStruct(
        primaryColor: data['primary_color'] as String?,
        secondaryColor: data['secondary_color'] as String?,
        logoUrl: data['logo_url'] as String?,
      );

  static BrandingStructStruct? maybeFromMap(dynamic data) => data is Map
      ? BrandingStructStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'primary_color': _primaryColor,
        'secondary_color': _secondaryColor,
        'logo_url': _logoUrl,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'primary_color': serializeParam(
          _primaryColor,
          ParamType.String,
        ),
        'secondary_color': serializeParam(
          _secondaryColor,
          ParamType.String,
        ),
        'logo_url': serializeParam(
          _logoUrl,
          ParamType.String,
        ),
      }.withoutNulls;

  static BrandingStructStruct fromSerializableMap(Map<String, dynamic> data) =>
      BrandingStructStruct(
        primaryColor: deserializeParam(
          data['primary_color'],
          ParamType.String,
          false,
        ),
        secondaryColor: deserializeParam(
          data['secondary_color'],
          ParamType.String,
          false,
        ),
        logoUrl: deserializeParam(
          data['logo_url'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'BrandingStructStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is BrandingStructStruct &&
        primaryColor == other.primaryColor &&
        secondaryColor == other.secondaryColor &&
        logoUrl == other.logoUrl;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([primaryColor, secondaryColor, logoUrl]);
}

BrandingStructStruct createBrandingStructStruct({
  String? primaryColor,
  String? secondaryColor,
  String? logoUrl,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    BrandingStructStruct(
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      logoUrl: logoUrl,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

BrandingStructStruct? updateBrandingStructStruct(
  BrandingStructStruct? brandingStruct, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    brandingStruct
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addBrandingStructStructData(
  Map<String, dynamic> firestoreData,
  BrandingStructStruct? brandingStruct,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (brandingStruct == null) {
    return;
  }
  if (brandingStruct.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && brandingStruct.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final brandingStructData =
      getBrandingStructFirestoreData(brandingStruct, forFieldValue);
  final nestedData =
      brandingStructData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = brandingStruct.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getBrandingStructFirestoreData(
  BrandingStructStruct? brandingStruct, [
  bool forFieldValue = false,
]) {
  if (brandingStruct == null) {
    return {};
  }
  final firestoreData = mapToFirestore(brandingStruct.toMap());

  // Add any Firestore field values
  mapToFirestore(brandingStruct.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getBrandingStructListFirestoreData(
  List<BrandingStructStruct>? brandingStructs,
) =>
    brandingStructs
        ?.map((e) => getBrandingStructFirestoreData(e, true))
        .toList() ??
    [];
