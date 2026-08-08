class RequestMaterial {
  final int? id;
  final int requestId;
  final int materialId;
  final String materialName;
  final String unit;
  final double quantity;
  final String createdAt;
  final String sourceKind;
  final int? sourceEngineerId;
  final String sourceEngineerName;

  const RequestMaterial({
    this.id,
    required this.requestId,
    required this.materialId,
    required this.materialName,
    required this.unit,
    required this.quantity,
    required this.createdAt,
    this.sourceKind = 'warehouse',
    this.sourceEngineerId,
    this.sourceEngineerName = '',
  });

  factory RequestMaterial.fromMap(Map<String, Object?> map) {
    return RequestMaterial(
      id: map['id'] as int?,
      requestId: map['request_id'] as int,
      materialId: map['material_id'] as int,
      materialName: map['material_name'] as String,
      unit: map['unit'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      createdAt: map['created_at'] as String,
      sourceKind: map['source_kind'] as String? ?? 'warehouse',
      sourceEngineerId: map['source_engineer_id'] as int?,
      sourceEngineerName:
          map['source_engineer_name'] as String? ?? '',
    );
  }
}
