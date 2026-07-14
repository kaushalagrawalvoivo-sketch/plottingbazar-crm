import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/lead_model.dart';
import '../../providers/lead_provider.dart';

class AddLeadScreen extends ConsumerStatefulWidget { const AddLeadScreen({super.key}); @override ConsumerState<AddLeadScreen> createState() => _AddLeadScreenState(); }
class _AddLeadScreenState extends ConsumerState<AddLeadScreen> {
  final _form = GlobalKey<FormState>(); final _name = TextEditingController(); final _phone = TextEditingController(); final _site = TextEditingController();
  String _status = 'New'; String? _assignee; bool _saving = false; List<Map<String,dynamic>> _users = [];
  @override void initState() { super.initState(); _loadUsers(); }
  Future<void> _loadUsers() async { final rows = await Supabase.instance.client.from('profiles').select('id,full_name,email').order('full_name'); if (mounted) setState(() => _users = List<Map<String,dynamic>>.from(rows)); }
  @override void dispose() { _name.dispose(); _phone.dispose(); _site.dispose(); super.dispose(); }
  Future<void> _save() async { if (!_form.currentState!.validate()) return; setState(() => _saving = true); try { await ref.read(leadProvider.notifier).addLead(LeadModel(name: _name.text.trim(), phone: _phone.text.trim(), site: _site.text.trim(), status: _status, assignedTo: _assignee)); if (mounted) Navigator.pop(context); } finally { if (mounted) setState(() => _saving = false); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Add lead')), body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [_field(_name, 'Customer name'), const SizedBox(height: 14), _field(_phone, 'Phone number'), const SizedBox(height: 14), _field(_site, 'Interested site'), const SizedBox(height: 14), DropdownButtonFormField<String>(value: _status, items: const ['New','Follow-up','Qualified','Booked','Lost'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => _status = v!)), const SizedBox(height: 14), DropdownButtonFormField<String>(value: _assignee, decoration: const InputDecoration(labelText: 'Assign to sales user'), items: _users.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text((u['full_name'] as String?)?.isNotEmpty == true ? u['full_name'] as String : u['email'] as String))).toList(), onChanged: (v) => setState(() => _assignee = v)), const SizedBox(height: 24), FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Save lead'))])));
  Widget _field(TextEditingController controller, String label) => TextFormField(controller: controller, validator: (v) => v == null || v.trim().isEmpty ? '$label is required' : null, decoration: InputDecoration(labelText: label));
}
