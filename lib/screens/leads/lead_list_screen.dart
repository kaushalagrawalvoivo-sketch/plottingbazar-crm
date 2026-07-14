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
    final leads = ref.watch(leadProvider).where((lead) { final q = _search.text.toLowerCase(); return (_status == 'All' || lead.status == _status) && (lead.name.toLowerCase().contains(q) || lead.phone.toLowerCase().contains(q) || lead.site.toLowerCase().contains(q)); }).toList();
    return Scaffold(appBar: AppBar(title: const Text('Leads')), floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [FloatingActionButton.extended(heroTag: 'import', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportLeadsScreen())), icon: const Icon(Icons.upload_file), label: const Text('Import CSV')), const SizedBox(height: 12), FloatingActionButton.extended(heroTag: 'add', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddLeadScreen())), icon: const Icon(Icons.add), label: const Text('Add lead'))]), body: Column(children: [Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search leads'))), Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: DropdownButtonFormField<String>(value: _status, items: const ['All','New','Follow-up','Qualified','Booked','Lost'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => _status = v!))), Expanded(child: ListView.builder(itemCount: leads.length, itemBuilder: (_, i) { final lead = leads[i]; return LeadCard(lead: lead, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditLeadScreen(lead: lead))), onDelete: lead.id == null ? () {} : () => ref.read(leadProvider.notifier).deleteLead(lead.id!)); }))]));
  }
}
