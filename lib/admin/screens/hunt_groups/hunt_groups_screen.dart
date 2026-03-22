import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/placeholder_screen.dart';

class HuntGroupsScreen extends ConsumerWidget {
  const HuntGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PlaceholderScreen(
      title: 'Hunt Groups',
      subtitle: 'Configure ring groups with simultaneous or sequential strategies.',
      icon: Icons.group_work_outlined,
    );
  }
}
