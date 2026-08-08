class InventoryDocument {
  final int? id;
  final String documentType;
  final String documentNumber;
  final String documentDate;
  final String status;
  final String title;
  final String organizationName;
  final String organizationInn;
  final String organizationKpp;
  final String contentDescription;
  final String basis;
  final int? sourceRequestId;
  final String creatorPosition;
  final String creatorName;
  final String accountantPosition;
  final String accountantName;
  final String approverPosition;
  final String approverName;
  final String responsiblePosition;
  final String responsibleName;
  final String formsApprovalOrderNo;
  final String formsApprovalOrderDate;
  final String procurementRegime;
  final String pdfPath;
  final String createdAt;

  const InventoryDocument({
    this.id,
    required this.documentType,
    required this.documentNumber,
    required this.documentDate,
    required this.status,
    required this.title,
    required this.organizationName,
    required this.organizationInn,
    required this.organizationKpp,
    required this.contentDescription,
    required this.basis,
    this.sourceRequestId,
    required this.creatorPosition,
    required this.creatorName,
    required this.accountantPosition,
    required this.accountantName,
    required this.approverPosition,
    required this.approverName,
    required this.responsiblePosition,
    required this.responsibleName,
    required this.formsApprovalOrderNo,
    required this.formsApprovalOrderDate,
    required this.procurementRegime,
    required this.pdfPath,
    required this.createdAt,
  });

  factory InventoryDocument.fromMap(Map<String, Object?> map) {
    return InventoryDocument(
      id: map['id'] as int?,
      documentType: map['document_type'] as String,
      documentNumber: map['document_number'] as String,
      documentDate: map['document_date'] as String,
      status: map['status'] as String,
      title: map['title'] as String,
      organizationName: map['organization_name'] as String,
      organizationInn: map['organization_inn'] as String? ?? '',
      organizationKpp: map['organization_kpp'] as String? ?? '',
      contentDescription:
          map['content_description'] as String? ?? '',
      basis: map['basis'] as String? ?? '',
      sourceRequestId: map['source_request_id'] as int?,
      creatorPosition: map['creator_position'] as String? ?? '',
      creatorName: map['creator_name'] as String? ?? '',
      accountantPosition: map['accountant_position'] as String? ?? '',
      accountantName: map['accountant_name'] as String? ?? '',
      approverPosition: map['approver_position'] as String? ?? '',
      approverName: map['approver_name'] as String? ?? '',
      responsiblePosition:
          map['responsible_position'] as String? ?? '',
      responsibleName: map['responsible_name'] as String? ?? '',
      formsApprovalOrderNo:
          map['forms_approval_order_no'] as String? ?? '',
      formsApprovalOrderDate:
          map['forms_approval_order_date'] as String? ?? '',
      procurementRegime:
          map['procurement_regime'] as String? ?? 'commercial',
      pdfPath: map['pdf_path'] as String? ?? '',
      createdAt: map['created_at'] as String,
    );
  }
}
