import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/placeholder_screen.dart';

class IntegrationsScreen extends ConsumerWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PlaceholderScreen(
      title: 'Integrations',
      subtitle: 'Connect third-party services and manage API integrations.',
      icon: Icons.extension_outlined,
    );
  }
}
