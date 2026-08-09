class ActivityLogModel {
  final String? id;
  final String? actorId;
  final String actorName;
  final String actionType;
  final String? leadId;
  final String? customerId;
  final String description;
  final DateTime? createdAt;

  const ActivityLogModel({
    this.id,
    this.actorId,
    required this.actorName,
    required this.actionType,
    this.leadId,
    this.customerId,
    required this.description,
    this.createdAt,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json) =>
      ActivityLogModel(
        id: json['id']?.toString(),
        actorId: json['actor_id']?.toString(),
        actorName: json['actor_name'] ?? 'Unknown',
        actionType: json['action_type'] ?? 'activity',
        leadId: json['lead_id']?.toString(),
        customerId: json['customer_id']?.toString(),
        description: json['description'] ?? '',
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'].toString()),
      );

  Map<String, dynamic> toJson() => {
    'actor_name': actorName,
    'action_type': actionType,
    if (leadId != null) 'lead_id': leadId,
    if (customerId != null) 'customer_id': customerId,
    'description': description,
  };

  /// Action type constants used across the app so every screen stays in sync.
  static const String callLogged = 'call_logged';
  static const String feedbackAdded = 'feedback_added';
  static const String leadAssigned = 'lead_assigned';
  static const String leadCreated = 'lead_created';
  static const String leadStatusChanged = 'lead_status_changed';
  static const String customerCreated = 'customer_created';
  static const String whatsappSent = 'whatsapp_sent';
}
