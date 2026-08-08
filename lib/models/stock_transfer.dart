class StockTransfer {
  final int? id;
  final String transferNumber;
  final String transferType;
  final int engineerId;
  final String engineerName;
  final String status;
  final String comment;
  final String createdAt;

  const StockTransfer({
    this.id,
    required this.transferNumber,
    required this.transferType,
    required this.engineerId,
    required this.engineerName,
    required this.status,
    required this.comment,
    required this.createdAt,
  });

  factory StockTransfer.fromMap(Map<String, Object?> map) {
    return StockTransfer(
      id: map['id'] as int?,
      transferNumber: map['transfer_number'] as String,
      transferType: map['transfer_type'] as String,
      engineerId: map['engineer_id'] as int,
      engineerName: map['engineer_name'] as String? ?? '',
      status: map['status'] as String,
      comment: map['comment'] as String? ?? '',
      createdAt: map['created_at'] as String,
    );
  }
}
