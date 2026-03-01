import '/components/m03_job_card/m03_job_card_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import 'm03_job_widget.dart' show M03JobWidget;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class M03JobModel extends FlutterFlowModel<M03JobWidget> {
  ///  State fields for stateful widgets in this component.

  // Model for m03_job_card component.
  late M03JobCardModel m03JobCardModel1;
  // Model for m03_job_card component.
  late M03JobCardModel m03JobCardModel2;
  // Model for m03_job_card component.
  late M03JobCardModel m03JobCardModel3;

  @override
  void initState(BuildContext context) {
    m03JobCardModel1 = createModel(context, () => M03JobCardModel());
    m03JobCardModel2 = createModel(context, () => M03JobCardModel());
    m03JobCardModel3 = createModel(context, () => M03JobCardModel());
  }

  @override
  void dispose() {
    m03JobCardModel1.dispose();
    m03JobCardModel2.dispose();
    m03JobCardModel3.dispose();
  }
}
