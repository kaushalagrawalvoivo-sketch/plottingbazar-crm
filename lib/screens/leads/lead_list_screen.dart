import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/lead_provider.dart';
import '../../widgets/lead_card.dart';
import 'add_lead_screen.dart';
import 'edit_lead_screen.dart';
import 'import_leads_screen.dart';

class LeadListScreen extends ConsumerStatefulWidget { const LeadListScreen({super.key}); @override ConsumerState<LeadListScreen> createState() => _LeadListScreenState(); }
class _LeadListScreenState extends ConsumerState<LeadListScreen> {
  final _search = TextEditingController(); String _status = 'All';
  @override void initState() { super.initState(); Future.microtask(() => ref.read(leadProvider.notifier).loadLeads()); }
  @override void dispose() { _search.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final leads = ref.watch(leadProvider).where((lead) { final query = _search.text.toLowerCase(); return (_status == 'All' || lead.status == _status) && (lead.name.toLowerCase().contains(query) || lead.phone.toLowerCase().contains(query) || lead.site.toLowerCase().contains(query)); }).toList();
    return Scaffold(appBar: AppBar(title: const Text('Leads')), floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [FloatingActionButton.extended(heroTag: 'import', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportLeadsScreen())), icon: const Icon(Icons.upload_file_outlined), label: const Text('Import CSV')), const SizedBox(height: 12), FloatingActionButton.extended(heroTag: 'add', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddLeadScreen())), icon: const Icon(Icons.add), label: const Text('Add lead'))]), body: Column(children: [Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name, phone or site'))), Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: DropdownButtonFormField<String>(value: _status, decoration: const InputDecoration(labelText: 'Status'), items: const ['All', 'New', 'Follow-up', 'Qualified', 'Booked', 'Lost'].map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(), onChanged: (value) => setState(() => _status = value!))), const SizedBox(height: 8), Expanded(child: RefreshIndicator(onRefresh: () => ref.read(leadProvider.notifier).refresh(), child: leads.isEmpty ? const Center(child: Text('No leads assigned to you.')) : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 4, 12, 110), itemCount: leads.length, itemBuilder: (_, index) { final lead = leads[index]; return LeadCard(lead: lead, onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => EditLeadScreen(lead: lead))); ref.read(leadProvider.notifier).refresh(); }, onDelete: lead.id == null ? () {} : () => ref.read(leadProvider.notifier).deleteLead(lead.id!)); }))]));
  }
}
