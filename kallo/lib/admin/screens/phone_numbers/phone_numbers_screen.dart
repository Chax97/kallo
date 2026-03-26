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
      quickship: json['quickship'] == true,
      reservable: json['reservable'] == true,
      bestEffort: json['best_effort'] == true,
      monthlyCost: cost['monthly_cost']?.toString() ?? '',
      upfrontCost: cost['upfront_cost']?.toString() ?? '',
      currency: cost['currency']?.toString() ?? 'USD',
      features: featureList,
      regions: regionList,
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

  bool   _searching   = false;
  String? _searchError;
  List<_AvailableNumber> _results = [];
  bool   _hasSearched = false;
  int    _totalResults = 0;
  bool   _purchasing  = false;
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
                                  onSelect: () => _purchaseNumber(_results[i]),
                                  purchasing: _purchasing,
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
