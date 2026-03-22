import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/dialler_providers.dart';
import '../../core/providers/telnyx_provider.dart';

class KeypadPanel extends ConsumerWidget {
  const KeypadPanel({super.key});

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

  static const _callerIds = ['1234', '5678', '9012', '3456'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dialledNumber = ref.watch(dialledNumberProvider);
    final callerId = ref.watch(callerIdProvider);

    return Container(
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Caller ID dropdown
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: callerId,
                      isExpanded: true,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: const Color(0xFF374151)),
                      icon: const Icon(Icons.keyboard_arrow_down,
                          size: 18, color: Color(0xFF6B7280)),
                      onChanged: (v) {
                        if (v != null) {
                          ref.read(callerIdProvider.notifier).set(v);
                        }
                      },
                      items: _callerIds
                          .map((id) => DropdownMenuItem(
                                value: id,
                                child: Text('Caller ID: $id',
                                    style: GoogleFonts.inter(fontSize: 13)),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Number display
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dialledNumber.isEmpty
                              ? 'Enter number or name'
                              : dialledNumber,
                          style: GoogleFonts.inter(
                            fontSize: dialledNumber.isEmpty ? 13 : 22,
                            color: dialledNumber.isEmpty
                                ? const Color(0xFFD1D5DB)
                                : const Color(0xFF111827),
                            fontWeight: dialledNumber.isEmpty
                                ? FontWeight.w400
                                : FontWeight.w300,
                            letterSpacing:
                                dialledNumber.isEmpty ? 0 : 2,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (dialledNumber.isNotEmpty)
                        GestureDetector(
                          onTap: () =>
                              ref.read(dialledNumberProvider.notifier).clear(),
                          child: const Icon(Icons.close,
                              size: 18, color: Color(0xFF9CA3AF)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Keypad grid
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.7,
                  children: _keys
                      .map((k) => _KeyButton(
                            digit: k.$1,
                            sub: k.$2,
                            onTap: () => ref
                                .read(dialledNumberProvider.notifier)
                                .append(k.$1),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                // Action buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: Icons.voicemail,
                      color: const Color(0xFF6B7280),
                      onTap: () {},
                    ),
                    _CallButton(
                      icon: Icons.call,
                      bgColor: const Color(0xFF22C55E),
                      onTap: () {
                        final number = ref.read(dialledNumberProvider);
                        if (number.isNotEmpty) {
                          ref.read(telnyxProvider.notifier).dial(number);
                        }
                      },
                    ),
                    _ActionButton(
                      icon: Icons.videocam_outlined,
                      color: const Color(0xFF6B7280),
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyButton extends StatefulWidget {
  final String digit;
  final String sub;
  final VoidCallback onTap;

  const _KeyButton(
      {required this.digit, required this.sub, required this.onTap});

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
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
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFFEDE9FE) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _pressed
                ? const Color(0xFF6C63FF)
                : const Color(0xFFE5E7EB),
          ),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
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
                fontSize: 20,
                fontWeight: FontWeight.w300,
                color: const Color(0xFF111827),
              ),
            ),
            if (widget.sub.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(
                widget.sub,
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF9CA3AF),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final VoidCallback onTap;

  const _CallButton(
      {required this.icon, required this.bgColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
