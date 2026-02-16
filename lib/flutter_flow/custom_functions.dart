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
