import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lead_model.dart';

class LeadService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<List<LeadModel>> getLeads() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];
    final profile = await _db.from('profiles').select('role').eq('id', userId).maybeSingle();
    var query = _db.from('leads').select();
    // RLS is the security boundary; this extra filter keeps the UI deliberately scoped.
    if (profile?['role'] != 'admin') query = query.eq('assigned_to', userId);
    final response = await query.order('created_at', ascending: false);
    return (response as List).map((row) => LeadModel.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<void> addLead(LeadModel lead) => _db.from('leads').insert(lead.toJson());
  Future<void> importLeads(List<LeadModel> leads) async {
    if (leads.isEmpty) return;
    await _db.from('leads').insert(leads.map((lead) => lead.toJson()).toList());
  }
  Future<void> updateLead(LeadModel lead) => _db.from('leads').update(lead.toJson()).eq('id', lead.id!);
  Future<void> deleteLead(String id) => _db.from('leads').delete().eq('id', id);
}
