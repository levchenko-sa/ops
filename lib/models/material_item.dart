class MaterialItem {
  final int? id;
  final String name;
  final String unit;
  final double quantity;
  final double minQuantity;
  final double accountingPrice;

  const MaterialItem({
    this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.minQuantity,
    this.accountingPrice = 0,
  });

  bool get lowStock => quantity <= minQuantity;

  factory MaterialItem.fromMap(Map<String, Object?> map) => MaterialItem(
        id: map['id'] as int?,
        name: map['name'] as String,
        unit: map['unit'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        minQuantity: (map['min_quantity'] as num).toDouble(),
        accountingPrice:
            (map['accounting_price'] as num?)?.toDouble() ?? 0,
      );
}
