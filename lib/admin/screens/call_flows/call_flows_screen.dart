import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/placeholder_screen.dart';

class CallFlowsScreen extends ConsumerWidget {
  const CallFlowsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PlaceholderScreen(
      title: 'Call Flows',
      subtitle: 'Build IVR menus and routing rules for your incoming calls.',
      icon: Icons.account_tree_outlined,
    );
  }
}
