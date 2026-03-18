import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/voicemail.dart';
import '../../core/providers/voicemail_provider.dart';

class VoicemailPanel extends ConsumerWidget {
  const VoicemailPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: const Color(0xFF0D0D14),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GreetingSection(),
          Divider(color: Color(0xFF1E1E2E), height: 1),
          Expanded(child: _InboxSection()),
        ],
      ),
    );
  }
}

// ── Greeting section ─────────────────────────────────────────────────────────

class _GreetingSection extends ConsumerStatefulWidget {
  const _GreetingSection();

  @override
  ConsumerState<_GreetingSection> createState() => _GreetingSectionState();
}

enum _GreetingState { idle, recording, recorded, uploading }

class _GreetingSectionState extends ConsumerState<_GreetingSection> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  _GreetingState _state = _GreetingState.idle;
  Uint8List? _recordedBytes;
  int _recordSeconds = 0;
  bool _previewPlaying = false;
  bool _existingPlaying = false;

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    final tmpPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kallo_greeting_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: tmpPath,
    );
    setState(() {
      _state = _GreetingState.recording;
      _recordSeconds = 0;
      _recordedBytes = null;
    });
    _tickTimer();
  }

  void _tickTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _state != _GreetingState.recording) return;
      setState(() => _recordSeconds++);
      _tickTimer();
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    setState(() {
      _state = _GreetingState.recorded;
      _recordedBytes = bytes;
    });
  }

  Future<void> _previewToggle() async {
    if (_recordedBytes == null) return;
    if (_previewPlaying) {
      await _player.pause();
      setState(() => _previewPlaying = false);
      return;
    }
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _previewPlaying = false);
    });
    await _player.play(BytesSource(_recordedBytes!));
    setState(() => _previewPlaying = true);
  }

  Future<void> _saveGreeting() async {
    if (_recordedBytes == null) return;
    setState(() => _state = _GreetingState.uploading);
    try {
      await Supabase.instance.client.storage
          .from('voicemails')
          .uploadBinary(kGreetingPath, _recordedBytes!,
              fileOptions: const FileOptions(contentType: 'audio/wav', upsert: true));
      ref.invalidate(greetingExistsProvider);
      setState(() {
        _state = _GreetingState.idle;
        _recordedBytes = null;
      });
    } catch (e) {
      debugPrint('Greeting upload error: $e');
      setState(() => _state = _GreetingState.recorded);
    }
  }

  Future<void> _deleteGreeting() async {
    await Supabase.instance.client.storage
        .from('voicemails')
        .remove([kGreetingPath]);
    ref.invalidate(greetingExistsProvider);
  }

  Future<void> _playExistingToggle() async {
    if (_existingPlaying) {
      await _player.pause();
      setState(() => _existingPlaying = false);
      return;
    }
    try {
      final signed = await Supabase.instance.client.storage
          .from('voicemails')
          .createSignedUrl(kGreetingPath, 3600);
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(signed));
      final response = await request.close();
      final bytes = await response.fold<List<int>>([], (a, c) => a..addAll(c));
      client.close();
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _existingPlaying = false);
      });
      await _player.play(BytesSource(Uint8List.fromList(bytes)));
      setState(() => _existingPlaying = true);
    } catch (e) {
      debugPrint('Greeting playback error: $e');
    }
  }

  String _fmtSeconds(int s) {
    final m = s ~/ 60;
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final greetingAsync = ref.watch(greetingExistsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.voicemail, size: 16, color: Color(0xFF7C75F0)),
              const SizedBox(width: 8),
              Text('Voicemail Greeting',
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8))),
            ],
          ),
          const SizedBox(height: 14),
          switch (_state) {
            _GreetingState.recording => _buildRecording(),
            _GreetingState.recorded => _buildRecorded(),
            _GreetingState.uploading => _buildUploading(),
            _GreetingState.idle => greetingAsync.when(
                loading: () => const SizedBox(height: 36,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF7C75F0)))),
                error: (_, _) => _buildNoGreeting(),
                data: (exists) => exists ? _buildHasGreeting() : _buildNoGreeting(),
              ),
          },
        ],
      ),
    );
  }

  Widget _buildNoGreeting() => Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF13131F),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A2A3E)),
            ),
            child: Text('Default TTS greeting active',
                style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white.withValues(alpha: 0.3))),
          ),
          const SizedBox(width: 10),
          _ActionChip(
            icon: Icons.fiber_manual_record,
            label: 'Record custom',
            color: const Color(0xFF7C75F0),
            onTap: _startRecording,
          ),
        ],
      );

  Widget _buildHasGreeting() => Row(
        children: [
          _ActionChip(
            icon: _existingPlaying ? Icons.pause : Icons.play_arrow,
            label: _existingPlaying ? 'Pause' : 'Play',
            color: const Color(0xFF7C75F0),
            onTap: _playExistingToggle,
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.fiber_manual_record,
            label: 'Re-record',
            color: Colors.white.withValues(alpha: 0.4),
            onTap: _startRecording,
            outlined: true,
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: const Color(0xFFEF4444),
            onTap: _deleteGreeting,
            outlined: true,
          ),
        ],
      );

  Widget _buildRecording() => Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(_fmtSeconds(_recordSeconds),
              style: GoogleFonts.dmMono(fontSize: 13, color: const Color(0xFFEF4444))),
          const SizedBox(width: 12),
          _ActionChip(
            icon: Icons.stop,
            label: 'Stop',
            color: const Color(0xFFEF4444),
            onTap: _stopRecording,
          ),
        ],
      );

  Widget _buildRecorded() => Row(
        children: [
          _ActionChip(
            icon: _previewPlaying ? Icons.pause : Icons.play_arrow,
            label: _previewPlaying ? 'Pause' : 'Preview',
            color: const Color(0xFF7C75F0),
            onTap: _previewToggle,
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.check,
            label: 'Save',
            color: const Color(0xFF22C55E),
            onTap: _saveGreeting,
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.close,
            label: 'Discard',
            color: Colors.white.withValues(alpha: 0.3),
            onTap: () => setState(() {
              _state = _GreetingState.idle;
              _recordedBytes = null;
            }),
            outlined: true,
          ),
        ],
      );

  Widget _buildUploading() => Row(
        children: [
          const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF7C75F0)),
          ),
          const SizedBox(width: 10),
          Text('Saving greeting…',
              style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
        ],
      );
}

// ── Inbox section ─────────────────────────────────────────────────────────────

class _InboxSection extends ConsumerWidget {
  const _InboxSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vmAsync = ref.watch(voicemailListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: vmAsync.when(
            loading: () => Text('Inbox',
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.3), letterSpacing: 0.8)),
            error: (_, _) => Text('Inbox',
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.3), letterSpacing: 0.8)),
            data: (vms) => Text('Inbox (${vms.length})',
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.3), letterSpacing: 0.8)),
          ),
        ),
        Expanded(
          child: vmAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5B52E8))),
            error: (e, _) => Center(
                child: Text('Failed to load', style: GoogleFonts.dmSans(color: Colors.white38))),
            data: (vms) => vms.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.voicemail, size: 40, color: Colors.white.withValues(alpha: 0.08)),
                        const SizedBox(height: 12),
                        Text('No voicemails yet',
                            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white.withValues(alpha: 0.2))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: vms.length,
                    itemBuilder: (_, i) => _VoicemailItem(key: ValueKey(vms[i].id), vm: vms[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Voicemail list item ───────────────────────────────────────────────────────

class _VoicemailItem extends ConsumerStatefulWidget {
  final Voicemail vm;
  const _VoicemailItem({super.key, required this.vm});

  @override
  ConsumerState<_VoicemailItem> createState() => _VoicemailItemState();
}

class _VoicemailItemState extends ConsumerState<_VoicemailItem> {
  AudioPlayer? _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = false;
  bool _deleting = false;
  Uint8List? _cachedBytes;

  @override
  void initState() {
    super.initState();
    try {
      _player = AudioPlayer();
      _player!.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _playerState = s);
      });
      _player!.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _player!.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
    } catch (e) {
      debugPrint('AudioPlayer init error: $e');
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  bool get _isPlaying => _playerState == PlayerState.playing;

  Future<void> _toggle() async {
    if (_player == null) return;
    if (_isPlaying) { await _player!.pause(); return; }
    if (_cachedBytes != null) { await _player!.play(BytesSource(_cachedBytes!)); return; }

    final path = widget.vm.storagePath;
    if (path == null) return;
    setState(() => _loading = true);
    try {
      final signed = await Supabase.instance.client.storage
          .from('voicemails').createSignedUrl(path, 3600);
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(signed));
      final res = await req.close();
      final bytes = await res.fold<List<int>>([], (a, c) => a..addAll(c));
      client.close();
      _cachedBytes = Uint8List.fromList(bytes);
      await _player!.play(BytesSource(_cachedBytes!));
    } catch (e) {
      debugPrint('Voicemail play error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      if (widget.vm.storagePath != null) {
        await Supabase.instance.client.storage
            .from('voicemails').remove([widget.vm.storagePath!]);
      }
      await Supabase.instance.client
          .from('voicemails').delete().eq('id', widget.vm.id);
      ref.invalidate(voicemailListProvider);
    } catch (e) {
      debugPrint('Delete error: $e');
      if (mounted) setState(() => _deleting = false);
    }
  }

  static String _initials(String? number) {
    if (number == null) return '?';
    final digits = number.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 2 ? digits.substring(digits.length - 2) : '?';
  }

  static String _fmtDuration(int? s) {
    if (s == null || s <= 0) return '';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  static String _fmtDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inDays == 0) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${local.day}/${local.month}/${local.year}';
  }

  String _fmtProgress(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final from = widget.vm.fromNumber;
    final progress = _duration.inSeconds > 0
        ? (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E1E2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C75F0).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF7C75F0).withValues(alpha: 0.25)),
                ),
                child: Center(
                  child: Text(_initials(from),
                      style: GoogleFonts.dmMono(fontSize: 11, fontWeight: FontWeight.w600,
                          color: const Color(0xFF7C75F0))),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(from ?? 'Unknown',
                        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(_fmtDate(widget.vm.createdAt),
                            style: GoogleFonts.dmMono(fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
                        if (widget.vm.durationSeconds != null) ...[
                          Text(' · ${_fmtDuration(widget.vm.durationSeconds)}',
                              style: GoogleFonts.dmMono(fontSize: 10, color: Colors.white.withValues(alpha: 0.25))),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Delete
              GestureDetector(
                onTap: _deleting ? null : _delete,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2A2A3E)),
                  ),
                  child: _deleting
                      ? const Padding(padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFEF4444)))
                      : Icon(Icons.delete_outline, size: 14, color: Colors.white.withValues(alpha: 0.3)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Player row
          Row(
            children: [
              // Progress bar
              if (_duration > Duration.zero) ...[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: const Color(0xFF2A2A3E),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF7C75F0)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_fmtProgress(_isPlaying ? _position : _duration),
                    style: GoogleFonts.dmMono(fontSize: 9, color: Colors.white.withValues(alpha: 0.3))),
                const SizedBox(width: 8),
              ],
              // Play/Pause button
              GestureDetector(
                onTap: _toggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C75F0).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF7C75F0).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14, height: 14,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_loading)
                              const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF7C75F0))),
                            Icon(_loading || _isPlaying ? Icons.pause : Icons.play_arrow,
                                size: _loading ? 9 : 14, color: const Color(0xFF7C75F0)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(_loading ? 'Loading' : _isPlaying ? 'Pause' : 'Play',
                          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500,
                              color: const Color(0xFF7C75F0))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared action chip ────────────────────────────────────────────────────────

class _ActionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                  : widget.color.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 13, color: widget.color),
              const SizedBox(width: 5),
              Text(widget.label,
                  style: GoogleFonts.dmSans(
                      fontSize: 12, fontWeight: FontWeight.w500, color: widget.color)),
            ],
          ),
        ),
      ),
    );
  }
}
