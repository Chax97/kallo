import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/placeholder_screen.dart';

class CallLogsScreen extends ConsumerWidget {
  const CallLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PlaceholderScreen(
      title: 'Call Logs',
      subtitle: 'Full history of all inbound and outbound calls across your workspace.',
      icon: Icons.history_rounded,
    );
  }
}
