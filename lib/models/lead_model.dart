class LeadModel {
  final String? id;
  final String name;
  final String phone;
  final String site;
  final String status;
  final String? assignedTo;
  final DateTime? followUpDate;
  final DateTime? createdAt;

  const LeadModel({this.id, required this.name, required this.phone, required this.site, required this.status, this.assignedTo, this.followUpDate, this.createdAt});

  factory LeadModel.fromJson(Map<String, dynamic> json) => LeadModel(
    id: json['id']?.toString(), name: json['name'] ?? '', phone: json['phone'] ?? '',
    site: json['site'] ?? '', status: json['status'] ?? 'New', assignedTo: json['assigned_to']?.toString(),
    followUpDate: json['follow_up_date'] == null ? null : DateTime.tryParse(json['follow_up_date'].toString()),
    createdAt: json['created_at'] == null ? null : DateTime.tryParse(json['created_at'].toString()),
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id, 'name': name, 'phone': phone, 'site': site, 'status': status,
    'assigned_to': assignedTo, 'follow_up_date': followUpDate?.toIso8601String(),
  };

  LeadModel copyWith({String? name, String? phone, String? site, String? status, String? assignedTo, DateTime? followUpDate}) => LeadModel(
    id: id, name: name ?? this.name, phone: phone ?? this.phone, site: site ?? this.site,
    status: status ?? this.status, assignedTo: assignedTo ?? this.assignedTo,
    followUpDate: followUpDate ?? this.followUpDate, createdAt: createdAt,
  );
}
