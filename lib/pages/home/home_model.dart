import '/components/m01_activity/m01_activity_widget.dart';
import '/components/m02_meet/m02_meet_widget.dart';
import '/components/m03_job/m03_job_widget.dart';
import '/components/m04_swimmer/m04_swimmer_widget.dart';
import '/components/m05_activity_dashboard/m05_activity_dashboard_widget.dart';
import '/components/nav_item/nav_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'home_widget.dart' show HomeWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HomeModel extends FlutterFlowModel<HomeWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for Activities.
  late NavItemModel activitiesModel;
  // Model for Meets.
  late NavItemModel meetsModel;
  // Model for Jobs.
  late NavItemModel jobsModel;
  // Model for Swimmer.
  late NavItemModel swimmerModel;
  // Model for Admin.
  late NavItemModel adminModel;
  // Model for m01_activity component.
  late M01ActivityModel m01ActivityModel;
  // Model for m02_meet component.
  late M02MeetModel m02MeetModel;
  // Model for m03_job component.
  late M03JobModel m03JobModel;
  // Model for m04_swimmer component.
  late M04SwimmerModel m04SwimmerModel;
  // Model for m05_activity_dashboard component.
  late M05ActivityDashboardModel m05ActivityDashboardModel;

  @override
  void initState(BuildContext context) {
    activitiesModel = createModel(context, () => NavItemModel());
    meetsModel = createModel(context, () => NavItemModel());
    jobsModel = createModel(context, () => NavItemModel());
    swimmerModel = createModel(context, () => NavItemModel());
    adminModel = createModel(context, () => NavItemModel());
    m01ActivityModel = createModel(context, () => M01ActivityModel());
    m02MeetModel = createModel(context, () => M02MeetModel());
    m03JobModel = createModel(context, () => M03JobModel());
    m04SwimmerModel = createModel(context, () => M04SwimmerModel());
    m05ActivityDashboardModel =
        createModel(context, () => M05ActivityDashboardModel());
  }

  @override
  void dispose() {
    activitiesModel.dispose();
    meetsModel.dispose();
    jobsModel.dispose();
    swimmerModel.dispose();
    adminModel.dispose();
    m01ActivityModel.dispose();
    m02MeetModel.dispose();
    m03JobModel.dispose();
    m04SwimmerModel.dispose();
    m05ActivityDashboardModel.dispose();
  }
}
