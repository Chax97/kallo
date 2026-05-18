import 'package:flutter/foundation.dart';

@immutable
class CrmSyncLogEntry {
  const CrmSyncLogEntry({
    required this.id,
    required this.companyId,
    this.connectionId,
    required this.provider,
    required this.operation,
    this.kalloObjectType,
    this.kalloObjectId,
    this.externalObjectId,
    required this.status,
    this.errorMessage,
    this.httpStatus,
    this.durationMs,
    required this.createdAt,
  });

  final int id;
  final String companyId;
  final String? connectionId;
  final String provider;
  final String operation;
  final String? kalloObjectType;
  final String? kalloObjectId;
  final String? externalObjectId;
  final String status;
  final String? errorMessage;
  final int? httpStatus;
  final int? durationMs;
  final DateTime createdAt;

  factory CrmSyncLogEntry.fromJson(Map<String, dynamic> json) {
    return CrmSyncLogEntry(
      id: json['id'] as int,
      companyId: json['company_id'] as String,
      connectionId: json['connection_id'] as String?,
      provider: json['provider'] as String,
      operation: json['operation'] as String,
      kalloObjectType: json['kallo_object_type'] as String?,
      kalloObjectId: json['kallo_object_id'] as String?,
      externalObjectId: json['external_object_id'] as String?,
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
      httpStatus: json['http_status'] as int?,
      durationMs: json['duration_ms'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}