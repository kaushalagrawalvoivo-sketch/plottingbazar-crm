import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/call_log_model.dart';

class CallLogService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<List<CallLogModel>> getCallLogs(String leadId) async {
    final rows = await _db
        .from('call_logs')
        .select()
        .eq('lead_id', leadId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => CallLogModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> addCallLog(CallLogModel log) async {
    final userId = _db.auth.currentUser?.id;
    await _db.from('call_logs').insert({
      ...log.toJson(),
      if (userId != null) 'called_by': userId,
    });
  }
}
