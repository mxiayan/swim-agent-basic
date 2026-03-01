import '/backend/backend.dart';
import '/components/m02_meet_card/m02_meet_card_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'm02_meet_model.dart';
export 'm02_meet_model.dart';

class M02MeetWidget extends StatefulWidget {
  const M02MeetWidget({super.key});

  @override
  State<M02MeetWidget> createState() => _M02MeetWidgetState();
}

class _M02MeetWidgetState extends State<M02MeetWidget>
    with TickerProviderStateMixin {
  late M02MeetModel _model;

  final animationsMap = <String, AnimationInfo>{};

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => M02MeetModel());

    animationsMap.addAll({
      'm02MeetCardOnPageLoadAnimation': AnimationInfo(
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

    return StreamBuilder<List<MonitoredMeetsRecord>>(
      stream: queryMonitoredMeetsRecord(
        queryBuilder: (monitoredMeetsRecord) =>
            monitoredMeetsRecord.orderBy('start_date'),
      ),
      builder: (context, snapshot) {
        // Customize what your widget looks like when it's loading.
        if (!snapshot.hasData) {
          return Center(
            child: SizedBox(
              width: 50.0,
              height: 50.0,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  FlutterFlowTheme.of(context).primary,
                ),
              ),
            ),
          );
        }
        List<MonitoredMeetsRecord> containerMonitoredMeetsRecordList =
            snapshot.data!;

        return Container(
          width: MediaQuery.sizeOf(context).width * 1.0,
          height: MediaQuery.sizeOf(context).height * 9.0,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primaryBackground,
          ),
          child: Builder(
            builder: (context) {
              final meets = containerMonitoredMeetsRecordList.toList();

              return ListView.builder(
                padding: EdgeInsets.zero,
                scrollDirection: Axis.vertical,
                itemCount: meets.length,
                itemBuilder: (context, meetsIndex) {
                  final meetsItem = meets[meetsIndex];
                  return Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 30.0, 0.0, 0.0),
                    child: InkWell(
                      splashColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () async {
                        if (FFAppState().showDetails1 == true) {
                          FFAppState().showDetails1 = false;
                          FFAppState().update(() {});
                        } else {
                          FFAppState().showDetails1 = true;
                          FFAppState().update(() {});
                        }
                      },
                      child: M02MeetCardWidget(
                        key: Key('Keyw9w_${meetsIndex}_of_${meets.length}'),
                        title: 'Kayaking',
                        subtitle: 'Fontaine de Vaucluse',
                        description:
                            'Explore the crystal clear waters of the Fontaine de Vaucluse. Paddle down the Sorgue River and discover hidden grottoes and cascading waterfalls with breathtaking views of the surrounding hills.',
                        expanded: FFAppState().showDetails1,
                        image:
                            'https://storage.googleapis.com/turo-deals-1599612493143.appspot.com/demo_images/kayaking.png',
                        favorite: FFAppState().favorites.elementAtOrNull(0),
                        index: 0,
                        meetDoc: meetsItem,
                      ),
                    ).animateOnPageLoad(
                        animationsMap['m02MeetCardOnPageLoadAnimation']!),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
