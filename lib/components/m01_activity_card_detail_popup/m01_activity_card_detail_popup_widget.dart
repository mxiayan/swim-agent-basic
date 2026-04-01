import '/components/m01_activity_card_detail_popup_details_field/m01_activity_card_detail_popup_details_field_widget.dart';
import '/components/m01_activity_card_detail_popup_signup_url/m01_activity_card_detail_popup_signup_url_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'm01_activity_card_detail_popup_model.dart';
export 'm01_activity_card_detail_popup_model.dart';

class M01ActivityCardDetailPopupWidget extends StatefulWidget {
  const M01ActivityCardDetailPopupWidget({
    super.key,
    this.location,
    this.startTime,
    this.endTime,
    this.signUpUrl,
  });

  final String? location;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? signUpUrl;

  @override
  State<M01ActivityCardDetailPopupWidget> createState() =>
      _M01ActivityCardDetailPopupWidgetState();
}

class _M01ActivityCardDetailPopupWidgetState
    extends State<M01ActivityCardDetailPopupWidget> {
  late M01ActivityCardDetailPopupModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => M01ActivityCardDetailPopupModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: MediaQuery.sizeOf(context).width * 0.9,
          height: MediaQuery.sizeOf(context).height * 0.5,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10.0),
              topRight: Radius.circular(10.0),
            ),
            border: Border.all(
              color: FlutterFlowTheme.of(context).tertiary,
              width: 10.0,
            ),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Stack(
                  children: [
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 30.0),
                      child: Container(
                        width: MediaQuery.sizeOf(context).width * 1.0,
                        height: 138.6,
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          image: DecorationImage(
                            fit: BoxFit.cover,
                            image: Image.asset(
                              'assets/images/munich.png',
                            ).image,
                          ),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 30.0),
                      child: Container(
                        width: MediaQuery.sizeOf(context).width * 1.0,
                        height: 138.6,
                        decoration: BoxDecoration(
                          color: Color(0x89DA4167),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        'LOCATION',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.sora(
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context).lightGrey,
                              fontSize: 12.0,
                              letterSpacing: 0.0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        widget!.location!,
                        style:
                            FlutterFlowTheme.of(context).displaySmall.override(
                                  font: GoogleFonts.sora(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .displaySmall
                                        .fontStyle,
                                  ),
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .displaySmall
                                      .fontStyle,
                                ),
                        overflow: TextOverflow.visible,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [],
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 0.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: wrapWithModel(
                          model: _model
                              .m01ActivityCardDetailPopupDetailsFieldModel1,
                          updateCallback: () => safeSetState(() {}),
                          child: M01ActivityCardDetailPopupDetailsFieldWidget(
                            title: 'DATE',
                            value: valueOrDefault<String>(
                              dateTimeFormat("MMMEd", widget!.startTime),
                              '[DATE]',
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: wrapWithModel(
                          model: _model
                              .m01ActivityCardDetailPopupDetailsFieldModel2,
                          updateCallback: () => safeSetState(() {}),
                          child: M01ActivityCardDetailPopupDetailsFieldWidget(
                            title: 'TIME',
                            value: valueOrDefault<String>(
                              dateTimeFormat("jm", widget!.startTime),
                              '[TIME]',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 0.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        child: wrapWithModel(
                          model:
                              _model.m01ActivityCardDetailPopupSignupUrlModel,
                          updateCallback: () => safeSetState(() {}),
                          child: M01ActivityCardDetailPopupSignupUrlWidget(
                            title: 'SIGN UP URL',
                            singupURL: widget!.signUpUrl,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 0.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: wrapWithModel(
                          model: _model
                              .m01ActivityCardDetailPopupDetailsFieldModel3,
                          updateCallback: () => safeSetState(() {}),
                          child: M01ActivityCardDetailPopupDetailsFieldWidget(
                            title: 'WARM UP TIME',
                            value: '7:30 AM',
                          ),
                        ),
                      ),
                      Expanded(
                        child: wrapWithModel(
                          model: _model
                              .m01ActivityCardDetailPopupDetailsFieldModel4,
                          updateCallback: () => safeSetState(() {}),
                          child: M01ActivityCardDetailPopupDetailsFieldWidget(
                            title: 'SEAT',
                            value: '2A',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
