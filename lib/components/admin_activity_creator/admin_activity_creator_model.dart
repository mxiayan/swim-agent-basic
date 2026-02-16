import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_choice_chips.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:math';
import 'dart:ui';
import 'admin_activity_creator_widget.dart' show AdminActivityCreatorWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AdminActivityCreatorModel
    extends FlutterFlowModel<AdminActivityCreatorWidget> {
  ///  Local state fields for this component.

  DateTime? tmpStartTime;

  DateTime? tmpEndTime;

  ///  State fields for stateful widgets in this component.

  // State field(s) for ChoiceChips widget.
  FormFieldController<List<String>>? choiceChipsValueController;
  List<String>? get choiceChipsValues => choiceChipsValueController?.value;
  set choiceChipsValues(List<String>? val) =>
      choiceChipsValueController?.value = val;
  // State field(s) for ActivityTypeDropDown widget.
  String? activityTypeDropDownValue;
  FormFieldController<String>? activityTypeDropDownValueController;
  // State field(s) for Location widget.
  FocusNode? locationFocusNode1;
  TextEditingController? locationTextController1;
  String? Function(BuildContext, String?)? locationTextController1Validator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController2;
  String? Function(BuildContext, String?)? textController2Validator;
  // State field(s) for Location widget.
  FocusNode? locationFocusNode2;
  TextEditingController? locationTextController2;
  String? Function(BuildContext, String?)? locationTextController2Validator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    locationFocusNode1?.dispose();
    locationTextController1?.dispose();

    textFieldFocusNode?.dispose();
    textController2?.dispose();

    locationFocusNode2?.dispose();
    locationTextController2?.dispose();
  }
}
