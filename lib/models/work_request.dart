class WorkRequest {
  final int? id;
  final int objectId;
  final String address;
  final String type;
  final int priority;
  final String status;
  final String comment;
  final String createdAt;
  final bool isTest;
  final String source;

  const WorkRequest({
    this.id,
    required this.objectId,
    required this.address,
    required this.type,
    required this.priority,
    required this.status,
    required this.comment,
    required this.createdAt,
    this.isTest = false,
    this.source = 'manual',
  });

  factory WorkRequest.fromMap(Map<String, Object?> map) => WorkRequest(
        id: map['id'] as int?,
        objectId: map['object_id'] as int,
        address: map['address'] as String? ?? '',
        type: map['type'] as String,
        priority: map['priority'] as int? ?? 1,
        status: map['status'] as String,
        comment: map['comment'] as String? ?? '',
        createdAt: map['created_at'] as String,
        isTest: ((map['is_test'] as num?)?.toInt() ?? 0) == 1,
        source: map['source'] as String? ?? 'manual',
      );
}
