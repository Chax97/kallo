import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/crm_connection.dart';
import '../../../../core/providers/crm_provider.dart';

class HubSpotProviderCard extends ConsumerStatefulWidget {
  const HubSpotProviderCard({super.key});

  @override
  ConsumerState<HubSpotProviderCard> createState() =>
      _HubSpotProviderCardState();
}

class _HubSpotProviderCardState extends ConsumerState<HubSpotProviderCard> {
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  Future<void> _connect() async {
    setState(() => _isConnecting = true);
    try {
      final url = await ref.read(crmServiceProvider).startHubSpotConnection();
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!opened) throw Exception('Could not open browser');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Authorise Kallo in the new tab. This page will update automatically.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start connection: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect HubSpot?'),
        content: const Text(
          'Kallo will stop syncing calls and contacts to HubSpot. '
          'Existing CRM records will not be affected. You can reconnect at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDisconnecting = true);
    try {
      await ref.read(crmServiceProvider).disconnect('hubspot');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disconnect: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDisconnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(hubspotConnectionProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: connection.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error loading connection: $e'),
          data: _buildContent,
        ),
      ),
    );
  }

  Widget _buildContent(CrmConnection? conn) {
    final isConnected = conn?.isConnected ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.hub, color: Colors.orange),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'HubSpot',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 12),
                  _StatusChip(conn: conn),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Sync contacts, log calls, and update activity timelines in HubSpot.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (isConnected && conn != null) ...[
                const SizedBox(height: 12),
                _ConnectionDetails(conn: conn),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (isConnected)
          OutlinedButton(
            onPressed: _isDisconnecting ? null : _disconnect,
            child: _isDisconnecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Disconnect'),
          )
        else
          FilledButton(
            onPressed: _isConnecting ? null : _connect,
            child: _isConnecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Connect'),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.conn});
  final CrmConnection? conn;

  @override
  Widget build(BuildContext context) {
    if (conn == null || conn!.isDisconnected) {
      return const _Chip(label: 'Not connected', color: Colors.grey);
    }
    if (conn!.isConnected) {
      return const _Chip(label: 'Connected', color: Colors.green);
    }
    if (conn!.isExpired) {
      return const _Chip(label: 'Expired', color: Colors.orange);
    }
    if (conn!.isError) {
      return const _Chip(label: 'Error', color: Colors.red);
    }
    return _Chip(label: conn!.status, color: Colors.grey);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ConnectionDetails extends StatelessWidget {
  const _ConnectionDetails({required this.conn});
  final CrmConnection conn;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('d MMM yyyy, HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (conn.externalAccountName != null)
          _row(context, 'Account', conn.externalAccountName!),
        _row(context, 'Connected', formatter.format(conn.connectedAt.toLocal())),
        if (conn.lastSyncedAt != null)
          _row(context, 'Last sync', formatter.format(conn.lastSyncedAt!.toLocal())),
        if (conn.errorMessage != null)
          _row(context, 'Error', conn.errorMessage!, isError: true),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isError ? Colors.red : null,
              ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}