import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalResourcePhoto {
  const LocalResourcePhoto({
    required this.id,
    required this.path,
    required this.createdAt,
  });

  final String id;
  final String path;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'path': path,
        'created_at': createdAt.toIso8601String(),
      };

  static LocalResourcePhoto fromJson(Map<String, dynamic> json) {
    return LocalResourcePhoto(
      id: (json['id'] as String?) ?? '',
      path: (json['path'] as String?) ?? '',
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class LocalSwimVideoEntry {
  const LocalSwimVideoEntry({
    required this.id,
    required this.path,
    this.thumbnailPath = '',
    required this.stroke,
    this.distance = 0,
    this.unit = 'Y',
    this.isLongCourse = false,
    required this.createdAt,
    this.eventLabel = '',
    this.heat = '',
    this.lane = '',
    this.note = '',
  });

  final String id;
  final String path;
  final String thumbnailPath;
  final String stroke;
  final int distance;
  final String unit;
  final bool isLongCourse;
  final DateTime createdAt;
  final String eventLabel;
  final String heat;
  final String lane;
  final String note;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'path': path,
        'thumbnail_path': thumbnailPath,
        'stroke': stroke,
        'distance': distance,
        'unit': unit,
        'is_long_course': isLongCourse,
        'created_at': createdAt.toIso8601String(),
        'event_label': eventLabel,
        'heat': heat,
        'lane': lane,
        'note': note,
      };

  static LocalSwimVideoEntry fromJson(Map<String, dynamic> json) {
    return LocalSwimVideoEntry(
      id: (json['id'] as String?) ?? '',
      path: (json['path'] as String?) ?? '',
      thumbnailPath: (json['thumbnail_path'] as String?) ?? '',
      stroke: (json['stroke'] as String?) ?? '',
      distance: (json['distance'] as num?)?.toInt() ?? 0,
      unit: (json['unit'] as String?) ?? 'Y',
      isLongCourse: json['is_long_course'] as bool? ?? false,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now(),
      eventLabel: (json['event_label'] as String?) ?? '',
      heat: (json['heat'] as String?) ?? '',
      lane: (json['lane'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
    );
  }
}

class LocalMeetMediaStore {
  static String _photosKey(String uid, String meetId, String resourceId) =>
      'local_photos_v1::$uid::$meetId::$resourceId';

  static String _videosKey(String uid, String meetId) =>
      'local_videos_v1::$uid::$meetId';

  static String _enteredEventOrderKey(String uid, String meetId) =>
      'local_entered_event_order_v1::$uid::$meetId';

  static String _strokePresetKey(String uid, String swimmerName) =>
      'local_stroke_presets_v1::$uid::${swimmerName.trim().toLowerCase()}';

  static List<Map<String, dynamic>> _decodeList(String raw) {
    if (raw.trim().isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <Map<String, dynamic>>[];
      }
      return decoded
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  static Future<List<LocalResourcePhoto>> listPhotos(
    String uid,
    String meetId,
    String resourceId, {
    List<String> fallbackResourceIds = const <String>[],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = <String>{resourceId.trim(), ...fallbackResourceIds.map((e) => e.trim())}
      ..removeWhere((e) => e.isEmpty);
    final merged = <String, LocalResourcePhoto>{};
    for (final id in ids) {
      final raw = prefs.getString(_photosKey(uid, meetId, id)) ?? '';
      final items = _decodeList(raw)
          .map(LocalResourcePhoto.fromJson)
          .where((e) => e.path.trim().isNotEmpty);
      for (final photo in items) {
        merged[photo.id] = photo;
      }
    }
    final items = merged.values.toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  static Future<void> savePhotos(
    String uid,
    String meetId,
    String resourceId,
    List<LocalResourcePhoto> photos,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _photosKey(uid, meetId, resourceId),
      jsonEncode(photos.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> clearPhotos(
    String uid,
    String meetId,
    String resourceId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_photosKey(uid, meetId, resourceId));
  }

  static Future<String> copyIntoLocalMedia(String sourcePath, String kind) async {
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(
      '${dir.path}${Platform.pathSeparator}local_media${Platform.pathSeparator}$kind',
    );
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    final src = File(sourcePath);
    if (!await src.exists()) {
      return sourcePath;
    }
    final dot = sourcePath.lastIndexOf('.');
    final ext = dot >= 0 ? sourcePath.substring(dot) : '';
    final name = '${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '' : ext}';
    final target = File('${mediaDir.path}${Platform.pathSeparator}$name');
    await src.copy(target.path);
    return target.path;
  }

  static Future<List<LocalSwimVideoEntry>> listVideos(
    String uid,
    String meetId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_videosKey(uid, meetId)) ?? '';
    final items = _decodeList(raw)
        .map(LocalSwimVideoEntry.fromJson)
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  static Future<void> saveVideos(
    String uid,
    String meetId,
    List<LocalSwimVideoEntry> videos,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _videosKey(uid, meetId),
      jsonEncode(videos.map((e) => e.toJson()).toList()),
    );
  }

  static Future<List<String>> getEnteredEventOrder(
    String uid,
    String meetId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_enteredEventOrderKey(uid, meetId)) ?? '';
    if (raw.trim().isEmpty) {
      return const <String>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <String>[];
      }
      return decoded
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  static Future<void> saveEnteredEventOrder(
    String uid,
    String meetId,
    List<String> orderKeys,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = orderKeys
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await prefs.setString(
      _enteredEventOrderKey(uid, meetId),
      jsonEncode(cleaned),
    );
  }

  static Future<List<String>> getStrokePresets(
    String uid,
    String swimmerName,
  ) async {
    final defaults = <String>[
      'Freestyle',
      'Backstroke',
      'Breaststroke',
      'Butterfly',
      'IM',
    ];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_strokePresetKey(uid, swimmerName)) ?? '';
    final list = _decodeList(raw)
        .map((e) => (e['value'] as String?)?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    return list.isEmpty ? defaults : list;
  }

  static Future<void> saveStrokePresets(
    String uid,
    String swimmerName,
    List<String> strokes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _strokePresetKey(uid, swimmerName),
      jsonEncode(
        strokes
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .map((e) => <String, dynamic>{'value': e})
            .toList(),
      ),
    );
  }
}
