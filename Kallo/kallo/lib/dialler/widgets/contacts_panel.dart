import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/contact.dart';
import '../../core/providers/contact_provider.dart';
import '../../core/providers/telnyx_provider.dart';
import 'add_contact_dialog.dart';

class ContactsPanel extends ConsumerStatefulWidget {
  const ContactsPanel({super.key});

  @override
  ConsumerState<ContactsPanel> createState() => _ContactsPanelState();
}

class _ContactsPanelState extends ConsumerState<ContactsPanel> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        border: Border(left: BorderSide(color: Color(0xFF1E1E2E), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Text(
                  'Contacts',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const Spacer(),
                _IconBtn(
                  icon: Icons.person_add_outlined,
                  onTap: () => showAddContactDialog(
                    context,
                    onSaved: () => ref.invalidate(contactsProvider),
                  ),
                ),
                const SizedBox(width: 4),
                _IconBtn(
                  icon: Icons.refresh,
                  onTap: () => ref.invalidate(contactsProvider),
                ),
              ],
            ),
          ),
          // ── Search bar ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF13131F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A2A3E)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(Icons.search,
                      size: 14, color: Colors.white.withValues(alpha: 0.25)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v.toLowerCase()),
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.2)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.close,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(height: 1, color: const Color(0xFF1E1E2E)),
          // ── List ──────────────────────────────────────────────────
          Expanded(
            child: contactsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF5B52E8)),
              ),
              error: (_, _) => Center(
                child: Text('Failed to load',
                    style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.3))),
              ),
              data: (contacts) {
                final filtered = _query.isEmpty
                    ? contacts
                    : contacts
                        .where((c) =>
                            c.name.toLowerCase().contains(_query) ||
                            (c.companyName?.toLowerCase().contains(_query) ??
                                false) ||
                            (c.notes?.toLowerCase().contains(_query) ??
                                false) ||
                            (c.phoneNumber?.contains(_query) ?? false) ||
                            (c.mobileNumber?.contains(_query) ?? false))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search,
                            size: 36,
                            color: Colors.white.withValues(alpha: 0.07)),
                        const SizedBox(height: 10),
                        Text(
                          _query.isEmpty ? 'No contacts yet' : 'No results',
                          style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.2)),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _ContactRow(contact: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contact row ───────────────────────────────────────────────────────────────

class _ContactRow extends ConsumerStatefulWidget {
  final Contact contact;
  const _ContactRow({required this.contact});

  @override
  ConsumerState<_ContactRow> createState() => _ContactRowState();
}

class _ContactRowState extends ConsumerState<_ContactRow> {
  bool _hovered = false;

  static Color _avatarColor(String name) {
    const colors = [
      Color(0xFF5B52E8),
      Color(0xFF22C55E),
      Color(0xFFEF4444),
      Color(0xFFF59E0B),
      Color(0xFF06B6D4),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
      Color(0xFF10B981),
    ];
    return colors[name.codeUnits.first % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    final color = _avatarColor(c.name);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _showContactDetail(context, widget.contact),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hovered
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Center(
                child: Text(
                  c.initials,
                  style: GoogleFonts.dmMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Name + details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (c.companyName != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      c.companyName!,
                      style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.45)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (c.phoneNumber != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      c.phoneNumber!,
                      style: GoogleFonts.dmMono(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.3)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (c.mobileNumber != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      c.mobileNumber!,
                      style: GoogleFonts.dmMono(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.25)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (c.notes != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      c.notes!,
                      style: GoogleFonts.dmSans(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.3)),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
            ),
            // Call button (visible on hover)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: _hovered && c.phoneNumber != null ? 1.0 : 0.0,
              child: GestureDetector(
                onTap: c.phoneNumber != null
                    ? () => ref
                        .read(telnyxProvider.notifier)
                        .dial(c.phoneNumber!)
                    : null,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.call,
                      size: 13, color: Color(0xFF22C55E)),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _showContactDetail(BuildContext context, Contact contact) {
    showDialog(
      context: context,
      builder: (_) => _ContactDetailDialog(contact: contact),
    );
  }
}

// ── Icon button ───────────────────────────────────────────────────────────────

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
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
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF1E1E2E) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon,
              size: 15,
              color: Colors.white.withValues(alpha: _hovered ? 0.5 : 0.25)),
        ),
      ),
    );
  }
}

// ── Contact detail dialog ─────────────────────────────────────────────────────

class _ContactDetailDialog extends ConsumerStatefulWidget {
  final Contact contact;
  const _ContactDetailDialog({required this.contact});

  @override
  ConsumerState<_ContactDetailDialog> createState() =>
      _ContactDetailDialogState();
}

class _ContactDetailDialogState extends ConsumerState<_ContactDetailDialog> {
  bool _editing = false;
  bool _saving = false;
  bool _deleting = false;
  bool _notesCopied = false;

  Future<void> _copyNotes() async {
    await Clipboard.setData(ClipboardData(text: widget.contact.notes ?? ''));
    setState(() => _notesCopied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _notesCopied = false);
  }

  late final TextEditingController _name;
  late final TextEditingController _company;
  late final TextEditingController _phone;
  late final TextEditingController _mobile;
  late final TextEditingController _email;
  late final TextEditingController _notes;

  final _formKey = GlobalKey<FormState>();

  static Color _avatarColor(String name) {
    const colors = [
      Color(0xFF5B52E8), Color(0xFF22C55E), Color(0xFFEF4444),
      Color(0xFFF59E0B), Color(0xFF06B6D4), Color(0xFFEC4899),
      Color(0xFF8B5CF6), Color(0xFF10B981),
    ];
    return colors[name.codeUnits.first % colors.length];
  }

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _name    = TextEditingController(text: c.name);
    _company = TextEditingController(text: c.companyName ?? '');
    _phone   = TextEditingController(text: c.phoneNumber ?? '');
    _mobile  = TextEditingController(text: c.mobileNumber ?? '');
    _email   = TextEditingController(text: c.email ?? '');
    _notes   = TextEditingController(text: c.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose(); _company.dispose(); _phone.dispose();
    _mobile.dispose(); _email.dispose(); _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client
          .from('phonebook_contacts')
          .update({
            'name':         _name.text.trim(),
            'company_name': _company.text.trim().isEmpty ? null : _company.text.trim(),
            'phone_number': _phone.text.trim().isEmpty   ? null : _phone.text.trim(),
            'mobile_number':_mobile.text.trim().isEmpty  ? null : _mobile.text.trim(),
            'email':        _email.text.trim().isEmpty   ? null : _email.text.trim(),
            'notes':        _notes.text.trim().isEmpty   ? null : _notes.text.trim(),
          })
          .eq('id', widget.contact.id);
      ref.invalidate(contactsProvider);
      if (mounted) setState(() { _editing = false; _saving = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e',
              style: GoogleFonts.dmSans(fontSize: 12)),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF13131F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF1E1E2E)),
        ),
        title: Text('Delete contact?',
            style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9))),
        content: Text(
          'This will permanently remove ${widget.contact.name} from your contacts.',
          style: GoogleFonts.dmSans(
              fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.4))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.dmSans(color: const Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await Supabase.instance.client
          .from('phonebook_contacts')
          .delete()
          .eq('id', widget.contact.id);
      ref.invalidate(contactsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete: $e',
              style: GoogleFonts.dmSans(fontSize: 12)),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    final color = _avatarColor(c.name);

    return Dialog(
      backgroundColor: const Color(0xFF13131F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF1E1E2E)),
      ),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: color.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          c.initials,
                          style: GoogleFonts.dmMono(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _editing
                          ? TextFormField(
                              controller: _name,
                              style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9)),
                              decoration: _inputDecoration('Full name'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name,
                                    style: GoogleFonts.dmSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            Colors.white.withValues(alpha: 0.9))),
                                if (c.companyName != null) ...[
                                  const SizedBox(height: 2),
                                  Text(c.companyName!,
                                      style: GoogleFonts.dmSans(
                                          fontSize: 12,
                                          color: Colors.white
                                              .withValues(alpha: 0.4))),
                                ],
                              ],
                            ),
                    ),
                    // Edit / Delete / Close buttons
                    if (!_editing) ...[
                      _HeaderBtn(
                        icon: Icons.edit_outlined,
                        onTap: () => setState(() => _editing = true),
                      ),
                      const SizedBox(width: 4),
                      _HeaderBtn(
                        icon: Icons.delete_outline,
                        color: const Color(0xFFEF4444),
                        onTap: _deleting ? null : _delete,
                      ),
                      const SizedBox(width: 4),
                    ],
                    _HeaderBtn(
                      icon: Icons.close,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Container(height: 1, color: const Color(0xFF1E1E2E)),
                const SizedBox(height: 20),

                // ── View mode ────────────────────────────────────────
                if (!_editing) ...[
                  if (c.phoneNumber != null)
                    _NumberRow(
                      label: 'Phone',
                      number: c.phoneNumber!,
                      onCall: () {
                        Navigator.of(context).pop();
                        ref
                            .read(telnyxProvider.notifier)
                            .dial(c.phoneNumber!);
                      },
                    ),
                  if (c.phoneNumber != null && c.mobileNumber != null)
                    const SizedBox(height: 10),
                  if (c.mobileNumber != null)
                    _NumberRow(
                      label: 'Mobile',
                      number: c.mobileNumber!,
                      onCall: () {
                        Navigator.of(context).pop();
                        ref
                            .read(telnyxProvider.notifier)
                            .dial(c.mobileNumber!);
                      },
                    ),
                  if (c.phoneNumber == null && c.mobileNumber == null)
                    Text('No numbers saved',
                        style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.25))),
                  if (c.email != null) ...[
                    const SizedBox(height: 10),
                    _DetailRow(
                        icon: Icons.email_outlined, value: c.email!),
                  ],
                  if (c.notes != null) ...[
                    const SizedBox(height: 16),
                    Container(height: 1, color: const Color(0xFF1E1E2E)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('Notes',
                            style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.3),
                                letterSpacing: 0.6)),
                        const Spacer(),
                        _CopyBtn(copied: _notesCopied, onTap: _copyNotes),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(c.notes!,
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.55))),
                  ],
                ],

                // ── Edit mode ────────────────────────────────────────
                if (_editing) ...[
                  _EditField(label: 'Company', controller: _company, hint: 'Organisation'),
                  const SizedBox(height: 10),
                  _EditField(label: 'Phone Number', controller: _phone, hint: '+44...', keyboard: TextInputType.phone),
                  const SizedBox(height: 10),
                  _EditField(label: 'Mobile Number', controller: _mobile, hint: '+44...', keyboard: TextInputType.phone),
                  const SizedBox(height: 10),
                  _EditField(label: 'Email', controller: _email, hint: 'email@example.com', keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 10),
                  _EditField(label: 'Notes', controller: _notes, hint: 'Any additional info…'),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _DialogActionBtn(
                        label: 'Cancel',
                        onTap: () => setState(() => _editing = false),
                        filled: false,
                      ),
                      const SizedBox(width: 8),
                      _DialogActionBtn(
                        label: _saving ? 'Saving…' : 'Save',
                        onTap: _saving ? null : _save,
                        filled: true,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(
            fontSize: 13, color: Colors.white.withValues(alpha: 0.2)),
        filled: true,
        fillColor: const Color(0xFF0D0D14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2A2A3E))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2A2A3E))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF5B52E8))),
        isDense: true,
      );
}

// ── Number row with call button ───────────────────────────────────────────────

class _NumberRow extends StatefulWidget {
  final String label;
  final String number;
  final VoidCallback onCall;
  const _NumberRow(
      {required this.label, required this.number, required this.onCall});

  @override
  State<_NumberRow> createState() => _NumberRowState();
}

class _NumberRowState extends State<_NumberRow> {
  bool _hovered = false;
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.number));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered
              ? Colors.white.withValues(alpha: 0.03)
              : const Color(0xFF0D0D14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E1E2E)),
        ),
        child: Row(
          children: [
            Icon(
              widget.label == 'Mobile'
                  ? Icons.smartphone
                  : Icons.phone_outlined,
              size: 14,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.number,
                    style: GoogleFonts.dmMono(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            _CopyBtn(copied: _copied, onTap: _copy),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onCall,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E)
                      .withValues(alpha: _hovered ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.35)),
                ),
                child:
                    const Icon(Icons.call, size: 14, color: Color(0xFF22C55E)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Generic detail row ────────────────────────────────────────────────────────

class _DetailRow extends StatefulWidget {
  final IconData icon;
  final String value;
  const _DetailRow({required this.icon, required this.value});

  @override
  State<_DetailRow> createState() => _DetailRowState();
}

class _DetailRowState extends State<_DetailRow> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(widget.icon, size: 14, color: Colors.white.withValues(alpha: 0.3)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.value,
            style: GoogleFonts.dmSans(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
        _CopyBtn(copied: _copied, onTap: _copy),
      ],
    );
  }
}

// ── Header icon button (edit/delete/close) ────────────────────────────────────

class _HeaderBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  const _HeaderBtn({required this.icon, this.onTap, this.color});

  @override
  State<_HeaderBtn> createState() => _HeaderBtnState();
}

class _HeaderBtnState extends State<_HeaderBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final col = widget.color ?? Colors.white.withValues(alpha: 0.35);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered
                ? col.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon, size: 15, color: col),
        ),
      ),
    );
  }
}

// ── Edit field ────────────────────────────────────────────────────────────────

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboard;

  const _EditField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.35)),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          style: GoogleFonts.dmSans(
              fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.2)),
            filled: true,
            fillColor: const Color(0xFF0D0D14),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2A2A3E))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2A2A3E))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF5B52E8))),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ── Dialog action button (Save / Cancel) ──────────────────────────────────────

class _DialogActionBtn extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  const _DialogActionBtn(
      {required this.label, required this.onTap, required this.filled});

  @override
  State<_DialogActionBtn> createState() => _DialogActionBtnState();
}

class _DialogActionBtnState extends State<_DialogActionBtn> {
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
            border:
                widget.filled ? null : Border.all(color: const Color(0xFF2A2A3E)),
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

// ── Copy button ───────────────────────────────────────────────────────────────

class _CopyBtn extends StatefulWidget {
  final bool copied;
  final VoidCallback onTap;
  const _CopyBtn({required this.copied, required this.onTap});

  @override
  State<_CopyBtn> createState() => _CopyBtnState();
}

class _CopyBtnState extends State<_CopyBtn> {
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
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: widget.copied
                ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                : _hovered
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.copied ? Icons.check : Icons.copy_outlined,
            size: 13,
            color: widget.copied
                ? const Color(0xFF22C55E)
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}
