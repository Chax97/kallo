import 'package:flutter/material.dart';

enum CallType { outbound, inbound, missed, conference }

class CallRecord {
  final String name;
  final String number;
  final CallType type;
  final DateTime timestamp;
  final Duration? duration;
  final int count;
  final String initials;
  final Color avatarColor;

  const CallRecord({
    required this.name,
    required this.number,
    required this.type,
    required this.timestamp,
    this.duration,
    this.count = 1,
    required this.initials,
    required this.avatarColor,
  });
}
