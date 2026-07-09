class SiteModel {
  final String? id;
  final String name;
  final String location;
  final double pricePerSqft;
  final String description;
  final bool isActive;
  final DateTime? createdAt;

  const SiteModel({
    this.id,
    required this.name,
    required this.location,
    required this.pricePerSqft,
    required this.description,
    this.isActive = true,
    this.createdAt,
  });

  factory SiteModel.fromJson(Map<String, dynamic> json) {
    return SiteModel(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      location: json['location'] ?? '',
      pricePerSqft: (json['price_per_sqft'] as num?)?.toDouble() ?? 0,
      description: json['description'] ?? '',
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'location': location,
      'price_per_sqft': pricePerSqft,
      'description': description,
      'is_active': isActive,
    };
  }

  SiteModel copyWith({
    String? id,
    String? name,
    String? location,
    double? pricePerSqft,
    String? description,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SiteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      pricePerSqft: pricePerSqft ?? this.pricePerSqft,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}