class LeadModel {
  final String? id;
  final String name;
  final String phone;
  final String site;
  final String status;
  final DateTime? followUpDate;
  final DateTime? createdAt;

  const LeadModel({
    this.id,
    required this.name,
    required this.phone,
    required this.site,
    required this.status,
    this.followUpDate,
    this.createdAt,
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    return LeadModel(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      site: json['site'] ?? '',
      status: json['status'] ?? 'New',
      followUpDate: json['follow_up_date'] != null
          ? DateTime.parse(json['follow_up_date'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'site': site,
      'status': status,
      'follow_up_date': followUpDate?.toIso8601String(),
    };
  }

  LeadModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? site,
    String? status,
    DateTime? followUpDate,
    DateTime? createdAt,
  }) {
    return LeadModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      site: site ?? this.site,
      status: status ?? this.status,
      followUpDate: followUpDate ?? this.followUpDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}