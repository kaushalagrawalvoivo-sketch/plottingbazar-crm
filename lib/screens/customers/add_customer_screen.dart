import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  bool _loading = false;
  bool _isAdmin = false;
  String? _assignedTo;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadRoleAndUsers();
  }

  Future<void> _loadRoleAndUsers() async {
    final db = Supabase.instance.client;
    final userId = db.auth.currentUser?.id;
    if (userId == null) return;
    // A non-admin always owns the customers they add.
    _assignedTo = userId;
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
    if (mounted) {
      setState(() {
        _isAdmin = true;
        _users = List<Map<String, dynamic>>.from(users);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final customer = CustomerModel(
      name: _nameController.text.trim(),
      mobile: _mobileController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      assignedTo: _assignedTo,
    );

    await ref.read(customerProvider.notifier).addCustomer(customer);

    if (mounted) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Customer Added Successfully")),
      );
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Customer")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Customer Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? "Enter customer name"
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Mobile Number",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().length < 10
                    ? "Enter valid mobile number"
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email (Optional)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Address",
                  border: OutlineInputBorder(),
                ),
              ),
              if (_isAdmin) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _assignedTo,
                  decoration: const InputDecoration(
                    labelText: "Assign to sales user",
                    border: OutlineInputBorder(),
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
                  onChanged: (v) => setState(() => _assignedTo = v),
                ),
              ],
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text("Save Customer"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
