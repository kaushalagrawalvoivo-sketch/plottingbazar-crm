import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/lead_service.dart';
import '../models/lead_model.dart';

final leadServiceProvider = Provider<LeadService>((ref) {
  return LeadService();
});

final leadProvider =
    StateNotifierProvider<LeadNotifier, List<LeadModel>>((ref) {
  return LeadNotifier(ref.read(leadServiceProvider));
});

class LeadNotifier extends StateNotifier<List<LeadModel>> {
  final LeadService _service;

  LeadNotifier(this._service) : super([]);

  Future<void> loadLeads() async {
    try {
      state = await _service.getLeads();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refresh() async {
    await loadLeads();
  }

  Future<void> addLead(LeadModel lead) async {
    await _service.addLead(lead);
    await loadLeads();
  }

  Future<void> updateLead(LeadModel lead) async {
    await _service.updateLead(lead);
    await loadLeads();
  }

  Future<void> deleteLead(String id) async {
    await _service.deleteLead(id);
    await loadLeads();
  }

  void clear() {
    state = [];
  }

  int totalLeads() => state.length;

  int countByStatus(String status) {
    return state.where((lead) => lead.status == status).length;
  }

  List<LeadModel> search(String query) {
    if (query.trim().isEmpty) return state;

    final q = query.toLowerCase();

    return state.where((lead) {
      return lead.name.toLowerCase().contains(q) ||
          lead.phone.toLowerCase().contains(q) ||
          lead.site.toLowerCase().contains(q);
    }).toList();
  }
}