import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/lead_service.dart';
import '../models/lead_model.dart';

final leadServiceProvider = Provider<LeadService>((ref) => LeadService());
final leadProvider = StateNotifierProvider<LeadNotifier, List<LeadModel>>((ref) => LeadNotifier(ref.read(leadServiceProvider)));
class LeadNotifier extends StateNotifier<List<LeadModel>> {
  LeadNotifier(this._service) : super([]);
  final LeadService _service;
  Future<void> loadLeads() async => state = await _service.getLeads();
  Future<void> refresh() => loadLeads();
  Future<void> addLead(LeadModel lead) async { await _service.addLead(lead); await loadLeads(); }
  Future<void> importLeads(List<LeadModel> leads) async { await _service.importLeads(leads); await loadLeads(); }
  Future<void> updateLead(LeadModel lead) async { await _service.updateLead(lead); await loadLeads(); }
  Future<void> deleteLead(String id) async { await _service.deleteLead(id); await loadLeads(); }
  int totalLeads() => state.length;
  int countByStatus(String status) => state.where((lead) => lead.status == status).length;
}
