class CallLog {
  final String id;
  final String? callControlId; // DB column: telnyx_call_id
  final String? direction;
  final String? fromNumber;
  final String? toNumber;
  final String? state; // reads from status (or legacy state)
  final DateTime? startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final String? hangupCause;
  final int? durationSeconds;
  final String? recordingUrl;
  final String? storagePath;

  const CallLog({
    required this.id,
    this.callControlId,
    this.direction,
    this.fromNumber,
    this.toNumber,
    this.state,
    this.startedAt,
    this.answeredAt,
    this.endedAt,
    this.hangupCause,
    this.durationSeconds,
    this.recordingUrl,
    this.storagePath,
  });

  factory CallLog.fromJson(Map<String, dynamic> json) => CallLog(
        id: json['id'] as String,
        // telnyx_call_id is the new column name; fall back to old call_control_id
        callControlId:
            (json['telnyx_call_id'] ?? json['call_control_id']) as String?,
        direction: json['direction'] as String?,
        fromNumber: json['from_number'] as String?,
        toNumber: json['to_number'] as String?,
        // status is the new column name; fall back to old state
        state: (json['status'] ?? json['state']) as String?,
        startedAt: json['started_at'] != null
            ? DateTime.parse(json['started_at'] as String)
            : null,
        answeredAt: json['answered_at'] != null
            ? DateTime.parse(json['answered_at'] as String)
            : null,
        endedAt: json['ended_at'] != null
            ? DateTime.parse(json['ended_at'] as String)
            : null,
        hangupCause: json['hangup_cause'] as String?,
        durationSeconds: json['duration_seconds'] as int?,
        recordingUrl: json['recording_url'] as String?,
        storagePath: json['storage_path'] as String?,
      );

  /// The "other party" number to show in the UI.
  String get displayNumber {
    if (direction == 'incoming') return fromNumber ?? 'Unknown';
    return toNumber ?? 'Unknown';
  }
}
