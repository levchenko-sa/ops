class OpsObject {
  final int? id;
  final String address;
  final String system;
  final String connection;
  final String status;
  final String notes;
  final int? entrances;
  final double? latitude;
  final double? longitude;

  const OpsObject({
    this.id,
    required this.address,
    required this.system,
    this.connection = 'SIM',
    this.status = 'Норма',
    this.notes = '',
    this.entrances,
    this.latitude,
    this.longitude,
  });

  factory OpsObject.fromMap(Map<String, Object?> map) => OpsObject(
        id: map['id'] as int?,
        address: map['address'] as String,
        system: map['system'] as String? ?? '',
        connection: map['connection'] as String? ?? 'SIM',
        status: map['status'] as String? ?? 'Норма',
        notes: map['notes'] as String? ?? '',
        entrances: (map['entrances'] as num?)?.toInt(),
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
      );

  OpsObject copyWith({
    String? address,
    String? system,
    String? connection,
    String? status,
    String? notes,
    int? entrances,
    double? latitude,
    double? longitude,
  }) {
    return OpsObject(
      id: id,
      address: address ?? this.address,
      system: system ?? this.system,
      connection: connection ?? this.connection,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      entrances: entrances ?? this.entrances,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
