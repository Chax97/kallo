import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/sip_provider.dart';
import '../../providers/telnyx_provider.dart';

class ActiveCallOverlay extends ConsumerStatefulWidget {
  const ActiveCallOverlay({super.key});

  @override
  ConsumerState<ActiveCallOverlay> createState() => _ActiveCallOverlayState();
}

class _ActiveCallOverlayState extends ConsumerState<ActiveCallOverlay> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _elapsed = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  String get _formattedDuration {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final tx = ref.watch(telnyxProvider);
    final verto = ref.watch(vertoProvider);

    ref.listen(telnyxProvider, (prev, next) {
      if (next.call == TxCallState.active && prev?.call != TxCallState.active) _startTimer();
      if (next.call == TxCallState.idle) {
        _timer?.cancel();
        _elapsed = Duration.zero;
      }
    });

    ref.listen(vertoProvider, (prev, next) {
      if (next.call == VertoCallState.active && prev?.call != VertoCallState.active) _startTimer();
      if (next.call == VertoCallState.idle) {
        _timer?.cancel();
        _elapsed = Duration.zero;
      }
    });

    // ── Inbound ring screen ───────────────────────────────────────────────
    if (verto.call == VertoCallState.inbound) {
      return _InboundCallScreen(
        callerNumber: verto.inboundCallerNumber ?? 'Unknown',
        onAnswer: () => ref.read(vertoProvider.notifier).acceptCall(),
        onDecline: () => ref.read(vertoProvider.notifier).declineCall(),
      );
    }

    // ── Active call bar ───────────────────────────────────────────────────
    final isOutboundActive = tx.call != TxCallState.idle;
    final isInboundActive = verto.call == VertoCallState.active;
    if (!isOutboundActive && !isInboundActive) return const SizedBox.shrink();

    final displayNumber = isInboundActive ? (verto.inboundCallerNumber ?? '') : (tx.activeNumber ?? '');
    final isMuted = isInboundActive ? verto.muted : tx.muted;

    final statusLabel = switch (tx.call) {
      TxCallState.dialing => 'Dialing...',
      TxCallState.ringing => 'Ringing...',
      TxCallState.active => _formattedDuration,
      TxCallState.idle => isInboundActive ? _formattedDuration : '',
    };

    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 360,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A3E)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
                  ),
                  child: Icon(Icons.call, size: 18, color: const Color(0xFF22C55E).withOpacity(0.8)),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayNumber,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusLabel,
                        style: GoogleFonts.dmMono(
                          fontSize: 12,
                          color: const Color(0xFF22C55E).withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Mute
                _CallControl(
                  icon: isMuted ? Icons.mic_off : Icons.mic,
                  color: isMuted ? const Color(0xFFF59E0B) : Colors.white.withOpacity(0.4),
                  onTap: () {
                    if (isInboundActive) {
                      ref.read(vertoProvider.notifier).toggleMute();
                    } else {
                      ref.read(telnyxProvider.notifier).toggleMute();
                    }
                  },
                ),
                const SizedBox(width: 8),
                // Hangup
                GestureDetector(
                  onTap: () {
                    if (isInboundActive) {
                      ref.read(vertoProvider.notifier).hangup();
                    } else {
                      ref.read(telnyxProvider.notifier).hangup();
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallControl extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CallControl({required this.icon, required this.color, required this.onTap});

  @override
  State<_CallControl> createState() => _CallControlState();
}

class _CallControlState extends State<_CallControl> {
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF1E1E2E) : const Color(0xFF13131F),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2A2A3E)),
          ),
          child: Icon(widget.icon, color: widget.color, size: 18),
        ),
      ),
    );
  }
}

// ── Inbound call screen ─────────────────────────────────────────────────────

class _InboundCallScreen extends StatefulWidget {
  final String callerNumber;
  final VoidCallback onAnswer;
  final VoidCallback onDecline;

  const _InboundCallScreen({
    required this.callerNumber,
    required this.onAnswer,
    required this.onDecline,
  });

  @override
  State<_InboundCallScreen> createState() => _InboundCallScreenState();
}

class _InboundCallScreenState extends State<_InboundCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 360,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF5B52E8).withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5B52E8).withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Pulsing avatar
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => Transform.scale(
                    scale: _pulse.value,
                    child: child,
                  ),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B52E8).withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF5B52E8).withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.call_received, size: 20, color: Color(0xFF7C75F0)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Incoming call',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.callerNumber,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Decline
                GestureDetector(
                  onTap: widget.onDecline,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.call_end, color: Color(0xFFEF4444), size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                // Answer
                GestureDetector(
                  onTap: widget.onAnswer,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}