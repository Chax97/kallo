import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/crm_connection.dart';
import '../models/crm_sync_log_entry.dart';
import '../services/crm_service.dart';

final crmServiceProvider = Provider<CrmService>((ref) {
  return CrmService(Supabase.instance.client);
});

/// Current user's company id. Cached so we don't re query.
final currentCompanyIdProvider = FutureProvider<String?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  final row = await Supabase.instance.client
      .from('users')
      .select('company_id')
      .eq('id', user.id)
      .single();
  return row['company_id'] as String?;
});

/// Realtime stream of all CRM connections for the current company.
final crmConnectionsProvider =
    StreamProvider<List<CrmConnection>>((ref) async* {
  final companyId = await ref.watch(currentCompanyIdProvider.future);
  if (companyId == null) {
    yield const [];
    return;
  }
  yield* ref.watch(crmServiceProvider).connectionsStream(companyId);
});

/// HubSpot connection in particular, or null if none exists.
final hubspotConnectionProvider = Provider<AsyncValue<CrmConnection?>>((ref) {
  final connections = ref.watch(crmConnectionsProvider);
  return connections.whenData((list) {
    final hubspot = list.where((c) => c.provider == 'hubspot');
    return hubspot.isEmpty ? null : hubspot.first;
  });
});

/// Realtime stream of recent sync log entries.
final crmSyncLogProvider =
    StreamProvider<List<CrmSyncLogEntry>>((ref) async* {
  final companyId = await ref.watch(currentCompanyIdProvider.future);
  if (companyId == null) {
    yield const [];
    return;
  }
  yield* ref.watch(crmServiceProvider).syncLogStream(companyId);
});