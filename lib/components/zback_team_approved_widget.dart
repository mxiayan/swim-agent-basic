import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'zback_team_approved_model.dart';
export 'zback_team_approved_model.dart';

/// "Design a small, modern 'Badge' component.
///
/// It should have a soft emerald green background, a tiny white checkmark
/// icon, and the text 'TEAM APPROVED' in all caps (10px, bold). The corners
/// should be fully rounded (pills shape). Add a subtle 1px green border."
class ZbackTeamApprovedWidget extends StatefulWidget {
  const ZbackTeamApprovedWidget({super.key});

  @override
  State<ZbackTeamApprovedWidget> createState() =>
      _ZbackTeamApprovedWidgetState();
}

class _ZbackTeamApprovedWidgetState extends State<ZbackTeamApprovedWidget> {
  late ZbackTeamApprovedModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ZbackTeamApprovedModel());

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
        color: Color(0xFFE6F4F1),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: Color(0xFF2ECC71),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(6.0, 12.0, 6.0, 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF27AE60),
              size: 12.0,
            ),
            Text(
              'TEAM APPROVED',
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.sora(
                      fontWeight: FontWeight.bold,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
                    color: Color(0xFF27AE60),
                    fontSize: 10.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.bold,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
            ),
          ].divide(SizedBox(width: 4.0)),
        ),
      ),
    );
  }
}
