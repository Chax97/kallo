import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Sample data ───────────────────────────────────────────────────────────────

final _sampleNumbers = [
  _PhoneNumberRow(country: 'GB +44', area: '020', number: '33552116', routing: 'Forward to Xelion Farhaan KK R', routingSet: true,  emergencyAddress: 'None Set'),
  _PhoneNumberRow(country: 'GB +44', area: '020', number: '34045173', routing: 'User',                            routingSet: true,  emergencyAddress: 'None Set'),
  _PhoneNumberRow(country: 'GB +44', area: '020', number: '34045174', routing: 'Set Call Routing',               routingSet: false, emergencyAddress: 'Main Office'),
  _PhoneNumberRow(country: 'GB +44', area: '020', number: '39843500', routing: 'Set Call Routing',               routingSet: false, emergencyAddress: 'None Set'),
  _PhoneNumberRow(country: 'GB +44', area: '020', number: '39843501', routing: 'Xelion forward to Rafiq ARQ Hor', routingSet: true,  emergencyAddress: 'Main Office'),
  _PhoneNumberRow(country: 'GB +44', area: '020', number: '39843502', routing: 'Xelion forward to Ali ARQ Home', routingSet: true,  emergencyAddress: 'Main Office'),
  _PhoneNumberRow(country: 'GB +44', area: '020', number: '39843503', routing: 'Xelion forward to Hamad ARQ H',  routingSet: true,  emergencyAddress: 'Main Office'),
];

class _PhoneNumberRow {
  final String country;
  final String area;
  final String number;
  final String routing;
  final bool routingSet;
  final String emergencyAddress;
  const _PhoneNumberRow({
    required this.country,
    required this.area,
    required this.number,
    required this.routing,
    required this.routingSet,
    required this.emergencyAddress,
  });
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _sampleNumbers.where((r) =>
      r.number.contains(_searchQuery) ||
      r.routing.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      r.emergencyAddress.toLowerCase().contains(_searchQuery.toLowerCase()),
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

          // Search + Export row
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
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Export'),
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
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('No numbers found.',
                                style: TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                                    color: Color(0xFF9999AA))),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, i) => _NumberRow(row: filtered[i]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
          _HeaderCell('Country',            flex: 2),
          _HeaderCell('Area',               flex: 1),
          _HeaderCell('Number',             flex: 2),
          _HeaderCell('Routing',            flex: 4),
          _HeaderCell('Emergency Address',  flex: 3),
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
      child: Row(
        children: [
          Text(text, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 11,
              fontWeight: FontWeight.w600, color: Color(0xFF9999AA), letterSpacing: 0.5)),
          if (text == 'Routing') ...[
            const SizedBox(width: 4),
            const Icon(Icons.arrow_downward_rounded, size: 11, color: Color(0xFF9999AA)),
          ],
        ],
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  final _PhoneNumberRow row;
  const _NumberRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Country
          Expanded(
            flex: 2,
            child: Row(
              children: [
                // UK flag approximation
                Container(
                  width: 22, height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF012169),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Center(
                    child: Text('🇬🇧', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 6),
                Text(row.country, style: const TextStyle(fontFamily: 'DM Sans',
                    fontSize: 12, color: Color(0xFF6B6B8A))),
              ],
            ),
          ),
          // Area
          Expanded(
            flex: 1,
            child: Text(row.area, style: const TextStyle(fontFamily: 'DM Sans',
                fontSize: 13, color: Color(0xFF3D3D5C))),
          ),
          // Number
          Expanded(
            flex: 2,
            child: Text(row.number, style: const TextStyle(fontFamily: 'DM Sans',
                fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF4F6AFF))),
          ),
          // Routing
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Icon(
                  row.routingSet ? Icons.share_outlined : Icons.check_box_outline_blank,
                  size: 13,
                  color: row.routingSet ? const Color(0xFF9999AA) : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(row.routing,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'DM Sans', fontSize: 13,
                      color: row.routingSet ? const Color(0xFF3D3D5C) : const Color(0xFFEF4444),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 16,
                    color: Color(0xFF6B6B8A)),
              ],
            ),
          ),
          // Emergency Address
          Expanded(
            flex: 3,
            child: Text(row.emergencyAddress,
              style: TextStyle(
                fontFamily: 'DM Sans', fontSize: 13,
                color: row.emergencyAddress == 'None Set'
                    ? const Color(0xFF9999AA) : const Color(0xFF3D3D5C),
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
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _CircleIconButton(
                  icon: Icons.delete_outline,
                  color: const Color(0xFFEF4444),
                  onTap: () {},
                ),
              ],
            ),
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
