class LeadFeedbackModel {
  final String? id;
  final String leadId;
  final String? createdBy;
  final String feedback;
  final DateTime? nextFollowUpDate;
  final DateTime? createdAt;

  const LeadFeedbackModel({
    this.id,
    required this.leadId,
    this.createdBy,
    required this.feedback,
    this.nextFollowUpDate,
    this.createdAt,
  });

  factory LeadFeedbackModel.fromJson(Map<String, dynamic> json) =>
      LeadFeedbackModel(
        id: json['id']?.toString(),
        leadId: json['lead_id']?.toString() ?? '',
        createdBy: json['created_by']?.toString(),
        feedback: json['feedback'] ?? '',
        nextFollowUpDate: json['next_follow_up_date'] == null
            ? null
            : DateTime.tryParse(json['next_follow_up_date'].toString()),
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'].toString()),
      );

  Map<String, dynamic> toJson() => {
    'lead_id': leadId,
    'feedback': feedback,
    if (nextFollowUpDate != null)
      'next_follow_up_date': nextFollowUpDate!.toIso8601String(),
  };
}
