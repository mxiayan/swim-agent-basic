import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../flutter_flow/flutter_flow_util.dart';
import 'schema/util/firestore_util.dart';

import 'schema/teams_record.dart';
import 'schema/activities_record.dart';
import 'schema/groups_record.dart';
import 'schema/swimmer_record.dart';
import 'schema/metadata_clubs_record.dart';
import 'schema/monitored_meets_record.dart';

export 'dart:async' show StreamSubscription;
export 'package:cloud_firestore/cloud_firestore.dart' hide Order;
export 'package:firebase_core/firebase_core.dart';
export 'schema/index.dart';
export 'schema/util/firestore_util.dart';
export 'schema/util/schema_util.dart';

export 'schema/teams_record.dart';
export 'schema/activities_record.dart';
export 'schema/groups_record.dart';
export 'schema/swimmer_record.dart';
export 'schema/metadata_clubs_record.dart';
export 'schema/monitored_meets_record.dart';

/// Functions to query TeamsRecords (as a Stream and as a Future).
Future<int> queryTeamsRecordCount({
  Query Function(Query)? queryBuilder,
  int limit = -1,
}) =>
    queryCollectionCount(
      TeamsRecord.collection,
      queryBuilder: queryBuilder,
      limit: limit,
    );

Stream<List<TeamsRecord>> queryTeamsRecord({
  Query Function(Query)? queryBuilder,
  int limit = -1,
  bool singleRecord = false,
}) =>
    queryCollection(
      TeamsRecord.collection,
      TeamsRecord.fromSnapshot,
      queryBuilder: queryBuilder,
      limit: limit,
      singleRecord: singleRecord,
    );

Future<List<TeamsRecord>> queryTeamsRecordOnce({
  Query Function(Query)? queryBuilder,
  int limit = -1,
  bool singleRecord = false,
}) =>
    queryCollectionOnce(
      TeamsRecord.collection,
      TeamsRecord.fromSnapshot,
      queryBuilder: queryBuilder,
      limit: limit,
      singleRecord: singleRecord,
    );

/// Functions to query ActivitiesRecords (as a Stream and as a Future).
Future<int> queryActivitiesRecordCount({
  Query Function(Query)? queryBuilder,
  int limit = -1,
}) =>
    queryCollectionCount(
      ActivitiesRecord.collection,
      queryBuilder: queryBuilder,
      limit: limit,
    );

Stream<List<ActivitiesRecord>> queryActivitiesRecord({
  Query Function(Query)? queryBuilder,
  int limit = -1,
  bool singleRecord = false,
}) =>
    queryCollection(
      ActivitiesRecord.collection,
      ActivitiesRecord.fromSnapshot,
      queryBuilder: queryBuilder,
      limit: limit,
      singleRecord: singleRecord,
    );

Future<List<ActivitiesRecord>> queryActivitiesRecordOnce({
  Query Function(Query)? queryBuilder,
  int limit = -1,
  bool singleRecord = false,
}) =>
    queryCollectionOnce(
      ActivitiesRecord.collection,
      ActivitiesRecord.fromSnapshot,
      queryBuilder: queryBuilder,
      limit: limit,
      singleRecord: singleRecord,
    );

/// Functions to query GroupsRecords (as a Stream and as a Future).
Future<int> queryGroupsRecordCount({
  Query Function(Query)? queryBuilder,
  int limit = -1,
}) =>
    queryCollectionCount(
      GroupsRecord.collection,
      queryBuilder: queryBuilder,
      limit: limit,
    );

Stream<List<GroupsRecord>> queryGroupsRecord({
  Query Function(Query)? queryBuilder,
  int limit = -1,
  bool singleRecord = false,
}) =>
    queryCollection(
      GroupsRecord.collection,
      GroupsRecord.fromSnapshot,
      queryBuilder: queryBuilder,
      limit: limit,
      singleRecord: singleRecord,
    );

Future<List<GroupsRecord>> queryGroupsRecordOnce({
  Query Function(Query)? queryBuilder,
  int limit = -1,
  bool singleRecord = false,
}) =>
    queryCollectionOnce(
      GroupsRecord.collection,
      GroupsRecord.fromSnapshot,
      queryBuilder: queryBuilder,
      limit: limit,
      singleRecord: singleRecord,
    );

/// Swimmer profile (document id = Firebase Auth uid).
Future<int> querySwimmerRecordCount({
  Query Function(Query)? queryBuilder,
  int limit = -1,
}) =>
    queryCollectionCount(
      SwimmerRecord.collection,
      queryBuilder: queryBuilder,
      limit: limit,
    );

Stream<List<SwimmerRecord>> querySwimmerRecord({
  Query Function(Query)? queryBuilder,
  int limit = -1,
  bool singleRecord = false,
}) =>
    queryCollection(
      SwimmerRecord.collection,
      SwimmerRecord.fromSnapshot,
      queryBuilder: queryBuilder,
      limit: limit,
      singleRecord: singleRecord,
    );

Future<List<SwimmerRecord>> querySwimmerRecordOnce({
  Query Function(Query)? queryBuilder,
  int limit = -1,
  bool singleRecord = false,
}) =>
    queryCollectionOnce(
      SwimmerRecord.collection,
      SwimmerRecord.fromSnapshot,
      queryBuilder: queryBuilder,
      limit: limit,
      singleRecord: singleRecord,
    );

/// Pacific Swimming club → zone metadata.
Future<int> queryMetadataClubsRecordCount({
  Query Function(Query)? queryBuilder,
  int limit = -1,
}) =>
    queryCollectionCount(
      MetadataClubsRecord.collection,
      queryBuilder: queryBuilder,
      limit: limit,
    );

Stream<List<MetadataClubsRecord>> queryMetadataClubsRecord({
  Query Function(Query)? queryBuilder,
  int limit = -1,
  bool singleRecord = false,
}) =>
    queryCollection(
      MetadataClubsRecord.collection,
      MetadataClubsRecord.fromSnapshot,
      queryBuilder: queryBuilder,
      limit: limit,
      singleRecord: singleRecord,
    );

Future<List<MetadataClubsRecord>> queryMetadataClubsRecordOnce({
  Query Function(Query)? queryBuilder,
  int limit = -1,
  bool singleRecord = false,
}) =>
    queryCollectionOnce(
      MetadataClubsRecord.collection,
      MetadataClubsRecord.fromSnapshot,
      queryBuilder: queryBuilder,
      limit: limit,
      singleRecord: singleRecord,
    );

/// Monitored meets (filter by meet_zone in UI or queryBuilder).
Future<int> queryMonitoredMeetsRecordCount({
  Query Function(Query)? queryBuilder,
  int limit = -1,
}) =>
    queryCollectionCount(
      MonitoredMeetsRecord.collection,
      queryBuilder: queryBuilder,
      limit: limit,
    );

Stream<List<MonitoredMeetsRecord>> queryMonitoredMeetsRecord({
  Query Function(Query)? queryBuilder,
  int limit = -1,
  bool singleRecord = false,
}) =>
    queryCollection(
      MonitoredMeetsRecord.collection,
      MonitoredMeetsRecord.fromSnapshot,
      queryBuilder: queryBuilder,
      limit: limit,
      singleRecord: singleRecord,
    );

Future<List<MonitoredMeetsRecord>> queryMonitoredMeetsRecordOnce({
  Query Function(Query)? queryBuilder,
  int limit = -1,
  bool singleRecord = false,
}) =>
    queryCollectionOnce(
      MonitoredMeetsRecord.collection,
      MonitoredMeetsRecord.fromSnapshot,
      queryBuilder: queryBuilder,
      limit: limit,
      singleRecord: singleRecord,
    );

String _normZoneKey(String z) => z.trim().toUpperCase();

/// Canonical Pacific zone so `Z2`, `Z02`, and parsed meet fields compare equal.
String canonicalPacificZoneId(String z) {
  final t = _normZoneKey(z);
  final m = RegExp(r'^Z(\d+)([NSEW]?)$').firstMatch(t);
  if (m == null) {
    return t;
  }
  final n = int.tryParse(m.group(1)!);
  if (n == null) {
    return t;
  }
  return 'Z$n${m.group(2) ?? ''}';
}

/// Values for Firestore `whereIn('region_id', ...)` (max 10); matches PC_Z2, PC-Z2, etc.
List<String> pacificZoneRegionIdsForWhereIn(String canonicalZone) {
  final z = canonicalPacificZoneId(canonicalZone);
  final m = RegExp(r'^Z(\d+)([NSEW]?)$').firstMatch(z);
  if (m == null) {
    return const [];
  }
  final n = m.group(1)!;
  final suf = (m.group(2) ?? '').toUpperCase();
  final mid = 'Z$n$suf';
  return <String>{
    'PC_$mid',
    'PC-$mid',
    'PC_$mid'.toLowerCase(),
    'PC-$mid'.toLowerCase(),
  }.toList();
}

List<MonitoredMeetsRecord> _filterSortMeetsForZone(
  Iterable<MonitoredMeetsRecord> meets, {
  required String wantCanonical,
  required String priorityHostGroup,
}) {
  final filtered = meets.where((m) {
    final mz = canonicalPacificZoneId(m.meetZone);
    return mz.isNotEmpty && mz == wantCanonical;
  }).toList();

  final hostWant = priorityHostGroup.trim();
  filtered.sort((a, b) {
    final aHome =
        hostWant.isNotEmpty && a.hostGroup.trim() == hostWant ? 0 : 1;
    final bHome =
        hostWant.isNotEmpty && b.hostGroup.trim() == hostWant ? 0 : 1;
    if (aHome != bHome) {
      return aHome.compareTo(bHome);
    }
    final ad = a.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bd = b.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    return ad.compareTo(bd);
  });
  return filtered;
}

Stream<List<MonitoredMeetsRecord>> _mergeMonitoredMeetStreams(
  List<Stream<List<MonitoredMeetsRecord>>> streams,
  List<MonitoredMeetsRecord> Function(List<MonitoredMeetsRecord> merged) project,
) {
  if (streams.isEmpty) {
    return Stream.value(project(<MonitoredMeetsRecord>[]));
  }
  final latest = List<List<MonitoredMeetsRecord>?>.generate(
      streams.length, (_) => null);
  StreamController<List<MonitoredMeetsRecord>>? controller;
  final subs = <StreamSubscription<List<MonitoredMeetsRecord>>>[];

  void emit(StreamController<List<MonitoredMeetsRecord>> c) {
    final byPath = <String, MonitoredMeetsRecord>{};
    for (final list in latest) {
      if (list == null) {
        continue;
      }
      for (final m in list) {
        byPath[m.reference.path] = m;
      }
    }
    if (!c.isClosed) {
      c.add(project(byPath.values.toList()));
    }
  }

  controller = StreamController<List<MonitoredMeetsRecord>>(
    onListen: () {
      final c = controller;
      if (c == null) {
        return;
      }
      for (var i = 0; i < streams.length; i++) {
        final idx = i;
        subs.add(
          streams[i].listen(
            (data) {
              latest[idx] = data;
              emit(c);
            },
            onError: c.addError,
          ),
        );
      }
    },
    onCancel: () {
      for (final s in subs) {
        s.cancel();
      }
      subs.clear();
    },
  );
  return controller.stream;
}

/// Meets for a zone, sorted: host group first, then by start time.
///
/// Uses server-side `region_id` / `meet_zone` filters when possible so Z2 meets
/// are not dropped just because they are outside the first N collection docs.
Stream<List<MonitoredMeetsRecord>> streamMonitoredMeetsForSwimmer({
  required String zoneId,
  required String priorityHostGroup,
  int meetFetchLimit = 500,
}) {
  if (zoneId.isEmpty) {
    return Stream.value(<MonitoredMeetsRecord>[]);
  }
  final want = canonicalPacificZoneId(zoneId);
  final hostWant = priorityHostGroup.trim();

  List<MonitoredMeetsRecord> project(List<MonitoredMeetsRecord> merged) =>
      _filterSortMeetsForZone(
        merged,
        wantCanonical: want,
        priorityHostGroup: hostWant,
      );

  final regionVals = pacificZoneRegionIdsForWhereIn(want);
  if (regionVals.isEmpty) {
    final cap = meetFetchLimit < 2500 ? 2500 : meetFetchLimit;
    return queryMonitoredMeetsRecord(
      limit: cap,
    ).map(project);
  }

  final byRegion = queryMonitoredMeetsRecord(
    queryBuilder: (q) => q.where('region_id', whereIn: regionVals),
    limit: meetFetchLimit,
  );
  final byMeetZone = queryMonitoredMeetsRecord(
    queryBuilder: (q) => q.where('meet_zone', isEqualTo: want),
    limit: meetFetchLimit,
  );

  return _mergeMonitoredMeetStreams([byRegion, byMeetZone], project);
}

Future<int> queryCollectionCount(
  Query collection, {
  Query Function(Query)? queryBuilder,
  int limit = -1,
}) {
  final builder = queryBuilder ?? (q) => q;
  var query = builder(collection);
  if (limit > 0) {
    query = query.limit(limit);
  }

  return query.count().get().catchError((err) {
    print('Error querying $collection: $err');
  }).then((value) => value.count!);
}

Stream<List<T>> queryCollection<T>(
  Query collection,
  RecordBuilder<T> recordBuilder, {
  Query Function(Query)? queryBuilder,
  int limit = -1,
  bool singleRecord = false,
}) {
  final builder = queryBuilder ?? (q) => q;
  var query = builder(collection);
  if (limit > 0 || singleRecord) {
    query = query.limit(singleRecord ? 1 : limit);
  }
  return query.snapshots().handleError((err) {
    print('Error querying $collection: $err');
  }).map((s) => s.docs
      .map(
        (d) => safeGet(
          () => recordBuilder(d),
          (e) => print('Error serializing doc ${d.reference.path}:\n$e'),
        ),
      )
      .where((d) => d != null)
      .map((d) => d!)
      .toList());
}

Future<List<T>> queryCollectionOnce<T>(
  Query collection,
  RecordBuilder<T> recordBuilder, {
  Query Function(Query)? queryBuilder,
  int limit = -1,
  bool singleRecord = false,
}) {
  final builder = queryBuilder ?? (q) => q;
  var query = builder(collection);
  if (limit > 0 || singleRecord) {
    query = query.limit(singleRecord ? 1 : limit);
  }
  return query.get().then((s) => s.docs
      .map(
        (d) => safeGet(
          () => recordBuilder(d),
          (e) => print('Error serializing doc ${d.reference.path}:\n$e'),
        ),
      )
      .where((d) => d != null)
      .map((d) => d!)
      .toList());
}

Filter filterIn(String field, List? list) => (list?.isEmpty ?? true)
    ? Filter(field, whereIn: null)
    : Filter(field, whereIn: list);

Filter filterArrayContainsAny(String field, List? list) =>
    (list?.isEmpty ?? true)
        ? Filter(field, arrayContainsAny: null)
        : Filter(field, arrayContainsAny: list);

extension QueryExtension on Query {
  Query whereIn(String field, List? list) => (list?.isEmpty ?? true)
      ? where(field, whereIn: null)
      : where(field, whereIn: list);

  Query whereNotIn(String field, List? list) => (list?.isEmpty ?? true)
      ? where(field, whereNotIn: null)
      : where(field, whereNotIn: list);

  Query whereArrayContainsAny(String field, List? list) =>
      (list?.isEmpty ?? true)
          ? where(field, arrayContainsAny: null)
          : where(field, arrayContainsAny: list);
}

class FFFirestorePage<T> {
  final List<T> data;
  final Stream<List<T>>? dataStream;
  final QueryDocumentSnapshot? nextPageMarker;

  FFFirestorePage(this.data, this.dataStream, this.nextPageMarker);
}

Future<FFFirestorePage<T>> queryCollectionPage<T>(
  Query collection,
  RecordBuilder<T> recordBuilder, {
  Query Function(Query)? queryBuilder,
  DocumentSnapshot? nextPageMarker,
  required int pageSize,
  required bool isStream,
}) async {
  final builder = queryBuilder ?? (q) => q;
  var query = builder(collection).limit(pageSize);
  if (nextPageMarker != null) {
    query = query.startAfterDocument(nextPageMarker);
  }
  Stream<QuerySnapshot>? docSnapshotStream;
  QuerySnapshot docSnapshot;
  if (isStream) {
    docSnapshotStream = query.snapshots();
    docSnapshot = await docSnapshotStream.first;
  } else {
    docSnapshot = await query.get();
  }
  final getDocs = (QuerySnapshot s) => s.docs
      .map(
        (d) => safeGet(
          () => recordBuilder(d),
          (e) => print('Error serializing doc ${d.reference.path}:\n$e'),
        ),
      )
      .where((d) => d != null)
      .map((d) => d!)
      .toList();
  final data = getDocs(docSnapshot);
  final dataStream = docSnapshotStream?.map(getDocs);
  final nextPageToken = docSnapshot.docs.isEmpty ? null : docSnapshot.docs.last;
  return FFFirestorePage(data, dataStream, nextPageToken);
}
