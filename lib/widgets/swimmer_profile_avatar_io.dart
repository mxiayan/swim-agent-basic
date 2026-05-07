import 'dart:io';

import 'package:flutter/material.dart';

/// Desktop / mobile — local file path when set.
Widget buildSwimmerProfileAvatar({
  required String defaultAssetPath,
  required String? filePath,
  required String? webBase64,
  double size = 48,
}) {
  final p = filePath?.trim() ?? '';
  if (p.isNotEmpty) {
    final f = File(p);
    if (f.existsSync()) {
      return ClipOval(
        child: Image.file(
          f,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _fallbackAsset(defaultAssetPath, size),
        ),
      );
    }
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
