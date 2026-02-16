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
import 'package:cloud_firestore/cloud_firestore.dart';

Future batchCreateActivities(
  List<String> groupList,
  String type,
  String location,
  DateTime? startTime,
  DateTime? endTime, // ADDED
  String? signupUrl, // ADDED
  String? description, // ADDED
) async {
  // 1. Fallback: If startTime is null, use the current time
  final DateTime finalStartTime = startTime ?? DateTime.now();

  // 2. Reference to the Firestore Instance
  final firestore = FirebaseFirestore.instance;

  // 3. Initialize a WriteBatch
  final WriteBatch batch = firestore.batch();

  // 4. Reference to your 'activities' collection
  final CollectionReference activities = firestore.collection('activities');

  // 5. Loop through each selected group
  for (String group in groupList) {
    DocumentReference docRef = activities.doc();

    batch.set(docRef, {
      'group_id': group,
      'type': type,
      'location_name': location,
      'start_time': finalStartTime,
      'end_time': endTime, // Can stay null if not provided
      'signup_url': signupUrl ?? '', // Fallback to empty string
      'description': description ?? '', // Fallback to empty string
      'is_updated': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // 6. Atomic Commit
  try {
    await batch.commit();
    print(
        'QA Log: Successfully created ${groupList.length} activities with full details.');
  } catch (e) {
    print('QA Log ERROR: Error creating batch activities: $e');
    rethrow;
  }
}
