import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/crm_sync_log_entry.dart';
import '../../../../core/providers/crm_provider.dart';

class SyncLogPanel extends ConsumerWidget {
  const SyncLogPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(crmSyncLogProvider);
    return logs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text(
              'No sync activity yet',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Card(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _LogRow(entry: list[i]),
          ),
        );
      },
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});
  final CrmSyncLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('d MMM, HH:mm:ss');
    final title = entry.operation.replaceAll('_', ' ');
    return ListTile(
      dense: true,
      leading: _statusIcon(),
      title: Text(
        '$title (${entry.provider})',
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        entry.errorMessage ?? formatter.format(entry.createdAt.toLocal()),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: entry.durationMs != null
          ? Text(
              '${entry.durationMs}ms',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            )
          : null,
    );
  }

  Widget _statusIcon() {
    switch (entry.status) {
      case 'success':
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case 'error':
        return const Icon(Icons.error, color: Colors.red, size: 20);
      case 'skipped':
        return const Icon(Icons.skip_next, color: Colors.grey, size: 20);
      default:
        return const Icon(Icons.circle, size: 20);
    }
  }
}