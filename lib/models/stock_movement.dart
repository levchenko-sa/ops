class StockMovement {
  final int? id;
  final int materialId;
  final int? requestId;
  final int? receiptId;
  final int? engineerId;
  final double? engineerBalanceAfter;
  final String engineerName;
  final String movementType;
  final double quantity;
  final double balanceAfter;
  final String comment;
  final String createdAt;

  const StockMovement({
    this.id,
    required this.materialId,
    this.requestId,
    this.receiptId,
    this.engineerId,
    this.engineerBalanceAfter,
    this.engineerName = '',
    required this.movementType,
    required this.quantity,
    required this.balanceAfter,
    required this.comment,
    required this.createdAt,
  });

  factory StockMovement.fromMap(Map<String, Object?> map) {
    return StockMovement(
      id: map['id'] as int?,
      materialId: map['material_id'] as int,
      requestId: map['request_id'] as int?,
      receiptId: map['receipt_id'] as int?,
      engineerId: map['engineer_id'] as int?,
      engineerBalanceAfter:
          (map['engineer_balance_after'] as num?)?.toDouble(),
      engineerName: map['engineer_name'] as String? ?? '',
      movementType: map['movement_type'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      balanceAfter: (map['balance_after'] as num).toDouble(),
      comment: map['comment'] as String? ?? '',
      createdAt: map['created_at'] as String,
    );
  }
}
