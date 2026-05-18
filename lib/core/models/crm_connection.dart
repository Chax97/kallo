import 'package:flutter/foundation.dart';

@immutable
class CrmConnection {
  const CrmConnection({
    required this.id,
    required this.companyId,
    required this.provider,
    required this.status,
    this.tokenExpiresAt,
    this.scopes = const [],
    this.externalAccountId,
    this.externalAccountName,
    this.errorMessage,
    this.connectedBy,
    required this.connectedAt,
    this.lastRefreshedAt,
    this.lastSyncedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String provider;
  final String status;
  final DateTime? tokenExpiresAt;
  final List<String> scopes;
  final String? externalAccountId;
  final String? externalAccountName;
  final String? errorMessage;
  final String? connectedBy;
  final DateTime connectedAt;
  final DateTime? lastRefreshedAt;
  final DateTime? lastSyncedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isConnected => status == 'connected';
  bool get isError => status == 'error';
  bool get isExpired => status == 'expired';
  bool get isDisconnected => status == 'disconnected';

  factory CrmConnection.fromJson(Map<String, dynamic> json) {
    return CrmConnection(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      provider: json['provider'] as String,
      status: json['status'] as String,
      tokenExpiresAt: _parseDate(json['token_expires_at']),
      scopes: (json['scopes'] as List?)?.cast<String>() ?? const [],
      externalAccountId: json['external_account_id'] as String?,
      externalAccountName: json['external_account_name'] as String?,
      errorMessage: json['error_message'] as String?,
      connectedBy: json['connected_by'] as String?,
      connectedAt: _parseDate(json['connected_at'])!,
      lastRefreshedAt: _parseDate(json['last_refreshed_at']),
      lastSyncedAt: _parseDate(json['last_synced_at']),
      createdAt: _parseDate(json['created_at'])!,
      updatedAt: _parseDate(json['updated_at'])!,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.parse(value as String);
  }
}