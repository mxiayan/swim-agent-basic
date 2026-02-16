import '/components/job_card/job_card_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'job_model.dart';
export 'job_model.dart';

class JobWidget extends StatefulWidget {
  const JobWidget({super.key});

  @override
  State<JobWidget> createState() => _JobWidgetState();
}

class _JobWidgetState extends State<JobWidget> with TickerProviderStateMixin {
  late JobModel _model;

  final animationsMap = <String, AnimationInfo>{};

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => JobModel());

    animationsMap.addAll({
      'containerOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          SaturateEffect(
            curve: Curves.easeIn,
            delay: 900.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
      'jobCardOnPageLoadAnimation1': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          VisibilityEffect(duration: 1.ms),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 300.0.ms,
            begin: Offset(0.0, 75.0),
            end: Offset(0.0, 0.0),
          ),
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 300.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
          ScaleEffect(
            curve: Curves.easeInOut,
            delay: 150.0.ms,
            duration: 300.0.ms,
            begin: Offset(0.8, 1.0),
            end: Offset(1.0, 1.0),
          ),
        ],
      ),
      'jobCardOnPageLoadAnimation2': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          VisibilityEffect(duration: 200.ms),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 200.0.ms,
            duration: 300.0.ms,
            begin: Offset(0.0, 75.0),
            end: Offset(0.0, 0.0),
          ),
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 200.0.ms,
            duration: 300.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
          ScaleEffect(
            curve: Curves.easeInOut,
            delay: 350.0.ms,
            duration: 300.0.ms,
            begin: Offset(0.8, 1.0),
            end: Offset(1.0, 1.0),
          ),
        ],
      ),
      'jobCardOnPageLoadAnimation3': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          VisibilityEffect(duration: 400.ms),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 400.0.ms,
            duration: 300.0.ms,
            begin: Offset(0.0, 75.0),
            end: Offset(0.0, 0.0),
          ),
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 400.0.ms,
            duration: 300.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
          ScaleEffect(
            curve: Curves.easeInOut,
            delay: 550.0.ms,
            duration: 300.0.ms,
            begin: Offset(0.8, 1.0),
            end: Offset(1.0, 1.0),
          ),
        ],
      ),
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Container(
      width: MediaQuery.sizeOf(context).width * 1.0,
      height: MediaQuery.sizeOf(context).height * 1.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(30.0, 30.0, 30.0, 0.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30.0),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: FFAppState().cookSelected.elementAtOrNull(0)! &&
                          FFAppState().cookSelected.elementAtOrNull(1)! &&
                          FFAppState().cookSelected.elementAtOrNull(2)!
                      ? 0.0
                      : 65.0,
                  constraints: BoxConstraints(
                    maxWidth: 450.0,
                  ),
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).cerise,
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(30.0, 0.0, 30.0, 0.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning_rounded,
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          size: 30.0,
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                15.0, 0.0, 0.0, 0.0),
                            child: AutoSizeText(
                              'Urgent: Timers needed for Saturday!',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.sora(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animateOnPageLoad(
                  animationsMap['containerOnPageLoadAnimation']!),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(30.0, 0.0, 30.0, 0.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30.0),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: MediaQuery.sizeOf(context).width * 1.0,
                  height: FFAppState().cookSelected.elementAtOrNull(0)! &&
                          FFAppState().cookSelected.elementAtOrNull(1)! &&
                          FFAppState().cookSelected.elementAtOrNull(2)!
                      ? 0.0
                      : 30.0,
                  constraints: BoxConstraints(
                    maxWidth: 450.0,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(30.0, 0.0, 30.0, 0.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    'HOME-MADE MEALS',
                    style: FlutterFlowTheme.of(context).titleSmall.override(
                          font: GoogleFonts.sora(
                            fontWeight: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontStyle,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(context)
                              .titleSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).titleSmall.fontStyle,
                        ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 0.0),
              child: wrapWithModel(
                model: _model.jobCardModel1,
                updateCallback: () => safeSetState(() {}),
                child: JobCardWidget(
                  jobTitle: 'Lane Timer',
                  description:
                      'with chicken braised in red wine, bacon, mushrooms, and onions',
                  signedUp: false,
                  image:
                      'https://storage.googleapis.com/turo-deals-1599612493143.appspot.com/demo_images/coq-au-vin.png',
                  volunteerName: FFAppState().cooks.elementAtOrNull(0),
                  index: 0,
                ),
              ).animateOnPageLoad(
                  animationsMap['jobCardOnPageLoadAnimation1']!),
            ),
            wrapWithModel(
              model: _model.jobCardModel2,
              updateCallback: () => safeSetState(() {}),
              child: JobCardWidget(
                jobTitle: 'Boeuf Bourguignon',
                description: 'with beef, bacon, carrots, onions, and mushrooms',
                signedUp: FFAppState().cookSelected.elementAtOrNull(1),
                image:
                    'https://storage.googleapis.com/turo-deals-1599612493143.appspot.com/demo_images/boeuf-bourguignon.png',
                volunteerName: FFAppState().cooks.elementAtOrNull(1),
                index: 1,
              ),
            ).animateOnPageLoad(animationsMap['jobCardOnPageLoadAnimation2']!),
            wrapWithModel(
              model: _model.jobCardModel3,
              updateCallback: () => safeSetState(() {}),
              child: JobCardWidget(
                jobTitle: 'Ratatouille',
                description:
                    'with eggplant, zucchini, bell peppers, and tomatoes',
                signedUp: FFAppState().cookSelected.elementAtOrNull(2),
                image:
                    'https://storage.googleapis.com/turo-deals-1599612493143.appspot.com/demo_images/ratatouille.png',
                volunteerName: FFAppState().cooks.elementAtOrNull(2),
                index: 2,
              ),
            ).animateOnPageLoad(animationsMap['jobCardOnPageLoadAnimation3']!),
          ],
        ),
      ),
    );
  }
}
