import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
/// Injected JavaScript intercepts the `fetch` / `XMLHttpRequest` call that the
/// FastSwim web-app makes to `api2.fastswims.com`.  It captures both the URL
/// (giving us the `orderToken` and numeric meet ID) **and the full response
/// body** (giving us the entered-event JSON — with authentication already
/// applied by the browser).  This means no separate HTTP call from Dart is
/// needed and 401 errors are avoided.
class FastSwimEntryBrowser extends StatefulWidget {
  const FastSwimEntryBrowser({
    super.key,
    required this.entryUrl,
    required this.firestoreMeetId,
    required this.uid,
    this.onCaptured,
  });

  final String entryUrl;

  /// Firestore document ID — used only for persisting to
  /// `entered_meets/{firestoreMeetId}`.
  final String firestoreMeetId;
  final String uid;

  /// Called as soon as the token + response body are captured.
  final void Function(FastSwimCaptureResult result)? onCaptured;

  @override
  State<FastSwimEntryBrowser> createState() => _FastSwimEntryBrowserState();
}

class _FastSwimEntryBrowserState extends State<FastSwimEntryBrowser> {
  late final WebViewController _controller;
  bool _loading = true;
  FastSwimCaptureResult? _captured;

  // Intercepts fetch / XHR calls to the FastSwim entry API.
  // Sends { token, meetId, responseBody } back to Flutter via TokenChannel.
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

  // --- Intercept fetch (captures authenticated response) ---
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

  // --- Intercept XMLHttpRequest (captures authenticated response) ---
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
      ..addJavaScriptChannel(
        'TokenChannel',
        onMessageReceived: _onMessage,
      )
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
        return; // duplicate
      }

      final result = FastSwimCaptureResult(
        orderToken: token,
        fastSwimMeetId: meetId,
        responseBody: body,
      );
      setState(() => _captured = result);
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

  @override
  Widget build(BuildContext context) {
    final captured = _captured;
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
        actions: [
          if (captured != null)
            const Padding(
              padding: EdgeInsets.only(right: 12.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF4ADE80), size: 18),
                  SizedBox(width: 4),
                  Text(
                    'Ready to sync',
                    style: TextStyle(fontSize: 13, color: Color(0xFF4ADE80)),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Info banner sits above the WebView — never covers page content.
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
