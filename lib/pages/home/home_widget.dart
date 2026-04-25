import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/m01_activity/m01_activity_widget.dart';
import '/components/m02_meet/m02_meet_widget.dart';
import '/components/m03_job/m03_job_widget.dart';
import '/components/m04_swimmer/m04_swimmer_widget.dart';
import '/components/m05_activity_dashboard/m05_activity_dashboard_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
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
  static const double _bottomNavHeight = 68.0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomeModel());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FFAppState().activeTab != 2) {
        FFAppState().update(() => FFAppState().activeTab = 2);
      }
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

    final primaryBlue = FlutterFlowTheme.of(context).primary;
    final muted = FlutterFlowTheme.of(context).secondaryText;

    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(currentUserReference!),
      builder: (context, snapshot) {
        // Customize what your widget looks like when it's loading.
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
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
            backgroundColor: Colors.white,
            bottomNavigationBar: _buildBottomNavigationBar(
              context: context,
              primaryBlue: primaryBlue,
              muted: muted,
            ),
            body: SafeArea(
              top: true,
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 14.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Orinda Aquatics',
                              style: FlutterFlowTheme.of(context)
                                  .displaySmall
                                  .override(
                                    font: GoogleFonts.sora(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .displaySmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .displaySmall
                                          .fontStyle,
                                    ),
                                    fontSize: 28.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .displaySmall
                                        .fontStyle,
                                  ),
                            ),
                            Text(
                              'Swim Season 2025 - 2026',
                              style: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .override(
                                    font: GoogleFonts.sora(
                                      fontWeight: FontWeight.w400,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w400,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                            ),
                          ],
                        ),
                        Container(
                          width: 40.0,
                          height: 40.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).primary,
                              width: 1.5,
                            ),
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
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      alignment: AlignmentDirectional(0.0, -1.0),
                      children: [
                        if (FFAppState().activeTab == 0)
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
                        if (FFAppState().activeTab == 1)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                0.0, 4.0, 0.0, 0.0),
                            child: wrapWithModel(
                              model: _model.m04SwimmerModel,
                              updateCallback: () => safeSetState(() {}),
                              child: M04SwimmerWidget(),
                            ),
                          ),
                        if (FFAppState().activeTab == 4)
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

  Widget _buildBottomNavigationBar({
    required BuildContext context,
    required Color primaryBlue,
    required Color muted,
  }) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14.0, 0.0, 14.0, 8.0),
        height: _bottomNavHeight,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(22.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20.0,
              offset: const Offset(0.0, 6.0),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFE6ECF4),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            _buildBottomNavItem(
              label: 'Schedule',
              icon: Icons.calendar_today_rounded,
              tabIndex: 0,
              primaryBlue: primaryBlue,
              muted: muted,
            ),
            _buildBottomNavItem(
              label: 'Meets',
              icon: Icons.pool_rounded,
              tabIndex: 2,
              primaryBlue: primaryBlue,
              muted: muted,
            ),
            _buildBottomNavItem(
              label: 'Jobs',
              icon: Icons.work_outline_rounded,
              tabIndex: 3,
              primaryBlue: primaryBlue,
              muted: muted,
            ),
            _buildBottomNavItem(
              label: 'Swimmer',
              icon: Icons.person_outline_rounded,
              tabIndex: 1,
              primaryBlue: primaryBlue,
              muted: muted,
            ),
            _buildBottomNavItem(
              label: 'Admin',
              icon: Icons.shield_outlined,
              tabIndex: 4,
              primaryBlue: primaryBlue,
              muted: muted,
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
    required Color primaryBlue,
    required Color muted,
  }) {
    final selected = FFAppState().activeTab == tabIndex;
    final iconColor = selected ? primaryBlue : muted.withValues(alpha: 0.78);
    final labelColor = selected ? primaryBlue : muted.withValues(alpha: 0.86);

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
                Icon(icon, size: selected ? 20.5 : 20.0, color: iconColor),
                const SizedBox(height: 4.0),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 11.0,
                    letterSpacing: 0.0,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: labelColor,
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
