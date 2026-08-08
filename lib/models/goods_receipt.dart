class GoodsReceipt {
  final int? id;
  final String receiptNumber;
  final String receiptDate;
  final String status;
  final int? purchaseDocumentId;
  final String supplierName;
  final String supplierInn;
  final String supplierDocumentType;
  final String supplierDocumentNumber;
  final String supplierDocumentDate;
  final String notes;
  final double totalAmount;
  final String createdAt;

  const GoodsReceipt({
    this.id,
    required this.receiptNumber,
    required this.receiptDate,
    required this.status,
    this.purchaseDocumentId,
    required this.supplierName,
    required this.supplierInn,
    required this.supplierDocumentType,
    required this.supplierDocumentNumber,
    required this.supplierDocumentDate,
    required this.notes,
    required this.totalAmount,
    required this.createdAt,
  });

  factory GoodsReceipt.fromMap(Map<String, Object?> map) => GoodsReceipt(
        id: map['id'] as int?,
        receiptNumber: map['receipt_number'] as String,
        receiptDate: map['receipt_date'] as String,
        status: map['status'] as String,
        purchaseDocumentId: map['purchase_document_id'] as int?,
        supplierName: map['supplier_name'] as String? ?? '',
        supplierInn: map['supplier_inn'] as String? ?? '',
        supplierDocumentType:
            map['supplier_document_type'] as String? ?? 'УПД',
        supplierDocumentNumber:
            map['supplier_document_number'] as String? ?? '',
        supplierDocumentDate:
            map['supplier_document_date'] as String? ?? '',
        notes: map['notes'] as String? ?? '',
        totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
        createdAt: map['created_at'] as String,
      );
}
