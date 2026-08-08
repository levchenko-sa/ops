class StockBatch {
  final int? id;
  final int materialId;
  final int receiptId;
  final int receiptItemId;
  final double quantityReceived;
  final double quantityRemaining;
  final double unitPrice;
  final String receivedAt;
  final String supplierName;
  final String supplierDocument;

  const StockBatch({
    this.id,
    required this.materialId,
    required this.receiptId,
    required this.receiptItemId,
    required this.quantityReceived,
    required this.quantityRemaining,
    required this.unitPrice,
    required this.receivedAt,
    required this.supplierName,
    required this.supplierDocument,
  });

  factory StockBatch.fromMap(Map<String, Object?> map) => StockBatch(
        id: map['id'] as int?,
        materialId: map['material_id'] as int,
        receiptId: map['receipt_id'] as int,
        receiptItemId: map['receipt_item_id'] as int,
        quantityReceived: (map['quantity_received'] as num).toDouble(),
        quantityRemaining: (map['quantity_remaining'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
        receivedAt: map['received_at'] as String,
        supplierName: map['supplier_name'] as String? ?? '',
        supplierDocument: map['supplier_document'] as String? ?? '',
      );
}
