import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/telnyx_config.dart';

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
  String? _activeCallControlId;
  RealtimeChannel? _callChannel;

  @override
  TxState build() {
    ref.onDispose(_cleanup);
    // REST API — always ready
    return const TxState(connection: TxConnectState.connected);
  }

  void _cleanup() {
    final supabase = Supabase.instance.client;
    if (_callChannel != null) supabase.removeChannel(_callChannel!);
  }

  Future<void> dial(String number) async {
  if (state.call != TxCallState.idle) return;
  state = state.copyWith(call: TxCallState.dialing, activeNumber: number);

  try {
    print('Dialing $number...');
    print('User: ${Supabase.instance.client.auth.currentUser?.id}');
    
    final response = await Supabase.instance.client.functions.invoke(
      'telnyx-call',
      body: {'to': number, 'from': kTelnyxCallerNumber},
    );

    print('Response: ${response.data}');
    print('Status: ${response.status}');

    final callControlId = response.data?['call_control_id'] as String?;
    if (callControlId == null) {
      print('No call_control_id in response');
      _endCall();
      return;
    }

    _activeCallControlId = callControlId;
    state = state.copyWith(call: TxCallState.ringing);
    _watchCall(callControlId);
  } catch (e, stack) {
    print('Dial error: $e');
    print('Stack: $stack');
    _endCall();
  }
}
  void _watchCall(String callControlId) {
    final supabase = Supabase.instance.client;
    if (_callChannel != null) supabase.removeChannel(_callChannel!);

    _callChannel = supabase
        .channel('active_call_$callControlId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'call_logs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'call_control_id',
            value: callControlId,
          ),
          callback: (payload) {
            final newState = payload.newRecord['state'] as String?;
            switch (newState) {
              case 'answered':
                state = state.copyWith(call: TxCallState.active);
              case 'completed':
              case 'missed':
                _endCall();
            }
          },
        )
        .subscribe();
  }

  Future<void> hangup() async {
    final callControlId = _activeCallControlId;
    _endCall();
    if (callControlId != null) {
      try {
        print('Hanging up call: $callControlId');
        final response = await Supabase.instance.client.functions
            .invoke('telnyx-hangup', body: {'call_control_id': callControlId});
        print('Hangup response: ${response.data} status: ${response.status}');
      } catch (e) {
        print('Hangup error: $e');
      }
    } else {
      print('Hangup called but no active call_control_id');
    }
  }

  void _endCall() {
    final supabase = Supabase.instance.client;
    if (_callChannel != null) {
      supabase.removeChannel(_callChannel!);
      _callChannel = null;
    }
    _activeCallControlId = null;
    state = state.copyWith(
      call: TxCallState.idle,
      clearNumber: true,
      muted: false,
    );
  }

  void toggleMute() {
    // No in-app audio with REST API — UI feedback only
    state = state.copyWith(muted: !state.muted);
  }
}

final telnyxProvider =
    NotifierProvider<TelnyxNotifier, TxState>(TelnyxNotifier.new);
