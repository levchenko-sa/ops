class PhotoRecord {
  final int? id;
  final int requestId;
  final String type;
  final String path;
  final String createdAt;
  final int fileSizeBytes;
  final String captureMode;

  const PhotoRecord({
    this.id,
    required this.requestId,
    required this.type,
    required this.path,
    required this.createdAt,
    this.fileSizeBytes = 0,
    this.captureMode = 'lite',
  });

  factory PhotoRecord.fromMap(Map<String, Object?> map) => PhotoRecord(
        id: map['id'] as int?,
        requestId: map['request_id'] as int,
        type: map['type'] as String,
        path: map['path'] as String,
        createdAt: map['created_at'] as String,
        fileSizeBytes:
            (map['file_size_bytes'] as num?)?.toInt() ?? 0,
        captureMode: map['capture_mode'] as String? ?? 'lite',
      );
}
