class ReferenceValue {
  final int? id;
  final String category;
  final String value;
  final int sortOrder;
  final bool active;

  const ReferenceValue({
    this.id,
    required this.category,
    required this.value,
    this.sortOrder = 100,
    this.active = true,
  });

  factory ReferenceValue.fromMap(Map<String, Object?> map) {
    return ReferenceValue(
      id: map['id'] as int?,
      category: map['category'] as String,
      value: map['value'] as String,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 100,
      active: ((map['active'] as num?)?.toInt() ?? 1) == 1,
    );
  }
}
