import '/backend/backend.dart';
import '/components/m01_activity_card/m01_activity_card_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'm01_activity_model.dart';
export 'm01_activity_model.dart';

class M01ActivityWidget extends StatefulWidget {
  const M01ActivityWidget({super.key});

  @override
  State<M01ActivityWidget> createState() => _M01ActivityWidgetState();
}

class _M01ActivityWidgetState extends State<M01ActivityWidget>
    with TickerProviderStateMixin {
  late M01ActivityModel _model;

  final animationsMap = <String, AnimationInfo>{};

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => M01ActivityModel());

    animationsMap.addAll({
      'containerOnPageLoadAnimation': AnimationInfo(
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
      'm01ActivityCardOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 550.0.ms,
            duration: 300.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 550.0.ms,
            duration: 300.0.ms,
            begin: Offset(0.0, -20.0),
            end: Offset(0.0, 0.0),
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
    // Fills the home Stack slot so ListView gets a bounded height (avoids
    // RenderFlex overflow from Columns with mainAxisSize.max inside scroll).
    return SizedBox.expand(
      child: StreamBuilder<List<ActivitiesRecord>>(
        stream: queryActivitiesRecord(
          queryBuilder: (activitiesRecord) => activitiesRecord
              .where(
                'team_id',
                isEqualTo: 'oapb',
              )
              .orderBy('start_time', descending: true),
        ),
        builder: (context, snapshot) {
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

          final containerActivitiesRecordList = snapshot.data!;
          final activities = containerActivitiesRecordList
              .where((e) => e.groupIds.contains(_model.currentGroup))
              .toList();

          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: activities.isEmpty
                  ? KeyedSubtree(
                      key: const ValueKey<String>('m01_schedule_empty'),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Image.asset(
                            'assets/images/vineyard.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    )
                  : KeyedSubtree(
                      key: ValueKey<String>(
                        'm01_schedule_${activities.length}',
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.only(top: 2.0, bottom: 24.0),
                        itemCount: activities.length,
                        separatorBuilder: (_, __) => SizedBox(height: 8.0),
                        itemBuilder: (context, activitiesIndex) {
                          final activitiesItem = activities[activitiesIndex];
                          return Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                20.0, 0.0, 20.0, 0.0),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: activitiesItem.activityType == 'meet'
                                      ? const Color(0xFF007AFF)
                                          .withValues(alpha: 0.35)
                                      : const Color(0x00000000),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                    20.0, 0.0, 20.0, 0.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    M01ActivityCardWidget(
                                      key: Key(
                                          'Keyqfs_${activitiesIndex}_of_${activities.length}'),
                                      complete: false,
                                      index: 1,
                                      activityItem: activitiesItem,
                                    ).animateOnPageLoad(animationsMap[
                                        'm01ActivityCardOnPageLoadAnimation']!),
                                  ],
                                ),
                              ),
                            ).animateOnPageLoad(
                                animationsMap['containerOnPageLoadAnimation']!),
                          );
                        },
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
