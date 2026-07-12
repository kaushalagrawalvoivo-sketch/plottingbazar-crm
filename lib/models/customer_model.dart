class CustomerModel {
  final String? id;
  final String name;
  final String mobile;
  final String? email;
  final String? address;
  final String? siteId;
  final bool isActive;
  final DateTime? createdAt;

  CustomerModel({
    this.id,
    required this.name,
    required this.mobile,
    this.email,
    this.address,
    this.siteId,
    this.isActive = true,
    this.createdAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      mobile: json['mobile'] ?? '',
      email: json['email'],
      address: json['address'],
      siteId: json['site_id']?.toString(),
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'name': name,
      'mobile': mobile,
      'email': email,
      'address': address,
      'site_id': siteId,
      'is_active': isActive,
    };

    if (id != null) {
      data['id'] = id;
    }

    return data;
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? mobile,
    String? email,
    String? address,
    String? siteId,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      address: address ?? this.address,
      siteId: siteId ?? this.siteId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
