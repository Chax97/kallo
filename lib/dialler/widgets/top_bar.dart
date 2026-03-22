import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/dialler_providers.dart';

class DiallerTopBar extends ConsumerWidget {
  const DiallerTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoAnswer = ref.watch(autoAnswerProvider);
    final dnd = ref.watch(dndProvider);

    final user = Supabase.instance.client.auth.currentUser;
    final displayName =
        user?.userMetadata?['full_name'] as String? ?? user?.email ?? 'User';
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final initials = _initials(displayName);

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Active calls
          GestureDetector(
            onTap: () {},
            child: Row(
              children: [
                Text(
                  'Active Calls',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right,
                    size: 16, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
          const Spacer(),
          // Auto Answer
          _Toggle(
            label: 'Auto Answer',
            value: autoAnswer,
            activeColor: const Color(0xFF6C63FF),
            onChanged: (v) =>
                ref.read(autoAnswerProvider.notifier).set(v),
          ),
          const SizedBox(width: 8),
          // DND
          _Toggle(
            label: 'DND',
            value: dnd,
            activeColor: const Color(0xFFEF4444),
            onChanged: (v) => ref.read(dndProvider.notifier).set(v),
          ),
          const SizedBox(width: 20),
          const VerticalDivider(
              width: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(width: 20),
          // User profile
          Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'REGISTERED',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF22C55E),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 18,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                backgroundColor: const Color(0xFF6C63FF),
                child: avatarUrl == null
                    ? Text(
                        initials,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty && parts[0].isNotEmpty
        ? parts[0][0].toUpperCase()
        : 'U';
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: value ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
            fontWeight: FontWeight.w500,
          ),
        ),
        Transform.scale(
          scale: 0.75,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}
