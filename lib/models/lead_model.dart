class LeadModel {
  final String? id;
  final String name;
  final String phone;
  final String site;
  final String status;
  final String? assignedTo;
  final String? source;
  final String? purpose;
  final double? budget;
  final DateTime? followUpDate;
  final DateTime? createdAt;

  const LeadModel({
    this.id,
    required this.name,
    required this.phone,
    required this.site,
    required this.status,
    this.assignedTo,
    this.source,
    this.purpose,
    this.budget,
    this.followUpDate,
    this.createdAt,
  });

  bool get isFollowUpOverdue =>
      followUpDate != null &&
      followUpDate!.isBefore(DateTime.now()) &&
      status != 'Booked' &&
      status != 'Lost';

  factory LeadModel.fromJson(Map<String, dynamic> json) => LeadModel(
    id: json['id']?.toString(),
    name: json['name'] ?? '',
    phone: json['phone'] ?? '',
    site: json['site'] ?? '',
    status: json['status'] ?? 'New',
    assignedTo: json['assigned_to']?.toString(),
    source: json['source'],
    purpose: json['purpose'],
    budget: json['budget'] == null
        ? null
        : double.tryParse(json['budget'].toString()),
    followUpDate: json['follow_up_date'] == null
        ? null
        : DateTime.tryParse(json['follow_up_date'].toString()),
    createdAt: json['created_at'] == null
        ? null
        : DateTime.tryParse(json['created_at'].toString()),
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'phone': phone,
    'site': site,
    'status': status,
    'assigned_to': assignedTo,
    'source': source,
    'purpose': purpose,
    'budget': budget,
    'follow_up_date': followUpDate?.toIso8601String(),
  };

  LeadModel copyWith({
    String? name,
    String? phone,
    String? site,
    String? status,
    String? assignedTo,
    String? source,
    String? purpose,
    double? budget,
    DateTime? followUpDate,
  }) => LeadModel(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    site: site ?? this.site,
    status: status ?? this.status,
    assignedTo: assignedTo ?? this.assignedTo,
    source: source ?? this.source,
    purpose: purpose ?? this.purpose,
    budget: budget ?? this.budget,
    followUpDate: followUpDate ?? this.followUpDate,
    createdAt: createdAt,
  );

  static const List<String> sources = [
    'Facebook',
    'Instagram',
    'Google Ads',
    'Referral',
    'Walk-in',
    'Website',
    'Newspaper',
    'Other',
  ];

  static const List<String> purposes = [
    'Investment',
    'Self Use',
    'Resale',
    'Commercial',
    'Agricultural',
    'Other',
  ];
}
