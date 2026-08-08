class Engineer {
  final int? id;
  final String name;
  final String vehicle;
  final bool active;
  final String createdAt;

  const Engineer({
    this.id,
    required this.name,
    this.vehicle = '',
    this.active = true,
    required this.createdAt,
  });

  factory Engineer.fromMap(Map<String, Object?> map) => Engineer(
        id: map['id'] as int?,
        name: map['name'] as String,
        vehicle: map['vehicle'] as String? ?? '',
        active: ((map['active'] as num?)?.toInt() ?? 1) == 1,
        createdAt: map['created_at'] as String,
      );
}
