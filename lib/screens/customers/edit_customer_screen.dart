import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/roles.dart';
import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart';

class EditCustomerScreen extends ConsumerStatefulWidget {
  final CustomerModel customer;

  const EditCustomerScreen({super.key, required this.customer});

  @override
  ConsumerState<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends ConsumerState<EditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;

  bool _loading = false;
  bool _canManage = false;
  String? _assignedTo;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.customer.name);
    _mobileController = TextEditingController(text: widget.customer.mobile);
    _emailController = TextEditingController(text: widget.customer.email ?? '');
    _addressController = TextEditingController(
      text: widget.customer.address ?? '',
    );
    _assignedTo = widget.customer.assignedTo;
    _loadRoleAndUsers();
  }

  Future<void> _loadRoleAndUsers() async {
    final db = Supabase.instance.client;
    final userId = db.auth.currentUser?.id;
    if (userId == null) return;
    final profile = await db
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    if (!AppRoles.canManage(profile?['role']?.toString()) || !mounted) return;
    final users = await db
        .from('profiles')
        .select('id, full_name, email, role')
        .order('full_name');
    final assignable = List<Map<String, dynamic>>.from(
      users,
    ).where((u) => AppRoles.assignable.contains(u['role']?.toString())).toList();
    if (mounted) {
      setState(() {
        _canManage = true;
        _users = assignable;
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

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final updated = widget.customer.copyWith(
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

    await ref.read(customerProvider.notifier).updateCustomer(updated);

    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Customer Updated Successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Customer")),
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
                  labelText: "Email",
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
              if (_canManage) ...[
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
                  onPressed: _loading ? null : _update,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text("Update Customer"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
