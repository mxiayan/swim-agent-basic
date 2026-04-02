import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'accommodations_model.dart';
export 'accommodations_model.dart';

/// Placeholder for copied FlutterFlow "Accommodations" tab (not in this repo).
class AccommodationsWidget extends StatefulWidget {
  const AccommodationsWidget({super.key});

  @override
  State<AccommodationsWidget> createState() => _AccommodationsWidgetState();
}

class _AccommodationsWidgetState extends State<AccommodationsWidget> {
  late AccommodationsModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AccommodationsModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: FlutterFlowTheme.of(context).primaryBackground,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Accommodations',
            textAlign: TextAlign.center,
            style: FlutterFlowTheme.of(context).titleMedium.override(
                  font: GoogleFonts.sora(),
                ),
          ),
        ),
      ),
    );
  }
}
