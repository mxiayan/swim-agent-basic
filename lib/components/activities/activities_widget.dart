import '/components/activity_card/activity_card_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'activities_model.dart';
export 'activities_model.dart';

class ActivitiesWidget extends StatefulWidget {
  const ActivitiesWidget({super.key});

  @override
  State<ActivitiesWidget> createState() => _ActivitiesWidgetState();
}

class _ActivitiesWidgetState extends State<ActivitiesWidget>
    with TickerProviderStateMixin {
  late ActivitiesModel _model;

  final animationsMap = <String, AnimationInfo>{};

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ActivitiesModel());

    animationsMap.addAll({
      'activityCardOnPageLoadAnimation1': AnimationInfo(
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
      'activityCardOnPageLoadAnimation2': AnimationInfo(
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
      'activityCardOnPageLoadAnimation3': AnimationInfo(
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
      'activityCardOnPageLoadAnimation4': AnimationInfo(
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
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 30.0, 0.0, 0.0),
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
                child: wrapWithModel(
                  model: _model.activityCardModel1,
                  updateCallback: () => safeSetState(() {}),
                  child: ActivityCardWidget(
                    title: 'Kayaking',
                    subtitle: 'Fontaine de Vaucluse',
                    description:
                        'Explore the crystal clear waters of the Fontaine de Vaucluse. Paddle down the Sorgue River and discover hidden grottoes and cascading waterfalls with breathtaking views of the surrounding hills.',
                    expanded: FFAppState().showDetails1,
                    image:
                        'https://storage.googleapis.com/turo-deals-1599612493143.appspot.com/demo_images/kayaking.png',
                    favorite: FFAppState().favorites.elementAtOrNull(0),
                    index: 0,
                  ),
                ),
              ).animateOnPageLoad(
                  animationsMap['activityCardOnPageLoadAnimation1']!),
            ),
            InkWell(
              splashColor: Colors.transparent,
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () async {
                if (FFAppState().showDetails2 == true) {
                  FFAppState().showDetails2 = false;
                  FFAppState().update(() {});
                } else {
                  FFAppState().showDetails2 = true;
                  FFAppState().update(() {});
                }
              },
              child: wrapWithModel(
                model: _model.activityCardModel2,
                updateCallback: () => safeSetState(() {}),
                child: ActivityCardWidget(
                  title: 'Vaucluse Spring',
                  subtitle: 'Hiking',
                  description:
                      'This scenic hike takes you through the lush greenery of the Vaucluse Regional Nature Reserve, leading you to the stunning Vaucluse Spring, the largest spring in France. Along the way, you\'ll spot a variety of wildlife.',
                  expanded: FFAppState().showDetails2,
                  image:
                      'https://storage.googleapis.com/turo-deals-1599612493143.appspot.com/demo_images/spring.png',
                  favorite: FFAppState().favorites.elementAtOrNull(1),
                  index: 1,
                ),
              ),
            ).animateOnPageLoad(
                animationsMap['activityCardOnPageLoadAnimation2']!),
            InkWell(
              splashColor: Colors.transparent,
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () async {
                if (FFAppState().showDetails3 == true) {
                  FFAppState().showDetails3 = false;
                  FFAppState().update(() {});
                } else {
                  FFAppState().showDetails3 = true;
                  FFAppState().update(() {});
                }
              },
              child: wrapWithModel(
                model: _model.activityCardModel3,
                updateCallback: () => safeSetState(() {}),
                child: ActivityCardWidget(
                  title: 'Domaine Tourbillon',
                  subtitle: 'Winery',
                  description:
                      'Indulge in the rich flavors of Provence with a wine tasting experience at Châteauneuf-du-Pape, one of the most famous wine-producing regions in France. Famous for its bold and full-bodied red wines',
                  expanded: FFAppState().showDetails3,
                  image:
                      'https://storage.googleapis.com/turo-deals-1599612493143.appspot.com/demo_images/vineyard.png',
                  favorite: FFAppState().favorites.elementAtOrNull(2),
                  index: 2,
                ),
              ),
            ).animateOnPageLoad(
                animationsMap['activityCardOnPageLoadAnimation3']!),
            InkWell(
              splashColor: Colors.transparent,
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () async {
                if (FFAppState().showDetails4 == true) {
                  FFAppState().showDetails4 = false;
                  FFAppState().update(() {});
                } else {
                  FFAppState().showDetails4 = true;
                  FFAppState().update(() {});
                }
              },
              child: wrapWithModel(
                model: _model.activityCardModel4,
                updateCallback: () => safeSetState(() {}),
                child: ActivityCardWidget(
                  title: 'Gordes',
                  subtitle: 'Hilltop Village',
                  description:
                      ' Known for its stunning lavender fields, the village offers breathtaking panoramic views of the surrounding countryside. The village is a perfect blend of traditional Provencal architecture and natural beauty.',
                  expanded: FFAppState().showDetails4,
                  image:
                      'https://storage.googleapis.com/turo-deals-1599612493143.appspot.com/demo_images/hilltop.png',
                  favorite: FFAppState().favorites.elementAtOrNull(3),
                  index: 3,
                ),
              ),
            ).animateOnPageLoad(
                animationsMap['activityCardOnPageLoadAnimation4']!),
          ],
        ),
      ),
    );
  }
}
