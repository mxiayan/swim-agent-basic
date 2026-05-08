import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'swimmer_profile_avatar_fallback.dart';

/// Desktop / mobile — decodes photo off the first frame and caches; avoids
/// blocking route transitions and repeated base64 work on every rebuild.
Widget buildSwimmerProfileAvatar({
  required String? filePath,
  required String? webBase64,
  required String swimmerDisplayName,
  double size = 48,
}) =>
    _SwimmerProfileAvatarIo(
      filePath: filePath,
      webBase64: webBase64,
      swimmerDisplayName: swimmerDisplayName,
      size: size,
    );

class _SwimmerProfileAvatarIo extends StatefulWidget {
  const _SwimmerProfileAvatarIo({
    required this.filePath,
    required this.webBase64,
    required this.swimmerDisplayName,
    required this.size,
  });

  final String? filePath;
  final String? webBase64;
  final String swimmerDisplayName;
  final double size;

  @override
  State<_SwimmerProfileAvatarIo> createState() => _SwimmerProfileAvatarIoState();
}

class _SwimmerProfileAvatarIoState extends State<_SwimmerProfileAvatarIo> {
  Uint8List? _memoryBytes;
  String _scheduledB64Key = '';
  bool? _fileExists;
  String _fileCheckPath = '';

  @override
  void initState() {
    super.initState();
    _kickDecode();
    _kickFileCheck();
  }

  @override
  void didUpdateWidget(covariant _SwimmerProfileAvatarIo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.webBase64 != widget.webBase64) {
      _memoryBytes = null;
      _scheduledB64Key = '';
      _kickDecode();
    }
    if (oldWidget.filePath != widget.filePath) {
      _fileExists = null;
      _fileCheckPath = '';
      _kickFileCheck();
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
        if (mounted) {
          setState(() => _memoryBytes = bytes);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _memoryBytes = null);
        }
      }
    }

    // Let the page transition / first layout finish before heavy decode.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduleMicrotask(decode);
    });
  }

  void _kickFileCheck() {
    final p = widget.filePath?.trim() ?? '';
    if (p.isEmpty) {
      _fileExists = null;
      _fileCheckPath = '';
      return;
    }
    _fileCheckPath = p;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduleMicrotask(() {
        if (!mounted || _fileCheckPath != (widget.filePath?.trim() ?? '')) {
          return;
        }
        final ok = File(_fileCheckPath).existsSync();
        if (mounted) {
          setState(() => _fileExists = ok);
        }
      });
    });
  }

  int? _cachePx(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final px = (widget.size * dpr).round();
    return px.clamp(64, 512);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.filePath?.trim() ?? '';
    if (p.isNotEmpty && _fileExists == true) {
      final cachePx = _cachePx(context);
      return ClipOval(
        child: Image.file(
          File(p),
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
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

    final b64 = widget.webBase64?.trim() ?? '';
    if (b64.isNotEmpty && _memoryBytes != null) {
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
