import '/backend/backend.dart';
import '/components/admin_activity_creator/admin_activity_creator_widget.dart';
import '/flutter_flow/flutter_flow_choice_chips.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import 'admin_dashboard_widget.dart' show AdminDashboardWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AdminDashboardModel extends FlutterFlowModel<AdminDashboardWidget> {
  ///  Local state fields for this component.

  String activeGroup = 'junior_1';

  ///  State fields for stateful widgets in this component.

  // State field(s) for SwimGroupSelector widget.
  FormFieldController<List<String>>? swimGroupSelectorValueController;
  String? get swimGroupSelectorValue =>
      swimGroupSelectorValueController?.value?.firstOrNull;
  set swimGroupSelectorValue(String? val) =>
      swimGroupSelectorValueController?.value = val != null ? [val] : [];

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
