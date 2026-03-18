import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final usersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('users')
      .select('''
        id, display_name, email, role, extension, status, created_at,
        phone_numbers(id, number, label)
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

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UsersHeader(onInvite: () => _showInviteDialog(context, ref)),
          const SizedBox(height: 20),
          Expanded(
            child: users.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorCard(message: e.toString()),
              data: (data) => _UsersTable(users: data),
            ),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
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
            Text('Users & Agents', style: Theme.of(context).textTheme.displayLarge),
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
  const _UsersTable({required this.users});

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
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) => _UserRow(
                user: users[index],
                onRefresh: () => ref.invalidate(usersProvider),
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
          _HeaderCell('User', flex: 3),
          _HeaderCell('Extension', flex: 2),
          _HeaderCell('Phone number', flex: 3),
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
  const _UserRow({required this.user, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user['display_name'] ?? user['email'] ?? 'Unknown';
    final email = user['email'] ?? '';
    final role = user['role'] ?? 'agent';
    final extension = user['extension'];
    final status = user['status'] ?? 'active';
    final phoneNumbers = user['phone_numbers'];

    String phoneDisplay = '-';
    if (phoneNumbers is List && phoneNumbers.isNotEmpty) {
      final pn = phoneNumbers.first as Map;
      phoneDisplay = pn['label'] ?? pn['number'] ?? '-';
    } else if (phoneNumbers is Map) {
      phoneDisplay = phoneNumbers['label'] ?? phoneNumbers['number'] ?? '-';
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
          // Extension cell
          Expanded(
            flex: 2,
            child: extension != null
                ? SizedBox(
                    width: 60,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(extension,
                        style: const TextStyle(
                          fontFamily: 'DM Sans', fontSize: 13,
                          fontWeight: FontWeight.w500, color: Color(0xFF3D3D5C),
                        ),
                      ),
                    ),
                  )
                : const Text('-',
                    style: TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: Color(0xFF9999AA))),
          ),
          // Phone number cell
          Expanded(
            flex: 3,
            child: Text(phoneDisplay,
              style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: Color(0xFF3D3D5C)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Status cell
          Expanded(flex: 2, child: _StatusBadge(status: status)),
          // Actions cell
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  offset: const Offset(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE8E8F0)),
                  ),
                  elevation: 4,
                  icon: const Icon(Icons.more_horiz, size: 18, color: Color(0xFF6B6B8A)),
                  onSelected: (value) => _handleAction(context, ref, value, status),
                  itemBuilder: (context) => [
                    _popupItem(context, 'edit', Icons.edit_outlined, 'Edit details'),
                    _popupItem(context, 'hunt_group', Icons.group_work_outlined, 'Assign hunt group'),
                    _popupItem(
                      context,
                      status == 'active' ? 'deactivate' : 'activate',
                      status == 'active' ? Icons.pause_circle_outline : Icons.play_circle_outline,
                      status == 'active' ? 'Deactivate' : 'Activate',
                    ),
                    const PopupMenuDivider(),
                    _popupItem(context, 'delete', Icons.delete_outline, 'Delete user',
                        color: const Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _popupItem(
    BuildContext context, String value, IconData icon, String label,
    {Color color = const Color(0xFF3D3D5C)}) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: color)),
      ]),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action, String status) {
    switch (action) {
      case 'edit':
        showDialog(context: context,
            builder: (_) => _EditUserDialog(user: user, onSuccess: onRefresh));
        break;
      case 'hunt_group':
        showDialog(context: context,
            builder: (_) => _AssignHuntGroupDialog(user: user, onSuccess: onRefresh));
        break;
      case 'deactivate':
      case 'activate':
        _toggleStatus(context, action == 'activate');
        break;
      case 'delete':
        showDialog(context: context,
            builder: (_) => _DeleteUserDialog(user: user, onSuccess: onRefresh));
        break;
    }
  }

  Future<void> _toggleStatus(BuildContext context, bool activate) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'status': activate ? 'active' : 'inactive'})
          .eq('id', user['id']);
      onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
                    value: _role,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'agent', child: Text('Agent')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
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

// ── Edit Dialog ───────────────────────────────────────────────────────────────

class _EditUserDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSuccess;
  const _EditUserDialog({required this.user, required this.onSuccess});

  @override
  ConsumerState<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<_EditUserDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _extensionController;
  late String _role;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['display_name'] ?? '');
    _extensionController = TextEditingController(text: widget.user['extension'] ?? '');
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
      if (mounted) { Navigator.pop(context); widget.onSuccess(); }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: 'Edit user',
      subtitle: widget.user['email'] ?? '',
      confirmLabel: 'Save changes',
      loading: _loading,
      onConfirm: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[_ErrorBanner(message: _error!), const SizedBox(height: 16)],
          _FieldLabel('Display name'),
          const SizedBox(height: 6),
          TextField(controller: _nameController,
              decoration: const InputDecoration(hintText: 'Full name')),
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
                    value: _role,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'agent', child: Text('Agent')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
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