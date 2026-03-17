import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/contact.dart';
import '../../providers/contact_provider.dart';
import '../../providers/telnyx_provider.dart';

class ContactsPanel extends ConsumerStatefulWidget {
  const ContactsPanel({super.key});

  @override
  ConsumerState<ContactsPanel> createState() => _ContactsPanelState();
}

class _ContactsPanelState extends ConsumerState<ContactsPanel> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        border: Border(left: BorderSide(color: Color(0xFF1E1E2E), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Text(
                  'Contacts',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const Spacer(),
                _IconBtn(
                  icon: Icons.refresh,
                  onTap: () => ref.invalidate(contactsProvider),
                ),
              ],
            ),
          ),
          // ── Search bar ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF13131F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A2A3E)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(Icons.search,
                      size: 14, color: Colors.white.withValues(alpha: 0.25)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v.toLowerCase()),
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.2)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.close,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(height: 1, color: const Color(0xFF1E1E2E)),
          // ── List ──────────────────────────────────────────────────
          Expanded(
            child: contactsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF5B52E8)),
              ),
              error: (_, _) => Center(
                child: Text('Failed to load',
                    style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.3))),
              ),
              data: (contacts) {
                final filtered = _query.isEmpty
                    ? contacts
                    : contacts
                        .where((c) =>
                            c.name.toLowerCase().contains(_query) ||
                            (c.phoneNumber?.contains(_query) ?? false))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search,
                            size: 36,
                            color: Colors.white.withValues(alpha: 0.07)),
                        const SizedBox(height: 10),
                        Text(
                          _query.isEmpty ? 'No contacts yet' : 'No results',
                          style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.2)),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _ContactRow(contact: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contact row ───────────────────────────────────────────────────────────────

class _ContactRow extends ConsumerStatefulWidget {
  final Contact contact;
  const _ContactRow({required this.contact});

  @override
  ConsumerState<_ContactRow> createState() => _ContactRowState();
}

class _ContactRowState extends ConsumerState<_ContactRow> {
  bool _hovered = false;

  static Color _avatarColor(String name) {
    const colors = [
      Color(0xFF5B52E8),
      Color(0xFF22C55E),
      Color(0xFFEF4444),
      Color(0xFFF59E0B),
      Color(0xFF06B6D4),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
      Color(0xFF10B981),
    ];
    return colors[name.codeUnits.first % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    final color = _avatarColor(c.name);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hovered
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Center(
                child: Text(
                  c.initials,
                  style: GoogleFonts.dmMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Name + number
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (c.phoneNumber != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      c.phoneNumber!,
                      style: GoogleFonts.dmMono(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.3)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Call button (visible on hover)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: _hovered && c.phoneNumber != null ? 1.0 : 0.0,
              child: GestureDetector(
                onTap: c.phoneNumber != null
                    ? () => ref
                        .read(telnyxProvider.notifier)
                        .dial(c.phoneNumber!)
                    : null,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.call,
                      size: 13, color: Color(0xFF22C55E)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Icon button ───────────────────────────────────────────────────────────────

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF1E1E2E) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon,
              size: 15,
              color: Colors.white.withValues(alpha: _hovered ? 0.5 : 0.25)),
        ),
      ),
    );
  }
}
