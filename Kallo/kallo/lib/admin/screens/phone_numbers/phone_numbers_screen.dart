import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/placeholder_screen.dart';

class PhoneNumbersScreen extends ConsumerWidget {
  const PhoneNumbersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PlaceholderScreen(
      title: 'Phone Numbers',
      subtitle: 'Manage your DIDs, assign numbers to agents or call flows.',
      icon: Icons.phone_outlined,
    );
  }
}
