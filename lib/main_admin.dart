import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin/admin_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://iqzewdhqmpqligwochua.supabase.co',
    anonKey: 'sb_publishable_-3a2oDGKp1K-y7kDOS-Uaw_N8Gm1Lgg'
  );

  runApp(const ProviderScope(child: AdminApp()));
}
