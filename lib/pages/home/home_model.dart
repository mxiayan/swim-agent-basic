import '/components/m01_activity/m01_activity_widget.dart';
import '/components/m02_meet/m02_meet_widget.dart';
import '/components/m03_job/m03_job_widget.dart';
import '/components/nav_item/nav_item_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'home_widget.dart' show HomeWidget;
import 'package:flutter/material.dart';

class HomeModel extends FlutterFlowModel<HomeWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for Activities.
  late NavItemModel activitiesModel;
  // Model for Meets.
  late NavItemModel meetsModel;
  // Model for Jobs.
  late NavItemModel jobsModel;
  // Model for m01_activity component.
  late M01ActivityModel m01ActivityModel;
  // Model for m02_meet component.
  late M02MeetModel m02MeetModel;
  // Model for m03_job component.
  late M03JobModel m03JobModel;

  @override
  void initState(BuildContext context) {
    activitiesModel = createModel(context, () => NavItemModel());
    meetsModel = createModel(context, () => NavItemModel());
    jobsModel = createModel(context, () => NavItemModel());
    m01ActivityModel = createModel(context, () => M01ActivityModel());
    m02MeetModel = createModel(context, () => M02MeetModel());
    m03JobModel = createModel(context, () => M03JobModel());
  }

  @override
  void dispose() {
    activitiesModel.dispose();
    meetsModel.dispose();
    jobsModel.dispose();
    m01ActivityModel.dispose();
    m02MeetModel.dispose();
    m03JobModel.dispose();
  }
}
