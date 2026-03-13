import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/call_log.dart';
import '../../models/call_record.dart';
import '../../providers/dialler_providers.dart';

class CallListPanel extends ConsumerWidget {
  const CallListPanel({super.key});

  static final List<CallRecord> _calls = [
    CallRecord(
      name: 'Jason Markus',
      number: '+1 (555) 234-5678',
      type: CallType.outbound,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      duration: const Duration(minutes: 3, seconds: 22),
      count: 5,
      initials: 'JM',
      avatarColor: Color(0xFF6C63FF),
    ),
    CallRecord(
      name: 'Sarah Connor',
      number: '+1 (555) 987-6543',
      type: CallType.inbound,
      timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
      duration: const Duration(minutes: 7, seconds: 45),
      count: 2,
      initials: 'SC',
      avatarColor: Color(0xFF22C55E),
    ),
    CallRecord(
      name: 'Mike Williams',
      number: '+1 (555) 456-7890',
      type: CallType.missed,
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      count: 3,
      initials: 'MW',
      avatarColor: Color(0xFFEF4444),
    ),
    CallRecord(
      name: 'Emma Thompson',
      number: '+44 20 7946 0958',
      type: CallType.outbound,
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      duration: const Duration(minutes: 12, seconds: 8),
      count: 1,
      initials: 'ET',
      avatarColor: Color(0xFFF59E0B),
    ),
    CallRecord(
      name: 'David Chen',
      number: '+1 (555) 321-0987',
      type: CallType.conference,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      duration: const Duration(minutes: 45, seconds: 30),
      count: 2,
      initials: 'DC',
      avatarColor: Color(0xFF0EA5E9),
    ),
    CallRecord(
      name: 'Linda Park',
      number: '+1 (555) 654-3210',
      type: CallType.missed,
      timestamp: DateTime.now().subtract(const Duration(hours: 26)),
      count: 4,
      initials: 'LP',
      avatarColor: Color(0xFFEC4899),
    ),
    CallRecord(
      name: 'Robert Smith',
      number: '+1 (555) 789-0123',
      type: CallType.inbound,
      timestamp: DateTime.now().subtract(const Duration(hours: 28)),
      duration: const Duration(minutes: 2, seconds: 15),
      count: 1,
      initials: 'RS',
      avatarColor: Color(0xFF8B5CF6),
    ),
    CallRecord(
      name: 'Anna Foster',
      number: '+1 (555) 012-3456',
      type: CallType.outbound,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      duration: const Duration(minutes: 18, seconds: 52),
      count: 6,
      initials: 'AF',
      avatarColor: Color(0xFF14B8A6),
    ),
  ];

  static const _tabs = ['Favourites', 'Active Call', 'Call History', 'Missed Call'];

  // Index of the Call History tab
  static const _callHistoryTabIndex = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = ref.watch(callsTabIndexProvider);
    final selectedCallIndex = ref.watch(selectedCallIndexProvider);

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Column(
        children: [
          // ── Tab bar ─────────────────────────────────────────────────────────
          Container(
            height: 44,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Row(
              children: [
                ..._tabs.asMap().entries.map((e) {
                  final isSelected = e.key == tabIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          ref.read(callsTabIndexProvider.notifier).set(e.key),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF6C63FF)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          e.value,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? const Color(0xFF6C63FF)
                                : const Color(0xFF9CA3AF),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                }),
                IconButton(
                  icon: const Icon(Icons.more_horiz,
                      size: 18, color: Color(0xFF9CA3AF)),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 44),
                ),
              ],
            ),
          ),
          // ── Search bar ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search, size: 15, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 6),
                  Text(
                    'Search calls...',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: const Color(0xFFD1D5DB)),
                  ),
                ],
              ),
            ),
          ),
          // ── List ────────────────────────────────────────────────────────────
          Expanded(
            child: tabIndex == _callHistoryTabIndex
                ? const _CallHistoryList()
                : ListView.builder(
                    itemCount: _calls.length,
                    itemBuilder: (context, index) {
                      return _CallItem(
                        call: _calls[index],
                        isSelected: selectedCallIndex == index,
                        onTap: () {
                          final notifier =
                              ref.read(selectedCallIndexProvider.notifier);
                          notifier.set(
                              selectedCallIndex == index ? null : index);
                        },
                        onCall: () => ref
                            .read(dialledNumberProvider.notifier)
                            .append(_calls[index].number),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Call History tab content ──────────────────────────────────────────────────

class _CallHistoryList extends ConsumerWidget {
  const _CallHistoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(callHistoryProvider);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6C63FF),
          strokeWidth: 2,
        ),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 32),
            const SizedBox(height: 8),
            Text(
              'Failed to load call history',
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(callHistoryProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history, size: 40, color: Color(0xFFD1D5DB)),
                const SizedBox(height: 12),
                Text(
                  'No call history yet',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFF9CA3AF)),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: const Color(0xFF6C63FF),
          onRefresh: () async => ref.invalidate(callHistoryProvider),
          child: ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, i) => _CallLogItem(log: logs[i]),
          ),
        );
      },
    );
  }
}

class _CallLogItem extends StatefulWidget {
  final CallLog log;
  const _CallLogItem({required this.log});

  @override
  State<_CallLogItem> createState() => _CallLogItemState();
}

class _CallLogItemState extends State<_CallLogItem> {
  bool _hovered = false;

  static (IconData, Color, String) _stateInfo(CallLog log) {
    final state = log.state ?? '';
    final direction = log.direction ?? '';
    if (state == 'missed') {
      return (Icons.call_missed, const Color(0xFFEF4444), 'Missed');
    }
    if (direction == 'incoming') {
      return (Icons.call_received, const Color(0xFF22C55E), 'Inbound');
    }
    return (Icons.call_made, const Color(0xFF6C63FF), 'Outbound');
  }

  static Color _avatarColor(CallLog log) {
    final state = log.state ?? '';
    if (state == 'missed') return const Color(0xFFEF4444);
    if (log.direction == 'incoming') return const Color(0xFF22C55E);
    return const Color(0xFF6C63FF);
  }

  static String _initials(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 2) return digits.substring(digits.length - 2);
    return number.isNotEmpty ? number[0] : '?';
  }

  static String _formatTimestamp(DateTime? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  static String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final (typeIcon, typeColor, typeLabel) = _stateInfo(log);
    final color = _avatarColor(log);
    final number = log.displayNumber;
    final initials = _initials(number);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? const Color(0xFFF5F3FF) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    number,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(typeIcon, size: 12, color: typeColor),
                      const SizedBox(width: 3),
                      Text(
                        typeLabel,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: typeColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (log.hangupCause != null &&
                          log.state == 'missed') ...[
                        const SizedBox(width: 4),
                        Text(
                          '· ${log.hangupCause}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Timestamp + duration
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTimestamp(log.startedAt),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
                if (_formatDuration(log.durationSeconds).isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(log.durationSeconds),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFFD1D5DB),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Existing static-list widgets (Favourites / Active / Missed tabs) ──────────

class _CallItem extends StatefulWidget {
  final CallRecord call;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onCall;

  const _CallItem({
    required this.call,
    required this.isSelected,
    required this.onTap,
    required this.onCall,
  });

  @override
  State<_CallItem> createState() => _CallItemState();
}

class _CallItemState extends State<_CallItem> {
  bool _hovered = false;

  static (IconData, Color, String) _typeInfo(CallType type) {
    return switch (type) {
      CallType.outbound =>
        (Icons.call_made, const Color(0xFF6C63FF), 'Outbound call'),
      CallType.inbound =>
        (Icons.call_received, const Color(0xFF22C55E), 'Inbound call'),
      CallType.missed =>
        (Icons.call_missed, const Color(0xFFEF4444), 'Missed call'),
      CallType.conference =>
        (Icons.people_outline, const Color(0xFFF59E0B), 'Conference call'),
    };
  }

  static String _formatTimestamp(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  static String _formatDuration(Duration? d) {
    if (d == null) return '';
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final (typeIcon, typeColor, typeLabel) = _typeInfo(call.type);
    final showActions = _hovered || widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: widget.isSelected
              ? const Color(0xFFEDE9FE)
              : _hovered
                  ? const Color(0xFFF5F3FF)
                  : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: call.avatarColor.withValues(alpha: 0.15),
                child: Text(
                  call.initials,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: call.avatarColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            call.count > 1
                                ? '${call.name} (${call.count})'
                                : call.name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      call.number,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(typeIcon, size: 12, color: typeColor),
                        const SizedBox(width: 3),
                        Text(
                          typeLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: typeColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (showActions)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _IconAction(
                      icon: Icons.videocam_outlined,
                      color: const Color(0xFF6C63FF),
                      onTap: () {},
                    ),
                    const SizedBox(width: 6),
                    _IconAction(
                      icon: Icons.call,
                      color: const Color(0xFF22C55E),
                      onTap: widget.onCall,
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTimestamp(call.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    if (call.duration != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatDuration(call.duration),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFFD1D5DB),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconAction(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
