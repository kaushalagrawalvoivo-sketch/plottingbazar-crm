class PasswordResetRequestModel {
  final String id;
  final String email;
  final String? note;
  final String status;
  final DateTime requestedAt;

  const PasswordResetRequestModel({
    required this.id,
    required this.email,
    required this.status,
    required this.requestedAt,
    this.note,
  });

  factory PasswordResetRequestModel.fromJson(Map<String, dynamic> json) =>
      PasswordResetRequestModel(
        id: json['id'].toString(),
        email: json['email'] ?? '',
        note: json['note'],
        status: json['status'] ?? 'pending',
        requestedAt: DateTime.tryParse(json['requested_at'].toString()) ??
            DateTime.now(),
      );
}
