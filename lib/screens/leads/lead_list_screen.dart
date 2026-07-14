import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/lead_provider.dart';
import '../../widgets/lead_card.dart';
import 'add_lead_screen.dart';
import 'edit_lead_screen.dart';
import 'import_leads_screen.dart';

class LeadListScreen extends ConsumerStatefulWidget {
  const LeadListScreen({super.key});

  @override
  ConsumerState<LeadListScreen> createState() => _LeadListScreenState();
}

class _LeadListScreenState extends ConsumerState<LeadListScreen> {
  final _search = TextEditingController();
  final Set<String> _selectedIds = {};
  String _status = 'All';
  bool _isAdmin = false;
  bool _selectionMode = false;
  bool _assigning = false;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(leadProvider.notifier).loadLeads();
      _loadAdminData();
    });
  }

  Future<void> _loadAdminData() async {
    final db = Supabase.instance.client;
    final userId = db.auth.currentUser?.id;
    if (userId == null) return;
    final profile = await db
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    if (profile?['role'] != 'admin' || !mounted) return;
    final users = await db
        .from('profiles')
        .select('id, full_name, email')
        .order('full_name');
    if (mounted)
      setState(() {
        _isAdmin = true;
        _users = List<Map<String, dynamic>>.from(users);
      });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSelectionMode() => setState(() {
    _selectionMode = !_selectionMode;
    _selectedIds.clear();
  });

  Future<void> _assignSelected() async {
    if (_selectedIds.isEmpty) return;
    String? assignee;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: StatefulBuilder(
            builder: (_, setSheetState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Assign ${_selectedIds.length} lead${_selectedIds.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: assignee,
                  decoration: const InputDecoration(
                    labelText: 'Assign to user',
                  ),
                  items: _users.map((user) {
                    final name = (user['full_name'] as String?)?.trim();
                    final email = user['email']?.toString() ?? '';
                    return DropdownMenuItem(
                      value: user['id'] as String,
                      child: Text(name?.isNotEmpty == true ? name! : email),
                    );
                  }).toList(),
                  onChanged: (value) => setSheetState(() => assignee = value),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: assignee == null
                      ? null
                      : () => Navigator.pop(sheetContext, assignee),
                  child: const Text('Assign leads'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _assigning = true);
    try {
      await ref
          .read(leadProvider.notifier)
          .assignLeads(_selectedIds.toList(), selected);
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _selectionMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leads assigned successfully.')),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not assign leads: $error')),
        );
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leads = ref.watch(leadProvider).where((lead) {
      final query = _search.text.toLowerCase();
      return (_status == 'All' || lead.status == _status) &&
          (lead.name.toLowerCase().contains(query) ||
              lead.phone.toLowerCase().contains(query) ||
              lead.site.toLowerCase().contains(query));
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode ? '${_selectedIds.length} selected' : 'Leads',
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: _selectionMode ? 'Cancel selection' : 'Select leads',
              onPressed: _toggleSelectionMode,
              icon: Icon(_selectionMode ? Icons.close : Icons.checklist),
            ),
        ],
      ),
      floatingActionButton: _selectionMode
          ? FloatingActionButton.extended(
              onPressed: _selectedIds.isEmpty || _assigning
                  ? null
                  : _assignSelected,
              icon: _assigning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: const Text('Assign selected'),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'import',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ImportLeadsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import CSV'),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'add',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddLeadScreen()),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add lead'),
                ),
              ],
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search leads',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              value: _status,
              items:
                  const [
                        'All',
                        'New',
                        'Follow-up',
                        'Qualified',
                        'Booked',
                        'Lost',
                      ]
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _status = value!),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: leads.length,
              itemBuilder: (_, index) {
                final lead = leads[index];
                final id = lead.id;
                return LeadCard(
                  lead: lead,
                  selectionMode: _selectionMode,
                  selected: id != null && _selectedIds.contains(id),
                  onSelected: id == null
                      ? null
                      : (value) => setState(() {
                          if (value == true)
                            _selectedIds.add(id);
                          else
                            _selectedIds.remove(id);
                        }),
                  onTap: _selectionMode
                      ? (id == null
                            ? null
                            : () => setState(() {
                                if (_selectedIds.contains(id))
                                  _selectedIds.remove(id);
                                else
                                  _selectedIds.add(id);
                              }))
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditLeadScreen(lead: lead),
                          ),
                        ),
                  onDelete: lead.id == null
                      ? () {}
                      : () => ref
                            .read(leadProvider.notifier)
                            .deleteLead(lead.id!),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
