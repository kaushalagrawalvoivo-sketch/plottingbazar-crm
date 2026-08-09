class CallLogModel {
  final String? id;
  final String leadId;
  final String? calledBy;
  final String outcome;
  final int? durationSeconds;
  final String? notes;
  final DateTime? createdAt;

  const CallLogModel({
    this.id,
    required this.leadId,
    this.calledBy,
    this.outcome = 'Connected',
    this.durationSeconds,
    this.notes,
    this.createdAt,
  });

  factory CallLogModel.fromJson(Map<String, dynamic> json) => CallLogModel(
    id: json['id']?.toString(),
    leadId: json['lead_id']?.toString() ?? '',
    calledBy: json['called_by']?.toString(),
    outcome: json['outcome'] ?? 'Connected',
    durationSeconds: json['duration_seconds'] == null
        ? null
        : int.tryParse(json['duration_seconds'].toString()),
    notes: json['notes'],
    createdAt: json['created_at'] == null
        ? null
        : DateTime.tryParse(json['created_at'].toString()),
  );

  Map<String, dynamic> toJson() => {
    'lead_id': leadId,
    'outcome': outcome,
    if (durationSeconds != null) 'duration_seconds': durationSeconds,
    if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
  };

  static const List<String> outcomes = [
    'Connected',
    'Not Answered',
    'Busy',
    'Switched Off',
    'Invalid Number',
    'Call Back Later',
  ];
}
