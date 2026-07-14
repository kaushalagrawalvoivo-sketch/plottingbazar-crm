import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/lead_model.dart';
import '../../providers/lead_provider.dart';

class EditLeadScreen extends ConsumerStatefulWidget { const EditLeadScreen({super.key, required this.lead}); final LeadModel lead; @override ConsumerState<EditLeadScreen> createState() => _EditLeadScreenState(); }
class _EditLeadScreenState extends ConsumerState<EditLeadScreen> {
  final _form = GlobalKey<FormState>(); late final TextEditingController _name; late final TextEditingController _phone; late final TextEditingController _site; late String _status; bool _saving = false;
  @override void initState() { super.initState(); _name = TextEditingController(text: widget.lead.name); _phone = TextEditingController(text: widget.lead.phone); _site = TextEditingController(text: widget.lead.site); _status = widget.lead.status; }
  @override void dispose() { _name.dispose(); _phone.dispose(); _site.dispose(); super.dispose(); }
  Future<void> _save() async { if (!_form.currentState!.validate()) return; setState(() => _saving = true); try { await ref.read(leadProvider.notifier).updateLead(widget.lead.copyWith(name: _name.text.trim(), phone: _phone.text.trim(), site: _site.text.trim(), status: _status)); if (mounted) Navigator.pop(context); } finally { if (mounted) setState(() => _saving = false); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Edit lead')), body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [_field(_name, 'Customer name'), const SizedBox(height: 14), _field(_phone, 'Phone number'), const SizedBox(height: 14), _field(_site, 'Interested site'), const SizedBox(height: 14), DropdownButtonFormField<String>(value: _status, items: const ['New','Follow-up','Qualified','Booked','Lost'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => _status = v!)), const SizedBox(height: 24), FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Updating...' : 'Update lead'))])));
  Widget _field(TextEditingController controller, String label) => TextFormField(controller: controller, validator: (v) => v == null || v.trim().isEmpty ? '$label is required' : null, decoration: InputDecoration(labelText: label));
}
