import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final usersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('users')
      .select('''
        id, display_name, email, role, extension, status, created_at,
        phone_numbers(number, label),
        hunt_group_members(hunt_groups(id, name))
      ''')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

final huntGroupsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('hunt_groups')
      .select('id, name, strategy')
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});

// ── Main Screen ───────────────────────────────────────────────────────────────

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  Map<String, dynamic>? _selectedUser;

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider);

    if (_selectedUser != null) {
      return _EditUserPanel(
        user: _selectedUser!,
        onBack: () => setState(() => _selectedUser = null),
        onSuccess: () {
          ref.invalidate(usersProvider);
          setState(() => _selectedUser = null);
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UsersHeader(onInvite: () => _showInviteDialog(context)),
          const SizedBox(height: 20),
          Expanded(
            child: users.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorCard(message: e.toString()),
              data: (data) => _UsersTable(
                users: data,
                onEdit: (user) => setState(() => _selectedUser = user),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _InviteUserDialog(onSuccess: () => ref.invalidate(usersProvider)),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _UsersHeader extends StatelessWidget {
  final VoidCallback onInvite;
  const _UsersHeader({required this.onInvite});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Users', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 2),
            Text(
              'Manage your team members, roles and extensions.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: onInvite,
          icon: const Icon(Icons.person_add_outlined, size: 16),
          label: const Text('Invite user'),
        ),
      ],
    );
  }
}

// ── Users Table ───────────────────────────────────────────────────────────────

class _UsersTable extends ConsumerWidget {
  final List<Map<String, dynamic>> users;
  final ValueChanged<Map<String, dynamic>> onEdit;
  const _UsersTable({required this.users, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.people_outline_rounded, size: 26, color: Color(0xFF4F6AFF)),
            ),
            const SizedBox(height: 16),
            Text('No users yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Invite your first team member to get started.',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    return Container(
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
            child: ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => _UserRow(
                user: users[index],
                onRefresh: () => ref.invalidate(usersProvider),
                onEdit: onEdit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: const [
          _HeaderCell('Name', flex: 3),
          _HeaderCell('Ext', flex: 1),
          _HeaderCell('Phone Number', flex: 2),
          _HeaderCell('Hunt Groups', flex: 3),
          _HeaderCell('Status', flex: 2),
          _HeaderCell('', flex: 1),
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
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF9999AA),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── User Row ──────────────────────────────────────────────────────────────────

class _UserRow extends ConsumerWidget {
  final Map<String, dynamic> user;
  final VoidCallback onRefresh;
  final ValueChanged<Map<String, dynamic>> onEdit;
  const _UserRow({required this.user, required this.onRefresh, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String name = (user['display_name'] ?? user['email'] ?? 'Unknown').toString();
    final String email = (user['email'] ?? '').toString();
    final String role = (user['role'] ?? 'agent').toString();
    final extension = user['extension'];
    final String status = (user['status'] ?? 'active').toString();
    final phoneNumbers = user['phone_numbers'];
    String phoneDisplay = '-';
    if (phoneNumbers is List && phoneNumbers.isNotEmpty) {
      final pn = phoneNumbers.first as Map;
      phoneDisplay = (pn['label'] ?? pn['number'] ?? '-').toString();
    } else if (phoneNumbers is Map) {
      phoneDisplay = (phoneNumbers['label'] ?? phoneNumbers['number'] ?? '-').toString();
    }

    final huntGroupMembers = user['hunt_group_members'];

    List<String> huntGroupNames = [];
    if (huntGroupMembers is List) {
      for (final m in huntGroupMembers) {
        final hg = m['hunt_groups'];
        if (hg is Map && hg['name'] != null) {
          huntGroupNames.add(hg['name'].toString());
        }
      }
    }

    final initials = name.trim().split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join()
        .toUpperCase();

    final roleColor = role == 'admin' ? const Color(0xFF4F6AFF) : const Color(0xFF6B6B8A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // User cell
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: roleColor.withValues(alpha: 0.12),
                  child: Text(
                    initials.isEmpty ? '?' : initials,
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: roleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(name,
                              style: const TextStyle(
                                fontFamily: 'DM Sans', fontSize: 13,
                                fontWeight: FontWeight.w500, color: Color(0xFF0D0D1A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _RoleBadge(role: role),
                        ],
                      ),
                      Text(email,
                        style: const TextStyle(
                          fontFamily: 'DM Sans', fontSize: 11, color: Color(0xFF9999AA),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Ext cell
          Expanded(
            flex: 1,
            child: extension != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(extension.toString(),
                      style: const TextStyle(
                        fontFamily: 'DM Sans', fontSize: 13,
                        fontWeight: FontWeight.w500, color: Color(0xFF3D3D5C),
                      ),
                    ),
                  )
                : const Text('-',
                    style: TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: Color(0xFF9999AA))),
          ),
          // Phone Number cell
          Expanded(
            flex: 2,
            child: Text(phoneDisplay,
              style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: Color(0xFF3D3D5C)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Hunt Groups cell
          Expanded(
            flex: 3,
            child: huntGroupNames.isEmpty
                ? const Text('-',
                    style: TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: Color(0xFF9999AA)))
                : Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: huntGroupNames.map((hg) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF0FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(hg,
                        style: const TextStyle(
                          fontFamily: 'DM Sans', fontSize: 11,
                          fontWeight: FontWeight.w500, color: Color(0xFF4F6AFF),
                        ),
                      ),
                    )).toList(),
                  ),
          ),
          // Status cell
          Expanded(flex: 2, child: _StatusBadge(status: status)),
          // Edit cell
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => onEdit(user),
                  icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6B6B8A)),
                  tooltip: 'Edit user',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

// ── Badges ────────────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAdmin ? const Color(0xFFEEF0FF) : const Color(0xFFF0F0F8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(role,
        style: TextStyle(
          fontFamily: 'DM Sans', fontSize: 10, fontWeight: FontWeight.w600,
          color: isAdmin ? const Color(0xFF4F6AFF) : const Color(0xFF6B6B8A),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, text, dot) = switch (status.toLowerCase()) {
      'active'    => (const Color(0xFFDCFCE7), const Color(0xFF16A34A), const Color(0xFF22C55E)),
      'suspended' => (const Color(0xFFFEF2F2), const Color(0xFFDC2626), const Color(0xFFEF4444)),
      _           => (const Color(0xFFF0F0F8), const Color(0xFF6B6B8A), const Color(0xFF9999AA)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(status,
            style: TextStyle(fontFamily: 'DM Sans', fontSize: 11, fontWeight: FontWeight.w500, color: text)),
        ],
      ),
    );
  }
}

// ── Invite Dialog ─────────────────────────────────────────────────────────────

class _InviteUserDialog extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _InviteUserDialog({required this.onSuccess});

  @override
  ConsumerState<_InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends ConsumerState<_InviteUserDialog> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _extensionController = TextEditingController();
  String _role = 'agent';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _extensionController.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = 'Email is required');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final currentUser = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('id', Supabase.instance.client.auth.currentUser!.id)
          .single();
      final companyId = currentUser['company_id'];

      await Supabase.instance.client.auth.admin.inviteUserByEmail(
        _emailController.text.trim(),
      );

      final authUsers = await Supabase.instance.client.auth.admin.listUsers();
      final invitedUser = authUsers.firstWhere(
        (u) => u.email == _emailController.text.trim(),
        orElse: () => throw Exception('Could not find invited user in auth'),
      );

      await Supabase.instance.client.from('users').upsert({
        'id': invitedUser.id,
        'company_id': companyId,
        'email': _emailController.text.trim(),
        'display_name': _nameController.text.trim(),
        'extension': _extensionController.text.trim().isEmpty
            ? null : _extensionController.text.trim(),
        'role': _role,
        'status': 'inactive',
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite sent successfully')));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: 'Invite user',
      subtitle: 'They will receive an email to set their password.',
      confirmLabel: 'Send invite',
      loading: _loading,
      onConfirm: _invite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[_ErrorBanner(message: _error!), const SizedBox(height: 16)],
          _FieldLabel('Email address'),
          const SizedBox(height: 6),
          TextField(controller: _emailController, keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'agent@company.com')),
          const SizedBox(height: 14),
          _FieldLabel('Display name'),
          const SizedBox(height: 6),
          TextField(controller: _nameController,
              decoration: const InputDecoration(hintText: 'e.g. Sarah Jones')),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _FieldLabel('Extension'),
                  const SizedBox(height: 6),
                  TextField(controller: _extensionController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '101')),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _FieldLabel('Role'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'agent', child: Text('Agent')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                    ],
                    onChanged: (v) => setState(() => _role = v ?? 'agent'),
                  ),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Edit Panel (inline) ───────────────────────────────────────────────────────

class _EditUserPanel extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onBack;
  final VoidCallback onSuccess;
  const _EditUserPanel({required this.user, required this.onBack, required this.onSuccess});

  @override
  ConsumerState<_EditUserPanel> createState() => _EditUserPanelState();
}

class _EditUserPanelState extends ConsumerState<_EditUserPanel> {
  int _selectedIndex = 0;
  late final TextEditingController _nameController;
  late final TextEditingController _extensionController;
  late String _role;
  bool _loading = false;
  String? _error;

  static const _tabs = [
    ('Overview',           Icons.dashboard_outlined),
    ('General',            Icons.person_outline),
    ('Call Handling',      Icons.queue_outlined),
    ('Voicemail',          Icons.voicemail_outlined),
    ('User settings',      Icons.manage_accounts_outlined),
    ('Automatic transfer', Icons.swap_calls_outlined),
    ('Schedule',           Icons.calendar_today_outlined),
    ('Advanced',           Icons.tune_outlined),
    ('Chat',               Icons.chat_outlined),
    ('Managers',           Icons.supervisor_account_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['display_name'] ?? '');
    _extensionController = TextEditingController(text: widget.user['extension']?.toString() ?? '');
    _role = widget.user['role'] ?? 'agent';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _extensionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.from('users').update({
        'display_name': _nameController.text.trim(),
        'extension': _extensionController.text.trim().isEmpty
            ? null : _extensionController.text.trim(),
        'role': _role,
      }).eq('id', widget.user['id']);
      if (mounted) widget.onSuccess();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.user['display_name'] ?? widget.user['email'] ?? 'User').toString();
    final email = (widget.user['email'] ?? '').toString();
    final initials = name.trim().split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back breadcrumb
          GestureDetector(
            onTap: widget.onBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: Color(0xFF6B6B8A)),
                const SizedBox(width: 4),
                const Text('Users', style: TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: Color(0xFF6B6B8A))),
                const Text(' / ', style: TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: Color(0xFF9999AA))),
                Text(name, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: Color(0xFF0D0D1A), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Main card
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left sidebar
                  Container(
                    width: 200,
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Color(0xFFE8E8F0))),
                    ),
                    child: Column(
                      children: [
                        // User identity
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFEEF0FF),
                                child: Text(initials.isEmpty ? '?' : initials,
                                  style: const TextStyle(fontFamily: 'DM Sans', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4F6AFF))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D0D1A)), overflow: TextOverflow.ellipsis),
                                    Text(email, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 11, color: Color(0xFF9999AA)), overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        // Nav items
                        ...List.generate(_tabs.length, (i) {
                          final (label, icon) = _tabs[i];
                          final selected = _selectedIndex == i;
                          return InkWell(
                            onTap: () => setState(() => _selectedIndex = i),
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFFEEF0FF) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(icon, size: 15,
                                    color: selected ? const Color(0xFF4F6AFF) : const Color(0xFF6B6B8A)),
                                  const SizedBox(width: 8),
                                  Text(label,
                                    style: TextStyle(
                                      fontFamily: 'DM Sans', fontSize: 13,
                                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                                      color: selected ? const Color(0xFF4F6AFF) : const Color(0xFF3D3D5C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  // Right content
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: IndexedStack(
                            index: _selectedIndex,
                            children: [
                              _OverviewTab(user: widget.user),
                              _GeneralTab(
                                nameController: _nameController,
                                extensionController: _extensionController,
                                role: _role,
                                onRoleChanged: (v) => setState(() => _role = v),
                                error: _error,
                              ),
                              _PlaceholderTab(icon: Icons.queue_outlined, label: 'Call Handling'),
                              _PlaceholderTab(icon: Icons.voicemail_outlined, label: 'Voicemail'),
                              _PlaceholderTab(icon: Icons.manage_accounts_outlined, label: 'User settings'),
                              _PlaceholderTab(icon: Icons.swap_calls_outlined, label: 'Automatic transfer'),
                              const _ScheduleTab(),
                              const _AdvancedTab(),
                              _PlaceholderTab(icon: Icons.chat_outlined, label: 'Chat'),
                              _PlaceholderTab(icon: Icons.supervisor_account_outlined, label: 'Managers'),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: _loading ? null : widget.onBack,
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _loading ? null : _save,
                                child: _loading
                                    ? const SizedBox(width: 14, height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Save changes'),
                              ),
                            ],
                          ),
                        ),
                      ],
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

// ── Edit Dialog Tabs ──────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> user;
  const _OverviewTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final status = (user['status'] ?? 'active').toString();
    final role = (user['role'] ?? 'agent').toString();
    final extension = user['extension'];
    final createdAt = user['created_at']?.toString() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Account'),
          const SizedBox(height: 12),
          _InfoGrid(items: [
            _InfoItem('Status', _StatusBadge(status: status)),
            _InfoItem('Role', _RoleBadge(role: role)),
            _InfoItem('Extension', Text(extension?.toString() ?? '—',
                style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: Color(0xFF3D3D5C)))),
            _InfoItem('Member since', Text(createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt,
                style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: Color(0xFF3D3D5C)))),
          ]),
        ],
      ),
    );
  }
}

class _GeneralTab extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController extensionController;
  final String role;
  final ValueChanged<String> onRoleChanged;
  final String? error;

  const _GeneralTab({
    required this.nameController,
    required this.extensionController,
    required this.role,
    required this.onRoleChanged,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null) ...[_ErrorBanner(message: error!), const SizedBox(height: 16)],
          _SectionLabel('Basic information'),
          const SizedBox(height: 12),
          _FieldLabel('Display name'),
          const SizedBox(height: 6),
          TextField(controller: nameController,
              decoration: const InputDecoration(hintText: 'Full name')),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _FieldLabel('Extension'),
                  const SizedBox(height: 6),
                  TextField(controller: extensionController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '101')),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _FieldLabel('Role'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'agent', child: Text('Agent')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                    ],
                    onChanged: (v) => onRoleChanged(v ?? 'agent'),
                  ),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Schedule Tab ─────────────────────────────────────────────────────────────

class _ScheduleTab extends StatefulWidget {
  const _ScheduleTab();

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab>
    with SingleTickerProviderStateMixin {
  late final TabController _subTabController;
  bool _active = true;
  bool _synchronize = true;
  String _template = 'Main Operating Hours';

  static const _templates = [
    'Main Operating Hours',
    'Extended Hours',
    'Custom',
  ];

  // Default Mon–Fri 09:00–17:00/18:00 schedule
  final List<Map<String, String>> _switchTimes = [
    {'day': 'Monday',    'time': '09:00', 'transferTo': ''},
    {'day': 'Monday',    'time': '18:00', 'transferTo': 'Moneypenny'},
    {'day': 'Tuesday',   'time': '09:00', 'transferTo': ''},
    {'day': 'Tuesday',   'time': '18:00', 'transferTo': 'Moneypenny'},
    {'day': 'Wednesday', 'time': '09:00', 'transferTo': ''},
    {'day': 'Wednesday', 'time': '18:00', 'transferTo': 'Moneypenny'},
    {'day': 'Thursday',  'time': '09:00', 'transferTo': ''},
    {'day': 'Thursday',  'time': '17:00', 'transferTo': 'Moneypenny'},
    {'day': 'Friday',    'time': '09:00', 'transferTo': ''},
    {'day': 'Friday',    'time': '17:00', 'transferTo': 'Moneypenny'},
  ];

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active toggle
          Row(
            children: [
              const Text('Active',
                  style: TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                      fontWeight: FontWeight.w500, color: Color(0xFF3D3D5C))),
              const SizedBox(width: 12),
              SizedBox(
                width: 36, height: 20,
                child: Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF4F6AFF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sub-tabs
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE8E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sub-tab bar
                Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE8E8F0))),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: TabBar(
                    controller: _subTabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelStyle: const TextStyle(fontFamily: 'DM Sans', fontSize: 12,
                        fontWeight: FontWeight.w500),
                    unselectedLabelStyle: const TextStyle(fontFamily: 'DM Sans', fontSize: 12),
                    labelColor: const Color(0xFF4F6AFF),
                    unselectedLabelColor: const Color(0xFF6B6B8A),
                    indicatorColor: const Color(0xFF4F6AFF),
                    indicatorWeight: 2,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Switch times', height: 36),
                      Tab(text: 'Exception',    height: 36),
                      Tab(text: 'One off override', height: 36),
                    ],
                  ),
                ),
                // Sub-tab content (fixed height so it doesn't fight scroll)
                SizedBox(
                  height: 420,
                  child: TabBarView(
                    controller: _subTabController,
                    children: [
                      _SwitchTimesView(
                        template: _template,
                        templates: _templates,
                        synchronize: _synchronize,
                        rows: _switchTimes,
                        onTemplateChanged: (v) => setState(() => _template = v),
                        onSynchronizeChanged: (v) => setState(() => _synchronize = v),
                        onDeleteRow: (i) => setState(() => _switchTimes.removeAt(i)),
                      ),
                      _SchedulePlaceholder(label: 'Exception'),
                      _SchedulePlaceholder(label: 'One off override'),
                    ],
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

class _SwitchTimesView extends StatelessWidget {
  final String template;
  final List<String> templates;
  final bool synchronize;
  final List<Map<String, String>> rows;
  final ValueChanged<String> onTemplateChanged;
  final ValueChanged<bool> onSynchronizeChanged;
  final ValueChanged<int> onDeleteRow;

  const _SwitchTimesView({
    required this.template,
    required this.templates,
    required this.synchronize,
    required this.rows,
    required this.onTemplateChanged,
    required this.onSynchronizeChanged,
    required this.onDeleteRow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Template + Synchronize
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              const Text('Template',
                  style: TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                      fontWeight: FontWeight.w500, color: Color(0xFF3D3D5C))),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: template,
                  decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true),
                  items: templates.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13)),
                  )).toList(),
                  onChanged: (v) { if (v != null) onTemplateChanged(v); },
                ),
              ),
              const SizedBox(width: 24),
              Row(
                children: [
                  const Text('Synchronize',
                      style: TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                          fontWeight: FontWeight.w500, color: Color(0xFF3D3D5C))),
                  Checkbox(
                    value: synchronize,
                    onChanged: (v) => onSynchronizeChanged(v ?? false),
                    activeColor: const Color(0xFF4F6AFF),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Table header
        Container(
          color: const Color(0xFFF8F8FC),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: const [
              Expanded(flex: 3, child: _SchedHeaderCell('Day')),
              Expanded(flex: 2, child: _SchedHeaderCell('Time')),
              Expanded(flex: 3, child: _SchedHeaderCell('Transfer to')),
              Expanded(flex: 3, child: _SchedHeaderCell('Status')),
              Expanded(flex: 3, child: _SchedHeaderCell('Location')),
              SizedBox(width: 32),
            ],
          ),
        ),
        const Divider(height: 1),
        // Table rows
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final row = rows[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(row['day'] ?? '',
                        style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                            color: Color(0xFF3D3D5C)))),
                    Expanded(flex: 2, child: Text(row['time'] ?? '',
                        style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                            color: Color(0xFF3D3D5C)))),
                    Expanded(flex: 3, child: Text(row['transferTo'] ?? '',
                        style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                            color: Color(0xFF4F6AFF)))),
                    const Expanded(flex: 3, child: SizedBox()),
                    const Expanded(flex: 3, child: SizedBox()),
                    SizedBox(
                      width: 32,
                      child: IconButton(
                        onPressed: () => onDeleteRow(i),
                        icon: const Icon(Icons.delete_outline, size: 16,
                            color: Color(0xFF9999AA)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Remove',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SchedHeaderCell extends StatelessWidget {
  final String text;
  const _SchedHeaderCell(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontFamily: 'DM Sans', fontSize: 11,
          fontWeight: FontWeight.w600, color: Color(0xFF9999AA), letterSpacing: 0.4));
}

class _SchedulePlaceholder extends StatelessWidget {
  final String label;
  const _SchedulePlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('$label — coming soon',
          style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
              color: Color(0xFF9999AA))),
    );
  }
}

// ── Advanced Tab ──────────────────────────────────────────────────────────────

class _AdvancedTab extends StatefulWidget {
  const _AdvancedTab();

  @override
  State<_AdvancedTab> createState() => _AdvancedTabState();
}

class _AdvancedTabState extends State<_AdvancedTab> {
  String _countryCode = 'United Kingdom (+44)';
  String _showMissedCalls = 'Unanswered Only';
  String _emergencyLineId = "Use this user's caller ID";

  bool _pickUpOtherExtensions = true;
  bool _letOthersPickUp = true;
  bool _allowExternalInvites = true;
  bool _callEncryption = false;
  bool _availableInCallQueues = true;
  bool _canConfigureLineKeys = true;
  bool _disableCallWaiting = false;
  bool _enableCallFeedback = false;
  bool _canCreateFeedbackTags = false;
  bool _canBlockCallers = false;
  bool _useAdvancedCallQueuing = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Advanced Options ──────────────────────────────────────
          _SectionLabel('Advanced Options'),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _DropdownField(
                label: 'LOCAL COUNTRY CODE',
                required: true,
                value: _countryCode,
                items: const ['United Kingdom (+44)', 'United States (+1)', 'Australia (+61)'],
                onChanged: (v) => setState(() => _countryCode = v),
              )),
              const SizedBox(width: 16),
              Expanded(child: _DropdownField(
                label: 'SHOW MISSED CALLS',
                required: true,
                value: _showMissedCalls,
                items: const ['Unanswered Only', 'All Missed', 'None'],
                onChanged: (v) => setState(() => _showMissedCalls = v),
              )),
              const SizedBox(width: 16),
              Expanded(child: _DropdownField(
                label: 'EMERGENCY SERVICES LINE IDENTIFIER',
                required: true,
                value: _emergencyLineId,
                items: const ["Use this user's caller ID", 'Use company number'],
                onChanged: (v) => setState(() => _emergencyLineId = v),
              )),
            ],
          ),
          const SizedBox(height: 28),

          // ── Advanced Settings ─────────────────────────────────────
          _SectionLabel('Advanced Settings'),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _ToggleRow(label: 'PICK UP OTHER EXTENSIONS',        value: _pickUpOtherExtensions,   onChanged: (v) => setState(() => _pickUpOtherExtensions = v)),
                    _ToggleRow(label: 'ALLOW EXTERNAL & ANONYMOUS INVITE\'S', value: _allowExternalInvites, onChanged: (v) => setState(() => _allowExternalInvites = v)),
                    _ToggleRow(label: 'AVAILABLE IN CALL QUEUES',        value: _availableInCallQueues,   onChanged: (v) => setState(() => _availableInCallQueues = v)),
                    _ToggleRow(label: 'DISABLE CALL WAITING',            value: _disableCallWaiting,      onChanged: (v) => setState(() => _disableCallWaiting = v)),
                    _ToggleRow(label: 'CAN CREATE FEEDBACK TAGS',        value: _canCreateFeedbackTags,   onChanged: (v) => setState(() => _canCreateFeedbackTags = v)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _ToggleRow(label: 'LET OTHERS PICK UP THIS EXTENSION', value: _letOthersPickUp,       onChanged: (v) => setState(() => _letOthersPickUp = v)),
                    _ToggleRow(label: 'CALL ENCRYPTION (SRTP)',            value: _callEncryption,        onChanged: (v) => setState(() => _callEncryption = v)),
                    _ToggleRow(label: 'CAN CONFIGURE LINE KEYS',           value: _canConfigureLineKeys,  onChanged: (v) => setState(() => _canConfigureLineKeys = v)),
                    _ToggleRow(label: 'ENABLE CALL FEEDBACK',              value: _enableCallFeedback,    onChanged: (v) => setState(() => _enableCallFeedback = v)),
                    _ToggleRow(label: 'CAN BLOCK CALLERS VIA APPS',        value: _canBlockCallers,       onChanged: (v) => setState(() => _canBlockCallers = v)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
              ),
              child: const Text('Reset User'),
            ),
          ),
          const SizedBox(height: 28),

          // ── Advanced Call Queue Availability ──────────────────────
          _SectionLabel('Advanced Call Queue Availability'),
          const SizedBox(height: 16),
          _ToggleRow(
            label: 'USE ADVANCED CALL QUEUING',
            value: _useAdvancedCallQueuing,
            onChanged: (v) => setState(() => _useAdvancedCallQueuing = v),
          ),
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final bool required;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 10,
                fontWeight: FontWeight.w600, color: Color(0xFF6B6B8A), letterSpacing: 0.4)),
            if (required) ...[
              const SizedBox(width: 2),
              const Text('*', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e,
              style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13)))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 11,
              fontWeight: FontWeight.w600, color: Color(0xFF3D3D5C), letterSpacing: 0.3)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF4F6AFF),
          ),
        ],
      ),
    );
  }
}

// ── Placeholder Tab ───────────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: const Color(0xFF4F6AFF)),
          ),
          const SizedBox(height: 12),
          Text(label,
              style: const TextStyle(fontFamily: 'DM Sans', fontSize: 14,
                  fontWeight: FontWeight.w500, color: Color(0xFF3D3D5C))),
          const SizedBox(height: 4),
          const Text('Coming soon',
              style: TextStyle(fontFamily: 'DM Sans', fontSize: 12, color: Color(0xFF9999AA))),
        ],
      ),
    );
  }
}

// ── Edit Dialog Helpers ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontFamily: 'DM Sans', fontSize: 11, fontWeight: FontWeight.w600,
          color: Color(0xFF9999AA), letterSpacing: 0.5));
}

class _InfoGrid extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: items.map((item) => SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.label,
                style: const TextStyle(fontFamily: 'DM Sans', fontSize: 11,
                    color: Color(0xFF9999AA))),
            const SizedBox(height: 4),
            item.value,
          ],
        ),
      )).toList(),
    );
  }
}

class _InfoItem {
  final String label;
  final Widget value;
  const _InfoItem(this.label, this.value);
}

// ── Assign Hunt Group Dialog ──────────────────────────────────────────────────

class _AssignHuntGroupDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSuccess;
  const _AssignHuntGroupDialog({required this.user, required this.onSuccess});

  @override
  ConsumerState<_AssignHuntGroupDialog> createState() => _AssignHuntGroupDialogState();
}

class _AssignHuntGroupDialogState extends ConsumerState<_AssignHuntGroupDialog> {
  Set<String> _selectedIds = {};
  bool _loadingCurrent = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrentMemberships();
  }

  Future<void> _loadCurrentMemberships() async {
    setState(() => _loadingCurrent = true);
    try {
      final response = await Supabase.instance.client
          .from('hunt_group_members')
          .select('hunt_group_id')
          .eq('user_id', widget.user['id']);
      setState(() {
        _selectedIds = Set<String>.from(
          (response as List).map((e) => e['hunt_group_id'].toString()),
        );
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingCurrent = false);
    }
  }

  Future<void> _save(List<Map<String, dynamic>> allGroups) async {
    setState(() { _saving = true; _error = null; });
    try {
      await Supabase.instance.client
          .from('hunt_group_members')
          .delete()
          .eq('user_id', widget.user['id']);

      if (_selectedIds.isNotEmpty) {
        await Supabase.instance.client.from('hunt_group_members').insert(
          _selectedIds.map((id) => {
            'hunt_group_id': id,
            'user_id': widget.user['id'],
            'order_index': 0,
          }).toList(),
        );
      }
      if (mounted) { Navigator.pop(context); widget.onSuccess(); }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final huntGroups = ref.watch(huntGroupsProvider);

    return huntGroups.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorCard(message: e.toString()),
      data: (groups) => _DialogShell(
        title: 'Assign hunt groups',
        subtitle: widget.user['display_name'] ?? widget.user['email'] ?? '',
        confirmLabel: 'Save',
        loading: _saving,
        onConfirm: () => _save(groups),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[_ErrorBanner(message: _error!), const SizedBox(height: 16)],
            if (_loadingCurrent)
              const Center(child: CircularProgressIndicator())
            else if (groups.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No hunt groups created yet. Create a hunt group first.',
                  style: TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: Color(0xFF6B6B8A)),
                ),
              )
            else
              ...groups.map((group) {
                final id = group['id'].toString();
                return CheckboxListTile(
                  value: _selectedIds.contains(id),
                  onChanged: (checked) => setState(() {
                    checked == true ? _selectedIds.add(id) : _selectedIds.remove(id);
                  }),
                  title: Text(group['name'] ?? '',
                    style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13,
                        fontWeight: FontWeight.w500, color: Color(0xFF0D0D1A))),
                  subtitle: Text(group['strategy'] ?? '',
                    style: const TextStyle(fontFamily: 'DM Sans', fontSize: 11, color: Color(0xFF9999AA))),
                  activeColor: const Color(0xFF4F6AFF),
                  contentPadding: EdgeInsets.zero,
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ── Delete Dialog ─────────────────────────────────────────────────────────────

class _DeleteUserDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSuccess;
  const _DeleteUserDialog({required this.user, required this.onSuccess});

  @override
  ConsumerState<_DeleteUserDialog> createState() => _DeleteUserDialogState();
}

class _DeleteUserDialogState extends ConsumerState<_DeleteUserDialog> {
  bool _loading = false;
  String? _error;

  Future<void> _delete() async {
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client
          .from('users')
          .delete()
          .eq('id', widget.user['id']);
      if (mounted) { Navigator.pop(context); widget.onSuccess(); }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['display_name'] ?? widget.user['email'] ?? 'this user';
    return _DialogShell(
      title: 'Delete user',
      subtitle: 'This action cannot be undone.',
      confirmLabel: 'Delete',
      confirmDanger: true,
      loading: _loading,
      onConfirm: _delete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[_ErrorBanner(message: _error!), const SizedBox(height: 16)],
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Are you sure you want to delete $name? This will remove them from all hunt groups and unassign their number.',
                    style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: Color(0xFFDC2626)),
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

// ── Shared Dialog Shell ───────────────────────────────────────────────────────

class _DialogShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onConfirm;
  final String confirmLabel;
  final bool confirmDanger;
  final bool loading;

  const _DialogShell({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onConfirm,
    required this.confirmLabel,
    this.confirmDanger = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 460,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleLarge),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF6B6B8A)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              child,
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: loading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: loading ? null : onConfirm,
                    style: confirmDanger
                        ? ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                          )
                        : null,
                    child: loading
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared Helpers ────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelLarge);
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, size: 15, color: Color(0xFFEF4444)),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: const TextStyle(fontFamily: 'DM Sans', fontSize: 12, color: Color(0xFFDC2626)))),
      ]),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Text(message,
          style: const TextStyle(fontFamily: 'DM Sans', color: Color(0xFFDC2626))),
    );
  }
}