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
  DateTime? endTime,
  String? signupUrl,
  String? description,
  DateTime? deadline,
) async {
  // 1. Setup Time Variables
  final DateTime rawStart = startTime ?? DateTime.now();

  // Normalize to Midnight for the 'start_time' field (best for daily filtering)
  final DateTime normalizedDate =
      DateTime(rawStart.year, rawStart.month, rawStart.day);

  final firestore = FirebaseFirestore.instance;
  final WriteBatch batch = firestore.batch();
  final CollectionReference activities = firestore.collection('activities');

  // 2. Loop through each group to create/update records
  for (String group in groupList) {
    // 3. Create a Deterministic ID to prevent duplicates
    // Pattern: GroupID_Type_Location_Date_HourMinute
    // Example: Jr1_Practice_Soda_2026216_0630
    String rawId = "${group}_${type}_${location}_"
        "${rawStart.year}${rawStart.month}${rawStart.day}_"
        "${rawStart.hour}${rawStart.minute}";

    // Sanitize ID (Remove spaces/special characters for Firestore compatibility)
    String customId = rawId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');

    // 4. Reference the document with our specific ID
    DocumentReference docRef = activities.doc(customId);

    // 5. Add "Set" operation with "Merge"
    // If this ID already exists, it will simply update the fields
    // instead of creating a second identical entry.
    batch.set(
        docRef,
        {
          'group_id': group,
          'type': type,
          'location_name': location,
          'start_time': normalizedDate, // Normalized for calendar views
          'actual_start_time':
              rawStart, // Exact time for specific practice logic
          'end_time': endTime,
          'signup_url': signupUrl ?? '',
          'description': description ?? '',
          'deadline': deadline,
          'is_updated': false,
          'created_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
  }

  // 6. Commit the Batch
  try {
    await batch.commit();
    print(
        'QA Log: Successfully processed ${groupList.length} activities (ID-verified).');
  } catch (e) {
    print('QA Log ERROR: Batch commit failed: $e');
    rethrow;
  }
}
