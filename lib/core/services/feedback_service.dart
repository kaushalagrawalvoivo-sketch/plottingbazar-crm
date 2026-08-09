import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/lead_feedback_model.dart';

class FeedbackService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<List<LeadFeedbackModel>> getFeedback(String leadId) async {
    final rows = await _db
        .from('lead_feedback')
        .select()
        .eq('lead_id', leadId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) => LeadFeedbackModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<void> addFeedback(LeadFeedbackModel feedback) async {
    final userId = _db.auth.currentUser?.id;
    await _db.from('lead_feedback').insert({
      ...feedback.toJson(),
      if (userId != null) 'created_by': userId,
    });
  }
}
