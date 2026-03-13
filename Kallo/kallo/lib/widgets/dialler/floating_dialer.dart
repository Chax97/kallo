import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/dialler_providers.dart';
import '../../providers/telnyx_provider.dart';

class FloatingDialer extends ConsumerStatefulWidget {
  const FloatingDialer({super.key});

  @override
  ConsumerState<FloatingDialer> createState() => _FloatingDialerState();
}

class _FloatingDialerState extends ConsumerState<FloatingDialer> {
  Offset _position = const Offset(120, 80);
  bool _minimized = false;

  static const _callerIds = ['1234', '5678', '9012', '3456'];
  static const _devices = ['This Device', 'SIP Phone', 'Web Phone'];
  String _device = 'This Device';

  static const _keys = [
    ('1', ''),
    ('2', 'ABC'),
    ('3', 'DEF'),
    ('4', 'GHI'),
    ('5', 'JKL'),
    ('6', 'MNO'),
    ('7', 'PQRS'),
    ('8', 'TUV'),
    ('9', 'WXYZ'),
    ('*', '.'),
    ('0', '+'),
    ('#', ''),
  ];

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _position = Offset(
        _position.dx + d.delta.dx,
        _position.dy + d.delta.dy,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_minimized) {
      return Positioned(
        left: _position.dx,
        top: _position.dy,
        child: GestureDetector(
          onPanUpdate: _onPanUpdate,
          onTap: () => setState(() => _minimized = false),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.dialpad, color: Colors.white, size: 22),
          ),
        ),
      );
    }

    final dialledNumber = ref.watch(dialledNumberProvider);
    final callerId = ref.watch(callerIdProvider);

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 290,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 40,
                offset: const Offset(0, 10),
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header (drag handle) ──────────────────────────────────
                GestureDetector(
                  onPanUpdate: _onPanUpdate,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Caller ID selector
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: callerId,
                              isDense: true,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF374151),
                              ),
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  size: 14, color: Color(0xFF6B7280)),
                              onChanged: (v) {
                                if (v != null) {
                                  ref.read(callerIdProvider.notifier).set(v);
                                }
                              },
                              items: _callerIds
                                  .map((id) => DropdownMenuItem(
                                        value: id,
                                        child: Text('+$id',
                                            style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color:
                                                    const Color(0xFF374151))),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                        // Via device selector
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _device,
                              isDense: true,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF6B7280),
                              ),
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  size: 13, color: Color(0xFF9CA3AF)),
                              onChanged: (v) {
                                if (v != null) setState(() => _device = v);
                              },
                              items: _devices
                                  .map((d) => DropdownMenuItem(
                                        value: d,
                                        child: Text('via $d',
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color:
                                                    const Color(0xFF6B7280))),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                        // Minimize button
                        GestureDetector(
                          onTap: () => setState(() => _minimized = true),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.remove,
                                size: 14, color: Color(0xFF6B7280)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Number display ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dialledNumber.isEmpty
                              ? 'Enter Name or Number'
                              : dialledNumber,
                          style: GoogleFonts.inter(
                            fontSize: dialledNumber.isEmpty ? 14 : 22,
                            color: dialledNumber.isEmpty
                                ? const Color(0xFFD1D5DB)
                                : const Color(0xFF111827),
                            fontWeight: dialledNumber.isEmpty
                                ? FontWeight.w400
                                : FontWeight.w300,
                            letterSpacing: dialledNumber.isEmpty ? 0 : 2,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Keypad grid ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 7,
                    crossAxisSpacing: 7,
                    childAspectRatio: 2.0,
                    children: _keys
                        .map((k) => _FloatKey(
                              digit: k.$1,
                              sub: k.$2,
                              onTap: () => ref
                                  .read(dialledNumberProvider.notifier)
                                  .append(k.$1),
                            ))
                        .toList(),
                  ),
                ),

                // ── Action row ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Contacts / voicemail
                      _OutlineRoundBtn(
                        icon: Icons.people_outline,
                        size: 50,
                        onTap: () {},
                      ),
                      // Call button
                      GestureDetector(
                        onTap: () {
                          final number = ref.read(dialledNumberProvider);
                          if (number.isNotEmpty) {
                            ref.read(telnyxProvider.notifier).dial(number);
                          }
                        },
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF22C55E)
                                    .withValues(alpha: 0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.call,
                              color: Colors.white, size: 28),
                        ),
                      ),
                      // Backspace — tap to trim, long-press to clear
                      GestureDetector(
                        onTap: () =>
                            ref.read(dialledNumberProvider.notifier).trimLast(),
                        onLongPress: () =>
                            ref.read(dialledNumberProvider.notifier).clear(),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            border:
                                Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Icon(Icons.backspace_outlined,
                              size: 18, color: Color(0xFF6B7280)),
                        ),
                      ),
                    ],
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

// ── Key button ─────────────────────────────────────────────────────────────────
class _FloatKey extends StatefulWidget {
  final String digit;
  final String sub;
  final VoidCallback onTap;

  const _FloatKey(
      {required this.digit, required this.sub, required this.onTap});

  @override
  State<_FloatKey> createState() => _FloatKeyState();
}

class _FloatKeyState extends State<_FloatKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFFEDE9FE) : const Color(0xFFF9FAFB),
          shape: BoxShape.circle,
          border: Border.all(
            color: _pressed
                ? const Color(0xFF6C63FF)
                : const Color(0xFFE5E7EB),
          ),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.digit,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w300,
                color: const Color(0xFF111827),
              ),
            ),
            if (widget.sub.isNotEmpty)
              Text(
                widget.sub,
                style: GoogleFonts.inter(
                  fontSize: 7,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF9CA3AF),
                  letterSpacing: 1.0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Outline round button ───────────────────────────────────────────────────────
class _OutlineRoundBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _OutlineRoundBtn(
      {required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
      ),
    );
  }
}
