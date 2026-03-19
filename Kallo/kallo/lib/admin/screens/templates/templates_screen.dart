import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/placeholder_screen.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PlaceholderScreen(
      title: 'Templates',
      subtitle: 'Manage reusable templates for schedules, call flows and more.',
      icon: Icons.copy_outlined,
    );
  }
}
