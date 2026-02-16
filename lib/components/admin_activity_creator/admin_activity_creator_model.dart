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
import '/custom_code/actions/index.dart' as actions;
import 'admin_activity_creator_widget.dart' show AdminActivityCreatorWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  // State field(s) for ActivityTypeDropDown widget.
  String? activityTypeDropDownValue;
  FormFieldController<String>? activityTypeDropDownValueController;
  // State field(s) for ChoiceChips widget.
  FormFieldController<List<String>>? choiceChipsValueController;
  List<String>? get choiceChipsValues => choiceChipsValueController?.value;
  set choiceChipsValues(List<String>? val) =>
      choiceChipsValueController?.value = val;
  // State field(s) for Location widget.
  FocusNode? locationFocusNode;
  TextEditingController? locationTextController;
  String? Function(BuildContext, String?)? locationTextControllerValidator;
  DateTime? datePicked1;
  DateTime? datePicked2;
  // State field(s) for si widget.
  FocusNode? siFocusNode;
  TextEditingController? siTextController;
  String? Function(BuildContext, String?)? siTextControllerValidator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController3;
  String? Function(BuildContext, String?)? textController3Validator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    locationFocusNode?.dispose();
    locationTextController?.dispose();

    siFocusNode?.dispose();
    siTextController?.dispose();

    textFieldFocusNode?.dispose();
    textController3?.dispose();
  }
}
