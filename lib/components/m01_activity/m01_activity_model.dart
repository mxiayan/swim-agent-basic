import '/backend/backend.dart';
import '/components/m01_activity_card/m01_activity_card_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_choice_chips.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:math';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import 'm01_activity_widget.dart' show M01ActivityWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class M01ActivityModel extends FlutterFlowModel<M01ActivityWidget> {
  ///  Local state fields for this component.

  String currentGroup = 'junior_1';

  ///  State fields for stateful widgets in this component.

  // State field(s) for chooseGroup widget.
  FormFieldController<List<String>>? chooseGroupValueController;
  String? get chooseGroupValue =>
      chooseGroupValueController?.value?.firstOrNull;
  set chooseGroupValue(String? val) =>
      chooseGroupValueController?.value = val != null ? [val] : [];

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
