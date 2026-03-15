import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/telnyx_config.dart';

class TelnyxSocketService {
  static const _wsUrl = 'wss://rtc.telnyx.com:443';

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  bool _disposed = false;
  String? _sessionId;
  String? get sessionId => _sessionId;

  final _uuid = const Uuid();

  /// Called for every non-login JSON-RPC message received from Telnyx.
  Function(Map<String, dynamic> msg)? onMessage;

  /// Called when login succeeds.
  Function()? onLoggedIn;

  /// Called when the socket disconnects.
  Function()? onDisconnected;

  Future<void> connect() async {
    print('🔥 TelnyxSocketService.connect() called');
    try {
      print('🔥 Creating WebSocket channel...');
      _channel = WebSocketChannel.connect(
        Uri.parse(_wsUrl),
        protocols: ['telnyx-rtc'],
      );
      print('🔥 Channel created, awaiting ready...');
      await _channel!.ready;
      print('🔥 WebSocket ready!');
    } catch (e, stack) {
      print('🔥 WebSocket connection failed: $e\n$stack');
      _handleDisconnect();
      return;
    }
    _sub = _channel!.stream.listen(
      _onRaw,
      onError: (e) {
        debugPrint('TelnyxSocket error: $e');
        _handleDisconnect();
      },
      onDone: () {
        debugPrint('TelnyxSocket closed');
        _handleDisconnect();
      },
    );
    _login();
  }

  void _login() {
    print('🔥 Sending login...');
    sendMessage({
      'jsonrpc': '2.0',
      'id': _uuid.v4(),
      'method': 'login',
      'params': {
        'login': kTelnyxSipUser,
        'passwd': kTelnyxSipPassword,
        'loginParams': {},
        'userVariables': {},
      },
    });
  }

  void _onRaw(dynamic raw) {
    print('🔥 Raw message received: $raw');
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('TelnyxSocket: failed to parse message: $e');
      return;
    }

    // Login response
    final result = msg['result'] as Map<String, dynamic>?;
    if (result?['message'] == 'logged in') {
      _sessionId = result?['sessid'] as String?;
      debugPrint('TelnyxSocket: logged in, sessid: $_sessionId');
      onLoggedIn?.call();
      _startPing();
      return;
    }

    // Pong
    final method = msg['method'] as String?;
    if (method == 'telnyx_rtc.pong') return;

    // Forward everything else to the WebRTC service
    onMessage?.call(msg);
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      sendMessage({
        'jsonrpc': '2.0',
        'id': _uuid.v4(),
        'method': 'telnyx_rtc.ping',
        'params': {},
      });
    });
  }

  void sendMessage(Map<String, dynamic> msg) {
    final json = jsonEncode(msg);
    print('🔥 Sending: $json');
    _channel?.sink.add(json);
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    onDisconnected?.call();
    if (!_disposed) {
      Future.delayed(const Duration(seconds: 5), () {
        if (!_disposed) connect();
      });
    }
  }

  void dispose() {
    _disposed = true;
    _pingTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
  }
}
