import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> showAddContactDialog(
  BuildContext context, {
  String? prefillPhone,
  VoidCallback? onSaved,
}) {
  return showDialog(
    context: context,
    builder: (_) =>
        _AddContactDialog(prefillPhone: prefillPhone, onSaved: onSaved),
  );
}

class _AddContactDialog extends StatefulWidget {
  final String? prefillPhone;
  final VoidCallback? onSaved;
  const _AddContactDialog({this.prefillPhone, this.onSaved});

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController();
  late final TextEditingController _company = TextEditingController();
  late final TextEditingController _phone = TextEditingController();
  late final TextEditingController _mobile = TextEditingController();
  late final TextEditingController _notes = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillPhone != null) {
      _phone.text = widget.prefillPhone!;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _phone.dispose();
    _mobile.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('phonebook_contacts').insert({
        'name': _name.text.trim(),
        if (_company.text.trim().isNotEmpty)
          'company_name': _company.text.trim(),
        if (_phone.text.trim().isNotEmpty)
          'phone_number': _phone.text.trim(),
        if (_mobile.text.trim().isNotEmpty)
          'mobile_number': _mobile.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      });
      if (mounted) {
        widget.onSaved?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save contact: $e',
                style: GoogleFonts.dmSans(fontSize: 12)),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF13131F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF1E1E2E)),
      ),
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B52E8).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF5B52E8).withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.person_add_outlined,
                          size: 15, color: Color(0xFF5B52E8)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'New Contact',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.close,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _Field(
                  label: 'Name',
                  controller: _name,
                  required: true,
                  hint: 'Full name',
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Company Name',
                  controller: _company,
                  hint: 'Organisation',
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Phone Number',
                  controller: _phone,
                  hint: '+44...',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Mobile Number',
                  controller: _mobile,
                  hint: '+44...',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Notes',
                  controller: _notes,
                  hint: 'Any additional info…',
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DialogBtn(
                      label: 'Cancel',
                      onTap: () => Navigator.of(context).pop(),
                      filled: false,
                    ),
                    const SizedBox(width: 8),
                    _DialogBtn(
                      label: _saving ? 'Saving…' : 'Save Contact',
                      onTap: _saving ? null : _save,
                      filled: true,
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

// ── Helpers ───────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Colors.white.withValues(alpha: 0.4),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool required;
  final String? hint;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    this.required = false,
    this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.dmSans(
              fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.2)),
            filled: true,
            fillColor: const Color(0xFF0D0D14),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2A2A3E)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2A2A3E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF5B52E8)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            isDense: true,
          ),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
        ),
      ],
    );
  }
}

class _DialogBtn extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  const _DialogBtn(
      {required this.label, required this.onTap, required this.filled});

  @override
  State<_DialogBtn> createState() => _DialogBtnState();
}

class _DialogBtnState extends State<_DialogBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: widget.filled
                ? (_hovered
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFF5B52E8))
                : (_hovered
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: widget.filled
                ? null
                : Border.all(color: const Color(0xFF2A2A3E)),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: widget.filled
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
