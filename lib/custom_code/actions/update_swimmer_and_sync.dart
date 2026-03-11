// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'index.dart'; // Imports other custom actions

Future updateSwimmerAndSync(
  DocumentReference swimmerRef,
  String newName,
  String newGroup,
  String newZone,
) async {
  // Update swimmer document in Firestore
  await swimmerRef.update({
    'name': newName,
    'group': newGroup,
    'zone': newZone,
    'is_active': true,
  });

  // Sync and refresh App State
  FFAppState().update(() {
    FFAppState().currentSwimmerName = newName;
    FFAppState().currentSwimmerGroup = newGroup;
    FFAppState().currentSwimmerZone = newZone;
  });

  return;
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
