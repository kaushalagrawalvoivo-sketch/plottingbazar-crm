import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/lead_model.dart';

class LeadService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<List<LeadModel>> getLeads() async {
    try {
      final response = await _db
          .from('leads')
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((e) => LeadModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint("GET ERROR: $e");
      rethrow;
    }
  }

  Future<void> addLead(LeadModel lead) async {
    try {
      await _db.from('leads').insert(lead.toJson());

      debugPrint("Lead Added Successfully");
    } catch (e) {
      debugPrint("ADD ERROR: $e");
      rethrow;
    }
  }

  Future<void> updateLead(LeadModel lead) async {
    try {
      debugPrint("========== UPDATE ==========");
      debugPrint("Lead ID : ${lead.id}");
      debugPrint("Lead Data : ${lead.toJson()}");

      final response = await _db
          .from('leads')
          .update(lead.toJson())
          .eq('id', lead.id!)
          .select();

      debugPrint("UPDATE RESPONSE : $response");
      debugPrint("Lead Updated Successfully");
    } catch (e) {
      debugPrint("UPDATE ERROR : $e");
      rethrow;
    }
  }

  Future<void> deleteLead(String id) async {
    try {
      await _db.from('leads').delete().eq('id', id);

      debugPrint("Lead Deleted Successfully");
    } catch (e) {
      debugPrint("DELETE ERROR : $e");
      rethrow;
    }
  }
}
