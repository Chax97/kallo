import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiAgentsScreen extends ConsumerWidget {
  const AiAgentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Agents', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 4),
          Text('Configure and manage your AI agents.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Agent list
                SizedBox(
                  width: 260,
                  child: Column(
                    children: [
                      _SectionHeader(
                        title: 'Your Agents',
                        action: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add, size: 15),
                          label: const Text('New Agent'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE8E8F0)),
                          ),
                          child: ListView(
                            children: const [
                              _AgentTile(
                                name: 'Reception Bot',
                                status: 'active',
                                description: 'Handles inbound reception calls',
                              ),
                              Divider(height: 1),
                              _AgentTile(
                                name: 'Support Agent',
                                status: 'inactive',
                                description: 'First-line customer support',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Config panel
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8E8F0)),
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Agent Configuration',
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0D0D1A),
                            )),
                        const SizedBox(height: 4),
                        const Text('Select an agent to configure.',
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 13,
                              color: Color(0xFF9999AA),
                            )),
                        const SizedBox(height: 28),
                        const _ConfigSection(title: 'Identity'),
                        const SizedBox(height: 16),
                        const _LabeledField(label: 'Agent Name', hint: 'e.g. Reception Bot'),
                        const SizedBox(height: 14),
                        const _LabeledField(
                          label: 'System Prompt',
                          hint: 'You are a helpful receptionist for Acme Corp...',
                          maxLines: 5,
                        ),
                        const SizedBox(height: 24),
                        const _ConfigSection(title: 'Voice & Language'),
                        const SizedBox(height: 16),
                        Row(
                          children: const [
                            Expanded(child: _LabeledDropdown(
                              label: 'Voice',
                              value: 'Female – Neural A',
                              items: ['Female – Neural A', 'Female – Neural B', 'Male – Neural A', 'Male – Neural B'],
                            )),
                            SizedBox(width: 16),
                            Expanded(child: _LabeledDropdown(
                              label: 'Language',
                              value: 'English (AU)',
                              items: ['English (AU)', 'English (UK)', 'English (US)'],
                            )),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const _ConfigSection(title: 'Behaviour'),
                        const SizedBox(height: 16),
                        const _ToggleRow(
                          label: 'Interrupt on speech',
                          subtitle: 'Allow callers to interrupt the agent mid-sentence',
                        ),
                        const SizedBox(height: 10),
                        const _ToggleRow(
                          label: 'Transfer to human on request',
                          subtitle: 'Route to a live agent when the caller asks',
                          defaultValue: true,
                        ),
                        const SizedBox(height: 10),
                        const _ToggleRow(
                          label: 'Record conversations',
                          subtitle: 'Save transcripts and audio of all calls',
                          defaultValue: true,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(onPressed: () {}, child: const Text('Discard')),
                            const SizedBox(width: 12),
                            ElevatedButton(onPressed: () {}, child: const Text('Save Agent')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget action;
  const _SectionHeader({required this.title, required this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(
          fontFamily: 'DM Sans', fontSize: 13,
          fontWeight: FontWeight.w600, color: Color(0xFF0D0D1A),
        )),
        const Spacer(),
        action,
      ],
    );
  }
}

class _AgentTile extends StatelessWidget {
  final String name;
  final String status;
  final String description;
  const _AgentTile({required this.name, required this.status, required this.description});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(
            fontFamily: 'DM Sans', fontSize: 13, fontWeight: FontWeight.w600,
            color: Color(0xFF0D0D1A),
          ))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                  : const Color(0xFF9999AA).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontFamily: 'DM Sans', fontSize: 10, fontWeight: FontWeight.w600,
                color: isActive ? const Color(0xFF22C55E) : const Color(0xFF9999AA),
              ),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(description, style: const TextStyle(
          fontFamily: 'DM Sans', fontSize: 11, color: Color(0xFF9999AA),
        )),
      ),
      onTap: () {},
    );
  }
}

class _ConfigSection extends StatelessWidget {
  final String title;
  const _ConfigSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(
          fontFamily: 'DM Sans', fontSize: 12,
          fontWeight: FontWeight.w700, color: Color(0xFF9999AA), letterSpacing: 0.8,
        )),
        const SizedBox(width: 12),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String hint;
  final int maxLines;
  const _LabeledField({required this.label, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
          fontFamily: 'DM Sans', fontSize: 12,
          fontWeight: FontWeight.w600, color: Color(0xFF3D3D5C),
        )),
        const SizedBox(height: 6),
        TextField(
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  const _LabeledDropdown({required this.label, required this.value, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
          fontFamily: 'DM Sans', fontSize: 12,
          fontWeight: FontWeight.w600, color: Color(0xFF3D3D5C),
        )),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isDense: true,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: items.map((e) => DropdownMenuItem(
            value: e,
            child: Text(e, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13)),
          )).toList(),
          onChanged: (_) {},
        ),
      ],
    );
  }
}

class _ToggleRow extends StatefulWidget {
  final String label;
  final String subtitle;
  final bool defaultValue;
  const _ToggleRow({required this.label, required this.subtitle, this.defaultValue = false});

  @override
  State<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<_ToggleRow> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(
                fontFamily: 'DM Sans', fontSize: 13,
                fontWeight: FontWeight.w500, color: Color(0xFF0D0D1A),
              )),
              Text(widget.subtitle, style: const TextStyle(
                fontFamily: 'DM Sans', fontSize: 11, color: Color(0xFF9999AA),
              )),
            ],
          ),
        ),
        Switch(
          value: _value,
          onChanged: (v) => setState(() => _value = v),
          activeThumbColor: Colors.white,
          activeTrackColor: const Color(0xFF4F6AFF),
        ),
      ],
    );
  }

  String get label => widget.label;
}
