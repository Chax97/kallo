import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/telnyx_config.dart';
import '../services/telnyx_socket_service.dart';
import '../services/telnyx_webrtc_service.dart';

enum VertoCallState { idle, dialing, ringing, inbound, active }

class VertoState {
  final bool connected;
  final bool loggedIn;
  final VertoCallState call;
  final String? activeNumber;
  final String? inboundCallerNumber;
  final bool muted;

  const VertoState({
    this.connected = false,
    this.loggedIn = false,
    this.call = VertoCallState.idle,
    this.activeNumber,
    this.inboundCallerNumber,
    this.muted = false,
  });

  VertoState copyWith({
    bool? connected,
    bool? loggedIn,
    VertoCallState? call,
    String? activeNumber,
    String? inboundCallerNumber,
    bool clearNumber = false,
    bool? muted,
  }) {
    return VertoState(
      connected: connected ?? this.connected,
      loggedIn: loggedIn ?? this.loggedIn,
      call: call ?? this.call,
      activeNumber: clearNumber ? null : (activeNumber ?? this.activeNumber),
      inboundCallerNumber: inboundCallerNumber ?? this.inboundCallerNumber,
      muted: muted ?? this.muted,
    );
  }
}

class VertoNotifier extends Notifier<VertoState> {
  late TelnyxSocketService _socket;
  late TelnyxWebRTCService _webrtc;

  @override
  VertoState build() {
    _socket = TelnyxSocketService();
    _webrtc = TelnyxWebRTCService(_socket);

    _socket.onLoggedIn = () {
      state = state.copyWith(connected: true, loggedIn: true);
    };

    _socket.onDisconnected = () {
      state = state.copyWith(connected: false, loggedIn: false);
    };

    _webrtc.onCallAnswered = () {
      state = state.copyWith(call: VertoCallState.active);
    };

    _webrtc.onIncomingCall = (callId, callerNumber) {
      state = state.copyWith(
        call: VertoCallState.inbound,
        inboundCallerNumber: callerNumber,
      );
    };

    _webrtc.onCallEnded = () {
      state = state.copyWith(
        call: VertoCallState.idle,
        clearNumber: true,
        muted: false,
      );
    };

    ref.onDispose(() {
      _webrtc.hangup();
      _socket.dispose();
    });

    _socket.connect();
    return const VertoState();
  }

  bool get hasRemoteRenderer => _webrtc.hasRemoteRenderer;
  RTCVideoRenderer get remoteRenderer => _webrtc.remoteRenderer;

  Future<void> dial(String number) async {
    if (state.call != VertoCallState.idle || !state.loggedIn) return;

    String formatted = number.replaceAll(RegExp(r'[\s\-]'), '');
    if (formatted.startsWith('0')) formatted = '+61${formatted.substring(1)}';
    if (!formatted.startsWith('+')) formatted = '+$formatted';

    state = state.copyWith(call: VertoCallState.dialing, activeNumber: number);
    try {
      await _webrtc.newCall(
        destination: formatted,
        callerName: kTelnyxCallerName,
        callerNumber: kTelnyxCallerNumber,
      );
      state = state.copyWith(call: VertoCallState.ringing);
    } catch (e) {
      debugPrint('WebRTC dial error: $e');
      state = state.copyWith(call: VertoCallState.idle, clearNumber: true);
    }
  }

  Future<void> acceptCall() async {
    // Transition immediately so ring screen dismisses on first tap
    state = state.copyWith(call: VertoCallState.active);

    // Mark call as answered by app before WebRTC negotiation so the
    // voicemail webhook sees answered_by = 'app' on call.answered
    final callControlId = _webrtc.inboundCallControlId;
    if (callControlId != null) {
      final err = await Supabase.instance.client
          .from('call_logs')
          .update({'answered_by': 'app'})
          .eq('call_control_id', callControlId)
          .then((_) => null, onError: (e) => e);
      if (err != null) debugPrint('acceptCall: DB update error: $err');
    }

    await _webrtc.acceptCall();
  }

  Future<void> declineCall() async {
    // Update state immediately so UI dismisses on first press
    state = state.copyWith(
      call: VertoCallState.idle,
      clearNumber: true,
      muted: false,
    );
    // Hang up the Call Control leg FIRST (awaited) so Telnyx stops retrying
    // before the WebSocket bye is sent
    final callControlId = _webrtc.inboundCallControlId;
    if (callControlId != null) {
      try {
        await Supabase.instance.client.functions.invoke(
          'telnyx-hangup',
          body: {'call_control_id': callControlId},
        );
        debugPrint('Call Control decline sent for $callControlId');
      } catch (e) {
        debugPrint('Call Control decline error: $e');
      }
    }
    await _webrtc.declineCall();
  }

  Future<void> hangup() async {
    // Also hang up via Call Control API if we have a control ID
    final callControlId = _webrtc.activeCallControlId;
    if (callControlId != null) {
      try {
        await Supabase.instance.client.functions.invoke(
          'telnyx-hangup',
          body: {'call_control_id': callControlId},
        );
      } catch (e) {
        debugPrint('Call Control hangup error: $e');
      }
    }
    await _webrtc.hangup();
    state = state.copyWith(
      call: VertoCallState.idle,
      clearNumber: true,
      muted: false,
    );
  }

  void toggleMute() {
    _webrtc.toggleMute();
    state = state.copyWith(muted: !state.muted);
  }
}

final vertoProvider =
    NotifierProvider<VertoNotifier, VertoState>(VertoNotifier.new);

/// Eagerly initialises Telnyx audio on all platforms.
final telnyxAudioProvider = Provider<void>((ref) {
  ref.watch(vertoProvider);
});
