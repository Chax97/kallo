import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/dialler_providers.dart';
import '../../providers/telnyx_provider.dart';

const _kPanelWidth = 280.0;
// Used only for drag clamping — actual height is determined by the Column layout.
const _kPanelEstH = 370.0;
const _kBubbleSize = 52.0;
const _kEdge = 8.0;

class FloatingDialer extends ConsumerStatefulWidget {
  const FloatingDialer({super.key});

  @override
  ConsumerState<FloatingDialer> createState() => _FloatingDialerState();
}

class _FloatingDialerState extends ConsumerState<FloatingDialer> {
  // Top-left of the entire combined widget (panel + bubble column).
  Offset _position = const Offset(120, 80);
  bool _open = false;
  bool _openAbove = false;

  static const _callerIds = ['1234', '5678', '9012', '3456'];

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

  // ── Toggle ──────────────────────────────────────────────────────────────────

  void _toggle(Size screen) {
    if (!_open) {
      // Decide which side has more space and lock it for the session.
      final spaceAbove = _position.dy - _kEdge;
      final spaceBelow = screen.height - (_position.dy + _kBubbleSize) - _kEdge;
      _openAbove = spaceAbove >= spaceBelow;

      // When opening above the bubble shifts _position up so the panel appears
      // above; the bubble stays at its original screen position.
      if (_openAbove) {
        _position = _clamp(
          Offset(_position.dx, _position.dy - _kPanelEstH),
          screen,
          open: true,
          openAbove: true,
        );
      } else {
        _position = _clamp(_position, screen, open: true, openAbove: false);
      }
    } else {
      // When closing above, restore _position to the bubble's screen position.
      if (_openAbove) {
        _position = Offset(_position.dx, _position.dy + _kPanelEstH);
      }
    }
    setState(() => _open = !_open);
  }

  // ── Drag ────────────────────────────────────────────────────────────────────

  void _onPanUpdate(DragUpdateDetails d, Size screen) {
    setState(() {
      _position = _clamp(
        Offset(_position.dx + d.delta.dx, _position.dy + d.delta.dy),
        screen,
        open: _open,
        openAbove: _openAbove,
      );
    });
  }

  Offset _clamp(Offset pos, Size screen,
      {required bool open, required bool openAbove}) {
    final totalH =
        open ? _kBubbleSize + _kPanelEstH : _kBubbleSize;
    return Offset(
      pos.dx.clamp(_kEdge, screen.width - _kPanelWidth - _kEdge),
      pos.dy.clamp(_kEdge, (screen.height - totalH - _kEdge).clamp(_kEdge, double.infinity)),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final dialledNumber = ref.watch(dialledNumberProvider);
    final callerId = ref.watch(callerIdProvider);

    final panel = _buildPanel(dialledNumber, callerId, screen);
    final bubble = _buildBubble(screen);

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _open && _openAbove
                  ? [panel, bubble]
                  : _open
                      ? [bubble, panel]
                      : [bubble],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bubble ───────────────────────────────────────────────────────────────────

  Widget _buildBubble(Size screen) {
    // Flatten the corners where the bubble meets the panel.
    final borderRadius = _open
        ? BorderRadius.only(
            topLeft: Radius.circular(_openAbove ? 0 : 26),
            topRight: Radius.circular(_openAbove ? 0 : 26),
            bottomLeft: Radius.circular(_openAbove ? 26 : 0),
            bottomRight: Radius.circular(_openAbove ? 26 : 0),
          )
        : BorderRadius.circular(26);

    return GestureDetector(
      onPanUpdate: (d) => _onPanUpdate(d, screen),
      onTap: () => _toggle(screen),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: _kBubbleSize,
        height: _kBubbleSize,
        decoration: BoxDecoration(
          color: const Color(0xFF5B52E8),
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B52E8).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          _open ? Icons.close : Icons.phone,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  // ── Panel ─────────────────────────────────────────────────────────────────────

  Widget _buildPanel(String dialledNumber, String callerId, Size screen) {
    // Round the corners that face away from the bubble.
    const r = Radius.circular(14);
    final borderRadius = _openAbove
        ? const BorderRadius.only(topLeft: r, topRight: r)
        : const BorderRadius.only(bottomLeft: r, bottomRight: r);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: _kPanelWidth,
        decoration: BoxDecoration(
          color: const Color(0xFF13131F),
          borderRadius: borderRadius,
          border: Border(
            top: _openAbove
                ? const BorderSide(color: Color(0xFF2A2A3E))
                : BorderSide.none,
            left: const BorderSide(color: Color(0xFF2A2A3E)),
            right: const BorderSide(color: Color(0xFF2A2A3E)),
            bottom: _openAbove
                ? BorderSide.none
                : const BorderSide(color: Color(0xFF2A2A3E)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 32,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header / drag handle ────────────────────────────────────
              GestureDetector(
                onPanUpdate: (d) => _onPanUpdate(d, screen),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: _openAbove
                        ? const BorderRadius.only(topLeft: r, topRight: r)
                        : BorderRadius.zero,
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFF2A2A3E), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.drag_indicator,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: callerId,
                            isDense: true,
                            dropdownColor: const Color(0xFF1A1A2E),
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            icon: Icon(Icons.keyboard_arrow_down,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.3)),
                            onChanged: (v) {
                              if (v != null) {
                                ref.read(callerIdProvider.notifier).set(v);
                              }
                            },
                            items: _callerIds
                                .map((id) => DropdownMenuItem(
                                      value: id,
                                      child: Text('+$id',
                                          style: GoogleFonts.dmSans(
                                              fontSize: 12,
                                              color: Colors.white
                                                  .withValues(alpha: 0.8))),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Number display ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF2A2A3E), width: 1),
                  ),
                ),
                child: Text(
                  dialledNumber.isEmpty ? 'Enter number…' : dialledNumber,
                  style: GoogleFonts.dmMono(
                    fontSize: dialledNumber.isEmpty ? 13 : 22,
                    color: dialledNumber.isEmpty
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w400,
                    letterSpacing: dialledNumber.isEmpty ? 0 : 2.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),

              // ── Keypad ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 2.1,
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
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CircleBtn(
                      size: 48,
                      color: const Color(0xFF1A1A2E),
                      borderColor: const Color(0xFF2A2A3E),
                      onTap: () =>
                          ref.read(dialledNumberProvider.notifier).trimLast(),
                      onLongPress: () =>
                          ref.read(dialledNumberProvider.notifier).clear(),
                      child: Icon(Icons.backspace_outlined,
                          size: 17,
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    GestureDetector(
                      onTap: () {
                        final number = ref.read(dialledNumberProvider);
                        if (number.isNotEmpty) {
                          ref.read(telnyxProvider.notifier).dial(number);
                        }
                      },
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22C55E)
                                  .withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.call,
                            color: Colors.white, size: 26),
                      ),
                    ),
                    _CircleBtn(
                      size: 48,
                      color: const Color(0xFF1A1A2E),
                      borderColor: const Color(0xFF2A2A3E),
                      onTap: () {},
                      child: Icon(Icons.people_outline,
                          size: 17,
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Key button ───────────────────────────────────────────────────────────────

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
          color: _pressed
              ? const Color(0xFF5B52E8).withValues(alpha: 0.15)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _pressed
                ? const Color(0xFF5B52E8).withValues(alpha: 0.5)
                : const Color(0xFF2A2A3E),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.digit,
              style: GoogleFonts.dmSans(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: _pressed
                    ? const Color(0xFF5B52E8)
                    : Colors.white.withValues(alpha: 0.85),
              ),
            ),
            if (widget.sub.isNotEmpty)
              Text(
                widget.sub,
                style: GoogleFonts.dmSans(
                  fontSize: 7,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.3),
                  letterSpacing: 0.8,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Small circle button ──────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final double size;
  final Color color;
  final Color borderColor;
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CircleBtn({
    required this.size,
    required this.color,
    required this.borderColor,
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
        ),
        child: child,
      ),
    );
  }
}
