import '/components/activity_detail_pop_up_sign_up_u_r_l/activity_detail_pop_up_sign_up_u_r_l_widget.dart';
import '/components/activity_details_fields/activity_details_fields_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'activity_details_popup_widget.dart' show ActivityDetailsPopupWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ActivityDetailsPopupModel
    extends FlutterFlowModel<ActivityDetailsPopupWidget> {
  ///  State fields for stateful widgets in this component.

  // Model for ActivityDetailsFields component.
  late ActivityDetailsFieldsModel activityDetailsFieldsModel1;
  // Model for ActivityDetailsFields component.
  late ActivityDetailsFieldsModel activityDetailsFieldsModel2;
  // Model for ActivityDetailPopUpSignUpURL component.
  late ActivityDetailPopUpSignUpURLModel activityDetailPopUpSignUpURLModel;
  // Model for ActivityDetailsFields component.
  late ActivityDetailsFieldsModel activityDetailsFieldsModel3;
  // Model for ActivityDetailsFields component.
  late ActivityDetailsFieldsModel activityDetailsFieldsModel4;

  @override
  void initState(BuildContext context) {
    activityDetailsFieldsModel1 =
        createModel(context, () => ActivityDetailsFieldsModel());
    activityDetailsFieldsModel2 =
        createModel(context, () => ActivityDetailsFieldsModel());
    activityDetailPopUpSignUpURLModel =
        createModel(context, () => ActivityDetailPopUpSignUpURLModel());
    activityDetailsFieldsModel3 =
        createModel(context, () => ActivityDetailsFieldsModel());
    activityDetailsFieldsModel4 =
        createModel(context, () => ActivityDetailsFieldsModel());
  }

  @override
  void dispose() {
    activityDetailsFieldsModel1.dispose();
    activityDetailsFieldsModel2.dispose();
    activityDetailPopUpSignUpURLModel.dispose();
    activityDetailsFieldsModel3.dispose();
    activityDetailsFieldsModel4.dispose();
  }
}
