import '/auth/firebase_auth/auth_util.dart';
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
import 'm05_activity_dashboard_new_activity_creator_widget.dart'
    show M05ActivityDashboardNewActivityCreatorWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class M05ActivityDashboardNewActivityCreatorModel
    extends FlutterFlowModel<M05ActivityDashboardNewActivityCreatorWidget> {
  ///  Local state fields for this component.

  DateTime? tmpStartTime;

  DateTime? tmpEndTime;

  DateTime? tmpDeadline;

  ///  State fields for stateful widgets in this component.

  // State field(s) for ActivityTypeDropDown widget.
  String? activityTypeDropDownValue;
  FormFieldController<String>? activityTypeDropDownValueController;
  // State field(s) for meetName widget.
  FocusNode? meetNameFocusNode;
  TextEditingController? meetNameTextController;
  String? Function(BuildContext, String?)? meetNameTextControllerValidator;
  // State field(s) for juniorGroupChoiceChips widget.
  FormFieldController<List<String>>? juniorGroupChoiceChipsValueController;
  List<String>? get juniorGroupChoiceChipsValues =>
      juniorGroupChoiceChipsValueController?.value;
  set juniorGroupChoiceChipsValues(List<String>? val) =>
      juniorGroupChoiceChipsValueController?.value = val;
  // State field(s) for seniorGroupChoiceChips widget.
  FormFieldController<List<String>>? seniorGroupChoiceChipsValueController;
  List<String>? get seniorGroupChoiceChipsValues =>
      seniorGroupChoiceChipsValueController?.value;
  set seniorGroupChoiceChipsValues(List<String>? val) =>
      seniorGroupChoiceChipsValueController?.value = val;
  // State field(s) for Location widget.
  FocusNode? locationFocusNode;
  TextEditingController? locationTextController;
  String? Function(BuildContext, String?)? locationTextControllerValidator;
  DateTime? datePicked1;
  DateTime? datePicked2;
  // State field(s) for singupURL widget.
  FocusNode? singupURLFocusNode;
  TextEditingController? singupURLTextController;
  String? Function(BuildContext, String?)? singupURLTextControllerValidator;
  DateTime? datePicked3;
  // State field(s) for description widget.
  FocusNode? descriptionFocusNode;
  TextEditingController? descriptionTextController;
  String? Function(BuildContext, String?)? descriptionTextControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    meetNameFocusNode?.dispose();
    meetNameTextController?.dispose();

    locationFocusNode?.dispose();
    locationTextController?.dispose();

    singupURLFocusNode?.dispose();
    singupURLTextController?.dispose();

    descriptionFocusNode?.dispose();
    descriptionTextController?.dispose();
  }
}
