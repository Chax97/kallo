import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/call_log.dart';
import '../../core/models/contact.dart';
import '../../core/providers/contact_provider.dart';
import '../../core/providers/dialler_providers.dart';
import 'add_contact_dialog.dart';

enum _CallFilter { all, missed, voicemail }

// ── Filter provider ──────────────────────────────────────────────────────────

class _CallFilterNotifier extends Notifier<_CallFilter> {
  @override
  _CallFilter build() => _CallFilter.all;
  void set(_CallFilter v) => state = v;
}

final _callFilterProvider =
    NotifierProvider<_CallFilterNotifier, _CallFilter>(_CallFilterNotifier.new);

// ── Selected caller provider (shared with detail panel) ──────────────────────

class _SelectedCallerNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

final selectedCallerNumberProvider =
    NotifierProvider<_SelectedCallerNotifier, String?>(_SelectedCallerNotifier.new);

// ── Caller group model ───────────────────────────────────────────────────────

class CallerGroup {
  final String number;
  final List<CallLog> calls; // sorted newest-first

  const CallerGroup(this.number, this.calls);

  CallLog get latest => calls.first;
  int get totalCount => calls.length;
  bool get hasMissed => calls.any((c) => c.state == 'missed');
  bool get hasVoicemail =>
      calls.any((c) => c.state == 'voicemail' || c.recordingUrl != null);
}

// ── Panel ────────────────────────────────────────────────────────────────────

class CallListPanel extends ConsumerWidget {
  const CallListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_callFilterProvider);
    final callsAsync = ref.watch(callHistoryProvider);
    final selectedNumber = ref.watch(selectedCallerNumberProvider);

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        border: Border(right: BorderSide(color: Color(0xFF1E1E2E), width: 1)),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Calls',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    _TopBarIcon(
                        icon: Icons.refresh,
                        onTap: () => ref.invalidate(callHistoryProvider)),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Search ──────────────────────────────────────────
                Container(
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
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.25)),
                      const SizedBox(width: 8),
                      Text(
                        'Search...',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // ── Filter pills ────────────────────────────────────
                Row(
                  children: [
                    _FilterPill(
                      label: 'All',
                      isActive: filter == _CallFilter.all,
                      onTap: () => ref
                          .read(_callFilterProvider.notifier)
                          .set(_CallFilter.all),
                    ),
                    const SizedBox(width: 6),
                    _FilterPill(
                      label: 'Missed',
                      isActive: filter == _CallFilter.missed,
                      onTap: () => ref
                          .read(_callFilterProvider.notifier)
                          .set(_CallFilter.missed),
                      accentColor: const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 6),
                    _FilterPill(
                      label: 'Voicemail',
                      isActive: filter == _CallFilter.voicemail,
                      onTap: () => ref
                          .read(_callFilterProvider.notifier)
                          .set(_CallFilter.voicemail),
                      accentColor: const Color(0xFF7C75F0),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFF1E1E2E)),
          // ── List ────────────────────────────────────────────────────
          Expanded(
            child: callsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF5B52E8),
                  strokeWidth: 2,
                ),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                        size: 28),
                    const SizedBox(height: 8),
                    Text('Failed to load',
                        style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.3))),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(callHistoryProvider),
                      child: Text('Retry',
                          style: GoogleFonts.dmSans(
                              color: const Color(0xFF5B52E8))),
                    ),
                  ],
                ),
              ),
              data: (logs) {
                final groups = _buildGroups(logs, filter);
                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_missed,
                            size: 32,
                            color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 10),
                        Text('No calls yet',
                            style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.25))),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, i) => _CallerRow(
                    group: groups[i],
                    isSelected: selectedNumber == groups[i].number,
                    onTap: () => ref
                        .read(selectedCallerNumberProvider.notifier)
                        .set(groups[i].number),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Groups logs by displayNumber, applies filter at the group level,
  /// and returns groups sorted by most-recent call first.
  List<CallerGroup> _buildGroups(List<CallLog> logs, _CallFilter filter) {
    final map = <String, List<CallLog>>{};
    for (final log in logs) {
      (map[log.displayNumber] ??= []).add(log);
    }
    final groups = map.entries
        .map((e) => CallerGroup(e.key, e.value)) // logs already newest-first
        .toList()
      ..sort((a, b) => (b.latest.startedAt ?? DateTime(0))
          .compareTo(a.latest.startedAt ?? DateTime(0)));

    return switch (filter) {
      _CallFilter.all => groups,
      _CallFilter.missed => groups.where((g) => g.hasMissed).toList(),
      _CallFilter.voicemail => groups.where((g) => g.hasVoicemail).toList(),
    };
  }
}

// ── Caller row ───────────────────────────────────────────────────────────────

class _CallerRow extends ConsumerStatefulWidget {
  final CallerGroup group;
  final bool isSelected;
  final VoidCallback onTap;

  const _CallerRow(
      {required this.group, required this.isSelected, required this.onTap});

  @override
  ConsumerState<_CallerRow> createState() => _CallerRowState();
}

class _CallerRowState extends ConsumerState<_CallerRow> {
  bool _hovered = false;

  static Color _latestColor(CallLog log) {
    if (log.state == 'missed') { return const Color(0xFFEF4444); }
    if (log.state == 'voicemail') { return const Color(0xFF7C75F0); }
    if (log.direction == 'incoming' || log.direction == 'inbound') { return const Color(0xFF22C55E); }
    return const Color(0xFF5B52E8);
  }

  static IconData _latestIcon(CallLog log) {
    if (log.state == 'missed') { return Icons.call_missed; }
    if (log.state == 'voicemail') { return Icons.voicemail; }
    if (log.direction == 'incoming' || log.direction == 'inbound') { return Icons.call_received; }
    return Icons.call_made;
  }

  static String _latestLabel(CallLog log) {
    if (log.state == 'missed') { return 'Missed'; }
    if (log.state == 'voicemail') { return 'Voicemail'; }
    if (log.direction == 'incoming' || log.direction == 'inbound') { return 'Inbound'; }
    return 'Outbound';
  }

  static String _initials(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 2) return digits.substring(digits.length - 2);
    return number.isNotEmpty ? number[0].toUpperCase() : '?';
  }

  static String _relativeTime(DateTime? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d';
  }

  static String _duration(int? s) {
    if (s == null || s <= 0) return '';
    final m = s ~/ 60;
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final log = group.latest;
    final color = _latestColor(log);
    final number = group.number;
    final dur = _duration(log.durationSeconds);
    final time = _relativeTime(log.startedAt);

    final contacts = ref.watch(contactsProvider).when(
          data: (d) => d,
          loading: () => const <Contact>[],
          error: (_, _) => const <Contact>[],
        );
    final matchedContact = contacts.firstWhere(
      (c) => c.phoneNumber == number || c.mobileNumber == number,
      orElse: () => Contact(id: '', name: ''),
    );
    final displayName =
        matchedContact.id.isNotEmpty ? matchedContact.name : null;
    final isSaved = displayName != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFF5B52E8).withValues(alpha: 0.08)
                : _hovered
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: widget.isSelected
                    ? const Color(0xFF5B52E8)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Center(
                  child: Text(
                    isSaved
                        ? displayName[0].toUpperCase()
                        : _initials(number),
                    style: GoogleFonts.dmMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName ?? number,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: log.state == 'missed'
                                      ? const Color(0xFFEF4444)
                                      : Colors.white.withValues(alpha: 0.9),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isSaved) ...[
                                Text(
                                  number,
                                  style: GoogleFonts.dmMono(
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Call count badge
                        if (group.totalCount > 1) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A3E),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${group.totalCount}',
                              style: GoogleFonts.dmMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(_latestIcon(log),
                            size: 11,
                            color: color.withValues(alpha: 0.7)),
                        const SizedBox(width: 3),
                        Text(
                          _latestLabel(log),
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: color.withValues(alpha: 0.7),
                          ),
                        ),
                        if (dur.isNotEmpty) ...[
                          Text(
                            ' · $dur',
                            style: GoogleFonts.dmMono(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                        ],
                        // Indicators for other call types in the group
                        if (group.hasMissed && log.state != 'missed') ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        if (group.hasVoicemail && log.state != 'voicemail') ...[
                          const SizedBox(width: 3),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF7C75F0),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Time
              Text(
                time,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              // Save contact button — only for unsaved numbers
              Builder(builder: (context) {
                if (isSaved) return const SizedBox.shrink();
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: _hovered ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: GestureDetector(
                      onTap: () => showAddContactDialog(
                        context,
                        prefillPhone: number,
                        onSaved: () => ref.invalidate(contactsProvider),
                      ),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B52E8).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF5B52E8)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.person_add_outlined,
                            size: 12, color: Color(0xFF5B52E8)),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter pill ──────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color accentColor;

  const _FilterPill({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.accentColor = const Color(0xFF5B52E8),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? accentColor.withValues(alpha: 0.15)
              : const Color(0xFF13131F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? accentColor.withValues(alpha: 0.4)
                : const Color(0xFF2A2A3E),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isActive ? accentColor : Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

// ── Top bar icon ─────────────────────────────────────────────────────────────

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
          duration: const Duration(milliseconds: 100),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF1E1E2E) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon,
              size: 16,
              color: Colors.white.withValues(alpha: _hovered ? 0.5 : 0.25)),
        ),
      ),
    );
  }
}
