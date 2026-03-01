import '/backend/backend.dart';
import '/components/m05_activity_dashboard_new_activity_creator/m05_activity_dashboard_new_activity_creator_widget.dart';
import '/flutter_flow/flutter_flow_choice_chips.dart';
import '/flutter_flow/flutter_flow_data_table.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import 'm05_activity_dashboard_widget.dart' show M05ActivityDashboardWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class M05ActivityDashboardModel
    extends FlutterFlowModel<M05ActivityDashboardWidget> {
  ///  Local state fields for this component.

  String activeGroup = 'junior_1';

  List<ActivitiesRecord> currentActivities = [];
  void addToCurrentActivities(ActivitiesRecord item) =>
      currentActivities.add(item);
  void removeFromCurrentActivities(ActivitiesRecord item) =>
      currentActivities.remove(item);
  void removeAtIndexFromCurrentActivities(int index) =>
      currentActivities.removeAt(index);
  void insertAtIndexInCurrentActivities(int index, ActivitiesRecord item) =>
      currentActivities.insert(index, item);
  void updateCurrentActivitiesAtIndex(
          int index, Function(ActivitiesRecord) updateFn) =>
      currentActivities[index] = updateFn(currentActivities[index]);

  List<ActivitiesRecord> filteredActivities = [];
  void addToFilteredActivities(ActivitiesRecord item) =>
      filteredActivities.add(item);
  void removeFromFilteredActivities(ActivitiesRecord item) =>
      filteredActivities.remove(item);
  void removeAtIndexFromFilteredActivities(int index) =>
      filteredActivities.removeAt(index);
  void insertAtIndexInFilteredActivities(int index, ActivitiesRecord item) =>
      filteredActivities.insert(index, item);
  void updateFilteredActivitiesAtIndex(
          int index, Function(ActivitiesRecord) updateFn) =>
      filteredActivities[index] = updateFn(filteredActivities[index]);

  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Firestore Query - Query a collection] action in m05_activity_dashboard widget.
  List<ActivitiesRecord>? componentLevelQueryActivies;
  // State field(s) for SwimGroupSelector widget.
  FormFieldController<List<String>>? swimGroupSelectorValueController;
  List<String>? get swimGroupSelectorValues =>
      swimGroupSelectorValueController?.value;
  set swimGroupSelectorValues(List<String>? val) =>
      swimGroupSelectorValueController?.value = val;
  // State field(s) for PaginatedDataTable widget.
  final paginatedDataTableController =
      FlutterFlowDataTableController<ActivitiesRecord>();

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    paginatedDataTableController.dispose();
  }
}
