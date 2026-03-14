import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';

import '../config/telnyx_config.dart';

class SipNotifier extends Notifier<void> implements SipUaHelperListener {
  late SIPUAHelper _helper;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  Call? _currentCall;
  bool _muted = false;

  @override
  void build() {
    _helper = SIPUAHelper();
    _helper.addSipUaHelperListener(this);
    ref.onDispose(() {
      _helper.removeSipUaHelperListener(this);
      _helper.stop();
      _localRenderer?.dispose();
      _remoteRenderer?.dispose();
    });
    _connect();
  }

  void _connect() {
    final settings = UaSettings();
    settings.transportType = TransportType.WS;
    settings.webSocketUrl = 'wss://rtc.telnyx.com:443';
    settings.webSocketSettings.extraHeaders = {};
    settings.webSocketSettings.allowBadCertificate = false;
    settings.uri = 'sip:${kTelnyxSipUser}@sip.telnyx.com';
    settings.authorizationUser = kTelnyxSipUser;
    settings.password = kTelnyxSipPassword;
    settings.displayName = kTelnyxCallerName;
    settings.userAgent = 'Kallo/1.0';
    settings.dtmfMode = DtmfMode.RFC2833;
    _helper.start(settings);
  }

  @override
  void callStateChanged(Call call, CallState callState) {
    _currentCall = call;
    switch (callState.state) {
      case CallStateEnum.STREAM:
        _attachStream(callState);
        break;
      case CallStateEnum.CONFIRMED:
        // Audio streams arrive via STREAM events
        break;
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _cleanupAudio();
        _currentCall = null;
        _muted = false;
        break;
      default:
        break;
    }
  }

  Future<void> _attachStream(CallState callState) async {
    _localRenderer ??= RTCVideoRenderer();
    _remoteRenderer ??= RTCVideoRenderer();
    await _localRenderer!.initialize();
    await _remoteRenderer!.initialize();

    if (callState.originator == Originator.local) {
      _localRenderer!.srcObject = callState.stream;
    } else {
      _remoteRenderer!.srcObject = callState.stream;
    }
  }

  void _cleanupAudio() {
    _localRenderer?.srcObject = null;
    _remoteRenderer?.srcObject = null;
  }

  void toggleMute() {
    final call = _currentCall;
    if (call == null) return;
    _muted = !_muted;
    if (_muted) {
      call.mute(true, false);
    } else {
      call.unmute(true, false);
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewReinvite(ReInvite event) {}

  @override
  void registrationStateChanged(RegistrationState state) {
    print('SIP registration: ${state.state}');
  }

  @override
  void transportStateChanged(TransportState state) {
    print('SIP transport: ${state.state}');
  }

  @override
  void onNewNotify(Notify ntf) {}
}

final sipProvider = NotifierProvider<SipNotifier, void>(SipNotifier.new);
