import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:math';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'm04_swimmer_widget.dart' show M04SwimmerWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class M04SwimmerModel extends FlutterFlowModel<M04SwimmerWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for zone_selector widget.
  String? zoneSelectorValue;
  FormFieldController<String>? zoneSelectorValueController;
  // State field(s) for group_selector widget.
  String? groupSelectorValue;
  FormFieldController<String>? groupSelectorValueController;
  // State field(s) for name_editor widget.
  FocusNode? nameEditorFocusNode;
  TextEditingController? nameEditorTextController;
  String? Function(BuildContext, String?)? nameEditorTextControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    nameEditorFocusNode?.dispose();
    nameEditorTextController?.dispose();
  }
}
