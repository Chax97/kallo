import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/call_log.dart';
import '../../core/providers/dialler_providers.dart';
import '../../core/providers/telnyx_provider.dart';
import 'call_list_panel.dart' show selectedCallerNumberProvider, CallerGroup;

class CallDetailPanel extends ConsumerWidget {
  const CallDetailPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callsAsync = ref.watch(callHistoryProvider);
    final selectedNumber = ref.watch(selectedCallerNumberProvider);

    return callsAsync.when(
      loading: () => const _EmptyState(),
      error: (_, _) => const _EmptyState(),
      data: (logs) {
        final number =
            selectedNumber ?? (logs.isNotEmpty ? logs.first.displayNumber : null);
        if (number == null) { return const _EmptyState(); }

        final callerLogs = logs.where((l) => l.displayNumber == number).toList();
        if (callerLogs.isEmpty) { return const _EmptyState(); }

        final group = CallerGroup(number, callerLogs);
        return _CallerDetail(group: group);
      },
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D14),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF5B52E8).withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF5B52E8).withValues(alpha: 0.15)),
              ),
              child: Icon(Icons.phone_outlined,
                  size: 28,
                  color: const Color(0xFF5B52E8).withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a caller to view history',
              style: GoogleFonts.dmSans(
                  fontSize: 14, color: Colors.white.withValues(alpha: 0.2)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Caller detail ────────────────────────────────────────────────────────────

class _CallerDetail extends ConsumerWidget {
  final CallerGroup group;
  const _CallerDetail({required this.group});

  static String _initials(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 2) { return digits.substring(digits.length - 2); }
    return number.isNotEmpty ? number[0].toUpperCase() : '?';
  }

  static Color _avatarColor(CallerGroup g) {
    if (g.hasMissed && g.latest.state == 'missed') { return const Color(0xFFEF4444); }
    if (g.latest.state == 'voicemail') { return const Color(0xFF7C75F0); }
    if (g.latest.direction == 'incoming' || g.latest.direction == 'inbound') { return const Color(0xFF22C55E); }
    return const Color(0xFF5B52E8);
  }

  static String _formatTime(DateTime? ts) {
    if (ts == null) { return ''; }
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inDays == 0) {
      final h = ts.hour.toString().padLeft(2, '0');
      final m = ts.minute.toString().padLeft(2, '0');
      return 'Today at $h:$m';
    }
    if (diff.inDays == 1) { return 'Yesterday'; }
    return '${ts.day}/${ts.month}/${ts.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final number = group.number;
    final color = _avatarColor(group);
    final missedCount = group.calls.where((c) => c.state == 'missed').length;
    final voicemailCount = group.calls
        .where((c) => c.state == 'voicemail' || c.recordingUrl != null)
        .length;

    return Container(
      color: const Color(0xFF0D0D14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Contact header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: Color(0xFF1E1E2E), width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: color.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _initials(number),
                      style: GoogleFonts.dmMono(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        number,
                        style: GoogleFonts.dmSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${group.totalCount} ${group.totalCount == 1 ? 'call' : 'calls'}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _ActionBtn(
                  icon: Icons.call,
                  label: 'Call back',
                  color: const Color(0xFF22C55E),
                  onTap: () => ref.read(telnyxProvider.notifier).dial(number),
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.chat_bubble_outline,
                  label: 'Message',
                  color: const Color(0xFF5B52E8),
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.person_add_outlined,
                  label: 'Save',
                  color: Colors.white.withValues(alpha: 0.3),
                  onTap: () {},
                  outlined: true,
                ),
              ],
            ),
          ),

          // ── Stats row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                _StatChip(
                  label: 'Total',
                  value: '${group.totalCount}',
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                if (missedCount > 0) ...[
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'Missed',
                    value: '$missedCount',
                    color: const Color(0xFFEF4444),
                  ),
                ],
                if (voicemailCount > 0) ...[
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'Voicemail',
                    value: '$voicemailCount',
                    color: const Color(0xFF7C75F0),
                  ),
                ],
              ],
            ),
          ),

          // ── Call history ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              'Call History',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.3),
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              itemCount: group.calls.length,
              itemBuilder: (context, i) =>
                  _CallEntry(log: group.calls[i], formatTime: _formatTime),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual call entry ────────────────────────────────────────────────────

class _CallEntry extends StatelessWidget {
  final CallLog log;
  final String Function(DateTime?) formatTime;

  const _CallEntry({required this.log, required this.formatTime});

  static Color _stateColor(CallLog log) {
    if (log.state == 'missed') { return const Color(0xFFEF4444); }
    if (log.state == 'voicemail') { return const Color(0xFF7C75F0); }
    if (log.direction == 'incoming' || log.direction == 'inbound') { return const Color(0xFF22C55E); }
    return const Color(0xFF5B52E8);
  }

  static IconData _stateIcon(CallLog log) {
    if (log.state == 'missed') { return Icons.call_missed; }
    if (log.state == 'voicemail') { return Icons.voicemail; }
    if (log.direction == 'incoming' || log.direction == 'inbound') { return Icons.call_received; }
    return Icons.call_made;
  }

  static String _stateLabel(CallLog log) {
    if (log.state == 'missed') { return 'Missed call'; }
    if (log.state == 'voicemail') { return 'Voicemail'; }
    if (log.state == 'answered') { return 'Call answered'; }
    return log.direction == 'incoming' || log.direction == 'inbound'
        ? 'Inbound call'
        : 'Outbound call';
  }

  static String _duration(int? s) {
    if (s == null || s <= 0) { return ''; }
    final m = s ~/ 60;
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final color = _stateColor(log);
    final dur = _duration(log.durationSeconds);
    final hasRecording = log.recordingUrl != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E1E2E)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_stateIcon(log), size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _stateLabel(log),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dur.isNotEmpty ? dur : formatTime(log.startedAt),
                  style: GoogleFonts.dmMono(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.3)),
                ),
              ],
            ),
          ),
          // Timestamp
          Text(
            formatTime(log.startedAt),
            style: GoogleFonts.dmSans(
                fontSize: 11, color: Colors.white.withValues(alpha: 0.2)),
          ),
          // Play button for recordings
          if (hasRecording) ...[
            const SizedBox(width: 10),
            _RecordingPlayer(
              url: log.recordingUrl!,
              storageBucket: 'call_recordings',
              storagePath: log.storagePath,
              callControlId: log.callControlId,
              fromNumber: log.fromNumber,
              toNumber: log.toNumber,
              startedAt: log.startedAt,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Recording player ─────────────────────────────────────────────────────────

class _RecordingPlayer extends StatefulWidget {
  final String url;
  final String? storagePath;
  final String storageBucket;
  final String? callControlId;
  final String? fromNumber;
  final String? toNumber;
  final DateTime? startedAt;
  const _RecordingPlayer({
    required this.url,
    required this.storageBucket,
    this.storagePath,
    this.callControlId,
    this.fromNumber,
    this.toNumber,
    this.startedAt,
  });

  @override
  State<_RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends State<_RecordingPlayer> {
  AudioPlayer? _player;
  bool _playerInitFailed = false;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _downloading = false;
  bool _downloaded = false;
  String? _storagePath; // cached after first fetch
  Uint8List? _cachedBytes; // downloaded once, reused for play + save

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    try {
      debugPrint('🎵 RecordingPlayer: creating AudioPlayer for ${widget.url}');
      _player = AudioPlayer();
      _player!.onPlayerStateChanged.listen((s) {
        debugPrint('🎵 PlayerState changed: $s');
        if (mounted) { setState(() => _playerState = s); }
      });
      _player!.onPositionChanged.listen((p) {
        if (mounted) { setState(() => _position = p); }
      });
      _player!.onDurationChanged.listen((d) {
        debugPrint('🎵 Duration: $d');
        if (mounted) { setState(() => _duration = d); }
      });
      debugPrint('🎵 AudioPlayer created OK');
    } catch (e, stack) {
      debugPrint('🎵 AudioPlayer init FAILED: $e\n$stack');
      _playerInitFailed = true;
      _player = null;
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  bool get _isPlaying => _playerState == PlayerState.playing;

  Future<void> _toggle() async {
    if (_playerInitFailed || _player == null) {
      debugPrint('🎵 _toggle: player not available (initFailed=$_playerInitFailed)');
      return;
    }
    if (_isPlaying) {
      debugPrint('🎵 _toggle: pausing');
      await _player!.pause();
      return;
    }
    // Resume mid-track if paused, otherwise start from cache or fetch.
    if (_playerState == PlayerState.paused) {
      await _player!.resume();
      return;
    }
    if (_cachedBytes != null) {
      debugPrint('🎵 _toggle: playing from cache (${_cachedBytes!.length} bytes)');
      await _player!.play(BytesSource(_cachedBytes!));
      return;
    }
    await _playFromStorage();
  }

  /// Fetch the recording from Supabase Storage. Generates a fresh signed URL
  /// on demand so it never expires before playback.
  Future<void> _playFromStorage() async {
    try {
      // Use storage_path from call_logs directly if available.
      String? path = widget.storagePath ?? _storagePath;

      // Fall back to querying voicemails table (older recordings).
      if (path == null) {
        final ccid = widget.callControlId;
        if (ccid == null) {
          debugPrint('🎵 _playFromStorage: no storagePath or callControlId');
          if (mounted) setState(() => _playerInitFailed = true);
          return;
        }
        debugPrint('🎵 _playFromStorage: querying voicemails for $ccid');
        final rows = await Supabase.instance.client
            .from('voicemails')
            .select('storage_path')
            .eq('call_control_id', ccid)
            .limit(1);
        path = rows.isNotEmpty ? rows.first['storage_path'] as String? : null;
      }

      if (path == null) {
        debugPrint('🎵 _playFromStorage: no storage_path found');
        if (mounted) setState(() => _playerInitFailed = true);
        return;
      }
      _storagePath = path;
      final bytes = await _fetchBytes(path);
      if (bytes == null) return;
      _cachedBytes = bytes;
      debugPrint('🎵 _playFromStorage: ${_cachedBytes!.length} bytes, calling play()');
      await _player!.play(BytesSource(_cachedBytes!));
      debugPrint('🎵 _playFromStorage: play() returned');
    } catch (e, stack) {
      debugPrint('🎵 _playFromStorage error: $e\n$stack');
      if (mounted) setState(() => _playerInitFailed = true);
    }
  }

  /// Downloads bytes from a Supabase Storage path via a fresh signed URL.
  Future<Uint8List?> _fetchBytes(String storagePath) async {
    try {
      final signed = await Supabase.instance.client.storage
          .from(widget.storageBucket)
          .createSignedUrl(storagePath, 3600);
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(signed));
      final response = await request.close();
      if (response.statusCode != 200) {
        debugPrint('🎵 _fetchBytes: HTTP ${response.statusCode}');
        client.close();
        if (mounted) setState(() => _playerInitFailed = true);
        return null;
      }
      final bytes = await response.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
      client.close();
      return Uint8List.fromList(bytes);
    } catch (e, stack) {
      debugPrint('🎵 _fetchBytes error: $e\n$stack');
      if (mounted) setState(() => _playerInitFailed = true);
      return null;
    }
  }

  /// Saves the recording to the user's Downloads folder.
  Future<void> _download() async {
    if (_downloading) return;
    if (mounted) setState(() => _downloading = true);
    try {
      // Use cached bytes if already fetched, otherwise fetch now.
      Uint8List? bytes = _cachedBytes;
      if (bytes == null) {
        // Ensure we have the storage path first.
        if (_storagePath == null) {
          final ccid = widget.callControlId;
          if (ccid == null) return;
          final rows = await Supabase.instance.client
              .from('voicemails')
              .select('storage_path')
              .eq('call_control_id', ccid)
              .limit(1);
          _storagePath = rows.isNotEmpty ? rows.first['storage_path'] as String? : null;
        }
        if (_storagePath == null) return;
        bytes = await _fetchBytes(_storagePath!);
        if (bytes == null) return;
        _cachedBytes = bytes;
      }

      // Save to Downloads folder.
      final home = Platform.environment['USERPROFILE'] // Windows
          ?? Platform.environment['HOME']              // macOS / Linux
          ?? '.';
      final downloadsDir = Directory('$home${Platform.pathSeparator}Downloads');
      if (!downloadsDir.existsSync()) downloadsDir.createSync(recursive: true);

      // Build filename from call log data, sanitising for Windows paths.
      String safe(String? s) =>
          (s ?? 'unknown').replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
      final from = safe(widget.fromNumber);
      final to = safe(widget.toNumber);
      final ts = widget.startedAt != null
          ? widget.startedAt!.toLocal().toString().substring(0, 16).replaceAll(':', '-')
          : safe(widget.callControlId);
      final filename = '${from}_to_${to}_$ts.mp3';
      final file = File('${downloadsDir.path}${Platform.pathSeparator}$filename');
      await file.writeAsBytes(bytes);
      debugPrint('🎵 Downloaded to ${file.path}');
      if (mounted) setState(() => _downloaded = true);
    } catch (e, stack) {
      debugPrint('🎵 _download error: $e\n$stack');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inSeconds > 0
        ? _position.inSeconds / _duration.inSeconds
        : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress bar (only when playing or paused mid-way)
        if (_duration > Duration.zero) ...[
          SizedBox(
            width: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: const Color(0xFF2A2A3E),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF7C75F0)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _fmt(_isPlaying ? _position : _duration),
            style: GoogleFonts.dmMono(
                fontSize: 9, color: Colors.white.withValues(alpha: 0.3)),
          ),
          const SizedBox(width: 6),
        ],
        // ── Play / Pause / Loading button ───────────────────────────
        GestureDetector(
          onTap: _playerInitFailed ? null : _toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _playerInitFailed
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFF7C75F0).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: _playerInitFailed
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFF7C75F0).withValues(alpha: 0.3)),
            ),
            child: _playerInitFailed
                ? Tooltip(
                    message: 'Recording unavailable',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off, size: 13,
                            color: Colors.white.withValues(alpha: 0.25)),
                        const SizedBox(width: 4),
                        Text('Unavailable',
                            style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.25))),
                      ],
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 14,
                        color: const Color(0xFF7C75F0),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isPlaying ? 'Pause' : 'Play',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF7C75F0),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        // ── Download button ─────────────────────────────────────────
        if (!_playerInitFailed) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _downloading ? null : _download,
            child: Tooltip(
              message: _downloaded ? 'Saved to Downloads' : 'Download recording',
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF2A2A3E)),
                ),
                child: _downloading
                    ? const Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: Color(0xFF7C75F0)),
                      )
                    : Icon(
                        _downloaded ? Icons.check : Icons.download,
                        size: 14,
                        color: _downloaded
                            ? const Color(0xFF22C55E)
                            : Colors.white.withValues(alpha: 0.4),
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Action button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.outlined
                ? (_hovered ? const Color(0xFF1E1E2E) : Colors.transparent)
                : (_hovered
                    ? widget.color.withValues(alpha: 0.2)
                    : widget.color.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.outlined
                  ? const Color(0xFF2A2A3E)
                  : widget.color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: widget.color),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 10, color: Colors.white.withValues(alpha: 0.25))),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.dmMono(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
