import '/components/accommodations/accommodations_widget.dart';
import '/components/activities/activities_widget.dart';
import '/components/admin_dashboard/admin_dashboard_widget.dart';
import '/components/job/job_widget.dart';
import '/components/nav_item/nav_item_widget.dart';
import '/components/s_a_schedule/s_a_schedule_widget.dart';
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

  // Model for NavItem component.
  late NavItemModel navItemModel1;
  // Model for NavItem component.
  late NavItemModel navItemModel2;
  // Model for NavItem component.
  late NavItemModel navItemModel3;
  // Model for NavItem component.
  late NavItemModel navItemModel4;
  // Model for NavItem component.
  late NavItemModel navItemModel5;
  // Model for SASchedule component.
  late SAScheduleModel sAScheduleModel;
  // Model for Accommodations component.
  late AccommodationsModel accommodationsModel;
  // Model for Activities component.
  late ActivitiesModel activitiesModel;
  // Model for Job component.
  late JobModel jobModel;
  // Model for AdminDashboard component.
  late AdminDashboardModel adminDashboardModel;

  @override
  void initState(BuildContext context) {
    navItemModel1 = createModel(context, () => NavItemModel());
    navItemModel2 = createModel(context, () => NavItemModel());
    navItemModel3 = createModel(context, () => NavItemModel());
    navItemModel4 = createModel(context, () => NavItemModel());
    navItemModel5 = createModel(context, () => NavItemModel());
    sAScheduleModel = createModel(context, () => SAScheduleModel());
    accommodationsModel = createModel(context, () => AccommodationsModel());
    activitiesModel = createModel(context, () => ActivitiesModel());
    jobModel = createModel(context, () => JobModel());
    adminDashboardModel = createModel(context, () => AdminDashboardModel());
  }

  @override
  void dispose() {
    navItemModel1.dispose();
    navItemModel2.dispose();
    navItemModel3.dispose();
    navItemModel4.dispose();
    navItemModel5.dispose();
    sAScheduleModel.dispose();
    accommodationsModel.dispose();
    activitiesModel.dispose();
    jobModel.dispose();
    adminDashboardModel.dispose();
  }
}
