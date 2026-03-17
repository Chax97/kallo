class Voicemail {
  final String id;
  final String? callControlId;
  final String? fromNumber;
  final String? toNumber;
  final String? recordingUrl;
  final String? storagePath;
  final int? durationSeconds;
  final DateTime? createdAt;

  const Voicemail({
    required this.id,
    this.callControlId,
    this.fromNumber,
    this.toNumber,
    this.recordingUrl,
    this.storagePath,
    this.durationSeconds,
    this.createdAt,
  });

  factory Voicemail.fromJson(Map<String, dynamic> json) => Voicemail(
        id: json['id'] as String,
        callControlId: json['call_control_id'] as String?,
        fromNumber: json['from_number'] as String?,
        toNumber: json['to_number'] as String?,
        recordingUrl: json['recording_url'] as String?,
        storagePath: json['storage_path'] as String?,
        durationSeconds: json['duration_seconds'] as int?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );
}
