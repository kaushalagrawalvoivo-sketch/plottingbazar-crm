import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lead_model.dart';
import '../../providers/lead_provider.dart';

class EditLeadScreen extends ConsumerStatefulWidget {
  final LeadModel lead;

  const EditLeadScreen({
    super.key,
    required this.lead,
  });

  @override
  ConsumerState<EditLeadScreen> createState() => _EditLeadScreenState();
}

class _EditLeadScreenState extends ConsumerState<EditLeadScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _siteController;

  late String _status;
  DateTime? _followUpDate;

  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.lead.name);
    _phoneController = TextEditingController(text: widget.lead.phone);
    _siteController = TextEditingController(text: widget.lead.site);

    _status = widget.lead.status;
    _followUpDate = widget.lead.followUpDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _siteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _followUpDate = picked);
    }
  }

  Future<void> _updateLead() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final updatedLead = widget.lead.copyWith(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      site: _siteController.text.trim(),
      status: _status,
      followUpDate: _followUpDate,
    );

    await ref.read(leadProvider.notifier).updateLead(updatedLead);

    if (!mounted) return;

    Navigator.pop(context, true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Lead Updated Successfully"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Lead"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Customer Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? "Enter customer name"
                        : null,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? "Enter phone number"
                        : null,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _siteController,
                decoration: const InputDecoration(
                  labelText: "Interested Site",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? "Enter site"
                        : null,
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: "Lead Status",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "New", child: Text("New")),
                  DropdownMenuItem(value: "Follow-up", child: Text("Follow-up")),
                  DropdownMenuItem(value: "Qualified", child: Text("Qualified")),
                  DropdownMenuItem(value: "Booked", child: Text("Booked")),
                  DropdownMenuItem(value: "Lost", child: Text("Lost")),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
              ),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _followUpDate == null
                      ? "Select Follow-up Date"
                      : _followUpDate!.toIso8601String().split('T').first,
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _updateLead,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Update Lead"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}