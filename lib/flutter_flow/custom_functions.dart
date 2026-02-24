import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'lat_lng.dart';
import 'place.dart';
import 'uploaded_file.dart';
import '/backend/backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/backend/schema/structs/index.dart';

List<bool>? flipBoolAtIndex(
  List<bool>? boolList,
  int? index,
) {
  if (boolList == null || index == null) return null;

  List<bool> result = [];
  for (var i = 0; i < boolList.length; i++) {
    result.add(i == index ? !boolList[i] : boolList[i]);
  }
  return result;
}

List<String>? updateStringAtIndex(
  List<String>? stringList,
  int? index,
  String? text,
) {
  if (stringList == null || index == null || text == null) {
    return null;
  }

  List<String>? updatedStringList = List.from(stringList);
  updatedStringList[index] = text;
  return updatedStringList;
}

bool showDateHeader(
  List<ActivitiesRecord> allActivities,
  int index,
) {
// 1. Safety check: Always show the header for the very first item in the list
  if (index == 0) {
    return true;
  }

  // 2. Get the start_time for the current practice and the previous one
  DateTime? currentTime = allActivities[index].startTime;
  DateTime? previousTime = allActivities[index - 1].startTime;

  // 3. If either time is missing (null), default to showing the header
  if (currentTime == null || previousTime == null) {
    return true;
  }

  // 4. Compare only the Year, Month, and Day.
  // If any of these are different, it's a new day, so return true to show the header.
  return currentTime.year != previousTime.year ||
      currentTime.month != previousTime.month ||
      currentTime.day != previousTime.day;
}

List<ActivitiesRecord>? filterActivitiesByGroup(
  List<ActivitiesRecord>? allActivities,
  List<String>? selectedGroupIds,
) {
// 1. Log the Input Data
  print('QA DEBUG: Input allActivities count: ${allActivities?.length ?? 0}');
  print('QA DEBUG: User selected chips: $selectedGroupIds');

  // Handle null inputs safely
  if (allActivities == null) {
    print('QA DEBUG: allActivities is NULL. Returning empty list.');
    return [];
  }

  // 2. Logic: If no chips selected, return everything
  if (selectedGroupIds == null || selectedGroupIds.isEmpty) {
    print('QA DEBUG: No groups selected. Returning full list.');
    return allActivities;
  }

  // 3. Perform filtering
  // We check if at least one group in the activity's list (groupIds)
  // is present in the user's selected list (selectedGroupIds).
  final filteredList = allActivities.where((activity) {
    // Access the new list field 'groupIds'
    final activityGroups = activity.groupIds ?? [];

    // Check for intersection: returns true if any element matches
    return activityGroups.any((group) => selectedGroupIds.contains(group));
  }).toList();

  // 4. Log the Output Data
  print('QA DEBUG: Filtered list count: ${filteredList.length}');

  return filteredList;
}
