import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'swimmer_profile_avatar_fallback.dart';

/// Web — same deferred base64 decode as IO to avoid jank on navigation.
Widget buildSwimmerProfileAvatar({
  required String? filePath,
  required String? webBase64,
  required String swimmerDisplayName,
  double size = 48,
}) =>
    _SwimmerProfileAvatarWeb(
      webBase64: webBase64,
      swimmerDisplayName: swimmerDisplayName,
      size: size,
    );

class _SwimmerProfileAvatarWeb extends StatefulWidget {
  const _SwimmerProfileAvatarWeb({
    required this.webBase64,
    required this.swimmerDisplayName,
    required this.size,
  });

  final String? webBase64;
  final String swimmerDisplayName;
  final double size;

  @override
  State<_SwimmerProfileAvatarWeb> createState() =>
      _SwimmerProfileAvatarWebState();
}

class _SwimmerProfileAvatarWebState extends State<_SwimmerProfileAvatarWeb> {
  Uint8List? _memoryBytes;
  String _scheduledB64Key = '';

  @override
  void initState() {
    super.initState();
    _kickDecode();
  }

  @override
  void didUpdateWidget(covariant _SwimmerProfileAvatarWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.webBase64 != widget.webBase64) {
      _memoryBytes = null;
      _scheduledB64Key = '';
      _kickDecode();
    }
  }

  void _kickDecode() {
    final b64 = widget.webBase64?.trim() ?? '';
    if (b64.isEmpty) {
      _memoryBytes = null;
      _scheduledB64Key = '';
      return;
    }
    if (_scheduledB64Key == b64 && _memoryBytes != null) {
      return;
    }
    _scheduledB64Key = b64;

    void decode() {
      if (!mounted) {
        return;
      }
      if (_scheduledB64Key != (widget.webBase64?.trim() ?? '')) {
        return;
      }
      try {
        final bytes = base64Decode(_scheduledB64Key);
        if (bytes.isEmpty) {
          if (mounted) {
            setState(() => _memoryBytes = null);
          }
          return;
        }
        if (mounted) {
          setState(() => _memoryBytes = bytes);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _memoryBytes = null);
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduleMicrotask(decode);
    });
  }

  int? _cachePx(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final px = (widget.size * dpr).round();
    return px.clamp(64, 512);
  }

  @override
  Widget build(BuildContext context) {
    if (_memoryBytes != null) {
      final cachePx = _cachePx(context);
      return ClipOval(
        child: Image.memory(
          _memoryBytes!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: cachePx,
          cacheHeight: cachePx,
          errorBuilder: (_, __, ___) =>
              buildSwimmerAvatarInitialsFallback(
            swimmerDisplayName: widget.swimmerDisplayName,
            size: widget.size,
          ),
        ),
      );
    }
    return buildSwimmerAvatarInitialsFallback(
      swimmerDisplayName: widget.swimmerDisplayName,
      size: widget.size,
    );
  }
}
