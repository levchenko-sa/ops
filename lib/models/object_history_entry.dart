class ObjectHistoryEntry {
  final int requestId;
  final String type;
  final String status;
  final int priority;
  final String createdAt;
  final String? updatedAt;
  final double? batteryVoltage;
  final double? loopResistanceKohm;
  final String? cause;
  final String? workDone;
  final String? result;
  final int photoCount;
  final int archivedPhotoCount;

  const ObjectHistoryEntry({
    required this.requestId,
    required this.type,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.updatedAt,
    this.batteryVoltage,
    this.loopResistanceKohm,
    this.cause,
    this.workDone,
    this.result,
    required this.photoCount,
    required this.archivedPhotoCount,
  });

  factory ObjectHistoryEntry.fromMap(Map<String, Object?> map) {
    return ObjectHistoryEntry(
      requestId: map['request_id'] as int,
      type: map['type'] as String,
      status: map['status'] as String,
      priority: map['priority'] as int? ?? 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
      batteryVoltage: (map['battery_voltage'] as num?)?.toDouble(),
      loopResistanceKohm:
          (map['loop_resistance_kohm'] as num?)?.toDouble(),
      cause: map['cause'] as String?,
      workDone: map['work_done'] as String?,
      result: map['result'] as String?,
      photoCount: (map['photo_count'] as num?)?.toInt() ?? 0,
      archivedPhotoCount:
          (map['archived_photo_count'] as num?)?.toInt() ?? 0,
    );
  }
}
