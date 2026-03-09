import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'zback_what_model.dart';
export 'zback_what_model.dart';

/// Design a premium horizontal category selector inspired by Instagram and
/// Airbnb.
///
/// Layout: A horizontal ListView containing 6 items: 'junior_1', 'junior_2',
/// 'junior_3', 'senior_2', 'senior_3', and 'senior_4'.
///
/// Styling: Use a clean white background. Each item should consist of a
/// Column with:
///
/// An icon at the top (use a 'person' or 'swimming' icon).
///
/// The category name text in a small, modern sans-serif font (size 12).
///
/// Active State: When an item is selected, the icon and text should turn dark
/// blue, and a 2px thick dark blue horizontal line (indicator) should appear
/// exactly 4px below the text.
///
/// Inactive State: The icon and text should be a light, muted gray with no
/// indicator line.
///
/// Spacing: Add 24px of horizontal spacing between each item and 16px padding
/// at the start and end of the scrollable list so the first and last items
/// don't touch the screen edges
class ZbackWhatWidget extends StatefulWidget {
  const ZbackWhatWidget({super.key});

  @override
  State<ZbackWhatWidget> createState() => _ZbackWhatWidgetState();
}

class _ZbackWhatWidgetState extends State<ZbackWhatWidget> {
  late ZbackWhatModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ZbackWhatModel());

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
        color: Colors.transparent,
      ),
      child: Container(
        width: double.infinity,
        height: 80.0,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16.0,
            0,
            16.0,
            0,
          ),
          primary: false,
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.person,
                  color: Color(0xFF57636C),
                  size: 24.0,
                ),
                Text(
                  'junior_1',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.sora(
                          fontWeight:
                              FlutterFlowTheme.of(context).bodySmall.fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodySmall.fontStyle,
                        ),
                        color: Color(0xFF57636C),
                        fontSize: 12.0,
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).bodySmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                ),
              ].divide(SizedBox(height: 8.0)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.question_mark,
                  color: Color(0xFF4B39EF),
                  size: 24.0,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'junior_2',
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            font: GoogleFonts.sora(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .fontStyle,
                            ),
                            color: Color(0xFF4B39EF),
                            fontSize: 12.0,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .bodySmall
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodySmall
                                .fontStyle,
                          ),
                    ),
                    Container(
                      width: 40.0,
                      height: 2.0,
                      decoration: BoxDecoration(
                        color: Color(0xFF4B39EF),
                      ),
                    ),
                  ].divide(SizedBox(height: 4.0)),
                ),
              ].divide(SizedBox(height: 8.0)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.person,
                  color: Color(0xFF57636C),
                  size: 24.0,
                ),
                Text(
                  'junior_3',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.sora(
                          fontWeight:
                              FlutterFlowTheme.of(context).bodySmall.fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodySmall.fontStyle,
                        ),
                        color: Color(0xFF57636C),
                        fontSize: 12.0,
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).bodySmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                ),
              ].divide(SizedBox(height: 8.0)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.question_mark,
                  color: Color(0xFF57636C),
                  size: 24.0,
                ),
                Text(
                  'senior_2',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.sora(
                          fontWeight:
                              FlutterFlowTheme.of(context).bodySmall.fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodySmall.fontStyle,
                        ),
                        color: Color(0xFF57636C),
                        fontSize: 12.0,
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).bodySmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                ),
              ].divide(SizedBox(height: 8.0)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.person,
                  color: Color(0xFF57636C),
                  size: 24.0,
                ),
                Text(
                  'senior_3',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.sora(
                          fontWeight:
                              FlutterFlowTheme.of(context).bodySmall.fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodySmall.fontStyle,
                        ),
                        color: Color(0xFF57636C),
                        fontSize: 12.0,
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).bodySmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                ),
              ].divide(SizedBox(height: 8.0)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.question_mark,
                  color: Color(0xFF57636C),
                  size: 24.0,
                ),
                Text(
                  'senior_4',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.sora(
                          fontWeight:
                              FlutterFlowTheme.of(context).bodySmall.fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodySmall.fontStyle,
                        ),
                        color: Color(0xFF57636C),
                        fontSize: 12.0,
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).bodySmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                ),
              ].divide(SizedBox(height: 8.0)),
            ),
          ].divide(SizedBox(width: 24.0)),
        ),
      ),
    );
  }
}
