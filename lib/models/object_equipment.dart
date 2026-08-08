class ObjectEquipment {
  final int? id;
  final int objectId;
  final String name;
  final String model;
  final String location;
  final String serialNumber;
  final String notes;
  final String createdAt;

  const ObjectEquipment({
    this.id,
    required this.objectId,
    required this.name,
    this.model = '',
    this.location = '',
    this.serialNumber = '',
    this.notes = '',
    required this.createdAt,
  });

  factory ObjectEquipment.fromMap(Map<String, Object?> map) {
    return ObjectEquipment(
      id: map['id'] as int?,
      objectId: map['object_id'] as int,
      name: map['name'] as String,
      model: map['model'] as String? ?? '',
      location: map['location'] as String? ?? '',
      serialNumber: map['serial_number'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdAt: map['created_at'] as String,
    );
  }
}
