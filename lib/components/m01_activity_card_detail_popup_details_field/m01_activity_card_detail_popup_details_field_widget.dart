import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'm01_activity_card_detail_popup_details_field_model.dart';
export 'm01_activity_card_detail_popup_details_field_model.dart';

class M01ActivityCardDetailPopupDetailsFieldWidget extends StatefulWidget {
  const M01ActivityCardDetailPopupDetailsFieldWidget({
    super.key,
    this.title,
    this.value,
  });

  final String? title;
  final String? value;

  @override
  State<M01ActivityCardDetailPopupDetailsFieldWidget> createState() =>
      _M01ActivityCardDetailPopupDetailsFieldWidgetState();
}

class _M01ActivityCardDetailPopupDetailsFieldWidgetState
    extends State<M01ActivityCardDetailPopupDetailsFieldWidget> {
  late M01ActivityCardDetailPopupDetailsFieldModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(
        context, () => M01ActivityCardDetailPopupDetailsFieldModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              widget!.title!,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.sora(
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).lightGrey,
                    fontSize: 12.0,
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              widget!.value!,
              style: FlutterFlowTheme.of(context).headlineSmall.override(
                    font: GoogleFonts.sora(
                      fontWeight:
                          FlutterFlowTheme.of(context).headlineSmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineSmall.fontStyle,
                    ),
                    fontSize: 22.0,
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).headlineSmall.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineSmall.fontStyle,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
