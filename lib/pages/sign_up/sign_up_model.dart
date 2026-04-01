import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/index.dart';
import 'sign_up_widget.dart' show SignUpWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SignUpModel extends FlutterFlowModel<SignUpWidget> {
  ///  Local state fields for this page.

  List<String> lscList = [];
  void addToLscList(String item) => lscList.add(item);
  void removeFromLscList(String item) => lscList.remove(item);
  void removeAtIndexFromLscList(int index) => lscList.removeAt(index);
  void insertAtIndexInLscList(int index, String item) =>
      lscList.insert(index, item);
  void updateLscListAtIndex(int index, Function(String) updateFn) =>
      lscList[index] = updateFn(lscList[index]);

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Firestore Query - Query a collection] action in SignUp widget.
  List<MetadataClubsRecord>? allClubs;
  // State field(s) for SectionSeletor widget.
  String? sectionSeletorValue;
  FormFieldController<String>? sectionSeletorValueController;
  // State field(s) for ClubSelector widget.
  String? clubSelectorValue;
  FormFieldController<String>? clubSelectorValueController;
  // State field(s) for SwimmerName widget.
  FocusNode? swimmerNameFocusNode;
  TextEditingController? swimmerNameTextController;
  String? Function(BuildContext, String?)? swimmerNameTextControllerValidator;
  // State field(s) for EmailAddress widget.
  FocusNode? emailAddressFocusNode;
  TextEditingController? emailAddressTextController;
  String? Function(BuildContext, String?)? emailAddressTextControllerValidator;
  // State field(s) for Password widget.
  FocusNode? passwordFocusNode;
  TextEditingController? passwordTextController;
  late bool passwordVisibility;
  String? Function(BuildContext, String?)? passwordTextControllerValidator;

  @override
  void initState(BuildContext context) {
    passwordVisibility = false;
  }

  @override
  void dispose() {
    swimmerNameFocusNode?.dispose();
    swimmerNameTextController?.dispose();

    emailAddressFocusNode?.dispose();
    emailAddressTextController?.dispose();

    passwordFocusNode?.dispose();
    passwordTextController?.dispose();
  }
}
