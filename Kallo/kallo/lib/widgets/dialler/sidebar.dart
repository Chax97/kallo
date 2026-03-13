import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/dialler_providers.dart';

class DiallerSidebar extends ConsumerWidget {
  const DiallerSidebar({super.key});

  static const _navItems = [
    (icon: Icons.dialpad, label: 'Keypad'),
    (icon: Icons.video_camera_front_outlined, label: 'Meeting'),
    (icon: Icons.history, label: 'Recents'),
    (icon: Icons.contacts_outlined, label: 'Contacts'),
    (icon: Icons.chat_bubble_outline, label: 'Chats'),
    (icon: Icons.message_outlined, label: 'Messages'),
    (icon: Icons.account_circle_outlined, label: 'Account'),
    (icon: Icons.link, label: 'Link 1'),
    (icon: Icons.link, label: 'Link 2'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);

    return Container(
      width: 72,
      color: const Color(0xFF16213E),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Logo
          Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_in_talk,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(height: 5),
              Text(
                'kallo',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1, indent: 8, endIndent: 8),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                return _NavItem(
                  icon: item.icon,
                  label: item.label,
                  isSelected: index == selectedIndex,
                  onTap: () =>
                      ref.read(selectedNavIndexProvider.notifier).set(index),
                );
              },
            ),
          ),
          const Divider(color: Colors.white12, height: 1, indent: 8, endIndent: 8),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isSelected: selectedIndex == 9,
            onTap: () => ref.read(selectedNavIndexProvider.notifier).set(9),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: active
                ? const Color(0xFF6C63FF).withValues(alpha: 0.2)
                : _hovered
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: active ? const Color(0xFF6C63FF) : Colors.white54,
                size: 21,
              ),
              const SizedBox(height: 3),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: active
                      ? const Color(0xFF6C63FF)
                      : Colors.white38,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
