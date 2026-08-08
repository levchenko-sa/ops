class EngineerStockItem {
  final int engineerId;
  final int materialId;
  final String materialName;
  final String unit;
  final double quantity;
  final double warehouseQuantity;

  const EngineerStockItem({
    required this.engineerId,
    required this.materialId,
    required this.materialName,
    required this.unit,
    required this.quantity,
    required this.warehouseQuantity,
  });

  factory EngineerStockItem.fromMap(Map<String, Object?> map) {
    return EngineerStockItem(
      engineerId: map['engineer_id'] as int,
      materialId: map['material_id'] as int,
      materialName: map['material_name'] as String,
      unit: map['unit'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      warehouseQuantity:
          (map['warehouse_quantity'] as num?)?.toDouble() ?? 0,
    );
  }
}
