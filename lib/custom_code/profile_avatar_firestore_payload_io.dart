import 'dart:convert';
import 'dart:io';

Future<String> encodeLocalAvatarToBase64(String path) async {
  final p = path.trim();
  if (p.isEmpty) {
    return '';
  }
  try {
    final f = File(p);
    if (!await f.exists()) {
      return '';
    }
    final bytes = await f.readAsBytes();
    if (bytes.length > 700000) {
      return '';
    }
    return base64Encode(bytes);
  } catch (_) {
    return '';
  }
}
