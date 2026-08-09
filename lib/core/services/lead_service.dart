import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lead_model.dart';
import '../constants/roles.dart';

class LeadService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<List<LeadModel>> getLeads() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];
    final profile = await _db
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    var query = _db.from('leads').select();
    // RLS is the security boundary; this extra filter keeps the UI
    // deliberately scoped. Managers see everything too, matching
    // AppRoles.canManage's contract everywhere else in the app.
    if (!AppRoles.canManage(profile?['role']?.toString())) {
      query = query.eq('assigned_to', userId);
    }
    final response = await query.order('created_at', ascending: false);
    return (response as List)
        .map((row) => LeadModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> addLead(LeadModel lead) =>
      _db.from('leads').insert(lead.toJson());

  Future<LeadModel?> getLeadById(String id) async {
    final row = await _db.from('leads').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return LeadModel.fromJson(Map<String, dynamic>.from(row));
  }

  /// Checks (via a security-definer RPC so RLS doesn't hide leads owned by
  /// other employees) whether a phone number is already a lead somewhere in
  /// the system, so the UI can warn before creating a duplicate -- the most
  /// common way two employees end up calling the same person.
  Future<Map<String, dynamic>?> checkDuplicatePhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return null;
    final rows = await _db.rpc(
      'check_lead_phone_exists',
      params: {'p_phone': digits},
    );
    final list = rows as List;
    if (list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first);
  }

  Future<void> importLeads(List<LeadModel> leads) async {
    if (leads.isEmpty) return;
    await _db.from('leads').insert(leads.map((lead) => lead.toJson()).toList());
  }

  Future<void> updateLead(LeadModel lead) =>
      _db.from('leads').update(lead.toJson()).eq('id', lead.id!);
  Future<void> assignLeads(List<String> leadIds, String userId) async {
    if (leadIds.isEmpty) return;
    await _db
        .from('leads')
        .update({'assigned_to': userId})
        .inFilter('id', leadIds);
  }

  Future<void> deleteLead(String id) => _db.from('leads').delete().eq('id', id);
}
