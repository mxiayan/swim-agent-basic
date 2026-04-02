import '/backend/backend.dart';
import '/components/activity_card/activity_card_widget.dart';
import '/custom_code/actions/refresh_swimmer_app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'activities_model.dart';
export 'activities_model.dart';

/// Default hero image when [MonitoredMeetsRecord.imageUrl] is empty.
const String _kDefaultMeetImage =
    'https://storage.googleapis.com/turo-deals-1599612493143.appspot.com/demo_images/kayaking.png';

class ActivitiesWidget extends StatefulWidget {
  const ActivitiesWidget({super.key});

  @override
  State<ActivitiesWidget> createState() => _ActivitiesWidgetState();
}

class _ActivitiesWidgetState extends State<ActivitiesWidget> {
  late ActivitiesModel _model;

  /// Which card index is expanded (-1 = none).
  int _expandedIndex = -1;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ActivitiesModel());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await refreshSwimmerAppState();
      if (mounted) {
        safeSetState(() {});
      }
    });
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<FFAppState>();

    final swimmerLabel = appState.currentSwimmerName.isEmpty
        ? 'your swimmer'
        : appState.currentSwimmerName;
    // Prefer display label, skip FlutterFlow placeholders like "Unknown Zone".
    final zoneForHeader = appState.currentSwimmerZoneLabel.isEmpty
        ? 'your zone'
        : appState.currentSwimmerZoneLabel;

    return Container(
      width: MediaQuery.sizeOf(context).width * 1.0,
      height: MediaQuery.sizeOf(context).height * 1.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24.0, 24.0, 24.0, 8.0),
            child: Text(
              'Showing meets for $swimmerLabel in $zoneForHeader',
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    font: GoogleFonts.sora(
                      fontWeight:
                          FlutterFlowTheme.of(context).titleMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleMedium.fontStyle,
                    ),
                    letterSpacing: 0.0,
                  ),
            ),
          ),
          if (appState.currentSwimmerZoneForMeets.isEmpty)
            Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 8.0),
              child: Text(
                'Choose your club in profile to load your Pacific zone.',
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      font: GoogleFonts.sora(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodySmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<MonitoredMeetsRecord>>(
              stream: streamMonitoredMeetsForSwimmer(
                zoneId: appState.currentSwimmerZoneForMeets,
                priorityHostGroup: appState.currentSwimmerGroup,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Could not load meets: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: FlutterFlowTheme.of(context).bodyMedium,
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final meets = snapshot.data ?? [];

                if (meets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        appState.currentSwimmerZoneForMeets.isEmpty
                            ? 'No meets until your zone is set.'
                            : 'No monitored meets for your zone yet.',
                        textAlign: TextAlign.center,
                        style: FlutterFlowTheme.of(context).bodyLarge,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      0.0, 16.0, 0.0, 24.0),
                  itemCount: meets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8.0),
                  itemBuilder: (context, index) {
                    final meet = meets[index];
                    final imageUrl = meet.imageUrl.isNotEmpty
                        ? meet.imageUrl
                        : _kDefaultMeetImage;
                    final subtitle = meet.subtitle.isNotEmpty
                        ? meet.subtitle
                        : (meet.startTime != null
                            ? DateFormat.yMMMd()
                                .add_jm()
                                .format(meet.startTime!.toLocal())
                            : '');

                    return InkWell(
                      splashColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () {
                        safeSetState(() {
                          _expandedIndex =
                              _expandedIndex == index ? -1 : index;
                        });
                      },
                      child: ActivityCardWidget(
                        title: meet.title.isNotEmpty ? meet.title : 'Meet',
                        subtitle: subtitle,
                        description: meet.description.isNotEmpty
                            ? meet.description
                            : 'Details coming soon.',
                        expanded: _expandedIndex == index,
                        image: imageUrl,
                        favorite: false,
                        index: index,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
