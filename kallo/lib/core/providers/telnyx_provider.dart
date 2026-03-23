import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sip_provider.dart';

enum TxConnectState { disconnected, connecting, connected, failed }

enum TxCallState { idle, dialing, ringing, active }

class TxState {
  final TxConnectState connection;
  final TxCallState call;
  final String? activeNumber;
  final bool muted;

  const TxState({
    this.connection = TxConnectState.disconnected,
    this.call = TxCallState.idle,
    this.activeNumber,
    this.muted = false,
  });

  TxState copyWith({
    TxConnectState? connection,
    TxCallState? call,
    String? activeNumber,
    bool clearNumber = false,
    bool? muted,
  }) {
    return TxState(
      connection: connection ?? this.connection,
      call: call ?? this.call,
      activeNumber: clearNumber ? null : (activeNumber ?? this.activeNumber),
      muted: muted ?? this.muted,
    );
  }
}

class TelnyxNotifier extends Notifier<TxState> {
  @override
  TxState build() {
    return const TxState(connection: TxConnectState.connected);
  }

  Future<void> dial(String number) async {
    if (state.call != TxCallState.idle) return;
    state = state.copyWith(call: TxCallState.dialing, activeNumber: number);

    try {
      await ref.read(vertoProvider.notifier).dial(number);
      state = state.copyWith(call: TxCallState.ringing);
    } catch (e) {
      print('Dial error: $e');
      _endCall();
    }
  }

  Future<void> hangup() async {
    await ref.read(vertoProvider.notifier).hangup();
    _endCall();
  }

  void _endCall() {
    state = state.copyWith(
      call: TxCallState.idle,
      clearNumber: true,
      muted: false,
    );
  }

  void toggleMute() {
    ref.read(vertoProvider.notifier).toggleMute();
    state = state.copyWith(muted: !state.muted);
  }
}

final telnyxProvider =
    NotifierProvider<TelnyxNotifier, TxState>(TelnyxNotifier.new);
