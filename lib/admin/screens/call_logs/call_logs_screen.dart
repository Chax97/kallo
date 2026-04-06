// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/call_log.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

class _CallLogFilter {
  final DateTime fromDate;
  final DateTime toDate;
  final String fromTime;
  final String toTime;
  final bool inbound;
  final bool outbound;
  final bool internal;
  final String callAnswered;
  final String callRecording;
  final String? callsFrom;
  final String? callsTo;
  final bool includeTransfers;
  final bool includeQueueBranches;

  const _CallLogFilter({
    required this.fromDate,
    required this.toDate,
    required this.fromTime,
    required this.toTime,
    required this.inbound,
    required this.outbound,
    required this.internal,
    required this.callAnswered,
    required this.callRecording,
    required this.includeTransfers,
    required this.includeQueueBranches,
    this.callsFrom,
    this.callsTo,
  });

  @override
  bool operator ==(Object other) =>
      other is _CallLogFilter &&
      fromDate == other.fromDate &&
      toDate == other.toDate &&
      fromTime == other.fromTime &&
      toTime == other.toTime &&
      inbound == other.inbound &&
      outbound == other.outbound &&
      internal == other.internal &&
      callAnswered == other.callAnswered &&
      callRecording == other.callRecording &&
      callsFrom == other.callsFrom &&
      callsTo == other.callsTo &&
      includeTransfers == other.includeTransfers &&
      includeQueueBranches == other.includeQueueBranches;

  @override
  int get hashCode => Object.hash(fromDate, toDate, fromTime, toTime,
      inbound, outbound, internal, callAnswered, callRecording,
      callsFrom, callsTo, includeTransfers, includeQueueBranches);
}


final _directionValuesProvider = FutureProvider<List<String>>((ref) async {
  final response = await Supabase.instance.client
      .from('calls')
      .select('direction')
      .not('direction', 'is', null);
  return (response as List)
      .map((e) => e['direction'].toString())
      .toSet()
      .toList();
});

final _fromNumbersProvider = FutureProvider<List<String>>((ref) async {
  final response = await Supabase.instance.client
      .from('calls')
      .select('from_number')
      .not('from_number', 'is', null)
      .order('from_number');
  final all = (response as List)
      .map((e) => e['from_number'].toString())
      .toSet()
      .toList()
    ..sort();
  return all;
});

final _toNumbersProvider = FutureProvider<List<String>>((ref) async {
  final response = await Supabase.instance.client
      .from('calls')
      .select('to_number')
      .not('to_number', 'is', null)
      .order('to_number');
  final all = (response as List)
      .map((e) => e['to_number'].toString())
      .toSet()
      .toList()
    ..sort();
  return all;
});

class _InsightIndex {
  final Set<String> callIds;       // matched by call_id
  final Set<String> callerNumbers; // fallback for older rows without call_id
  const _InsightIndex({required this.callIds, required this.callerNumbers});
  bool matches(CallLog log) =>
      callIds.contains(log.id) || callerNumbers.contains(log.fromNumber);
}

// Builds an index of which calls have insights, matching by call_id or caller_number
final _insightIndexProvider =
    FutureProvider.family<_InsightIndex, _CallLogFilter>((ref, filter) async {
  final response = await Supabase.instance.client
      .from('call_insights')
      .select('call_id, caller_number');
  final rows = response as List;
  final callIds = <String>{};
  final callerNumbers = <String>{};
  for (final r in rows) {
    if (r['call_id'] != null) callIds.add(r['call_id'] as String);
    if (r['caller_number'] != null) callerNumbers.add(r['caller_number'] as String);
  }
  debugPrint('[CallLogs] insightIndex callIds: $callIds callerNumbers: $callerNumbers');
  return _InsightIndex(callIds: callIds, callerNumbers: callerNumbers);
});

// Returns all insights for a specific call ID
final _callInsightsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, callId) async {
  final response = await Supabase.instance.client
      .from('call_insights')
      .select('insight_name, result, created_at')
      .eq('call_id', callId);
  return (response as List).cast<Map<String, dynamic>>();
});

final _recordingBlobUrlProvider =
    FutureProvider.family<String?, String>((ref, storagePath) async {
  try {
    final url = await Supabase.instance.client.storage
        .from('call_recordings')
        .createSignedUrl(storagePath, 3600);
    debugPrint('[Recording] signed URL: $url');
    return url;
  } catch (e) {
    debugPrint('[Recording] signed URL error: $e');
    return null;
  }
});

final _callLogsProvider =
    FutureProvider.family<List<CallLog>, _CallLogFilter>((ref, filter) async {
  final fromStr = '${filter.fromDate.toIso8601String().substring(0, 10)}T${filter.fromTime}:00';
  final toStr   = '${filter.toDate.toIso8601String().substring(0, 10)}T'
      '${filter.toTime == '24:00' ? '23:59:59' : '${filter.toTime}:00'}';

  // Fetch actual direction values stored in the DB
  final allDirs = await ref.watch(_directionValuesProvider.future);

  // Match checkbox selections to real DB values using substring
  final selected = <String>[];
  for (final d in allDirs) {
    final lower = d.toLowerCase();
    if (filter.inbound  && lower.contains('in')  && !lower.contains('out')) selected.add(d);
    if (filter.outbound && lower.contains('out'))                            selected.add(d);
    if (filter.internal && lower.contains('internal'))                       selected.add(d);
  }

  if (selected.isEmpty) return [];

  var filterQuery = Supabase.instance.client
      .from('calls')
      .select()
      .gte('started_at', fromStr)
      .lte('started_at', toStr);

  // Only apply direction filter when not all known values are selected
  if (selected.length < allDirs.length) {
    filterQuery = selected.length == 1
        ? filterQuery.eq('direction', selected.first)
        : filterQuery.inFilter('direction', selected);
  }
  if (filter.callsFrom != null) filterQuery = filterQuery.eq('from_number', filter.callsFrom!);
  if (filter.callsTo   != null) filterQuery = filterQuery.eq('to_number',   filter.callsTo!);

  if (filter.callAnswered == 'Answered Only') {
    filterQuery = filterQuery.eq('status', 'completed');
  } else if (filter.callAnswered == 'Unanswered Only') {
    filterQuery = filterQuery.inFilter('status', ['missed', 'initiated']);
  }

  final response = await filterQuery
      .order('started_at', ascending: false)
      .limit(200);
  return (response as List).map((e) => CallLog.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class CallLogsScreen extends ConsumerStatefulWidget {
  const CallLogsScreen({super.key});

  @override
  ConsumerState<CallLogsScreen> createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends ConsumerState<CallLogsScreen> {
  // Global call recording
  String _recordingMode = 'custom';

  // Search filters
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 2));
  DateTime _toDate = DateTime.now();
  String _fromTime = '00:00';
  String _toTime = '24:00';
  bool _inbound = true;
  bool _outbound = true;
  bool _internal = true;
  String _callAnswered = 'Answered / Unanswered';
  String _callRecording = 'Any Recording Status';
  String? _callsFrom;
  String? _callsTo;
  bool _includeTransfers = false;
  bool _includeQueueBranches = false;
  bool _stereo = false;

  bool _hasSearched = false;
  CallLog? _selectedLog;

  _CallLogFilter get _currentFilter => _CallLogFilter(
        fromDate: _fromDate,
        toDate: _toDate,
        fromTime: _fromTime,
        toTime: _toTime,
        inbound: _inbound,
        outbound: _outbound,
        internal: _internal,
        callAnswered: _callAnswered,
        callRecording: _callRecording,
        callsFrom: _callsFrom,
        callsTo: _callsTo,
        includeTransfers: _includeTransfers,
        includeQueueBranches: _includeQueueBranches,
      );

  void _search() => setState(() => _hasSearched = true);

  void _downloadCsv() {
    final logs = ref.read(_callLogsProvider(_currentFilter)).asData?.value;
    if (logs == null || logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No call data to export.')),
      );
      return;
    }

    final rows = <String>[
      'Direction,From,To,Status,Date/Time,Duration (s)',
      ...logs.map((l) {
        String esc(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
        final dt = l.startedAt?.toIso8601String() ?? '';
        return '${esc(l.direction)},${esc(l.fromNumber)},${esc(l.toNumber)},'
            '${esc(l.state)},$dt,${l.durationSeconds ?? 0}';
      }),
    ];

    final csv = rows.join('\n');
    final blob = html.Blob([csv], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'call_history.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _reset() {
    setState(() {
      _fromDate = DateTime.now().subtract(const Duration(days: 2));
      _toDate = DateTime.now();
      _fromTime = '00:00';
      _toTime = '24:00';
      _inbound = true;
      _outbound = true;
      _internal = true;
      _callAnswered = 'Answered / Unanswered';
      _callRecording = 'Any Recording Status';
      _callsFrom = null;
      _callsTo = null;
      _hasSearched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildMain(),
        // Backdrop
        if (_selectedLog != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _selectedLog = null),
              child: Container(color: Colors.black.withValues(alpha: 0.25)),
            ),
          ),
        // Slide-out drawer
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          right: _selectedLog != null ? 0 : -520,
          top: 0,
          bottom: 0,
          width: 500,
          child: Material(
            elevation: 16,
            child: _selectedLog != null
                ? _CallInsightDrawer(
                    log: _selectedLog!,
                    onClose: () => setState(() => _selectedLog = null),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildMain() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Global Call Recording bar (full width)
          _GlobalRecordingBar(
            mode: _recordingMode,
            onChanged: (v) => setState(() => _recordingMode = v),
          ),
          const SizedBox(height: 24),

          // Two-column layout
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Left column: toolbar + calls table ──────────────────────
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Toolbar
                      Row(
                        children: [
                          _CheckRow(
                            label: 'Include Call Transfers',
                            value: _includeTransfers,
                            onChanged: (v) => setState(() => _includeTransfers = v),
                          ),
                          const SizedBox(width: 20),
                          _CheckRow(
                            label: 'Include Queue Branches',
                            value: _includeQueueBranches,
                            onChanged: (v) => setState(() => _includeQueueBranches = v),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: _downloadCsv,
                            icon: const Icon(Icons.download_outlined, size: 15),
                            label: const Text('Download Call Data'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Calls table
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE8E8F0)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                color: const Color(0xFFF8F8FC),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 32),
                                    const Expanded(flex: 3, child: _ColHeader('From')),
                                    const Expanded(flex: 3, child: _ColHeader('To')),
                                    const Expanded(flex: 3, child: _ColHeader('Answered By')),
                                    const Expanded(flex: 3, child: _ColHeader('Date / Time')),
                                    const Expanded(flex: 2, child: _ColHeader('Duration')),
                                    Row(
                                      children: [
                                        Switch(
                                          value: _stereo,
                                          onChanged: (v) => setState(() => _stereo = v),
                                          activeThumbColor: Colors.white,
                                          activeTrackColor: const Color(0xFF4F6AFF),
                                        ),
                                        const Text('STEREO',
                                            style: TextStyle(fontFamily: 'DM Sans', fontSize: 11,
                                                fontWeight: FontWeight.w600, color: Color(0xFF9999AA),
                                                letterSpacing: 0.5)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(child: _ResultsBody(
                        filter: _currentFilter,
                        hasSearched: _hasSearched,
                        onSelectLog: (log) => setState(() => _selectedLog = log),
                      )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // ── Right column: filters ────────────────────────────────────
                SizedBox(
                  width: 280,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8E8F0)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          children: [
                            Text('Search History',
                                style: Theme.of(context).textTheme.titleLarge),
                            const Spacer(),
                            GestureDetector(
                              onTap: _reset,
                              child: const Text('Reset',
                                  style: TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                                      color: Color(0xFF9999AA))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // From date + time on one row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: _DateField(
                              label: 'FROM DATE',
                              value: _fromDate,
                              onChanged: (d) => setState(() => _fromDate = d),
                            )),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 82,
                              child: _TimeDropdown(
                                label: 'TIME',
                                value: _fromTime,
                                onChanged: (v) => setState(() => _fromTime = v),
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // To date + time on one row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: _DateField(
                              label: 'TO DATE',
                              value: _toDate,
                              onChanged: (d) => setState(() => _toDate = d),
                            )),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 82,
                              child: _TimeDropdown(
                                label: 'TIME',
                                value: _toTime,
                                onChanged: (v) => setState(() => _toTime = v),
                                endOfDay: true,
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // From + To numbers on one row
                        Row(
                          children: [
                            Expanded(child: _NumberPickerField(
                              label: 'FROM',
                              numbersProvider: _fromNumbersProvider,
                              selected: _callsFrom,
                              onChanged: (v) => setState(() => _callsFrom = v),
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: _NumberPickerField(
                              label: 'TO',
                              numbersProvider: _toNumbersProvider,
                              selected: _callsTo,
                              onChanged: (v) => setState(() => _callsTo = v),
                            )),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Call type — compact inline chips
                        const _FilterLabel('CALL TYPE'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: _CompactCallTypeChip(
                              label: 'Inbound',
                              icon: Icons.call_received_rounded,
                              color: const Color(0xFF22C55E),
                              checked: _inbound,
                              onChanged: (v) => setState(() => _inbound = v),
                            )),
                            const SizedBox(width: 6),
                            Expanded(child: _CompactCallTypeChip(
                              label: 'Outbound',
                              icon: Icons.call_made_rounded,
                              color: const Color(0xFF4F6AFF),
                              checked: _outbound,
                              onChanged: (v) => setState(() => _outbound = v),
                            )),
                            const SizedBox(width: 6),
                            Expanded(child: _CompactCallTypeChip(
                              label: 'Internal',
                              icon: Icons.call_rounded,
                              color: const Color(0xFF6366F1),
                              checked: _internal,
                              onChanged: (v) => setState(() => _internal = v),
                            )),
                          ],
                        ),
                        const SizedBox(height: 10),

                        _FilterDropdown(
                          label: 'CALL ANSWERED',
                          value: _callAnswered,
                          items: const ['Answered / Unanswered', 'Answered Only', 'Unanswered Only'],
                          onChanged: (v) => setState(() => _callAnswered = v),
                        ),
                        const SizedBox(height: 8),
                        _FilterDropdown(
                          label: 'CALL RECORDING',
                          value: _callRecording,
                          items: const ['Any Recording Status', 'Recorded', 'Not Recorded'],
                          onChanged: (v) => setState(() => _callRecording = v),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _search,
                            child: const Text('Search Calls'),
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Results Body ──────────────────────────────────────────────────────────────

class _ResultsBody extends ConsumerWidget {
  final _CallLogFilter filter;
  final bool hasSearched;
  final ValueChanged<CallLog> onSelectLog;
  const _ResultsBody({
    required this.filter,
    required this.hasSearched,
    required this.onSelectLog,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!hasSearched) {
      return const Center(
        child: Text('Set your filters above and press Search Calls.',
            style: TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: Color(0xFF9999AA))),
      );
    }

    final logs = ref.watch(_callLogsProvider(filter));
    return logs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(fontFamily: 'DM Sans', color: Color(0xFFEF4444))),
      ),
      data: (data) {
        if (data.isEmpty) {
          return const Center(
            child: Text('No calls found for the selected filters.',
                style: TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: Color(0xFF9999AA))),
          );
        }
        final insightIndex = ref.watch(_insightIndexProvider(filter)).asData?.value;
        return ListView.separated(
          itemCount: data.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => _CallLogRow(
            log: data[i],
            hasInsights: insightIndex?.matches(data[i]) ?? false,
            onOpenInsights: () => onSelectLog(data[i]),
          ),
        );
      },
    );
  }
}

class _CallLogRow extends StatelessWidget {
  final CallLog log;
  final bool hasInsights;
  final VoidCallback onOpenInsights;
  const _CallLogRow({
    required this.log,
    required this.hasInsights,
    required this.onOpenInsights,
  });

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '0 min 0 secs';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m min $s secs';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year.toString().substring(2)} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatAnsweredBy(String? v) {
    switch (v) {
      case 'ai_assistant': return 'AI Assistant';
      case 'app': return 'Human';
      case 'voicemail': return 'Voicemail';
      default: return v ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInbound = log.direction == 'inbound';
    final dirColor = isInbound ? const Color(0xFF22C55E) : const Color(0xFF4F6AFF);
    final dirIcon  = isInbound ? Icons.call_received_rounded : Icons.call_made_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 32, child: Icon(dirIcon, size: 18, color: dirColor)),
          Expanded(flex: 3, child: _NumberText(log.fromNumber ?? '—')),
          Expanded(flex: 3, child: _NumberText(log.toNumber ?? '—')),
          Expanded(
            flex: 3,
            child: Text(_formatAnsweredBy(log.answeredBy),
                style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                    color: Color(0xFF3D3D5C))),
          ),
          Expanded(
            flex: 3,
            child: Text(_formatDateTime(log.startedAt),
                style: const TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                    color: Color(0xFF6B6B8A))),
          ),
          Expanded(
            flex: 2,
            child: Text(_formatDuration(log.durationSeconds),
                style: const TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                    color: Color(0xFF4F6AFF))),
          ),
          SizedBox(
            width: 80,
            child: hasInsights
                ? Tooltip(
                    message: 'View AI Insights',
                    child: InkWell(
                      onTap: onOpenInsights,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 13, color: Color(0xFF6366F1)),
                            SizedBox(width: 4),
                            Text('AI', style: TextStyle(fontFamily: 'DM Sans', fontSize: 11,
                                fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Call Insight Drawer ───────────────────────────────────────────────────────

class _CallInsightDrawer extends ConsumerWidget {
  final CallLog log;
  final VoidCallback onClose;
  const _CallInsightDrawer({required this.log, required this.onClose});

  static String _extractText(dynamic result) {
    if (result is Map) return result['text'] as String? ?? '';
    return result?.toString() ?? '';
  }

  static String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year},  $h:$m';
  }

  static String _fmtDur(int? s) {
    if (s == null || s == 0) return '0s';
    final m = s ~/ 60;
    final sec = s % 60;
    return m > 0 ? '${m}m ${sec}s' : '${sec}s';
  }

  static String _fmtAnsweredBy(String? v) {
    switch (v) {
      case 'ai_assistant': return 'AI Assistant';
      case 'app': return 'Human';
      case 'voicemail': return 'Voicemail';
      default: return v ?? '—';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(_callInsightsProvider(log.id));

    final String? recordingUrl = log.storagePath != null
        ? ref.watch(_recordingBlobUrlProvider(log.storagePath!)).asData?.value
        : null;

    final metadata = [
      ('Caller',       log.fromNumber ?? '—'),
      ('Called',       log.toNumber ?? '—'),
      ('Date',         _fmtDate(log.startedAt)),
      ('Duration',     _fmtDur(log.durationSeconds)),
      ('Status',       log.state ?? '—'),
      ('Answered By',  _fmtAnsweredBy(log.answeredBy)),
    ];

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F8FC),
              border: Border(bottom: BorderSide(color: Color(0xFFE8E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.call_outlined, size: 16, color: Color(0xFF4F6AFF)),
                const SizedBox(width: 10),
                const Text('Call Details',
                    style: TextStyle(fontFamily: 'DM Sans', fontSize: 15,
                        fontWeight: FontWeight.w600, color: Color(0xFF0D0D1A))),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                  color: const Color(0xFF9999AA),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata
                  _DrawerSection(
                    title: 'Call Metadata',
                    child: Column(
                      children: metadata.map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(r.$1,
                                  style: const TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                                      fontWeight: FontWeight.w600, color: Color(0xFF6B6B8A))),
                            ),
                            Expanded(
                              child: Text(r.$2,
                                  style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                                      color: Color(0xFF0D0D1A))),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),

                  // Recording player
                  if (recordingUrl != null) ...[
                    const SizedBox(height: 20),
                    _DrawerSection(
                      title: 'Recording',
                      titleIcon: Icons.graphic_eq,
                      child: _RecordingPlayer(url: recordingUrl),
                    ),
                  ],

                  // AI insights
                  insightsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text('Error loading insights: $e',
                          style: const TextStyle(color: Color(0xFFEF4444))),
                    ),
                    data: (insights) {
                      final summary = insights
                          .where((i) => i['insight_name'] == 'Call Summary')
                          .firstOrNull;
                      final transcript = insights
                          .where((i) => i['insight_name'] == 'Transcript')
                          .firstOrNull;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (summary != null) ...[
                            const SizedBox(height: 20),
                            _DrawerSection(
                              title: 'AI Summary',
                              titleIcon: Icons.auto_awesome,
                              titleIconColor: const Color(0xFF6366F1),
                              child: Text(
                                _extractText(summary['result']),
                                style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                                    height: 1.6, color: Color(0xFF3D3D5C)),
                              ),
                            ),
                          ],
                          if (transcript != null) ...[
                            const SizedBox(height: 20),
                            _DrawerSection(
                              title: 'Transcript',
                              titleIcon: Icons.chat_bubble_outline,
                              titleIconColor: const Color(0xFF4F6AFF),
                              child: _TranscriptView(
                                  text: _extractText(transcript['result'])),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String title;
  final IconData? titleIcon;
  final Color? titleIconColor;
  final Widget child;
  const _DrawerSection({
    required this.title,
    required this.child,
    this.titleIcon,
    this.titleIconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (titleIcon != null) ...[
              Icon(titleIcon, size: 13, color: titleIconColor ?? const Color(0xFF9999AA)),
              const SizedBox(width: 6),
            ],
            Text(title.toUpperCase(),
                style: const TextStyle(fontFamily: 'DM Sans', fontSize: 10,
                    fontWeight: FontWeight.w700, color: Color(0xFF9999AA), letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8FC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8E8F0)),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _TranscriptView extends StatelessWidget {
  final String text;
  const _TranscriptView({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final isAgent = line.startsWith('Agent:');
        final content = line
            .replaceFirst('Agent: ', '')
            .replaceFirst('Caller: ', '');
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isAgent
                      ? const Color(0xFFEEF2FF)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isAgent ? 'Agent' : 'Caller',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'DM Sans', fontSize: 10, fontWeight: FontWeight.w700,
                    color: isAgent ? const Color(0xFF6366F1) : const Color(0xFF22C55E),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(content,
                    style: const TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                        height: 1.5, color: Color(0xFF3D3D5C))),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Recording Player ──────────────────────────────────────────────────────────

class _RecordingPlayer extends StatefulWidget {
  final String url;
  const _RecordingPlayer({required this.url});

  @override
  State<_RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends State<_RecordingPlayer> {
  late final html.AudioElement _audio;
  bool _playing = false;
  double _position = 0;
  double _duration = 0;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _audio = html.AudioElement(widget.url);
    _audio.onLoadedMetadata.listen((_) {
      if (mounted) setState(() { _duration = _audio.duration.toDouble(); _error = false; });
    });
    _audio.onTimeUpdate.listen((_) {
      if (mounted) setState(() => _position = _audio.currentTime.toDouble());
    });
    _audio.onEnded.listen((_) {
      if (mounted) setState(() { _playing = false; _position = 0; });
    });
    _audio.onError.listen((_) {
      debugPrint('[RecordingPlayer] error loading url: ${widget.url}');
      debugPrint('[RecordingPlayer] error code: ${_audio.error?.code} message: ${_audio.error?.message}');
      if (mounted) setState(() { _error = true; _playing = false; });
    });
  }

  @override
  void dispose() {
    _audio.pause();
    super.dispose();
  }

  String _fmt(double secs) {
    final d = Duration(seconds: secs.round());
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Color(0xFF9999AA)),
          const SizedBox(width: 8),
          const Text('Unable to load recording.',
              style: TextStyle(fontFamily: 'DM Sans', fontSize: 12, color: Color(0xFF9999AA))),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => html.window.open(widget.url, '_blank'),
            child: const Text('Open in browser',
                style: TextStyle(fontFamily: 'DM Sans', fontSize: 12)),
          ),
        ],
      );
    }
    final progress = _duration > 0 ? (_position / _duration).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        IconButton(
          icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle_filled),
          color: const Color(0xFF4F6AFF),
          iconSize: 38,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () {
            if (_playing) {
              _audio.pause();
              setState(() => _playing = false);
            } else {
              _audio.play();
              setState(() => _playing = true);
            }
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: const Color(0xFF4F6AFF),
                  inactiveTrackColor: const Color(0xFFE8E8F0),
                  thumbColor: const Color(0xFF4F6AFF),
                  overlayColor: const Color(0xFF4F6AFF).withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: progress,
                  onChanged: _duration > 0
                      ? (v) {
                          _audio.currentTime = _duration * v;
                          setState(() => _position = _duration * v);
                        }
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_position),
                        style: const TextStyle(fontFamily: 'DM Sans', fontSize: 11,
                            color: Color(0xFF9999AA))),
                    Text(_fmt(_duration),
                        style: const TextStyle(fontFamily: 'DM Sans', fontSize: 11,
                            color: Color(0xFF9999AA))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberText extends StatelessWidget {
  final String number;
  const _NumberText(this.number);

  @override
  Widget build(BuildContext context) => Text(number,
      style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
          fontWeight: FontWeight.w500, color: Color(0xFF4F6AFF)));
}

// ── Global Recording Bar ──────────────────────────────────────────────────────

class _GlobalRecordingBar extends StatelessWidget {
  final String mode;
  final ValueChanged<String> onChanged;
  const _GlobalRecordingBar({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8F0)),
      ),
      child: Row(
        children: [
          const Text('Global Call Recording',
              style: TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                  fontWeight: FontWeight.w600, color: Color(0xFF0D0D1A))),
          const SizedBox(width: 32),
          _RecordingOption(
            value: 'custom',
            label: 'Custom',
            subtitle: 'Recording set by user/routing',
            selected: mode == 'custom',
            dotColor: const Color(0xFFEF4444),
            onTap: () => onChanged('custom'),
          ),
          const SizedBox(width: 32),
          _RecordingOption(
            value: 'enabled',
            label: 'Enabled',
            subtitle: 'Record every call',
            selected: mode == 'enabled',
            onTap: () => onChanged('enabled'),
          ),
          const SizedBox(width: 32),
          _RecordingOption(
            value: 'disabled',
            label: 'Disabled',
            subtitle: 'Turn off call recording',
            selected: mode == 'disabled',
            onTap: () => onChanged('disabled'),
          ),
        ],
      ),
    );
  }
}

class _RecordingOption extends StatelessWidget {
  final String value;
  final String label;
  final String subtitle;
  final bool selected;
  final Color dotColor;
  final VoidCallback onTap;

  const _RecordingOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.dotColor = const Color(0xFF9999AA),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? dotColor : const Color(0xFFD1D1E0),
                width: 2,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: const Color(0xFF0D0D1A))),
              Text(subtitle,
                  style: const TextStyle(fontFamily: 'DM Sans', fontSize: 11,
                      color: Color(0xFF9999AA))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Search Form Widgets ───────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const _DateField({required this.label, required this.value, required this.onChanged});

  String _format(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterLabel(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE8E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(child: Text(_format(value),
                    style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                        color: Color(0xFF3D3D5C)))),
                const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF9999AA)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool endOfDay;
  final bool compact;

  const _TimeDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
    this.endOfDay = false,
    this.compact = false,
  });

  static List<String> get _times {
    final t = <String>[];
    for (int h = 0; h < 24; h++) {
      t.add('${h.toString().padLeft(2, '0')}:00');
      t.add('${h.toString().padLeft(2, '0')}:30');
    }
    t.add('24:00');
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterLabel(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isDense: true,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 12,
              vertical: compact ? 8 : 10,
            ),
          ),
          items: _times.map((t) => DropdownMenuItem(
            value: t,
            child: Text(t, style: TextStyle(
              fontFamily: 'DM Sans',
              fontSize: compact ? 11 : 13,
            )),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ],
    );
  }
}

class _NumberPickerField extends ConsumerWidget {
  final String label;
  final FutureProvider<List<String>> numbersProvider;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _NumberPickerField({
    required this.label,
    required this.numbersProvider,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numbersAsync = ref.watch(numbersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterLabel(label),
        const SizedBox(height: 6),
        numbersAsync.when(
          loading: () => const SizedBox(
            height: 44,
            child: Center(child: LinearProgressIndicator()),
          ),
          error: (e, _) => Text('Error: $e',
              style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
          data: (numbers) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE8E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: selected,
              isExpanded: true,
              underline: const SizedBox(),
              hint: const Text('Any',
                  style: TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                      color: Color(0xFF9999AA))),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Any',
                      style: TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                          color: Color(0xFF9999AA))),
                ),
                ...numbers.map((n) => DropdownMenuItem(
                  value: n,
                  child: Text(n,
                      style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13)),
                )),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}



class _CompactCallTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool checked;
  final ValueChanged<bool> onChanged;
  const _CompactCallTypeChip({
    required this.label, required this.icon, required this.color,
    required this.checked, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!checked),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: checked ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: checked ? color.withValues(alpha: 0.4) : const Color(0xFFE8E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: checked ? color : const Color(0xFF9999AA)),
            const SizedBox(width: 4),
            Flexible(child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'DM Sans', fontSize: 11,
                  fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
                  color: checked ? color : const Color(0xFF9999AA),
                ))),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _FilterDropdown({required this.label, required this.value,
      required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterLabel(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isDense: true,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: items.map((e) => DropdownMenuItem(
            value: e,
            child: Text(e, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13)),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ],
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(text, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 10,
          fontWeight: FontWeight.w600, color: Color(0xFF6B6B8A), letterSpacing: 0.4)),
      const SizedBox(width: 2),
      const Text('*', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
    ],
  );
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CheckRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: const Color(0xFF4F6AFF),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
            color: Color(0xFF3D3D5C))),
      ],
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  const _ColHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontFamily: 'DM Sans', fontSize: 11,
          fontWeight: FontWeight.w600, color: Color(0xFF9999AA), letterSpacing: 0.5));
}
