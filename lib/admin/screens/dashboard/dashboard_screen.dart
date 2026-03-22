import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/widgets/stat_card.dart';

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = Supabase.instance.client;

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

  final callsToday = await supabase
      .from('calls')
      .select()
      .gte('started_at', todayStart)
      .count(CountOption.exact);

  final missedToday = await supabase
      .from('calls')
      .select()
      .eq('status', 'missed')
      .gte('started_at', todayStart)
      .count(CountOption.exact);

  final activeAgents = await supabase
      .from('users')
      .select()
      .eq('status', 'active')
      .count(CountOption.exact);

  final unreadVoicemails = await supabase
      .from('voicemails')
      .select()
      .eq('listened', false)
      .count(CountOption.exact);

  return {
    'calls_today': callsToday.count,
    'missed_today': missedToday.count,
    'active_agents': activeAgents.count,
    'unread_voicemails': unreadVoicemails.count,
  };
});

final recentCallsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('calls')
      .select('id, from_number, to_number, status, direction, started_at, duration_seconds')
      .order('started_at', ascending: false)
      .limit(8);

  return List<Map<String, dynamic>>.from(response);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final recentCalls = ref.watch(recentCallsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Good ${_greeting()},',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(width: 8),
              Text(
                _getTimeEmoji(),
                style: const TextStyle(fontSize: 24),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Here\'s what\'s happening with your workspace today.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          stats.when(
            loading: () => _StatsGridSkeleton(),
            error: (e, _) => _ErrorCard(message: e.toString()),
            data: (data) => _StatsGrid(data: data),
          ),
          const SizedBox(height: 28),
          _SectionHeader(title: 'Recent Calls', action: 'View all'),
          const SizedBox(height: 12),
          recentCalls.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorCard(message: e.toString()),
            data: (calls) => _RecentCallsTable(calls: calls),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  String _getTimeEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    return '🌙';
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StatsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.6,
          children: [
            StatCard(
              label: 'Calls today',
              value: '${data['calls_today']}',
              icon: Icons.phone_in_talk_outlined,
              iconColor: const Color(0xFF4F6AFF),
              trend: '12%',
              trendUp: true,
            ),
            StatCard(
              label: 'Missed calls',
              value: '${data['missed_today']}',
              icon: Icons.phone_missed_outlined,
              iconColor: const Color(0xFFEF4444),
              trend: '3%',
              trendUp: false,
            ),
            StatCard(
              label: 'Active agents',
              value: '${data['active_agents']}',
              icon: Icons.headset_mic_outlined,
              iconColor: const Color(0xFF22C55E),
            ),
            StatCard(
              label: 'Unread voicemails',
              value: '${data['unread_voicemails']}',
              icon: Icons.voicemail_outlined,
              iconColor: const Color(0xFFF59E0B),
            ),
          ],
        );
      },
    );
  }
}

class _StatsGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.8,
      children: List.generate(4, (_) => _SkeletonBox(height: double.infinity)),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  const _SkeletonBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (action != null)
          TextButton(
            onPressed: () {},
            child: Text(
              action!,
              style: const TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 13,
                color: Color(0xFF4F6AFF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentCallsTable extends StatelessWidget {
  final List<Map<String, dynamic>> calls;
  const _RecentCallsTable({required this.calls});

  @override
  Widget build(BuildContext context) {
    if (calls.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8F0)),
        ),
        child: Center(
          child: Text(
            'No calls yet',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8F0)),
      ),
      child: Column(
        children: [
          _TableHeader(),
          const Divider(height: 1),
          ...calls.asMap().entries.map((entry) {
            final isLast = entry.key == calls.length - 1;
            return Column(
              children: [
                _CallRow(call: entry.value),
                if (!isLast) const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _HeaderCell('Direction', flex: 1),
          _HeaderCell('From', flex: 2),
          _HeaderCell('To', flex: 2),
          _HeaderCell('Status', flex: 2),
          _HeaderCell('Duration', flex: 1),
          _HeaderCell('Time', flex: 2),
        ],
      ),
    );
  }

  Widget _HeaderCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF9999AA),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _CallRow extends StatelessWidget {
  final Map<String, dynamic> call;
  const _CallRow({required this.call});

  @override
  Widget build(BuildContext context) {
    final direction = call['direction'] ?? 'inbound';
    final status = call['status'] ?? 'unknown';
    final duration = call['duration_seconds'] as int? ?? 0;
    final startedAt = call['started_at'] != null
        ? DateTime.parse(call['started_at']).toLocal()
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Icon(
                  direction == 'inbound'
                      ? Icons.call_received
                      : Icons.call_made,
                  size: 14,
                  color: direction == 'inbound'
                      ? const Color(0xFF4F6AFF)
                      : const Color(0xFF22C55E),
                ),
                const SizedBox(width: 4),
                Text(
                  direction == 'inbound' ? 'In' : 'Out',
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 12,
                    color: Color(0xFF3D3D5C),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              call['from_number'] ?? '-',
              style: const TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 13,
                color: Color(0xFF0D0D1A),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              call['to_number'] ?? '-',
              style: const TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 13,
                color: Color(0xFF0D0D1A),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _StatusBadge(status: status),
          ),
          Expanded(
            flex: 1,
            child: Text(
              _formatDuration(duration),
              style: const TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 13,
                color: Color(0xFF6B6B8A),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              startedAt != null ? _formatTime(startedAt) : '-',
              style: const TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 12,
                color: Color(0xFF9999AA),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _badgeConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: config['bg'] as Color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: config['text'] as Color,
        ),
      ),
    );
  }

  Map<String, Color> _badgeConfig(String status) {
    return switch (status.toLowerCase()) {
      'answered'  => {'bg': const Color(0xFFDCFCE7), 'text': const Color(0xFF16A34A)},
      'missed'    => {'bg': const Color(0xFFFEF2F2), 'text': const Color(0xFFDC2626)},
      'voicemail' => {'bg': const Color(0xFFFEF3C7), 'text': const Color(0xFFB45309)},
      _           => {'bg': const Color(0xFFF0F0F8), 'text': const Color(0xFF6B6B8A)},
    };
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFFDC2626))),
    );
  }
}
