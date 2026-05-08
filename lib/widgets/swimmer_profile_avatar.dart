import 'package:flutter/material.dart';

import 'swimmer_profile_avatar_stub.dart'
    if (dart.library.io) 'swimmer_profile_avatar_io.dart' as impl;

Widget buildSwimmerProfileAvatar({
  required String? filePath,
  required String? webBase64,
  required String swimmerDisplayName,
  double size = 48,
}) =>
    impl.buildSwimmerProfileAvatar(
      filePath: filePath,
      webBase64: webBase64,
      swimmerDisplayName: swimmerDisplayName,
      size: size,
    );
