import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lead_model.dart';
import '../../providers/lead_provider.dart';

class AddLeadScreen extends ConsumerStatefulWidget {
  const AddLeadScreen({super.key});

  @override
  ConsumerState<AddLeadScreen> createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends ConsumerState<AddLeadScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _siteController = TextEditingController();

  String _status = "New";
  DateTime? _followUpDate;

  bool _loading = false;

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

  Future<void> _saveLead() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final lead = LeadModel(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      site: _siteController.text.trim(),
      status: _status,
      followUpDate: _followUpDate,
    );

    await ref.read(leadProvider.notifier).addLead(lead);

    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Lead Added Successfully"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Lead"),
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
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Enter customer name" : null,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Enter phone number" : null,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _siteController,
                decoration: const InputDecoration(
                  labelText: "Interested Site",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Enter site name" : null,
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
                  setState(() => _status = value!);
                },
              ),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _followUpDate == null
                      ? "Select Follow-up Date"
                      : _followUpDate!.toString().split(' ').first,
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _saveLead,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text("Save Lead"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}