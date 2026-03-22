import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/dialler_providers.dart';
import '../../main.dart' show AuthScreen;

class KalloSidebar extends ConsumerWidget {
  const KalloSidebar({super.key});

  static const _navItems = [
    _NavItemData(icon: Icons.phone_outlined, label: 'Calls', index: 0),
    _NavItemData(icon: Icons.voicemail, label: 'Voicemail', index: 1),
    _NavItemData(icon: Icons.contacts_outlined, label: 'Contacts', index: 2),
    _NavItemData(icon: Icons.bar_chart_outlined, label: 'Analytics', index: 3),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final displayName = user?.userMetadata?['full_name'] as String? ?? user?.email ?? 'User';
    final initials = _initials(displayName);

    return Container(
      width: 64,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A10),
        border: Border(right: BorderSide(color: Color(0xFF1E1E2E), width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // ── Logo ───────────────────────────────────────────────────
          Tooltip(
            message: 'Kallo',
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF5B52E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.phone_in_talk, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: const Color(0xFF1E1E2E), margin: const EdgeInsets.symmetric(horizontal: 10)),
          const SizedBox(height: 12),
          // ── Nav items ──────────────────────────────────────────────
          ...List.generate(_navItems.length, (i) {
            final item = _navItems[i];
            final isSelected = selectedIndex == item.index;
            return _SidebarNavItem(
              icon: item.icon,
              label: item.label,
              isSelected: isSelected,
              onTap: () => ref.read(selectedNavIndexProvider.notifier).set(item.index),
            );
          }),
          const Spacer(),
          Container(height: 1, color: const Color(0xFF1E1E2E), margin: const EdgeInsets.symmetric(horizontal: 10)),
          const SizedBox(height: 8),
          // ── Settings ───────────────────────────────────────────────
          _SidebarNavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isSelected: selectedIndex == 9,
            onTap: () => ref.read(selectedNavIndexProvider.notifier).set(9),
          ),
          const SizedBox(height: 8),
          // ── Avatar ────────────────────────────────────────────────
          _AvatarMenuButton(
            displayName: displayName,
            initials: initials,
            avatarUrl: avatarUrl,
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'K';
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  final int index;
  const _NavItemData({required this.icon, required this.label, required this.index});
}

class _AvatarMenuButton extends StatelessWidget {
  final String displayName;
  final String initials;
  final String? avatarUrl;

  const _AvatarMenuButton({
    required this.displayName,
    required this.initials,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: PopupMenuButton<String>(
        offset: const Offset(64, 0),
        color: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (value) async {
          if (value == 'sign_out') {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            }
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              displayName,
              style: GoogleFonts.dmSans(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'sign_out',
            child: Row(
              children: [
                const Icon(Icons.logout, size: 16, color: Color(0xFFEF4444)),
                const SizedBox(width: 8),
                Text(
                  'Sign out',
                  style: GoogleFonts.dmSans(color: const Color(0xFFEF4444), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
        child: CircleAvatar(
          radius: 16,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          backgroundColor: const Color(0xFF5B52E8),
          child: avatarUrl == null
              ? Text(initials, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))
              : null,
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.label,
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            width: 48,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: widget.isSelected
                  ? const Color(0xFF5B52E8).withOpacity(0.18)
                  : _hovered
                      ? Colors.white.withOpacity(0.04)
                      : Colors.transparent,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.isSelected)
                  Positioned(
                    left: 0,
                    top: 10,
                    bottom: 10,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B52E8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Icon(
                  widget.icon,
                  size: 20,
                  color: widget.isSelected
                      ? const Color(0xFF7C75F0)
                      : Colors.white.withOpacity(0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
