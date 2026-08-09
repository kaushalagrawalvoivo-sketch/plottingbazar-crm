import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/activity_log_model.dart';

/// Writes activity entries whenever a user does something meaningful
/// (calls a lead, adds feedback, gets assigned a lead, etc.) and lets the
/// admin dashboard subscribe to a live, real-time feed of everyone's work.
class ActivityService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<void> log({
    required String actionType,
    required String description,
    String? leadId,
    String? customerId,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) return;

    String actorName = user.email ?? 'User';
    try {
      final profile = await _db
          .from('profiles')
          .select('full_name, email')
          .eq('id', user.id)
          .maybeSingle();
      final fullName = (profile?['full_name'] as String?)?.trim();
      if (fullName != null && fullName.isNotEmpty) actorName = fullName;
    } catch (_) {
      // Non-critical: fall back to the email/default actor name above.
    }

    final entry = ActivityLogModel(
      actorName: actorName,
      actionType: actionType,
      leadId: leadId,
      customerId: customerId,
      description: description,
    );

    await _db.from('activity_log').insert({
      ...entry.toJson(),
      'actor_id': user.id,
    });
  }

  /// Admin-only real-time stream of the latest activity across the team.
  Stream<List<ActivityLogModel>> streamRecentActivity({int limit = 100}) {
    return _db
        .from('activity_log')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map(
          (rows) => rows
              .map((row) => ActivityLogModel.fromJson(Map<String, dynamic>.from(row)))
              .toList(),
        );
  }
}
