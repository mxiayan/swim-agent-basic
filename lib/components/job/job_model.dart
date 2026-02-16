import '/components/job_card/job_card_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import 'job_widget.dart' show JobWidget;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class JobModel extends FlutterFlowModel<JobWidget> {
  ///  State fields for stateful widgets in this component.

  // Model for JobCard component.
  late JobCardModel jobCardModel1;
  // Model for JobCard component.
  late JobCardModel jobCardModel2;
  // Model for JobCard component.
  late JobCardModel jobCardModel3;

  @override
  void initState(BuildContext context) {
    jobCardModel1 = createModel(context, () => JobCardModel());
    jobCardModel2 = createModel(context, () => JobCardModel());
    jobCardModel3 = createModel(context, () => JobCardModel());
  }

  @override
  void dispose() {
    jobCardModel1.dispose();
    jobCardModel2.dispose();
    jobCardModel3.dispose();
  }
}
