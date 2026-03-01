import '/components/m01_activity_card_detail_popup_details_field/m01_activity_card_detail_popup_details_field_widget.dart';
import '/components/m01_activity_card_detail_popup_signup_url/m01_activity_card_detail_popup_signup_url_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'm01_activity_card_detail_popup_widget.dart'
    show M01ActivityCardDetailPopupWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class M01ActivityCardDetailPopupModel
    extends FlutterFlowModel<M01ActivityCardDetailPopupWidget> {
  ///  State fields for stateful widgets in this component.

  // Model for m01_activity_card_detail_popup_details_field component.
  late M01ActivityCardDetailPopupDetailsFieldModel
      m01ActivityCardDetailPopupDetailsFieldModel1;
  // Model for m01_activity_card_detail_popup_details_field component.
  late M01ActivityCardDetailPopupDetailsFieldModel
      m01ActivityCardDetailPopupDetailsFieldModel2;
  // Model for m01_activity_card_detail_popup_signup_url component.
  late M01ActivityCardDetailPopupSignupUrlModel
      m01ActivityCardDetailPopupSignupUrlModel;
  // Model for m01_activity_card_detail_popup_details_field component.
  late M01ActivityCardDetailPopupDetailsFieldModel
      m01ActivityCardDetailPopupDetailsFieldModel3;
  // Model for m01_activity_card_detail_popup_details_field component.
  late M01ActivityCardDetailPopupDetailsFieldModel
      m01ActivityCardDetailPopupDetailsFieldModel4;

  @override
  void initState(BuildContext context) {
    m01ActivityCardDetailPopupDetailsFieldModel1 = createModel(
        context, () => M01ActivityCardDetailPopupDetailsFieldModel());
    m01ActivityCardDetailPopupDetailsFieldModel2 = createModel(
        context, () => M01ActivityCardDetailPopupDetailsFieldModel());
    m01ActivityCardDetailPopupSignupUrlModel =
        createModel(context, () => M01ActivityCardDetailPopupSignupUrlModel());
    m01ActivityCardDetailPopupDetailsFieldModel3 = createModel(
        context, () => M01ActivityCardDetailPopupDetailsFieldModel());
    m01ActivityCardDetailPopupDetailsFieldModel4 = createModel(
        context, () => M01ActivityCardDetailPopupDetailsFieldModel());
  }

  @override
  void dispose() {
    m01ActivityCardDetailPopupDetailsFieldModel1.dispose();
    m01ActivityCardDetailPopupDetailsFieldModel2.dispose();
    m01ActivityCardDetailPopupSignupUrlModel.dispose();
    m01ActivityCardDetailPopupDetailsFieldModel3.dispose();
    m01ActivityCardDetailPopupDetailsFieldModel4.dispose();
  }
}
