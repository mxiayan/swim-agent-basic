import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/m01_activity/m01_activity_widget.dart';
import '/components/m02_meet/m02_meet_widget.dart';
import '/components/m03_job/m03_job_widget.dart';
import '/components/m04_swimmer/m04_swimmer_widget.dart';
import '/components/m05_activity_dashboard/m05_activity_dashboard_widget.dart';
import '/components/nav_item/nav_item_widget.dart';
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
            backgroundColor: Colors.white,
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
            body: SafeArea(
              top: true,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
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
                              'Orinda aquatics',
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
                                    fontSize: 26.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .displaySmall
                                        .fontWeight,
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
                          width: 36.0,
                          height: 36.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).primary,
                              width: 2.0,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
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
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              FFAppState().activeTab = 0;
                              FFAppState().update(() {});
                            },
                            child: wrapWithModel(
                              model: _model.activitiesModel,
                              updateCallback: () => safeSetState(() {}),
                              child: NavItemWidget(
                                text: 'SCHEDULE',
                                selected:
                                    FFAppState().activeTab.toString() == '0',
                                width: 70,
                              ),
                            ),
                          ),
                          InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              FFAppState().activeTab = 2;
                              FFAppState().update(() {});
                            },
                            child: wrapWithModel(
                              model: _model.meetsModel,
                              updateCallback: () => safeSetState(() {}),
                              child: NavItemWidget(
                                text: 'MEETS',
                                selected:
                                    FFAppState().activeTab.toString() == '2',
                                width: 45,
                              ),
                            ),
                          ),
                          InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              FFAppState().activeTab = 3;
                              FFAppState().update(() {});
                            },
                            child: wrapWithModel(
                              model: _model.jobsModel,
                              updateCallback: () => safeSetState(() {}),
                              child: NavItemWidget(
                                text: 'JOBS',
                                selected:
                                    FFAppState().activeTab.toString() == '3',
                                width: 38,
                              ),
                            ),
                          ),
                          InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              FFAppState().activeTab = 1;
                              FFAppState().update(() {});
                            },
                            child: wrapWithModel(
                              model: _model.swimmerModel,
                              updateCallback: () => safeSetState(() {}),
                              child: NavItemWidget(
                                text: 'SWIMMER',
                                selected:
                                    FFAppState().activeTab.toString() == '1',
                                width: 65,
                              ),
                            ),
                          ),
                          InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              FFAppState().activeTab = 4;
                              FFAppState().update(() {});
                            },
                            child: wrapWithModel(
                              model: _model.adminModel,
                              updateCallback: () => safeSetState(() {}),
                              child: NavItemWidget(
                                text: 'ADMIN',
                                selected:
                                    FFAppState().activeTab.toString() == '4',
                                width: 48,
                              ),
                            ),
                          ),
                        ].divide(SizedBox(width: 12.0)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      alignment: AlignmentDirectional(0.0, -1.0),
                      children: [
                        if (FFAppState().activeTab == 0)
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 5.0, 0.0, 0.0),
                            child: wrapWithModel(
                              model: _model.m01ActivityModel,
                              updateCallback: () => safeSetState(() {}),
                              child: M01ActivityWidget(),
                            ),
                          ),
                        if (FFAppState().activeTab == 2)
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 5.0, 0.0, 0.0),
                            child: wrapWithModel(
                              model: _model.m02MeetModel,
                              updateCallback: () => safeSetState(() {}),
                              child: M02MeetWidget(),
                            ),
                          ),
                        if (FFAppState().activeTab == 3)
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 5.0, 0.0, 0.0),
                            child: wrapWithModel(
                              model: _model.m03JobModel,
                              updateCallback: () => safeSetState(() {}),
                              child: M03JobWidget(),
                            ),
                          ),
                        if (FFAppState().activeTab == 1)
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 5.0, 0.0, 0.0),
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
}
