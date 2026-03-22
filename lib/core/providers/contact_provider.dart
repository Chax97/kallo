import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';

final contactsProvider = StreamProvider.autoDispose<List<Contact>>((ref) {
  final supabase = Supabase.instance.client;
  final controller = StreamController<List<Contact>>();

  Future<void> fetch() async {
    final rows = await supabase
        .from('phonebook_contacts')
        .select()
        .order('name', ascending: true);
    controller.add(rows.map((e) => Contact.fromJson(e)).toList());
  }

  fetch();

  final channel = supabase
      .channel('phonebook_contacts_realtime')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'phonebook_contacts',
        callback: (_) => fetch(),
      )
      .subscribe();

  ref.onDispose(() {
    supabase.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});
