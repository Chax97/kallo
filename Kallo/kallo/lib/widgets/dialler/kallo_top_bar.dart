import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/dialler_providers.dart';
import '../../providers/sip_provider.dart';

class KalloTopBar extends ConsumerWidget {
  const KalloTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dnd = ref.watch(dndProvider);
    final verto = ref.watch(vertoProvider);
    final isRegistered = verto.loggedIn;

    final user = Supabase.instance.client.auth.currentUser;
    final displayName = user?.userMetadata?['full_name'] as String? ?? user?.email ?? 'User';

    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E2E), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // ── Search ────────────────────────────────────────────────
          Container(
            width: 300,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF13131F),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A2A3E)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(Icons.search, size: 15, color: Colors.white.withOpacity(0.25)),
                const SizedBox(width: 8),
                Text(
                  'Search calls, contacts...',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '⌘K',
                    style: GoogleFonts.dmMono(fontSize: 10, color: Colors.white.withOpacity(0.25)),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // ── Status indicator ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isRegistered
                  ? const Color(0xFF22C55E).withOpacity(0.08)
                  : const Color(0xFFEF4444).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isRegistered
                    ? const Color(0xFF22C55E).withOpacity(0.2)
                    : const Color(0xFFEF4444).withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isRegistered ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isRegistered ? 'Online' : 'Offline',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isRegistered
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── DND toggle ────────────────────────────────────────────
          GestureDetector(
            onTap: () => ref.read(dndProvider.notifier).set(!dnd),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: dnd
                    ? const Color(0xFFEF4444).withOpacity(0.12)
                    : const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: dnd
                      ? const Color(0xFFEF4444).withOpacity(0.3)
                      : const Color(0xFF2A2A3E),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    dnd ? Icons.do_not_disturb_on : Icons.do_not_disturb_off,
                    size: 13,
                    color: dnd ? const Color(0xFFEF4444) : Colors.white.withOpacity(0.35),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'DND',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: dnd ? const Color(0xFFEF4444) : Colors.white.withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ── Notifications ─────────────────────────────────────────
          _TopBarIcon(
            icon: Icons.notifications_none,
            onTap: () {},
          ),
          const SizedBox(width: 4),
          _TopBarIcon(
            icon: Icons.help_outline,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _TopBarIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopBarIcon({required this.icon, required this.onTap});

  @override
  State<_TopBarIcon> createState() => _TopBarIconState();
}

class _TopBarIconState extends State<_TopBarIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF1E1E2E) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: Colors.white.withOpacity(_hovered ? 0.6 : 0.3),
          ),
        ),
      ),
    );
  }
}
