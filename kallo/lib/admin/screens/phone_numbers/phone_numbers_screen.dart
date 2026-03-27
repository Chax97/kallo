import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _PhoneNumber {
  final String id;
  final String phoneNumber;
  final String label;
  final String? telnyxNumberId;
  final String? assignedToUser;
  final String? status;

  const _PhoneNumber({
    required this.id,
    required this.phoneNumber,
    required this.label,
    this.telnyxNumberId,
    this.assignedToUser,
    this.status,
  });

  factory _PhoneNumber.fromRow(Map<String, dynamic> row) {
    return _PhoneNumber(
      id: row['id']?.toString() ?? '',
      phoneNumber: row['number']?.toString() ?? '',
      label: row['label']?.toString() ?? '',
      telnyxNumberId: row['telnyx_number_id']?.toString(),
      assignedToUser: row['assigned_to_user']?.toString(),
      status: row['status']?.toString(),
    );
  }

  String get flagEmoji {
    if (phoneNumber.startsWith('+44')) return '🇬🇧';
    if (phoneNumber.startsWith('+61')) return '🇦🇺';
    if (phoneNumber.startsWith('+1'))  return '🇺🇸';
    return '🌐';
  }

  bool get isAssigned =>
      assignedToUser != null && assignedToUser!.isNotEmpty;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PhoneNumbersScreen extends ConsumerStatefulWidget {
  const PhoneNumbersScreen({super.key});

  @override
  ConsumerState<PhoneNumbersScreen> createState() => _PhoneNumbersScreenState();
}

class _PhoneNumbersScreenState extends ConsumerState<PhoneNumbersScreen> {
  bool _bannerDismissed = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  String? _companyId;
  List<_PhoneNumber> _numbers = [];
  bool _loading = true;
  String? _error;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadCompanyAndNumbers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyAndNumbers() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');
      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('id', user.id)
          .single();
      _companyId = profile['company_id']?.toString();
      await _fetchNumbers();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _fetchNumbers() async {
    if (_companyId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Supabase.instance.client
          .from('phone_numbers')
          .select('id, number, label, telnyx_number_id, assigned_to_user, status')
          .eq('company_id', _companyId!)
          .order('created_at', ascending: false);

      setState(() {
        _numbers = (res as List)
            .map((e) => _PhoneNumber.fromRow(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _syncNumbers() async {
    if (_companyId == null) return;
    setState(() => _syncing = true);
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'telnyx-sync-numbers',
        body: {'company_id': _companyId},
      );
      if (res.status != 200) {
        throw Exception(res.data?['error'] ?? 'Sync failed');
      }
      await _fetchNumbers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _showEditDialog(_PhoneNumber number) async {
    await showDialog(
      context: context,
      builder: (_) => _EditLabelDialog(
        numberId: number.id,
        currentLabel: number.label,
        onSaved: _fetchNumbers,
      ),
    );
  }

  Future<void> _showDeleteDialog(_PhoneNumber number) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Remove Number',
            style: TextStyle(fontFamily: 'DM Sans', fontSize: 16,
                fontWeight: FontWeight.w600)),
        content: Text(
          'Remove ${number.phoneNumber} from your account? This cannot be undone.',
          style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
              color: Color(0xFF6B6B8A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('phone_numbers')
            .delete()
            .eq('id', number.id);
        await _fetchNumbers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove number: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _numbers.where((r) =>
      r.phoneNumber.contains(_searchQuery) ||
      r.label.toLowerCase().contains(_searchQuery.toLowerCase()),
    ).toList();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title
          Text('Phone Numbers', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 4),
          Text('Manage your DIDs, assign numbers to agents or call flows.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),

          // Getting Started banner
          if (!_bannerDismissed) ...[
            _GettingStartedBanner(onDismiss: () => setState(() => _bannerDismissed = true)),
            const SizedBox(height: 20),
          ],

          // Search + Refresh row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search numbers...',
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9999AA)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 36,
                width: 36,
                child: Tooltip(
                  message: 'Refresh',
                  child: ElevatedButton(
                    onPressed: _loading ? null : _fetchNumbers,
                    style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                    child: _loading
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh, size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                width: 36,
                child: Tooltip(
                  message: 'Buy a number',
                  child: ElevatedButton(
                    onPressed: _companyId == null ? null : () => showDialog(
                      context: context,
                      builder: (_) => _BuyNumbersDialog(
                        companyId: _companyId!,
                        onPurchased: _fetchNumbers,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Icon(Icons.add, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8E8F0)),
              ),
              child: Column(
                children: [
                  _TableHeader(),
                  const Divider(height: 1),
                  Expanded(
                    child: _buildBody(filtered),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<_PhoneNumber> filtered) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32, color: Color(0xFFEF4444)),
            const SizedBox(height: 8),
            const Text('Failed to load numbers',
                style: TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                    fontWeight: FontWeight.w600, color: Color(0xFF3D3D5C))),
            const SizedBox(height: 4),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                    color: Color(0xFF9999AA))),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchNumbers, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (filtered.isEmpty && _numbers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_outlined, size: 36, color: Color(0xFF9999AA)),
            const SizedBox(height: 12),
            const Text('No phone numbers yet.',
                style: TextStyle(fontFamily: 'DM Sans', fontSize: 14,
                    fontWeight: FontWeight.w600, color: Color(0xFF3D3D5C))),
            const SizedBox(height: 4),
            const Text('Import your existing Telnyx numbers or buy a new one.',
                style: TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                    color: Color(0xFF9999AA))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _syncing ? null : _syncNumbers,
              icon: _syncing
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_outlined, size: 16),
              label: Text(_syncing ? 'Importing…' : 'Import from Telnyx'),
            ),
          ],
        ),
      );
    }
    if (filtered.isEmpty) {
      return const Center(
        child: Text('No numbers match your search.',
            style: TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                color: Color(0xFF9999AA))),
      );
    }
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _NumberRow(
        number: filtered[i],
        onEdit:   () => _showEditDialog(filtered[i]),
        onDelete: () => _showDeleteDialog(filtered[i]),
      ),
    );
  }
}

// ── Getting Started Banner ────────────────────────────────────────────────────

class _GettingStartedBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  const _GettingStartedBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('Getting Started! — Setting Up Phone Numbers',
                  style: const TextStyle(fontFamily: 'DM Sans', fontSize: 14,
                      fontWeight: FontWeight.w600, color: Color(0xFF4F6AFF))),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFEF4444)),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 13, color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _BannerStep(
            number: '1',
            title: 'Phone Numbers',
            body: 'Manage and buy phone numbers here. Each number must have an emergency address so emergency services know where to go if you call them. Assign a number as a DDI or to a call route from the ',
            linkText: 'Call Routes',
            trailText: ' section to get started.',
          ),
          const SizedBox(height: 10),
          _BannerStep(
            number: '2',
            title: 'DDIs',
            body: 'You can assign a DDI directly from this page by selecting a user or hunt group from the drop-down menus in the ',
            linkText: 'Assigned To',
            trailText: ' field.',
          ),
          const SizedBox(height: 10),
          _BannerStep(
            number: '3',
            title: 'Labels',
            body: 'If you have many numbers, create labels and assign them to your numbers for easy filtering later on.',
          ),
        ],
      ),
    );
  }
}

class _BannerStep extends StatelessWidget {
  final String number;
  final String title;
  final String body;
  final String? linkText;
  final String? trailText;

  const _BannerStep({
    required this.number,
    required this.title,
    required this.body,
    this.linkText,
    this.trailText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$number. ', style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
            fontWeight: FontWeight.w600, color: Color(0xFF0D0D1A))),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                  fontWeight: FontWeight.w600, color: Color(0xFF0D0D1A))),
              const SizedBox(height: 2),
              if (linkText != null)
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                        color: Color(0xFF6B6B8A)),
                    children: [
                      TextSpan(text: body),
                      TextSpan(text: linkText,
                          style: const TextStyle(color: Color(0xFF4F6AFF),
                              fontWeight: FontWeight.w500)),
                      if (trailText != null) TextSpan(text: trailText),
                    ],
                  ),
                )
              else
                Text(body, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                    color: Color(0xFF6B6B8A))),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Table ─────────────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: const [
          _HeaderCell('Phone Number', flex: 4),
          _HeaderCell('Label',        flex: 3),
          _HeaderCell('Status',       flex: 2),
          _HeaderCell('Assigned',     flex: 2),
          SizedBox(width: 80),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 11,
          fontWeight: FontWeight.w600, color: Color(0xFF9999AA), letterSpacing: 0.5)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String? status;
  const _StatusBadge({this.status});

  static const _colors = <String, Color>{
    'active':           Color(0xFF22C55E),
    'purchase_pending': Color(0xFFF59E0B),
    'purchase_failed':  Color(0xFFEF4444),
    'port_pending':     Color(0xFFF59E0B),
    'port_failed':      Color(0xFFEF4444),
    'ported_out':       Color(0xFF9999AA),
    'port_out_pending': Color(0xFFF59E0B),
    'emergency_only':   Color(0xFFEF4444),
    'deleted':          Color(0xFF9999AA),
  };

  @override
  Widget build(BuildContext context) {
    final raw = status ?? 'unknown';
    final label = raw.replaceAll('_', ' ');
    final color = _colors[raw] ?? const Color(0xFF9999AA);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'DM Sans', fontSize: 11, fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  final _PhoneNumber number;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _NumberRow({
    required this.number,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Phone Number (flag + full E.164) — tap to copy
          Expanded(
            flex: 4,
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: number.phoneNumber));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${number.phoneNumber} copied to clipboard'),
                  duration: const Duration(seconds: 2),
                ));
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  children: [
                    Text(number.flagEmoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(number.phoneNumber,
                        style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                            fontWeight: FontWeight.w500, color: Color(0xFF4F6AFF))),
                    const SizedBox(width: 6),
                    const Icon(Icons.copy_outlined, size: 12, color: Color(0xFF9999AA)),
                  ],
                ),
              ),
            ),
          ),
          // Label
          Expanded(
            flex: 3,
            child: Text(
              number.label.isEmpty ? 'No label' : number.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'DM Sans', fontSize: 13,
                color: number.label.isEmpty
                    ? const Color(0xFF9999AA) : const Color(0xFF3D3D5C),
              ),
            ),
          ),
          // Status badge
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _StatusBadge(status: number.status),
            ),
          ),
          // Assigned badge
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: number.isAssigned
                      ? const Color(0xFF4F6AFF).withValues(alpha: 0.1)
                      : const Color(0xFF9999AA).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  number.isAssigned ? 'assigned' : 'unassigned',
                  style: TextStyle(
                    fontFamily: 'DM Sans', fontSize: 11, fontWeight: FontWeight.w500,
                    color: number.isAssigned
                        ? const Color(0xFF4F6AFF) : const Color(0xFF9999AA),
                  ),
                ),
              ),
            ),
          ),
          // Actions
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _CircleIconButton(
                  icon: Icons.edit_outlined,
                  color: const Color(0xFF4F6AFF),
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
                _CircleIconButton(
                  icon: Icons.delete_outline,
                  color: const Color(0xFFEF4444),
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Edit Label Dialog ─────────────────────────────────────────────────────────

class _EditLabelDialog extends StatefulWidget {
  final String numberId;
  final String currentLabel;
  final VoidCallback onSaved;
  const _EditLabelDialog({
    required this.numberId,
    required this.currentLabel,
    required this.onSaved,
  });

  @override
  State<_EditLabelDialog> createState() => _EditLabelDialogState();
}

class _EditLabelDialogState extends State<_EditLabelDialog> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentLabel);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client
          .from('phone_numbers')
          .update({'label': _controller.text.trim()})
          .eq('id', widget.numberId);
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Edit Label',
          style: TextStyle(fontFamily: 'DM Sans', fontSize: 16,
              fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Label',
            hintText: 'e.g. Main Office',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
          onSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Buy Numbers Dialog ────────────────────────────────────────────────────────

class _AvailableNumber {
  final String phoneNumber;
  final String numberType;
  final bool quickship;
  final bool reservable;
  final bool bestEffort;
  final String monthlyCost;
  final String upfrontCost;
  final String currency;
  final List<String> features;
  final List<Map<String, String>> regions;

  const _AvailableNumber({
    required this.phoneNumber,
    required this.numberType,
    required this.quickship,
    required this.reservable,
    required this.bestEffort,
    required this.monthlyCost,
    required this.upfrontCost,
    required this.currency,
    required this.features,
    required this.regions,
  });

  factory _AvailableNumber.fromJson(Map<String, dynamic> json) {
    final cost = json['cost_information'] as Map<String, dynamic>? ?? {};
    final featureList = (json['features'] as List<dynamic>? ?? [])
        .map((f) => (f as Map<String, dynamic>)['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final regionList = (json['region_information'] as List<dynamic>? ?? [])
        .map((r) => {
              'type': (r as Map<String, dynamic>)['region_type']?.toString() ?? '',
              'name': r['region_name']?.toString() ?? '',
            })
        .toList();
    return _AvailableNumber(
      phoneNumber: json['phone_number']?.toString() ?? '',
      numberType:  json['phone_number_type']?.toString() ?? 'local',
      quickship:   json['quickship'] == true,
      reservable:  json['reservable'] == true,
      bestEffort:  json['best_effort'] == true,
      monthlyCost: cost['monthly_cost']?.toString() ?? '',
      upfrontCost: cost['upfront_cost']?.toString() ?? '',
      currency:    cost['currency']?.toString() ?? 'USD',
      features:    featureList,
      regions:     regionList,
    );
  }

  String get regionLabel {
    String? find(String type) => regions
        .where((r) => r['type'] == type && (r['name'] ?? '').isNotEmpty)
        .map((r) => r['name']!)
        .firstOrNull;

    // Priority: rate_center > locality > any non-country_code region
    final primary = find('rate_center') ?? find('locality');
    final adminArea = find('administrative_area');
    final fallback = regions
        .where((r) => r['type'] != 'country_code' && (r['name'] ?? '').isNotEmpty)
        .map((r) => r['name']!)
        .firstOrNull;

    if (primary != null && adminArea != null) return '$primary, $adminArea';
    if (primary != null) return primary;
    if (adminArea != null) return adminArea;
    return fallback ?? '';
  }
}

class _BuyNumbersDialog extends StatefulWidget {
  final String companyId;
  final VoidCallback onPurchased;
  const _BuyNumbersDialog({required this.companyId, required this.onPurchased});

  @override
  State<_BuyNumbersDialog> createState() => _BuyNumbersDialogState();
}

class _BuyNumbersDialogState extends State<_BuyNumbersDialog> {
  // Maps display label → API value (null = omit filter)
  static const _countryMap = {
    'United Kingdom +44': 'GB',
    'Australia +61':      'AU',
  };
  static const _featureMap = {
    'Any feature': null,
    'Voice':       'voice',
    'SMS':         'sms',
    'MMS':         'mms',
    'Fax':         'fax',
  };
  static const _typeMap = {
    'All types': null,
    'Local':     'local',
    'Toll-free': 'toll_free',
    'Mobile':    'mobile',
    'National':  'national',
  };

  String _country      = 'United Kingdom +44';
  String _features     = 'Any feature';
  String _type         = 'All types';
  String _searchBy     = 'Area code';
  bool   _advancedExpanded  = false;
  String _phoneNumberMatch  = 'Starts with';

  final _areaCodeController    = TextEditingController();
  final _localityController    = TextEditingController();
  final _phraseController      = TextEditingController();
  final _resultsLimitController = TextEditingController(text: '20');

  bool   _searching            = false;
  String? _searchError;
  List<_AvailableNumber> _results = [];
  bool   _hasSearched          = false;
  int    _totalResults         = 0;
  bool   _purchasing           = false;
  bool   _checkingRequirements = false;
  String? _purchaseError;

  @override
  void dispose() {
    _areaCodeController.dispose();
    _localityController.dispose();
    _phraseController.dispose();
    _resultsLimitController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() { _searching = true; _searchError = null; });
    try {
      final countryCode  = _countryMap[_country] ?? 'GB';
      final feature      = _featureMap[_features];
      final numberType   = _typeMap[_type];
      final limit        = int.tryParse(_resultsLimitController.text.trim()) ?? 20;

      final body = <String, dynamic>{
        'country_code': countryCode,
        'limit': limit,
      };
      if (feature != null) body['features'] = [feature];
      if (numberType != null) body['phone_number_type'] = numberType;

      if (_searchBy == 'Area code' && _areaCodeController.text.trim().isNotEmpty) {
        body['national_destination_code'] = _areaCodeController.text.trim();
      }
      if (_searchBy == 'Locality' && _localityController.text.trim().isNotEmpty) {
        body['locality'] = _localityController.text.trim();
      }

      if (_advancedExpanded && _phraseController.text.trim().isNotEmpty) {
        final phrase = _phraseController.text.trim();
        switch (_phoneNumberMatch) {
          case 'Starts with': body['phone_number_starts_with'] = phrase;
          case 'Contains':    body['phone_number_contains']    = phrase;
          case 'Ends with':   body['phone_number_ends_with']   = phrase;
        }
      }

      final res = await Supabase.instance.client.functions.invoke(
        'telnyx-search-numbers',
        body: body,
      );

      final data = res.data as Map<String, dynamic>;
      if (data['error'] != null) throw Exception(data['error']);

      final results = (data['data'] as List<dynamic>? ?? [])
          .map((e) => _AvailableNumber.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = data['meta'] as Map<String, dynamic>? ?? {};

      setState(() {
        _results      = results;
        _totalResults = (meta['total_results'] as num?)?.toInt() ?? results.length;
        _hasSearched  = true;
        _searching    = false;
      });
    } catch (e) {
      setState(() {
        _searchError = e.toString();
        _searching   = false;
      });
    }
  }

  Future<void> _onNumberSelected(_AvailableNumber number) async {
    setState(() => _checkingRequirements = true);
    try {
      final countryCode = number.phoneNumber.startsWith('+44') ? 'GB'
          : number.phoneNumber.startsWith('+61') ? 'AU'
          : 'GB';

      final res = await Supabase.instance.client.functions.invoke(
        'telnyx-get-requirements',
        body: {
          'country_code':      countryCode,
          'phone_number_type': number.numberType,
          'action':            'ordering',
        },
      );

      final requirements = (res.data['data'] as List<dynamic>? ?? []);

      if (!mounted) return;
      setState(() => _checkingRequirements = false);

      if (requirements.isEmpty) {
        await _purchaseNumber(number);
        return;
      }

      // Check for an existing verified kyc record (returning customer fast path)
      final existingKyc = await Supabase.instance.client
          .from('company_kyc')
          .select('id, telnyx_requirement_group_id')
          .eq('company_id', widget.companyId)
          .eq('country_code', countryCode)
          .eq('phone_number_type', number.numberType)
          .maybeSingle();

      final existingGroupId =
          existingKyc?['telnyx_requirement_group_id'] as String?;

      if (existingGroupId != null) {
        // Fast path: requirement group already exists — skip wizard
        final kycId = existingKyc!['id'] as String;
        await _fulfillAndOrder(number, kycId: kycId);
        return;
      }

      // Show verification wizard — collects docs, returns kycId
      if (!mounted) return;
      final kycId = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _VerificationWizard(
          phoneNumber:  number.phoneNumber,
          companyId:    widget.companyId,
          requirements: requirements,
          countryCode:  countryCode,
          numberType:   number.numberType,
        ),
      );

      if (kycId != null) {
        await _fulfillAndOrder(number, kycId: kycId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingRequirements = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not check requirements: $e')),
        );
      }
    }
  }

  // Used when no regulatory requirements are needed (US numbers etc.)
  Future<void> _purchaseNumber(_AvailableNumber number) async {
    setState(() { _purchasing = true; _purchaseError = null; });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'telnyx-buy-number',
        body: {
          'phone_number': number.phoneNumber,
          'company_id':   widget.companyId,
        },
      );
      final data = res.data as Map<String, dynamic>;
      if (data['error'] != null) throw Exception(data['error']);

      widget.onPurchased();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _purchaseError = e.toString();
        _purchasing    = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    }
  }

  // Used when regulatory requirements exist — calls the all-in-one edge function
  Future<void> _fulfillAndOrder(_AvailableNumber number, {required String kycId}) async {
    setState(() { _purchasing = true; _purchaseError = null; });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'telnyx-fulfill-and-order',
        body: {
          'phone_number': number.phoneNumber,
          'company_id':   widget.companyId,
          'kyc_id':       kycId,
        },
      );
      final data = res.data as Map<String, dynamic>;
      if (data['error'] != null) throw Exception(data['error']);

      widget.onPurchased();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _purchaseError = e.toString();
        _purchasing    = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic label for the last filter field
    final lastFieldLabel = _searchBy == 'Locality' ? 'City' : 'Area Code';
    final lastFieldController =
        _searchBy == 'Locality' ? _localityController : _areaCodeController;
    final lastFieldHint =
        _searchBy == 'Locality' ? 'e.g. London' : 'e.g. 020';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
              child: Row(
                children: [
                  const Text('Buy Numbers',
                      style: TextStyle(fontFamily: 'DM Sans', fontSize: 22,
                          fontWeight: FontWeight.w700, color: Color(0xFF0D0D1A))),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, size: 20, color: Color(0xFF6B6B8A)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Scrollable body ─────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE8E8F0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top filter row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _FilterDropdown(
                                label: 'Country',
                                required: true,
                                value: _country,
                                items: _countryMap.keys.toList(),
                                onChanged: (v) => setState(() => _country = v!),
                                flex: 3,
                              ),
                              const SizedBox(width: 12),
                              _FilterDropdown(
                                label: 'Features',
                                value: _features,
                                items: _featureMap.keys.toList(),
                                onChanged: (v) => setState(() => _features = v!),
                                flex: 3,
                              ),
                              const SizedBox(width: 12),
                              _FilterDropdown(
                                label: 'Type',
                                value: _type,
                                items: _typeMap.keys.toList(),
                                onChanged: (v) => setState(() => _type = v!),
                                flex: 2,
                              ),
                              const SizedBox(width: 12),
                              _FilterDropdown(
                                label: 'Search By',
                                value: _searchBy,
                                items: const ['Area code', 'Locality'],
                                onChanged: (v) => setState(() => _searchBy = v!),
                                flex: 2,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(lastFieldLabel,
                                        style: const TextStyle(fontFamily: 'DM Sans',
                                            fontSize: 12, fontWeight: FontWeight.w500,
                                            color: Color(0xFF6B6B8A))),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: lastFieldController,
                                      decoration: InputDecoration(
                                        hintText: lastFieldHint,
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        isDense: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Advanced Search toggle
                          GestureDetector(
                            onTap: () => setState(
                                () => _advancedExpanded = !_advancedExpanded),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE8E8F0)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Advanced Search',
                                        style: TextStyle(fontFamily: 'DM Sans',
                                            fontSize: 12, fontWeight: FontWeight.w500,
                                            color: Color(0xFF3D3D5C))),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _advancedExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 16, color: const Color(0xFF6B6B8A),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Advanced section
                          if (_advancedExpanded) ...[
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _FilterDropdown(
                                  label: 'Phone Number Pattern',
                                  value: _phoneNumberMatch,
                                  items: const ['Starts with', 'Contains', 'Ends with'],
                                  onChanged: (v) =>
                                      setState(() => _phoneNumberMatch = v!),
                                  flex: 2,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 20),
                                      TextField(
                                        controller: _phraseController,
                                        decoration: const InputDecoration(
                                          hintText: 'Phrase or digits',
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          isDense: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Results Limit',
                                          style: TextStyle(fontFamily: 'DM Sans',
                                              fontSize: 12, fontWeight: FontWeight.w500,
                                              color: Color(0xFF6B6B8A))),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _resultsLimitController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          isDense: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _searching ? null : _search,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D0D1A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              textStyle: const TextStyle(fontFamily: 'DM Sans',
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            child: _searching
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Search Numbers'),
                          ),
                        ],
                      ),
                    ),

                    // ── Results ───────────────────────────────────────────────
                    if (_searchError != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 18, color: Color(0xFFEF4444)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_searchError!,
                                  style: const TextStyle(fontFamily: 'DM Sans',
                                      fontSize: 12, color: Color(0xFFDC2626))),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_hasSearched) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text(
                            '$_totalResults number${_totalResults == 1 ? '' : 's'} found',
                            style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                                fontWeight: FontWeight.w600, color: Color(0xFF3D3D5C)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_results.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Text('No numbers match your search.',
                                style: TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                                    color: Color(0xFF9999AA))),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE8E8F0)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // Results header
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                child: Row(
                                  children: const [
                                    Expanded(flex: 3, child: _ResultHeaderCell('Phone Number')),
                                    Expanded(flex: 2, child: _ResultHeaderCell('Region')),
                                    Expanded(flex: 3, child: _ResultHeaderCell('Features')),
                                    Expanded(flex: 2, child: _ResultHeaderCell('Monthly Cost')),
                                    SizedBox(width: 100),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _results.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (_, i) => _AvailableNumberRow(
                                  number: _results[i],
                                  onSelect: () => _onNumberSelected(_results[i]),
                                  purchasing: _purchasing || _checkingRequirements,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Verification Wizard ───────────────────────────────────────────────────────

class _VerificationWizard extends StatefulWidget {
  final String phoneNumber;
  final String companyId;
  final String countryCode;
  final String numberType;
  final List<dynamic> requirements;
  const _VerificationWizard({
    required this.phoneNumber,
    required this.companyId,
    required this.countryCode,
    required this.numberType,
    required this.requirements,
  });

  @override
  State<_VerificationWizard> createState() => _VerificationWizardState();
}

class _VerificationWizardState extends State<_VerificationWizard> {
  Map<String, dynamic> _company = {};
  Map<String, dynamic> _user    = {};
  bool    _loading    = true;
  bool    _submitting = false;
  String? _error;

  // TextControllers keyed by requirement id (for generic textual types)
  final Map<String, TextEditingController> _textCtrl = {};
  // Address sub-field controllers keyed by requirement id
  final Map<String, Map<String, TextEditingController>> _addrCtrl = {};
  // Contact info sub-field controllers keyed by requirement id
  final Map<String, Map<String, TextEditingController>> _contactCtrl = {};
  // Picked file data keyed by requirement id (for document types)
  final Map<String, ({Uint8List bytes, String name})> _files = {};
  // Existing telnyx_document_id per requirement_type_id (from company_kyc_documents)
  Map<String, String> _cachedDocIds = {};
  // Whether the user wants to replace a cached document
  final Map<String, bool> _replaceDoc = {};
  // Inline field-level validation errors; key = '${reqId}_fieldName'
  Set<String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final c in _textCtrl.values) { c.dispose(); }
    for (final m in _addrCtrl.values) { for (final c in m.values) { c.dispose(); } }
    for (final m in _contactCtrl.values) { for (final c in m.values) { c.dispose(); } }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final authUser = Supabase.instance.client.auth.currentUser!;
      final supabase  = Supabase.instance.client;

      final user = await supabase
          .from('users')
          .select('display_name, email, contact_phone')
          .eq('id', authUser.id)
          .single();
      final company = await supabase
          .from('companies')
          .select('name, website_url, address_line1, address_line2, city, postcode, country')
          .eq('id', widget.companyId)
          .single();
      final cachedDocs = await supabase
          .from('company_kyc_documents')
          .select('requirement_type_id, telnyx_document_id')
          .eq('company_id', widget.companyId)
          .not('telnyx_document_id', 'is', null);

      final cachedMap = <String, String>{
        for (final d in cachedDocs as List<dynamic>)
          (d as Map<String, dynamic>)['requirement_type_id'].toString():
              d['telnyx_document_id'].toString(),
      };

      setState(() {
        _user         = user;
        _company      = company;
        _cachedDocIds = cachedMap;
        _loading      = false;
      });

      for (final r in widget.requirements) {
        final req  = r as Map<String, dynamic>;
        final id   = req['id']?.toString() ?? '';
        final type = req['type']?.toString() ?? '';
        if (type == 'address') {
          _addrCtrl[id] = {
            'line1':    TextEditingController(text: company['address_line1']?.toString() ?? ''),
            'line2':    TextEditingController(text: company['address_line2']?.toString() ?? ''),
            'city':     TextEditingController(text: company['city']?.toString() ?? ''),
            'postcode': TextEditingController(text: company['postcode']?.toString() ?? ''),
            'country':  TextEditingController(text: company['country']?.toString() ?? ''),
          };
        } else if (type == 'textual' && _isContactReq(req)) {
          _contactCtrl[id] = {
            'name':    TextEditingController(text: user['display_name']?.toString() ?? ''),
            'company': TextEditingController(text: company['name']?.toString() ?? ''),
            'email':   TextEditingController(text: user['email']?.toString() ?? ''),
            'phone':   TextEditingController(text: user['contact_phone']?.toString() ?? ''),
          };
        } else if (type == 'textual') {
          _textCtrl[id] = TextEditingController(text: _prefill(req));
        }
      }
      setState(() {});
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _prefill(Map<String, dynamic> req) {
    final name = req['name']?.toString().toLowerCase() ?? '';
    final type = req['type']?.toString() ?? '';

    if (type == 'textual') {
      if (name.contains('website')) {
        return _company['website_url']?.toString() ?? '';
      }
      if (name.contains('contact')) {
        // contact_phone is on users table
        return [
          _user['display_name'],
          _company['name'],
          _user['email'],
          _user['contact_phone'],
        ].where((s) => s != null && s.toString().isNotEmpty).join(', ');
      }
      if (name.contains('use case') || name.contains('business use')) {
        final co = _company['name']?.toString() ?? 'our company';
        return 'This number will be used as a business contact line for $co. '
            'We are sub-allocating this number through Kallo, a VoIP and AI call management platform.';
      }
    }
    if (type == 'address') {
      return [
        _company['address_line1'],
        _company['address_line2'],
        _company['city'],
        _company['postcode'],
        _company['country'],
      ].where((s) => s != null && s.toString().isNotEmpty).join(', ');
    }
    return '';
  }

  bool _isContactReq(Map<String, dynamic> req) {
    final name = req['name']?.toString().toLowerCase() ?? '';
    return name.contains('contact') || name.contains('authorised person');
  }

  // Proof of address must always be uploaded fresh (expires within 3 months)
  bool _isProofOfAddressReq(Map<String, dynamic> req) {
    final name = req['name']?.toString().toLowerCase() ?? '';
    return name.contains('proof of address') ||
        (name.contains('address') && req['type'] == 'document');
  }

  // Any document that is NOT proof of address can be cached
  bool _hasCachedDoc(String reqId, Map<String, dynamic> req) {
    if (_isProofOfAddressReq(req)) return false;
    return _cachedDocIds.containsKey(reqId);
  }

  Future<void> _pickFile(String reqId) async {
    if (_submitting) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    // Validate PDF magic bytes (%PDF header)
    final bytes = file.bytes!;
    if (bytes.length < 4 ||
        bytes[0] != 0x25 || bytes[1] != 0x50 ||
        bytes[2] != 0x44 || bytes[3] != 0x46) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File does not appear to be a valid PDF')),
        );
      }
      return;
    }

    if (bytes.lengthInBytes > 20 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File must be under 20 MB')),
        );
      }
      return;
    }
    setState(() {
      _files[reqId] = (bytes: bytes, name: file.name);
      _fieldErrors.remove('${reqId}_file');
    });
  }

  /// Upload to Supabase Storage and create DB row (status: 'stored').
  /// The edge function handles the Telnyx upload later.
  Future<void> _storeDocument(
    String reqId,
    Map<String, dynamic> req,
    String kycId,
  ) async {
    final file      = _files[reqId]!;
    final supabase  = Supabase.instance.client;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName  = file.name.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final storagePath = '${widget.companyId}/$reqId/${timestamp}_$safeName';

    // 1. Supersede any previous non-superseded doc for this requirement
    await supabase
        .from('company_kyc_documents')
        .update({'is_superseded': true})
        .eq('company_id', widget.companyId)
        .eq('requirement_type_id', reqId)
        .eq('is_superseded', false);

    // 2. Upload file to private Supabase Storage bucket
    await supabase.storage.from('kyc-documents').uploadBinary(
      storagePath,
      file.bytes,
      fileOptions: const FileOptions(contentType: 'application/pdf', upsert: false),
    );

    // 3. Create company_kyc_documents row — status: 'stored'
    final isPoA     = _isProofOfAddressReq(req);
    final expiresAt = isPoA
        ? DateTime.now().add(const Duration(days: 90)).toIso8601String()
        : null;
    final deleteAfter =
        DateTime.now().add(const Duration(days: 365 * 7)).toIso8601String();

    await supabase.from('company_kyc_documents').insert({
      'company_id':          widget.companyId,
      'kyc_id':              kycId,
      'requirement_type_id': reqId,
      'requirement_name':    req['name']?.toString() ?? '',
      'document_type':       req['type']?.toString() ?? '',
      'storage_path':        storagePath,
      'status':              'stored',
      'uploaded_at':         DateTime.now().toIso8601String(),
      'expires_at': expiresAt,
      'delete_after':        deleteAfter,
    });
  }

  /// Save a textual or address field value to company_kyc_documents.
  Future<void> _storeFieldValue(
    String reqId,
    Map<String, dynamic> req,
    String kycId,
    String value,
  ) async {
    final supabase = Supabase.instance.client;

    // Supersede existing row for this requirement on this kyc record
    await supabase
        .from('company_kyc_documents')
        .update({'is_superseded': true})
        .eq('kyc_id', kycId)
        .eq('requirement_type_id', reqId)
        .eq('is_superseded', false);

    await supabase.from('company_kyc_documents').insert({
      'company_id':          widget.companyId,
      'kyc_id':              kycId,
      'requirement_type_id': reqId,
      'requirement_name':    req['name']?.toString() ?? '',
      'document_type':       req['type']?.toString() ?? '',
      'field_value':         value,
      'status':              'stored',
      'delete_after':
          DateTime.now().add(const Duration(days: 365 * 7)).toIso8601String(),
    });
  }

  Future<void> _submit() async {
    // Collect all validation errors in one pass
    final newErrors = <String>{};
    for (final r in widget.requirements) {
      final req  = r as Map<String, dynamic>;
      final id   = req['id']?.toString() ?? '';
      final type = req['type']?.toString() ?? '';
      if (type == 'address') {
        final ctrl = _addrCtrl[id];
        if (ctrl == null || ctrl['line1']!.text.trim().isEmpty) newErrors.add('${id}_line1');
        if (ctrl == null || ctrl['city']!.text.trim().isEmpty)  newErrors.add('${id}_city');
      } else if (type == 'textual' && _isContactReq(req)) {
        final ctrl = _contactCtrl[id];
        if (ctrl == null || ctrl['name']!.text.trim().isEmpty)    newErrors.add('${id}_name');
        if (ctrl == null || ctrl['company']!.text.trim().isEmpty) newErrors.add('${id}_company');
        if (ctrl == null || ctrl['email']!.text.trim().isEmpty)   newErrors.add('${id}_email');
        if (ctrl == null || ctrl['phone']!.text.trim().isEmpty)   newErrors.add('${id}_phone');
      } else if (type == 'textual' && (_textCtrl[id]?.text.trim().isEmpty ?? true)) {
        newErrors.add('${id}_text');
      } else if (type == 'document') {
        final hasCached    = _hasCachedDoc(id, req);
        final wantsReplace = _replaceDoc[id] ?? false;
        if ((!hasCached || wantsReplace) && !_files.containsKey(id)) newErrors.add('${id}_file');
      }
    }
    if (newErrors.isNotEmpty) {
      setState(() => _fieldErrors = newErrors);
      return;
    }

    setState(() { _submitting = true; _fieldErrors = {}; });
    try {
      final supabase = Supabase.instance.client;

      // Ensure a company_kyc record exists for this country+type
      final existingKyc = await supabase
          .from('company_kyc')
          .select('id')
          .eq('company_id', widget.companyId)
          .eq('country_code', widget.countryCode)
          .eq('phone_number_type', widget.numberType)
          .maybeSingle();

      final String kycId;
      if (existingKyc != null) {
        kycId = existingKyc['id'] as String;
      } else {
        final inserted = await supabase
            .from('company_kyc')
            .insert({
              'company_id':        widget.companyId,
              'country_code':      widget.countryCode,
              'phone_number_type': widget.numberType,
              'kyc_status':        'pending',
            })
            .select('id')
            .single();
        kycId = inserted['id'] as String;
      }

      // Save all requirements to DB — edge function handles Telnyx upload
      for (final r in widget.requirements) {
        final req   = r as Map<String, dynamic>;
        final reqId = req['id']?.toString() ?? '';
        final type  = req['type']?.toString() ?? '';

        if (type == 'address') {
          final ctrl = _addrCtrl[reqId]!;
          final parts = [
            ctrl['line1']!.text.trim(),
            ctrl['line2']!.text.trim(),
            ctrl['city']!.text.trim(),
            ctrl['postcode']!.text.trim(),
            ctrl['country']!.text.trim(),
          ].where((s) => s.isNotEmpty).join(', ');
          await _storeFieldValue(reqId, req, kycId, parts);
          // Keep company record in sync so the edge function uses updated values
          await Supabase.instance.client.from('companies').update({
            'address_line1': ctrl['line1']!.text.trim(),
            'address_line2': ctrl['line2']!.text.trim(),
            'city':          ctrl['city']!.text.trim(),
            'postcode':      ctrl['postcode']!.text.trim(),
            'country':       ctrl['country']!.text.trim(),
          }).eq('id', widget.companyId);
        } else if (type == 'textual' && _isContactReq(req)) {
          final ctrl = _contactCtrl[reqId]!;
          final parts = <String>[
            if (ctrl['name']!.text.trim().isNotEmpty)    ctrl['name']!.text.trim(),
            if (ctrl['company']!.text.trim().isNotEmpty) ctrl['company']!.text.trim(),
            if (ctrl['email']!.text.trim().isNotEmpty)   ctrl['email']!.text.trim(),
            if (ctrl['phone']!.text.trim().isNotEmpty)   ctrl['phone']!.text.trim(),
          ];
          await _storeFieldValue(reqId, req, kycId, parts.join(', '));
        } else if (type == 'textual') {
          await _storeFieldValue(reqId, req, kycId, _textCtrl[reqId]!.text.trim());
        } else if (type == 'document') {
          final hasCached    = _hasCachedDoc(reqId, req);
          final wantsReplace = _replaceDoc[reqId] ?? false;

          if (hasCached && !wantsReplace) {
            // Create a stub row for this kyc_id so the edge function finds it
            await Supabase.instance.client.from('company_kyc_documents').insert({
              'company_id':          widget.companyId,
              'kyc_id':              kycId,
              'requirement_type_id': reqId,
              'requirement_name':    req['name']?.toString() ?? '',
              'document_type':       type,
              'status':              'submitted',
              'telnyx_document_id':  _cachedDocIds[reqId],
              'delete_after':
                  DateTime.now().add(const Duration(days: 365 * 7)).toIso8601String(),
            });
          } else {
            await _storeDocument(reqId, req, kycId);
          }
        }
      }

      if (mounted) Navigator.of(context).pop(kycId);
    } catch (e) {
      setState(() { _submitting = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:  620,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 24, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Verify Identity',
                            style: TextStyle(fontFamily: 'DM Sans', fontSize: 20,
                                fontWeight: FontWeight.w700, color: Color(0xFF0D0D1A))),
                        SizedBox(height: 2),
                        Text('Required by the carrier to purchase this number.',
                            style: TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                                color: Color(0xFF9999AA))),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF6B6B8A)),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            // Body
            Flexible(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(_error!,
                              style: const TextStyle(color: Color(0xFFEF4444))),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Pre-filled section ──────────────────────────
                              _SectionLabel('Pre-filled from your account',
                                  Icons.check_circle_outline, const Color(0xFF22C55E)),
                              const SizedBox(height: 4),
                              const Text(
                                'Review and edit if anything is incorrect.',
                                style: TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                                    color: Color(0xFF9999AA)),
                              ),
                              const SizedBox(height: 14),
                              ...widget.requirements
                                  .where((r) {
                                    final t = (r as Map<String, dynamic>)['type']?.toString();
                                    return t == 'textual' || t == 'address';
                                  })
                                  .expand((r) {
                                    final req  = r as Map<String, dynamic>;
                                    final id   = req['id']?.toString() ?? '';
                                    final type = req['type']?.toString() ?? '';
                                    final label = req['name']?.toString() ?? '';

                                    if (type == 'address') {
                                      final ctrl = _addrCtrl[id];
                                      if (ctrl == null) return const <Widget>[];
                                      return <Widget>[
                                        _SubSectionLabel(label),
                                        _WizardField(label: 'Address Line 1', hint: '123 Main Street', controller: ctrl['line1']!,
                                            errorText: _fieldErrors.contains('${id}_line1') ? 'Address line 1 is required' : null),
                                        _WizardField(label: 'Address Line 2', hint: 'Suite, floor, building (optional)', controller: ctrl['line2']!),
                                        _WizardField(label: 'City', hint: 'London', controller: ctrl['city']!,
                                            errorText: _fieldErrors.contains('${id}_city') ? 'City is required' : null),
                                        _WizardField(label: 'Postcode / ZIP', hint: 'SW1A 1AA', controller: ctrl['postcode']!),
                                        _WizardField(label: 'Country', hint: 'United Kingdom', controller: ctrl['country']!),
                                      ];
                                    } else if (_isContactReq(req)) {
                                      final ctrl = _contactCtrl[id];
                                      if (ctrl == null) return const <Widget>[];
                                      return <Widget>[
                                        _SubSectionLabel(label),
                                        _WizardField(label: 'Full Name', hint: 'John Smith', controller: ctrl['name']!,
                                            errorText: _fieldErrors.contains('${id}_name') ? 'Full name is required' : null),
                                        _WizardField(label: 'Company Name', hint: 'Acme Ltd', controller: ctrl['company']!,
                                            errorText: _fieldErrors.contains('${id}_company') ? 'Company name is required' : null),
                                        _WizardField(label: 'Email Address', hint: 'john@acme.com', controller: ctrl['email']!,
                                            errorText: _fieldErrors.contains('${id}_email') ? 'Email address is required' : null),
                                        _WizardField(label: 'Phone Number', hint: '+44 7700 900000', controller: ctrl['phone']!,
                                            errorText: _fieldErrors.contains('${id}_phone') ? 'Phone number is required' : null),
                                      ];
                                    } else {
                                      return <Widget>[
                                        _WizardField(
                                          label:      label,
                                          hint:       req['example']?.toString() ?? '',
                                          controller: _textCtrl[id] ?? TextEditingController(),
                                          errorText:  _fieldErrors.contains('${id}_text') ? 'This field is required' : null,
                                        ),
                                      ];
                                    }
                                  }),

                              // ── Documents section ───────────────────────────
                              const SizedBox(height: 8),
                              _SectionLabel('Documents required',
                                  Icons.upload_file_outlined, const Color(0xFF4F6AFF)),
                              const SizedBox(height: 14),
                              ...widget.requirements
                                  .where((r) =>
                                      (r as Map<String, dynamic>)['type'] == 'document')
                                  .map((r) {
                                    final req  = r as Map<String, dynamic>;
                                    final id   = req['id']?.toString() ?? '';
                                    final hasCached    = _hasCachedDoc(id, req);
                                    final wantsReplace = _replaceDoc[id] ?? false;
                                    final showPicker   = !hasCached || wantsReplace;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(req['name']?.toString() ?? '',
                                              style: const TextStyle(
                                                  fontFamily: 'DM Sans', fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF3D3D5C))),
                                          if ((req['description']?.toString() ?? '').isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(req['description']!.toString(),
                                                style: const TextStyle(
                                                    fontFamily: 'DM Sans', fontSize: 12,
                                                    color: Color(0xFF9999AA))),
                                          ],
                                          if (_isProofOfAddressReq(req)) ...[
                                            const SizedBox(height: 2),
                                            const Text(
                                              'Must be dated within the last 3 months.',
                                              style: TextStyle(fontFamily: 'DM Sans',
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                  color: Color(0xFFF59E0B)),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          if (hasCached && !wantsReplace)
                                            Row(
                                              children: [
                                                const Icon(Icons.check_circle,
                                                    size: 16, color: Color(0xFF22C55E)),
                                                const SizedBox(width: 6),
                                                const Text('Document on file',
                                                    style: TextStyle(
                                                        fontFamily: 'DM Sans', fontSize: 13,
                                                        color: Color(0xFF22C55E))),
                                                const Spacer(),
                                                TextButton(
                                                  onPressed: () => setState(
                                                      () => _replaceDoc[id] = true),
                                                  child: const Text('Replace'),
                                                ),
                                              ],
                                            )
                                          else if (_files.containsKey(id))
                                            Row(
                                              children: [
                                                const Icon(Icons.picture_as_pdf,
                                                    size: 16, color: Color(0xFF4F6AFF)),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    _files[id]!.name,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontFamily: 'DM Sans', fontSize: 13,
                                                        color: Color(0xFF4F6AFF)),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: _submitting ? null : () => _pickFile(id),
                                                  child: const Text('Change'),
                                                ),
                                              ],
                                            )
                                          else if (showPicker)
                                            OutlinedButton.icon(
                                              onPressed: _submitting ? null : () => _pickFile(id),
                                              icon: const Icon(Icons.upload_outlined, size: 16),
                                              label: const Text('Upload PDF'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFF4F6AFF),
                                                side: const BorderSide(
                                                    color: Color(0xFF4F6AFF)),
                                                textStyle: const TextStyle(
                                                    fontFamily: 'DM Sans', fontSize: 12,
                                                    fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                          if (_fieldErrors.contains('${id}_file') && showPicker && !_files.containsKey(id)) ...[
                                            const SizedBox(height: 6),
                                            const Text('This document is required',
                                                style: TextStyle(fontFamily: 'DM Sans',
                                                    fontSize: 11, color: Color(0xFFEF4444))),
                                          ],
                                          if (!_isProofOfAddressReq(req) && !hasCached) ...[
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Saved securely — you won\'t need to upload this again.',
                                              style: TextStyle(fontFamily: 'DM Sans',
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                  color: Color(0xFF9999AA)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }),
                              const SizedBox(height: 8),

                              // Error
                              if (_error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFECACA)),
                                  ),
                                  child: Text(_error!,
                                      style: const TextStyle(
                                          fontFamily: 'DM Sans', fontSize: 12,
                                          color: Color(0xFFDC2626))),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting ? null
                        : () => Navigator.of(context).pop(null),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading || _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D0D1A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      textStyle: const TextStyle(fontFamily: 'DM Sans',
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm and Purchase'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _SectionLabel(this.text, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _SubSectionLabel extends StatelessWidget {
  final String text;
  const _SubSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(fontFamily: 'DM Sans', fontSize: 12,
              fontWeight: FontWeight.w600, color: Color(0xFF3D3D5C))),
    );
  }
}

class _WizardField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? errorText;
  const _WizardField({
    required this.label,
    required this.hint,
    required this.controller,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                fontFamily: 'DM Sans', fontSize: 12, fontWeight: FontWeight.w500,
                color: hasError ? const Color(0xFFEF4444) : const Color(0xFF6B6B8A),
              )),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint.isNotEmpty ? hint : null,
              hintStyle: const TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                  color: Color(0xFFB0B0C4)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
              enabledBorder: hasError
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFEF4444)))
                  : null,
              focusedBorder: hasError
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5))
                  : null,
            ),
            style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                color: Color(0xFF3D3D5C)),
          ),
          if (hasError) ...[
            const SizedBox(height: 4),
            Text(errorText!,
                style: const TextStyle(fontFamily: 'DM Sans', fontSize: 11,
                    color: Color(0xFFEF4444))),
          ],
        ],
      ),
    );
  }
}

// ── Result table widgets ──────────────────────────────────────────────────────

class _ResultHeaderCell extends StatelessWidget {
  final String text;
  const _ResultHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontFamily: 'DM Sans', fontSize: 11,
            fontWeight: FontWeight.w600, color: Color(0xFF9999AA), letterSpacing: 0.4));
  }
}

class _AvailableNumberRow extends StatelessWidget {
  final _AvailableNumber number;
  final VoidCallback onSelect;
  final bool purchasing;
  const _AvailableNumberRow({
    required this.number,
    required this.onSelect,
    required this.purchasing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Phone number
          Expanded(
            flex: 3,
            child: Text(number.phoneNumber,
                style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                    fontWeight: FontWeight.w500, color: Color(0xFF4F6AFF))),
          ),
          // Region
          Expanded(
            flex: 2,
            child: Text(
              number.regionLabel.isEmpty ? '—' : number.regionLabel,
              style: const TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                  color: Color(0xFF6B6B8A)),
            ),
          ),
          // Features + badges
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                ...number.features.map((f) => _Chip(f, const Color(0xFF4F6AFF))),
                if (number.quickship)  _Chip('quickship',  const Color(0xFF22C55E)),
                if (number.reservable) _Chip('reservable', const Color(0xFF9999AA)),
                if (number.bestEffort) _Chip('best effort', const Color(0xFFF59E0B)),
              ],
            ),
          ),
          // Monthly cost
          Expanded(
            flex: 2,
            child: number.monthlyCost.isEmpty
                ? const Text('—', style: TextStyle(fontFamily: 'DM Sans',
                    fontSize: 12, color: Color(0xFF9999AA)))
                : Text(
                    '${number.currency} ${number.monthlyCost}/mo',
                    style: const TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                        fontWeight: FontWeight.w500, color: Color(0xFF3D3D5C)),
                  ),
          ),
          // Select button
          SizedBox(
            width: 100,
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: purchasing ? null : onSelect,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F6AFF),
                  side: const BorderSide(color: Color(0xFF4F6AFF)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                child: purchasing
                    ? const SizedBox(width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Select'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontFamily: 'DM Sans', fontSize: 10,
              fontWeight: FontWeight.w500, color: color)),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final int flex;
  final bool required;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.flex,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                      fontWeight: FontWeight.w500, color: Color(0xFF6B6B8A))),
              if (required) ...[
                const Spacer(),
                const Text('Required',
                    style: TextStyle(fontFamily: 'DM Sans', fontSize: 11,
                        fontStyle: FontStyle.italic, color: Color(0xFF9999AA))),
              ],
            ],
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e,
                    style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13))))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
