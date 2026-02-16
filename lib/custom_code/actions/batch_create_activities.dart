// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_firestore/cloud_firestore.dart';

Future batchCreateActivities(
  List<String> groupList,
  String type,
  String location,
  DateTime startTime,
) async {
  // 1. Reference to the Firestore Instance
  final firestore = FirebaseFirestore.instance;
  
  // 2. Initialize a WriteBatch (Max 500 operations per batch)
  final WriteBatch batch = firestore.batch();
  
  // 3. Reference to your 'activities' collection
  final CollectionReference activities = firestore.collection('activities');

  // 4. Loop through each selected group from your ChoiceChips
  for (String group in groupList) {
    // Generate a new document reference with a unique ID
    DocumentReference docRef = activities.doc();

    // Add the "Set" operation to the batch
    batch.set(docRef, {
      'group_id': group,           // e.g., 'junior_3'
      'type': type,               // e.g., 'Practice'
      'location_name': location,  // e.g., 'Soda Center'
      'start_time': startTime,    // Firestore converts DateTime to Timestamp automatically
      'is_updated': false,        // Default flag for your logic
      'created_at': FieldValue.serverTimestamp(), // Tracks when you manually entered it
    });
  }

  // 5. Atomic Commit: All documents are created at the exact same time
  try {
    await batch.commit();
    print('Successfully created ${groupList.length} activities.');
  } catch (e) {
    print('Error creating batch activities: $e');
    rethrow; // Pass the error back to FlutterFlow for SnackBar handling
  }
}