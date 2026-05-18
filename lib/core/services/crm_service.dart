import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/crm_connection.dart';
import '../models/crm_sync_log_entry.dart';

class CrmService {
  CrmService(this._supabase);
  final SupabaseClient _supabase;

  /// Realtime stream of CRM connections for a company.
  Stream<List<CrmConnection>> connectionsStream(String companyId) {
    return _supabase
        .from('crm_connections')
        .stream(primaryKey: ['id'])
        .eq('company_id', companyId)
        .order('created_at')
        .map((data) => data.map(CrmConnection.fromJson).toList());
  }

  /// Realtime stream of recent sync log entries.
  Stream<List<CrmSyncLogEntry>> syncLogStream(String companyId, {int limit = 30}) {
    return _supabase
        .from('crm_sync_log')
        .stream(primaryKey: ['id'])
        .eq('company_id', companyId)
        .order('created_at', ascending: false)
        .limit(limit)
        .map((data) => data.map(CrmSyncLogEntry.fromJson).toList());
  }

  /// Start the HubSpot OAuth flow. Returns the URL to open.
  Future<String> startHubSpotConnection() async {
    final response = await _supabase.functions.invoke(
      'hubspot-oauth-initiate',
      method: HttpMethod.post,
    );
    if (response.status != 200) {
      throw Exception('Failed to start HubSpot connection: ${response.data}');
    }
    final data = response.data as Map<String, dynamic>;
    return data['url'] as String;
  }

  /// Disconnect a CRM provider.
  Future<void> disconnect(String provider) async {
    final response = await _supabase.functions.invoke(
      'hubspot-disconnect',
      method: HttpMethod.post,
      body: {'provider': provider},
    );
    if (response.status != 200) {
      throw Exception('Failed to disconnect: ${response.data}');
    }
  }
}