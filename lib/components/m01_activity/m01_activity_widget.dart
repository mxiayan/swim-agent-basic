import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/meet_preferences_api.dart';
import '/backend/schema/meet_preferences_record.dart';
import '/components/m01_activity_card/m01_activity_card_widget.dart';
import '/components/m01_activity/meet_detail_view.dart';
import '/components/m01_activity/schedule_hub_widget.dart';
import '/custom_code/actions/refresh_swimmer_app_state.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/theme/swim_ui_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
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

  /// Activity doc paths swiped away locally (activities stream is unrelated to meet_preferences).
  final Set<String> _swipeDismissedActivityPaths = <String>{};

  bool _isMeetActivity(ActivitiesRecord a) =>
      a.activityType.trim().toLowerCase() == 'meet';

  /// Meet preference doc id: OME URL segment or numeric Firestore activity id.
  String? _meetIdFromActivity(ActivitiesRecord a) {
    final url = a.details.signupUrl.trim();
    final fromUrl =
        RegExp(r'/meets/([^/?#]+)').firstMatch(url)?.group(1)?.trim();
    if (fromUrl != null && fromUrl.isNotEmpty) {
      return fromUrl;
    }
    final id = a.reference.id.trim();
    if (RegExp(r'^\d+$').hasMatch(id)) {
      return id;
    }
    return null;
  }

  bool _canSwipeSkipMeet(ActivitiesRecord a) =>
      _isMeetActivity(a) &&
      _meetIdFromActivity(a) != null &&
      currentUserUid.isNotEmpty;

  Future<void> _onMeetActivityDismissed(ActivitiesRecord activitiesItem) async {
    final path = activitiesItem.reference.path;
    final meetId = _meetIdFromActivity(activitiesItem)!;
    setState(() => _swipeDismissedActivityPaths.add(path));
    try {
      await mergeMeetPreference(
        currentUserUid,
        meetId,
        isHidden: true,
        status: MeetPreferenceStatus.notGoing,
        skipSelected: true,
      );
    } catch (_) {}
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Meet skipped. You can view or restore skipped meets in Filters.',
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            setState(() => _swipeDismissedActivityPaths.remove(path));
            try {
              await mergeMeetPreference(
                currentUserUid,
                meetId,
                isHidden: false,
              );
              await refreshSwimmerAppState();
            } catch (_) {}
          },
        ),
      ),
    );
  }

  Future<void> _openMeetFocusMode({
    required ActivitiesRecord activity,
    required MeetPreferencesRecord? preference,
    required String meetId,
  }) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => MeetDetailView(
          activity: activity,
          preference: preference,
          meetId: meetId,
          heroTag: meetId,
        ),
      ),
    );
  }

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
    // Schedule tab now renders the parser-produced `team_events` collection
    // (multi-team registry-driven). The legacy `activities` list is kept on
    // disk in case other surfaces need it; restore the old StreamBuilder if
    // that proves necessary.
    return const SizedBox.expand(
      child: ScheduleHubWidget(teamId: 'oapb'),
    );
  }

  @Deprecated('Replaced by ScheduleHubWidget; retained for fallback.')
  // ignore: unused_element
  Widget _buildLegacyActivitiesList(BuildContext context) {
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
              .where((e) =>
                  !_swipeDismissedActivityPaths.contains(e.reference.path))
              .toList();

          return StreamBuilder<Map<String, MeetPreferencesRecord>>(
            stream: streamMeetPreferencesMap(currentUserUid),
            builder: (context, prefSnap) {
              final preferences =
                  prefSnap.data ?? <String, MeetPreferencesRecord>{};
              return Container(
                decoration: const BoxDecoration(
                  color: SwimUiTokens.surfaceCanvasSchedule,
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
                          padding: const EdgeInsets.fromLTRB(32.0, 24.0, 32.0, 32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/vineyard.png',
                                fit: BoxFit.contain,
                                height: 160.0,
                              ),
                              const SizedBox(height: 20.0),
                              Text(
                                'Nothing on the schedule',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.sora(
                                  fontSize: 17.0,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  color: SwimUiTokens.textBannerTitle,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              Text(
                                'Team activities and meets will show up here when they are posted.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.sora(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                  color: SwimUiTokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : KeyedSubtree(
                      key: ValueKey<String>(
                        'm01_schedule_${activities.length}',
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(top: 12.0, bottom: 28.0),
                        itemCount: activities.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10.0),
                        itemBuilder: (context, activitiesIndex) {
                          final activitiesItem = activities[activitiesIndex];
                          final rowKey = activitiesItem.reference.path;
                          final parsedMeetId =
                              _meetIdFromActivity(activitiesItem);
                          final isMeet = _isMeetActivity(activitiesItem);
                          // Prefer OME / numeric id; fall back so focus mode opens for all meet rows.
                          final meetIdForFocus =
                              parsedMeetId ?? activitiesItem.reference.id;
                          final heroTag = isMeet
                              ? meetIdForFocus
                              : activitiesItem.reference.id;
                          MeetPreferencesRecord? preference;
                          if (isMeet) {
                            if (parsedMeetId != null) {
                              preference = preferences[parsedMeetId];
                            }
                            preference ??=
                                preferences[activitiesItem.reference.id];
                          }
                          final openMeetFocus = isMeet
                              ? () => _openMeetFocusMode(
                                    activity: activitiesItem,
                                    preference: preference,
                                    meetId: meetIdForFocus,
                                  )
                              : null;
                          final card = Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                16.0, 0.0, 16.0, 0.0),
                            child: Hero(
                              tag: heroTag,
                              flightShuttleBuilder: (
                                _,
                                animation,
                                __,
                                ___,
                                toHeroContext,
                              ) {
                                final curved = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOutCubic,
                                );
                                return FadeTransition(
                                  opacity: curved,
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.98,
                                      end: 1.0,
                                    ).animate(curved),
                                    child: toHeroContext.widget,
                                  ),
                                );
                              },
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(
                                    SwimUiTokens.radiusCard,
                                  ),
                                  onTap: openMeetFocus,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isMeet
                                            ? SwimUiTokens.meetRowRing
                                            : Colors.transparent,
                                        width: isMeet ? 1.0 : 0.0,
                                      ),
                                    ),
                                    child: Padding(
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              16.0, 0.0, 16.0, 0.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          M01ActivityCardWidget(
                                            key: ValueKey<String>(rowKey),
                                            complete: false,
                                            index: 1,
                                            activityItem: activitiesItem,
                                          ).animateOnPageLoad(animationsMap[
                                              'm01ActivityCardOnPageLoadAnimation']!),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ).animateOnPageLoad(
                                animationsMap['containerOnPageLoadAnimation']!),
                          );

                          if (!_canSwipeSkipMeet(activitiesItem)) {
                            return card;
                          }

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(
                              SwimUiTokens.radiusCard,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Dismissible(
                              key: ValueKey<String>('dismiss_$rowKey'),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) async {
                                HapticFeedback.mediumImpact();
                                return true;
                              },
                              // Required by [Dismissible] whenever [secondaryBackground] is non-null.
                              background: Container(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    SwimUiTokens.radiusCard,
                                  ),
                                ),
                              ),
                              secondaryBackground: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsetsDirectional.only(end: 20.0),
                                decoration: BoxDecoration(
                                  color: SwimUiTokens.swipeBackground,
                                  borderRadius: BorderRadius.circular(
                                    SwimUiTokens.radiusCard,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.archive_outlined,
                                  color: SwimUiTokens.swipeIcon,
                                  size: 28.0,
                                ),
                              ),
                              onDismissed: (_) =>
                                  _onMeetActivityDismissed(activitiesItem),
                              child: card,
                            ),
                          );
                        },
                      ),
                    ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
