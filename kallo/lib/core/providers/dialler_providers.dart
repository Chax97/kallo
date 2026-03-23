import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/call_log.dart';
import 'dart:async';

// ── Nav index (0 = Keypad) ────────────────────────────────────────────────────
class _NavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int v) => state = v;
}

final selectedNavIndexProvider =
    NotifierProvider<_NavIndexNotifier, int>(_NavIndexNotifier.new);

// ── Auto Answer toggle ────────────────────────────────────────────────────────
class _AutoAnswerNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final autoAnswerProvider =
    NotifierProvider<_AutoAnswerNotifier, bool>(_AutoAnswerNotifier.new);

// ── DND toggle ────────────────────────────────────────────────────────────────
class _DndNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final dndProvider =
    NotifierProvider<_DndNotifier, bool>(_DndNotifier.new);

// ── Dialled number string ─────────────────────────────────────────────────────
class _DialledNumberNotifier extends Notifier<String> {
  @override
  String build() => '';
  void append(String digit) => state = state + digit;
  void trimLast() { if (state.isNotEmpty) state = state.substring(0, state.length - 1); }
  void clear() => state = '';
}

final dialledNumberProvider =
    NotifierProvider<_DialledNumberNotifier, String>(_DialledNumberNotifier.new);

// ── Selected caller ID ────────────────────────────────────────────────────────
class _CallerIdNotifier extends Notifier<String> {
  @override
  String build() => '1234';
  void set(String v) => state = v;
}

final callerIdProvider =
    NotifierProvider<_CallerIdNotifier, String>(_CallerIdNotifier.new);

// ── Calls tab index (2 = Recent) ──────────────────────────────────────────────
class _CallsTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 2;
  void set(int v) => state = v;
}

final callsTabIndexProvider =
    NotifierProvider<_CallsTabIndexNotifier, int>(_CallsTabIndexNotifier.new);

// ── Selected call row ─────────────────────────────────────────────────────────
class _SelectedCallIndexNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? v) => state = v;
}

final selectedCallIndexProvider =
    NotifierProvider<_SelectedCallIndexNotifier, int?>(_SelectedCallIndexNotifier.new);

// ── Call history (live from Supabase calls) ───────────────────────────────────
final callHistoryProvider = StreamProvider.autoDispose<List<CallLog>>((ref) {
  final supabase = Supabase.instance.client;

  // Initial fetch + realtime stream
  final controller = StreamController<List<CallLog>>();

  Future<void> fetchLogs() async {
    final response = await supabase
        .from('calls')
        .select()
        // Exclude internal SIP forwarding legs — their to_number is a sip: URI.
        .not('to_number', 'ilike', 'sip:%')
        .order('started_at', ascending: false)
        .limit(200);
    final logs = (response as List)
        .map((e) => CallLog.fromJson(e as Map<String, dynamic>))
        .toList();
    controller.add(logs);
  }

  fetchLogs();

  // Listen for realtime inserts/updates
  final channel = supabase
      .channel('calls_changes')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'calls',
        callback: (_) => fetchLogs(),
      )
      .subscribe();

  ref.onDispose(() {
    supabase.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});
