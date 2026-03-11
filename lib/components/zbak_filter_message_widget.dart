import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'zbak_filter_message_model.dart';
export 'zbak_filter_message_model.dart';

/// "Design a modern, slim 'Info Banner' component for the top of a list page.
///
/// It should be a low-profile horizontal container with a very subtle
/// light-blue semi-transparent background (Glassmorphism style).
///
/// Requirements:
///
/// Icon: A small, clean 'Info' or 'Filter' icon on the left in a soft primary
/// blue.
///
/// Text: Two lines of text. Line 1: 'Personalized View' (Bold, 12px). Line 2:
/// 'Showing meets for [SwimmerName] in [ZoneName]' (Regular, 12px, slightly
/// muted color).
///
/// Action: A small 'Edit' or 'Settings' icon button on the far right that
/// looks like a ghost button.
///
/// Border: A very thin, light-grey bottom border only.
///
/// Vibe: Minimalist, clean, and professional. It should look like part of the
/// app's 'System' messages, not a loud advertisement."
class ZbakFilterMessageWidget extends StatefulWidget {
  const ZbakFilterMessageWidget({super.key});

  @override
  State<ZbakFilterMessageWidget> createState() =>
      _ZbakFilterMessageWidgetState();
}

class _ZbakFilterMessageWidgetState extends State<ZbakFilterMessageWidget> {
  late ZbakFilterMessageModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ZbakFilterMessageModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFE8F4FD),
        borderRadius: BorderRadius.circular(0.0),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: Color(0xFFE0E3E7),
                  width: 1.0,
                ),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(12.0, 10.0, 12.0, 10.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          width: 32.0,
                          height: 32.0,
                          decoration: BoxDecoration(
                            color: Color(0x1A4B39EF),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Icon(
                            Icons.info_outlined,
                            color: FlutterFlowTheme.of(context).primary,
                            size: 16.0,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personalized View',
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    font: GoogleFonts.sora(
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontSize: 12.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .fontStyle,
                                  ),
                            ),
                            Text(
                              'Showing meets for SwimmerName in ZoneName',
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    font: GoogleFonts.sora(
                                      fontWeight: FontWeight.normal,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    fontSize: 12.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .fontStyle,
                                  ),
                            ),
                          ],
                        ),
                      ].divide(SizedBox(width: 10.0)),
                    ),
                    FlutterFlowIconButton(
                      borderColor: Color(0xFFE0E3E7),
                      borderRadius: 8.0,
                      borderWidth: 1.0,
                      buttonSize: 32.0,
                      fillColor: Colors.transparent,
                      icon: Icon(
                        Icons.tune_rounded,
                        color: FlutterFlowTheme.of(context).secondaryText,
                        size: 16.0,
                      ),
                      onPressed: () {
                        print('IconButton pressed ...');
                      },
                    ),
                  ].divide(SizedBox(width: 12.0)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
