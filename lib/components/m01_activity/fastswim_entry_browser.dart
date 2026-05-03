import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Data returned when the in-app FastSwim browser captures an entry.
class FastSwimCaptureResult {
  const FastSwimCaptureResult({
    required this.orderToken,
    required this.fastSwimMeetId,
    required this.responseBody,
  });

  /// The `orderToken` query parameter from the FastSwim API call.
  final String orderToken;

  /// Numeric FastSwim meet ID extracted from the API URL path (e.g. `10796`).
  final String fastSwimMeetId;

  /// Raw JSON body of the FastSwim API response — captured directly from the
  /// authenticated WebView request so no separate HTTP call is needed.
  final String responseBody;
}

/// Opens the FastSwim entry form in an in-app WebView.
///
/// JavaScript intercepts the FastSwim API response, then shows a persistent
/// bottom bar with a "Sync events to app" / "Re-sync events" button so the
/// user can save their entries without leaving the browser.
class FastSwimEntryBrowser extends StatefulWidget {
  const FastSwimEntryBrowser({
    super.key,
    required this.entryUrl,
    required this.firestoreMeetId,
    required this.uid,
    /// True when the user has previously saved events for this meet, so the
    /// button label reads "Re-sync events" instead of "Sync events to app".
    this.hasExistingEvents = false,
    this.onCaptured,
    /// Called when the user taps the sync button.  The caller is responsible
    /// for parsing + persisting the events and returning when done.
    this.onSync,
  });

  final String entryUrl;
  final String firestoreMeetId;
  final String uid;
  final bool hasExistingEvents;
  final void Function(FastSwimCaptureResult result)? onCaptured;
  final Future<void> Function(FastSwimCaptureResult result)? onSync;

  @override
  State<FastSwimEntryBrowser> createState() => _FastSwimEntryBrowserState();
}

class _FastSwimEntryBrowserState extends State<FastSwimEntryBrowser> {
  late final WebViewController _controller;
  bool _loading = true;
  FastSwimCaptureResult? _captured;
  bool _syncing = false;
  bool _synced = false;

  static const String _interceptJs = r'''
(function() {
  const TARGET_HOST = 'api2.fastswims.com';
  const TOKEN_PARAM = 'orderToken';

  function extractInfo(rawUrl) {
    try {
      const u = new URL(rawUrl, window.location.href);
      if (u.hostname !== TARGET_HOST) return null;
      const token = u.searchParams.get(TOKEN_PARAM);
      if (!token) return null;
      const match = u.pathname.match(/\/meets\/(\d+)\//);
      const meetId = match ? match[1] : '';
      return { token: token, meetId: meetId };
    } catch (_) { return null; }
  }

  function postResult(info, body) {
    if (window.TokenChannel) {
      window.TokenChannel.postMessage(
        JSON.stringify({ token: info.token, meetId: info.meetId, responseBody: body })
      );
    }
  }

  const origFetch = window.fetch.bind(window);
  window.fetch = function(input, init) {
    const url = (typeof input === 'string') ? input : (input && input.url) || '';
    const info = extractInfo(url);
    if (info) {
      return origFetch(input, init).then(function(response) {
        const clone = response.clone();
        clone.text().then(function(body) { postResult(info, body); });
        return response;
      });
    }
    return origFetch(input, init);
  };

  const origOpen = XMLHttpRequest.prototype.open;
  const origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function(method, url) {
    this._fsInfo = extractInfo(typeof url === 'string' ? url : '');
    return origOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function() {
    if (this._fsInfo) {
      const info = this._fsInfo;
      this.addEventListener('load', function() {
        postResult(info, this.responseText);
      });
    }
    return origSend.apply(this, arguments);
  };
})();
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('TokenChannel', onMessageReceived: _onMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) async {
          await _controller.runJavaScript(_interceptJs);
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.entryUrl));
  }

  void _onMessage(JavaScriptMessage msg) {
    try {
      final json = jsonDecode(msg.message) as Map<String, dynamic>;
      final token = (json['token'] as String? ?? '').trim();
      final meetId = (json['meetId'] as String? ?? '').trim();
      final body = (json['responseBody'] as String? ?? '').trim();
      if (token.isEmpty) return;
      if (_captured?.orderToken == token && _captured?.responseBody == body) {
        return;
      }
      final result = FastSwimCaptureResult(
        orderToken: token,
        fastSwimMeetId: meetId,
        responseBody: body,
      );
      // New capture invalidates any previous synced state.
      setState(() {
        _captured = result;
        _synced = false;
      });
      _saveCapture(result);
      widget.onCaptured?.call(result);
    } catch (_) {}
  }

  Future<void> _saveCapture(FastSwimCaptureResult result) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('entered_meets')
          .doc(widget.firestoreMeetId)
          .set({
        'meet_id': widget.firestoreMeetId,
        if (result.fastSwimMeetId.isNotEmpty)
          'fastswim_meet_id': result.fastSwimMeetId,
        'order_token': result.orderToken,
        'token_captured_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _handleSync() async {
    final captured = _captured;
    if (captured == null || _syncing || widget.onSync == null) return;
    setState(() => _syncing = true);
    try {
      await widget.onSync!(captured);
      if (mounted) setState(() => _synced = true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final captured = _captured;
    final isResync = widget.hasExistingEvents || _synced;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text(
          'FastSwim Entry',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(captured),
        ),
      ),
      body: Column(
        children: [
          // Info banner: shown before capture, replaced by sync bar after.
          if (captured == null && !_loading)
            Material(
              color: const Color(0xFF1E3A5F),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14.0, vertical: 10.0),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline_rounded,
                        color: Color(0xFF93C5FD), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Log in to FastSwim to reach your meet entry — '
                        'your token will be saved automatically.',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFFBFDBFE)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Sync bar: shown once the entry data has been captured.
          if (captured != null)
            Material(
              color: _synced
                  ? const Color(0xFF14532D)
                  : const Color(0xFF0F172A),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14.0, vertical: 10.0),
                child: Row(
                  children: [
                    Icon(
                      _synced
                          ? Icons.check_circle_rounded
                          : Icons.cloud_download_rounded,
                      color: _synced
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFF93C5FD),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _synced
                            ? 'Events synced to app!'
                            : isResync
                                ? 'Entry data ready — tap to update your events.'
                                : 'Entry data ready — tap to save your events.',
                        style: GoogleFonts.sora(
                          fontSize: 12,
                          color: _synced
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFBFDBFE),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _synced
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        textStyle: GoogleFonts.sora(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _syncing ? null : _handleSync,
                      child: _syncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isResync && !_synced
                              ? 'Re-sync events'
                              : _synced
                                  ? 'Sync again'
                                  : 'Sync events to app'),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
