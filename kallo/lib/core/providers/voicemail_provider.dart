import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/voicemail.dart';

// ── Voicemail inbox (live) ────────────────────────────────────────────────────

final voicemailListProvider = StreamProvider.autoDispose<List<Voicemail>>((ref) {
  final supabase = Supabase.instance.client;
  final controller = StreamController<List<Voicemail>>();

  Future<void> fetch() async {
    final rows = await supabase
        .from('voicemails')
        .select()
        .order('created_at', ascending: false);
    controller.add(rows.map((e) => Voicemail.fromJson(e)).toList());
  }

  fetch();

  final channel = supabase
      .channel('voicemails_realtime')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'voicemails',
        callback: (_) => fetch(),
      )
      .subscribe();

  ref.onDispose(() {
    supabase.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

// ── Custom greeting existence ─────────────────────────────────────────────────

const kGreetingPath = 'greetings/custom_greeting.wav';

final greetingExistsProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    final files = await Supabase.instance.client.storage
        .from('voicemails')
        .list(path: 'greetings');
    return files.any((f) => f.name == 'custom_greeting.wav');
  } catch (_) {
    return false;
  }
});
