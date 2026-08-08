class GoodsReceiptItem {
  final int? id;
  final int receiptId;
  final int materialId;
  final String itemName;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double amount;
  final String comment;

  const GoodsReceiptItem({
    this.id,
    required this.receiptId,
    required this.materialId,
    required this.itemName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    required this.comment,
  });

  factory GoodsReceiptItem.fromMap(Map<String, Object?> map) =>
      GoodsReceiptItem(
        id: map['id'] as int?,
        receiptId: map['receipt_id'] as int,
        materialId: map['material_id'] as int,
        itemName: map['item_name'] as String,
        unit: map['unit'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
        amount: (map['amount'] as num).toDouble(),
        comment: map['comment'] as String? ?? '',
      );
}
