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

      return (response as List)
          .map((e) => LeadModel.fromJson(e))
          .toList();
    } catch (e) {
      print("GET ERROR: $e");
      rethrow;
    }
  }

  Future<void> addLead(LeadModel lead) async {
    try {
      await _db.from('leads').insert(lead.toJson());

      print("Lead Added Successfully");
    } catch (e) {
      print("ADD ERROR: $e");
      rethrow;
    }
  }

  Future<void> updateLead(LeadModel lead) async {
    try {
      print("========== UPDATE ==========");
      print("Lead ID : ${lead.id}");
      print("Lead Data : ${lead.toJson()}");

      final response = await _db
          .from('leads')
          .update(lead.toJson())
          .eq('id', lead.id!)
          .select();

      print("UPDATE RESPONSE : $response");
      print("Lead Updated Successfully");
    } catch (e) {
      print("UPDATE ERROR : $e");
      rethrow;
    }
  }

  Future<void> deleteLead(String id) async {
    try {
      await _db
          .from('leads')
          .delete()
          .eq('id', id);

      print("Lead Deleted Successfully");
    } catch (e) {
      print("DELETE ERROR : $e");
      rethrow;
    }
  }
}