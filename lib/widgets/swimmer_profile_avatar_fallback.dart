import 'package:flutter/material.dart';

import 'swimmer_display_initials.dart';

/// Default avatar when no custom photo: initials in a soft circle, else person icon.
Widget buildSwimmerAvatarInitialsFallback({
  required String swimmerDisplayName,
  required double size,
}) {
  final initials = swimmerDisplayInitials(swimmerDisplayName);
  if (initials.isEmpty) {
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFE8ECF5),
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded, size: size * 0.52, color: const Color(0xFF5C6370)),
      ),
    );
  }
  final fontSize = initials.length >= 2 ? size * 0.34 : size * 0.4;
  return ClipOval(
    child: Container(
      width: size,
      height: size,
      color: const Color(0xFFE8ECF5),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF2D3142),
          letterSpacing: initials.length >= 2 ? -0.6 : 0,
          height: 1,
        ),
      ),
    ),
  );
}
