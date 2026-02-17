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
  // 1. Normalize Start Time to Midnight
  // This ensures consistent querying and avoids the "12:06:02 PM" precision bug.
  final DateTime rawStart = startTime ?? DateTime.now();
  final DateTime finalStartTime =
      DateTime(rawStart.year, rawStart.month, rawStart.day);

  // 2. Reference to the Firestore Instance
  final firestore = FirebaseFirestore.instance;

  // 3. Initialize a WriteBatch (Max 500 operations per batch)
  final WriteBatch batch = firestore.batch();

  // 4. Reference to your 'activities' collection
  final CollectionReference activities = firestore.collection('activities');

  // 5. Loop through each selected group from your ChoiceChips
  for (String group in groupList) {
    // Generate a new document reference with a unique ID
    DocumentReference docRef = activities.doc();

    // Add the "Set" operation to the batch
    batch.set(docRef, {
      'group_id': group,
      'type': type,
      'location_name': location,
      'start_time': finalStartTime,
      'end_time': endTime, // Can be null (standard practice)
      'signup_url': signupUrl ?? '', // Ensure it's never a null-break in UI
      'description': description ?? '', // Ensure it's never a null-break in UI
      'deadline': deadline, // Can be null
      'is_updated': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // 6. Atomic Commit
  try {
    await batch.commit();
    print(
        'QA Log: Successfully created ${groupList.length} activities for type: $type.');
  } catch (e) {
    print('QA Log ERROR: Error creating batch activities: $e');
    // Rethrow allows FlutterFlow's "On Failure" action path to trigger
    rethrow;
  }
}
