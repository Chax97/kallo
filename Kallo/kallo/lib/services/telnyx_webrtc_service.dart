import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'telnyx_socket_service.dart';

class TelnyxWebRTCService {
  final TelnyxSocketService _socket;
  final _uuid = const Uuid();

  RTCPeerConnection? _peerConnection;
  RTCVideoRenderer? _remoteRenderer;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get hasRemoteRenderer => _remoteRenderer != null;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer!;
  String? _callId;

  // Callbacks
  Function(String callId, String callerNumber)? onIncomingCall;
  Function()? onCallAnswered;
  Function()? onCallEnded;

  TelnyxWebRTCService(this._socket) {
    _socket.onMessage = _handleMessage;
  }

  // ── Handle incoming socket messages ──────────────────────────────────────

  void _handleMessage(Map<String, dynamic> msg) {
    final method = msg['method'] as String?;
    final params = msg['params'] as Map<String, dynamic>?;

    switch (method) {
      case 'telnyx_rtc.invite':
        _handleIncomingCall(params);
        break;
      case 'telnyx_rtc.answer':
        _handleCallAnswered(params);
        break;
      case 'telnyx_rtc.bye':
        _handleCallEnded();
        break;
      case 'telnyx_rtc.media':
        _handleMedia(params);
        break;
    }
  }

  // ── Incoming call ────────────────────────────────────────────────────────

  void _handleIncomingCall(Map<String, dynamic>? params) {
    _callId = params?['callID'] as String?;
    final callerNumber = params?['callerIdNumber'] as String? ?? 'Unknown';
    debugPrint('Incoming call from $callerNumber, callId: $_callId');
    onIncomingCall?.call(_callId ?? '', callerNumber);
  }

  Future<void> acceptCall(String callId, String sdpOffer) async {
    _callId = callId;
    await _setupPeerConnection();
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdpOffer, 'offer'),
    );
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _socket.sendMessage({
      'jsonrpc': '2.0',
      'id': _uuid.v4(),
      'method': 'telnyx_rtc.answer',
      'params': {
        'callID': callId,
        'sdp': answer.sdp,
        'dialogParams': {
          'callID': callId,
        },
      },
    });
  }

  Future<void> declineCall(String callId) async {
    _socket.sendMessage({
      'jsonrpc': '2.0',
      'id': _uuid.v4(),
      'method': 'telnyx_rtc.bye',
      'params': {'callID': callId},
    });
    await _cleanup();
  }

  // ── Outbound call ────────────────────────────────────────────────────────

  Future<String> newCall({
    required String destination,
    required String callerName,
    required String callerNumber,
  }) async {
    print('🔥 WebRTC newCall to $destination');
    _callId = _uuid.v4();
    await _setupPeerConnection();
    print('🔥 PeerConnection set up, creating offer...');

    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await _peerConnection!.setLocalDescription(offer);
    print('🔥 Offer created, waiting for ICE gathering...');

    await _waitForIceGathering();

    final finalDesc = await _peerConnection!.getLocalDescription();
    print('🔥 ICE gathering complete, sending invite...');

    _socket.sendMessage({
      'jsonrpc': '2.0',
      'id': _uuid.v4(),
      'method': 'telnyx_rtc.invite',
      'params': {
        'sessid': _socket.sessionId,
        'sdp': finalDesc!.sdp,
        'dialogParams': {
          'callID': _callId,
          'destination_number': destination,
          'caller_id_name': callerName,
          'caller_id_number': callerNumber,
          'remote_caller_id_name': destination,
          'remote_caller_id_number': destination,
          'audio': true,
          'video': false,
          'useStereo': false,
          'attach': false,
          'screenShare': false,
          'userVariables': {},
        },
      },
    });

    return _callId!;
  }

  Future<void> _waitForIceGathering() async {
    if (_peerConnection == null) return;
    final completer = Completer<void>();

    _peerConnection!.onIceGatheringState = (state) {
      debugPrint('🔥 ICE gathering state: $state');
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        if (!completer.isCompleted) completer.complete();
      }
    };

    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => debugPrint('🔥 ICE gathering timed out, sending anyway'),
    );
  }

  Future<void> hangup() async {
    if (_callId != null) {
      _socket.sendMessage({
        'jsonrpc': '2.0',
        'id': _uuid.v4(),
        'method': 'telnyx_rtc.bye',
        'params': {'callID': _callId},
      });
    }
    await _cleanup();
  }

  // ── Handle answer/media/bye ──────────────────────────────────────────────

  void _handleCallAnswered(Map<String, dynamic>? params) async {
    print('🔥 WebRTC: call answered');
    final sdp = params?['sdp'] as String?;
    if (sdp != null && _peerConnection != null) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, 'answer'),
      );
    }
    onCallAnswered?.call();

    // Log RTP stats after 3 seconds to check if audio is flowing
    Future.delayed(const Duration(seconds: 3), () async {
      if (_peerConnection == null) return;
      final stats = await _peerConnection!.getStats();
      for (final stat in stats) {
        if (stat.type == 'outbound-rtp' || stat.type == 'inbound-rtp') {
          debugPrint('RTP stat [${stat.type}]: ${stat.values}');
        }
      }
    });
  }

  void _handleMedia(Map<String, dynamic>? params) async {
    debugPrint('🔥 telnyx_rtc.media received');
    final sdp = params?['sdp'] as String?;
    final callId = params?['callID'] as String?;
    if (sdp == null || callId == null) return;

    if (_peerConnection != null) {
      // Outbound call: early media (ringback). Just set as remote answer.
      debugPrint('🔥 Early media for outbound call — setting remote description');
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, 'answer'),
      );
      return;
    }

    // No peer connection yet — inbound-initiated media flow.
    _callId = callId;
    await _setupPeerConnection();

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, 'offer'),
    );
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _socket.sendMessage({
      'jsonrpc': '2.0',
      'id': _uuid.v4(),
      'method': 'telnyx_rtc.answer',
      'params': {
        'callID': callId,
        'sdp': answer.sdp,
      },
    });

    onCallAnswered?.call();
  }

  void _handleCallEnded() async {
    print('🔥 WebRTC: call ended');
    await _cleanup();
    onCallEnded?.call();
  }

  // ── Peer connection setup ────────────────────────────────────────────────

  Future<void> _setupPeerConnection() async {
    print('🔥 Setting up PeerConnection...');
    _remoteRenderer = RTCVideoRenderer();
    await _remoteRenderer!.initialize();
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun.telnyx.com:8000'},
        {
          'urls': 'turn:turn.telnyx.com:8000?transport=tcp',
          'username': 'telnyx',
          'credential': 'telnyx2013',
        },
      ],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(config);

    print('🔥 Requesting microphone access...');
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': false,
        'noiseSuppression': false,
        'autoGainControl': false,
      },
      'video': false,
    });
    print('🔥 Microphone granted, adding audio tracks...');

    for (final track in _localStream!.getAudioTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
      debugPrint('Local audio track added: id=${track.id}, enabled=${track.enabled}, muted=${track.muted}, kind=${track.kind}');
    }
    debugPrint('Local audio track count: ${_localStream!.getAudioTracks().length}');

    _peerConnection!.onTrack = (event) {
      if (event.track.kind == 'audio') {
        debugPrint('Remote audio track received');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          _remoteRenderer!.srcObject = event.streams[0];
          debugPrint('Remote stream set: ${_remoteStream?.id}');
          debugPrint('Audio tracks: ${_remoteStream?.getAudioTracks().length}');
          for (final track in _remoteStream!.getAudioTracks()) {
            track.enabled = true;
            debugPrint('Audio track enabled: ${track.id}, muted: ${track.muted}');
          }
        }
      }
    };

    _peerConnection!.onIceCandidate = (candidate) {
      debugPrint('🔥 ICE candidate gathered: ${candidate.candidate}');
    };

    _peerConnection!.onIceConnectionState = (state) {
      debugPrint('ICE connection state: $state');
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint('Peer connection state: $state');
    };

    _peerConnection!.onSignalingState = (state) {
      debugPrint('Signaling state: $state');
    };
  }

  Future<void> _cleanup() async {
    _remoteStream = null;
    _remoteRenderer?.srcObject = null;
    await _remoteRenderer?.dispose();
    _remoteRenderer = null;
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _localStream = null;
    await _peerConnection?.close();
    _peerConnection = null;
    _callId = null;
  }

  void toggleMute() {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !track.enabled;
    });
  }
}
