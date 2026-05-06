import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/m01_activity/m01_activity_widget.dart';
import '/components/m02_meet/m02_meet_widget.dart';
import '/components/m03_job/m03_job_widget.dart';
import '/components/m04_swimmer/m04_swimmer_widget.dart';
import '/components/m05_activity_dashboard/m05_activity_dashboard_widget.dart';
import '/pages/agent_home/agent_home_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/theme/lavender_indigo_tokens.dart';
import '/theme/obsidian_volt_tokens.dart';
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
  static const double _bottomNavHeight = 74.0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomeModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
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
            backgroundColor: ObsidianVoltTokens.bgBase,
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
            backgroundColor: ObsidianVoltTokens.bgBase,
            bottomNavigationBar: _buildBottomNavigationBar(context),
            body: SafeArea(
              top: true,
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (FFAppState().activeTab != 0)
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 10.0),
                      child: _SecondaryShellHeader(
                        tabIndex: FFAppState().activeTab,
                      ),
                    ),
                  Expanded(
                    child: Stack(
                      alignment: AlignmentDirectional(0.0, -1.0),
                      children: [
                        if (FFAppState().activeTab == 0)
                          AgentHomeWidget(
                            userDisplayName: snapshot.data!.displayName,
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
                        if (FFAppState().activeTab == 4)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                0.0, 4.0, 0.0, 0.0),
                            child: wrapWithModel(
                              model: _model.m04SwimmerModel,
                              updateCallback: () => safeSetState(() {}),
                              child: M04SwimmerWidget(),
                            ),
                          ),
                        if (FFAppState().activeTab == 5)
                          wrapWithModel(
                            model: _model.m05ActivityDashboardModel,
                            updateCallback: () => safeSetState(() {}),
                            child: M05ActivityDashboardWidget(),
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

  Widget _buildBottomNavigationBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14.0, 0.0, 14.0, 8.0),
        height: _bottomNavHeight,
        decoration: BoxDecoration(
          color: ObsidianVoltTokens.bottomNavBg,
          borderRadius: BorderRadius.circular(22.0),
          boxShadow: LavenderIndigoTokens.shadowNavUp,
        ),
        child: Row(
          children: [
            _buildBottomNavItem(
              label: 'Agent',
              icon: Icons.auto_awesome_rounded,
              tabIndex: 0,
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
            ),
            _buildBottomNavItem(
              label: 'Jobs',
              icon: Icons.work_outline_rounded,
              tabIndex: 3,
            ),
            _buildBottomNavItem(
              label: 'Swimmer',
              icon: Icons.person_outline_rounded,
              tabIndex: 4,
            ),
            _buildBottomNavItem(
              label: 'Admin',
              icon: Icons.shield_outlined,
              tabIndex: 5,
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
  }) {
    final selected = FFAppState().activeTab == tabIndex;
    const activeColor = Color(0xFF6366F1);
    const inactiveColor = Color(0xFFC5C8DC);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18.0),
          onTap: () {
            if (FFAppState().activeTab == tabIndex) {
              return;
            }
            FFAppState().update(() => FFAppState().activeTab = tabIndex);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: selected ? 2.0 : 0.0),
                  child: selected
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(99, 102, 241, 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            size: 20,
                            color: activeColor,
                          ),
                        )
                      : Icon(
                          icon,
                          size: 20,
                          color: inactiveColor,
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
                        selected ? FontWeight.w600 : FontWeight.w400,
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

class _SecondaryShellHeader extends StatelessWidget {
  const _SecondaryShellHeader({required this.tabIndex});

  final int tabIndex;

  static String _title(int tab) {
    switch (tab) {
      case 1:
        return 'Schedule';
      case 2:
        return 'Meets';
      case 3:
        return 'Jobs';
      case 4:
        return 'Swimmer';
      case 5:
        return 'Admin';
      default:
        return '';
    }
  }

  static String _subtitle(int tab) {
    switch (tab) {
      case 1:
        return 'Team calendar & events';
      case 2:
        return 'Entries & heat sheets';
      case 3:
        return 'Volunteer shifts';
      case 4:
        return 'Profile & zones';
      case 5:
        return 'Volunteer dashboard';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title(tabIndex),
                style: GoogleFonts.sora(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _subtitle(tabIndex),
                style: GoogleFonts.sora(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                  color: theme.secondaryText,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: LavenderIndigoTokens.bgSurface,
            border: Border.all(color: theme.primary, width: 1.5),
            boxShadow: LavenderIndigoTokens.shadowSm,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2.5),
            child: ClipOval(
              child: Image.asset(
                'assets/images/mcroskey-headshot.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
