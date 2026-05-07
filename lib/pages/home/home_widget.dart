import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/meet_preferences_api.dart';
import '/backend/schema/meet_preferences_record.dart';
import '/components/m01_activity/m01_activity_widget.dart';
import '/components/m02_meet/m02_meet_widget.dart';
import '/components/m03_job/m03_job_widget.dart';
import '/pages/agent_home/agent_feed_item.dart';
import '/pages/agent_home/agent_feed_logic.dart';
import '/pages/agent_home/agent_home_widget.dart';
import '/pages/agent_home/agent_meet_feed_bridge.dart';
import '/pages/agent_home/agent_priority_engine.dart';
import '/pages/swimmer_profile/swimmer_profile_page.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/theme/lavender_indigo_tokens.dart';
import '/theme/obsidian_volt_tokens.dart';
import '/theme/swim_design_tokens.dart';
import '/theme/swim_ui_tokens.dart';
import '/widgets/swim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'home_model.dart';
export 'home_model.dart';

class HomeWidget extends StatefulWidget {
  const HomeWidget({super.key});

  static String routeName = 'Home';
  static String routePath = 'home';

  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> {
  late HomeModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  static const double _bottomNavHeight = 72.0;

  static String _shellTitle(int tab) {
    switch (tab) {
      case 1:
        return 'Schedule';
      case 2:
        return 'Meets';
      case 3:
        return 'Jobs';
      default:
        return '';
    }
  }

  static String _shellSubtitle(int tab) {
    switch (tab) {
      case 1:
        return 'Team calendar & training';
      case 2:
        return 'Entries, deadlines & heat sheets';
      case 3:
        return 'Volunteer shifts & reminders';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomeModel());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FFAppState().update(() {
        final t = FFAppState().activeTab;
        if (t < 0 || t > 3) {
          FFAppState().activeTab = 0;
        }
      });
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(currentUserReference!),
      builder: (context, snapshot) {
        // Customize what your widget looks like when it's loading.
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: SwimUiTokens.surfaceCanvasAgent,
            body: Center(
              child: SizedBox(
                width: 50.0,
                height: 50.0,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    FlutterFlowTheme.of(context).primary,
                  ),
                ),
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: SwimUiTokens.surfaceCanvasAgent,
            bottomNavigationBar: StreamBuilder<List<MonitoredMeetsRecord>>(
              stream: streamMonitoredMeetsForSwimmer(
                zoneId: FFAppState().currentSwimmerZoneForMeets,
                priorityHostGroup: FFAppState().currentSwimmerGroup,
                showAll: FFAppState().meetsShowAllZones,
              ),
              builder: (context, meetSnap) {
                return StreamBuilder<Map<String, MeetPreferencesRecord>>(
                  stream: streamMeetPreferencesMap(currentUserUid),
                  builder: (context, prefSnap) {
                    final app = FFAppState();
                    final now = DateTime.now();
                    final feed = meetSnap.hasData
                        ? agentFeedItemsFromMonitoredMeets(
                            meets: meetSnap.data!,
                            app: app,
                            now: now,
                          )
                        : <AgentFeedItem>[];
                    final stats = AgentFeedLogic.computeSmartStats(feed, now);
                    final prefs = prefSnap.data ?? {};
                    final meetDot = prefs.values.any(
                      (p) =>
                          p.status == MeetPreferenceStatus.newStatus ||
                          p.status == MeetPreferenceStatus.needEntry,
                    );
                    final jobsDot = feed.any(
                      (i) =>
                          i.type == AgentFeedItemType.volunteerJob &&
                          AgentPriorityEngine.volunteerJobIsSignupUrgent(i),
                    );
                    return _buildBottomNavigationBar(
                      context,
                      agentDot: stats.needsAction > 0,
                      meetDot: meetDot,
                      jobsDot: jobsDot,
                    );
                  },
                );
              },
            ),
            body: SafeArea(
              top: true,
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (FFAppState().activeTab != 0)
                    AppShellHeader(
                      title: _shellTitle(FFAppState().activeTab),
                      subtitle: _shellSubtitle(FFAppState().activeTab),
                      onAvatarTap: () => SwimmerProfilePage.push(context),
                    ),
                  Expanded(
                    child: Stack(
                      alignment: AlignmentDirectional(0.0, -1.0),
                      children: [
                        if (FFAppState().activeTab == 0)
                          AgentHomeWidget(
                            userDisplayName: snapshot.data!.displayName,
                            onProfileTap: () =>
                                SwimmerProfilePage.push(context),
                          ),
                        if (FFAppState().activeTab == 1)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                0.0, 4.0, 0.0, 0.0),
                            child: wrapWithModel(
                              model: _model.m01ActivityModel,
                              updateCallback: () => safeSetState(() {}),
                              child: M01ActivityWidget(),
                            ),
                          ),
                        if (FFAppState().activeTab == 2)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                0.0, 4.0, 0.0, 0.0),
                            child: wrapWithModel(
                              model: _model.m02MeetModel,
                              updateCallback: () => safeSetState(() {}),
                              child: M02MeetWidget(),
                            ),
                          ),
                        if (FFAppState().activeTab == 3)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                0.0, 4.0, 0.0, 0.0),
                            child: wrapWithModel(
                              model: _model.m03JobModel,
                              updateCallback: () => safeSetState(() {}),
                              child: M03JobWidget(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar(
    BuildContext context, {
    bool agentDot = false,
    bool meetDot = false,
    bool jobsDot = false,
  }) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14.0, 0.0, 14.0, 6.0),
        height: _bottomNavHeight,
        decoration: BoxDecoration(
          color: ObsidianVoltTokens.bottomNavBg,
          borderRadius:
              BorderRadius.circular(SwimDsTokens.bottomNavRadius),
          boxShadow: LavenderIndigoTokens.shadowNavUp,
        ),
        child: Row(
          children: [
            _buildBottomNavItem(
              label: 'Agent',
              icon: Icons.auto_awesome_rounded,
              tabIndex: 0,
              showBadge: agentDot,
            ),
            _buildBottomNavItem(
              label: 'Schedule',
              icon: Icons.calendar_today_rounded,
              tabIndex: 1,
            ),
            _buildBottomNavItem(
              label: 'Meets',
              icon: Icons.pool_rounded,
              tabIndex: 2,
              showBadge: meetDot,
            ),
            _buildBottomNavItem(
              label: 'Jobs',
              icon: Icons.work_outline_rounded,
              tabIndex: 3,
              showBadge: jobsDot,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required String label,
    required IconData icon,
    required int tabIndex,
    bool showBadge = false,
  }) {
    final selected = FFAppState().activeTab == tabIndex;
    final activeColor = LavenderIndigoTokens.primary;
    final inactiveColor = LavenderIndigoTokens.textDisabled;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.0),
          onTap: () {
            if (FFAppState().activeTab == tabIndex) {
              return;
            }
            FFAppState().update(() => FFAppState().activeTab = tabIndex);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: selected ? 2.0 : 0.0),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      selected
                          ? Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: LavenderIndigoTokens.primarySoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                icon,
                                size: 22,
                                color: activeColor,
                              ),
                            )
                          : Icon(
                              icon,
                              size: 22,
                              color: inactiveColor,
                            ),
                      if (showBadge)
                        Positioned(
                          right: selected ? -1 : 10,
                          top: selected ? -2 : -4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: SwimDsTokens.dangerCoral,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ObsidianVoltTokens.bottomNavBg,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 10,
                    letterSpacing: 0.0,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? activeColor : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
