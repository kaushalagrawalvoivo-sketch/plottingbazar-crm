import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lead_model.dart';
import '../constants/roles.dart';

class LeadService {
  final SupabaseClient _db = Supabase.instance.client;

  /// Supabase/PostgREST caps any single `.select()` response at 1000 rows
  /// (the project's default `max_rows` setting) no matter how many rows
  /// actually match -- so once there were more than 1000 leads, the list,
  /// dashboard counts, exports, etc. would all silently stop at 1000 with
  /// no error. This fetches in pages of 1000 using `.range()` and keeps
  /// going until a page comes back with fewer than the page size, so every
  /// lead is returned regardless of how many there are.
  static const int _pageSize = 1000;

  Future<List<LeadModel>> getLeads() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];
    final profile = await _db
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    // RLS is the security boundary; this extra filter keeps the UI
    // deliberately scoped. Managers see everything too, matching
    // AppRoles.canManage's contract everywhere else in the app.
    final scoped = !AppRoles.canManage(profile?['role']?.toString());

    final all = <LeadModel>[];
    var from = 0;
    while (true) {
      var query = _db.from('leads').select();
      if (scoped) {
        query = query.eq('assigned_to', userId);
      }
      final response = await query
          .order('created_at', ascending: false)
          .range(from, from + _pageSize - 1);
      final page = (response as List)
          .map((row) => LeadModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      all.addAll(page);
      if (page.length < _pageSize) break;
      from += _pageSize;
    }
    return all;
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
