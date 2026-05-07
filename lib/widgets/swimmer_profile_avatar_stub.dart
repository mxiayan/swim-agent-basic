import 'dart:convert';

import 'package:flutter/material.dart';

/// Web — uses optional base64 payload from SharedPreferences.
Widget buildSwimmerProfileAvatar({
  required String defaultAssetPath,
  required String? filePath,
  required String? webBase64,
  double size = 48,
}) {
  final b64 = webBase64?.trim() ?? '';
  if (b64.isNotEmpty) {
    try {
      final bytes = base64Decode(b64);
      if (bytes.isNotEmpty) {
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _fallbackAsset(defaultAssetPath, size),
          ),
        );
      }
    } catch (_) {}
  }
  return _fallbackAsset(defaultAssetPath, size);
}

Widget _fallbackAsset(String assetPath, double size) {
  return ClipOval(
    child: Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        color: const Color(0xFFE8ECF5),
        child: const Icon(Icons.person_rounded, size: 26),
      ),
    ),
  );
}
