import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/activity_service.dart';
import '../core/services/lead_service.dart';
import '../models/activity_log_model.dart';
import '../models/lead_model.dart';

final leadServiceProvider = Provider<LeadService>((ref) => LeadService());
final activityServiceProvider = Provider<ActivityService>(
  (ref) => ActivityService(),
);

final leadProvider = StateNotifierProvider<LeadNotifier, List<LeadModel>>(
  (ref) => LeadNotifier(ref.read(leadServiceProvider), ref.read(activityServiceProvider)),
);

class LeadNotifier extends StateNotifier<List<LeadModel>> {
  LeadNotifier(this._service, this._activity) : super([]);
  final LeadService _service;
  final ActivityService _activity;

  Future<void> loadLeads() async => state = await _service.getLeads();
  Future<void> refresh() => loadLeads();

  Future<void> addLead(LeadModel lead) async {
    await _service.addLead(lead);
    await _activity.log(
      actionType: ActivityLogModel.leadCreated,
      description: 'Added a new lead: ${lead.name} (${lead.site})',
    );
    await loadLeads();
  }

  Future<void> importLeads(List<LeadModel> leads) async {
    await _service.importLeads(leads);
    await _activity.log(
      actionType: ActivityLogModel.leadCreated,
      description: 'Imported ${leads.length} leads from CSV',
    );
    await loadLeads();
  }

  Future<void> updateLead(LeadModel lead, {String? previousStatus}) async {
    await _service.updateLead(lead);
    if (previousStatus != null && previousStatus != lead.status && lead.id != null) {
      await _activity.log(
        actionType: ActivityLogModel.leadStatusChanged,
        leadId: lead.id,
        description:
            '${lead.name}: status changed from $previousStatus to ${lead.status}',
      );
    }
    await loadLeads();
  }

  Future<void> assignLeads(List<String> leadIds, String userId) async {
    await _service.assignLeads(leadIds, userId);
    await _activity.log(
      actionType: ActivityLogModel.leadAssigned,
      description: 'Assigned ${leadIds.length} lead(s) to a sales user',
    );
    await loadLeads();
  }

  Future<void> deleteLead(String id) async {
    await _service.deleteLead(id);
    await loadLeads();
  }

  int totalLeads() => state.length;
  int countByStatus(String status) =>
      state.where((lead) => lead.status == status).length;
}
