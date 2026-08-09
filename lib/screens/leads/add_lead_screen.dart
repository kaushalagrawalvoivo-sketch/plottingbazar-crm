import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/roles.dart';
import '../../core/services/lead_service.dart';
import '../../models/lead_model.dart';
import '../../providers/lead_provider.dart';

class AddLeadScreen extends ConsumerStatefulWidget {
  const AddLeadScreen({super.key});

  @override
  ConsumerState<AddLeadScreen> createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends ConsumerState<AddLeadScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _site = TextEditingController();
  final _budget = TextEditingController();
  final _leadService = LeadService();

  String _status = 'New';
  String? _source;
  String? _purpose;
  String? _assignee;
  bool _saving = false;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final rows = await Supabase.instance.client
        .from('profiles')
        .select('id,full_name,email,role')
        .order('full_name');
    final assignable = List<Map<String, dynamic>>.from(
      rows,
    ).where((u) => AppRoles.assignable.contains(u['role']?.toString())).toList();
    if (mounted) setState(() => _users = assignable);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _site.dispose();
    _budget.dispose();
    super.dispose();
  }

  /// Warns before creating a lead whose phone number already exists
  /// anywhere in the system (even under a different employee), so two
  /// people don't end up independently calling the same person.
  Future<bool> _confirmNotDuplicate() async {
    final duplicate = await _leadService.checkDuplicatePhone(_phone.text);
    if (duplicate == null || !mounted) return true;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('This number already exists'),
        content: Text(
          '"${duplicate['lead_name']}" with this phone number is already a '
          'lead (status: ${duplicate['lead_status']}), assigned to '
          '${duplicate['assigned_name']}.\n\nAdd it anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add anyway'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    if (!await _confirmNotDuplicate()) return;
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(leadProvider.notifier).addLead(
        LeadModel(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          site: _site.text.trim(),
          status: _status,
          source: _source,
          purpose: _purpose,
          budget: double.tryParse(_budget.text.trim()),
          assignedTo: _assignee,
        ),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add lead')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _field(_name, 'Customer name'),
          const SizedBox(height: 14),
          _field(_phone, 'Phone number'),
          const SizedBox(height: 14),
          _field(_site, 'Interested site'),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const ['New', 'Follow-up', 'Qualified', 'Booked', 'Lost']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _status = v!),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _purpose,
            decoration: const InputDecoration(labelText: 'Purpose (optional)'),
            items: LeadModel.purposes
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (v) => setState(() => _purpose = v),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _budget,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Budget in ₹ (optional)',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _source,
            decoration: const InputDecoration(labelText: 'Lead source (optional)'),
            items: LeadModel.sourceItems(_source)
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _source = v),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _assignee,
            decoration: InputDecoration(
              labelText: 'Assign to sales/telecaller',
              // With no Sales/Telecaller accounts yet, the menu would
              // otherwise render with zero items and tapping it would look
              // like it does nothing -- this explains why instead.
              helperText: _users.isEmpty
                  ? 'No Sales/Telecaller accounts yet -- add one from Manage users'
                  : null,
            ),
            items: _users
                .map(
                  (u) => DropdownMenuItem(
                    value: u['id'] as String,
                    child: Text(
                      (u['full_name'] as String?)?.isNotEmpty == true
                          ? u['full_name'] as String
                          : u['email'] as String,
                    ),
                  ),
                )
                .toList(),
            onChanged: _users.isEmpty ? null : (v) => setState(() => _assignee = v),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save lead'),
          ),
        ],
      ),
    ),
  );

  Widget _field(TextEditingController controller, String label) => TextFormField(
    controller: controller,
    validator: (v) => v == null || v.trim().isEmpty ? '$label is required' : null,
    decoration: InputDecoration(labelText: label),
  );
}
