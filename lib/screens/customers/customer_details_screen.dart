import 'package:flutter/material.dart';

import '../../core/services/contact_action_service.dart';
import '../../models/customer_model.dart';

class CustomerDetailsScreen extends StatelessWidget {
  final CustomerModel customer;

  const CustomerDetailsScreen({super.key, required this.customer});

  Widget _tile(String title, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value.isEmpty ? "-" : value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Customer Details")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),

          const SizedBox(height: 20),

          Center(
            child: Text(
              customer.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _call(context),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openWhatsApp(context),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          _tile("Mobile", customer.mobile, Icons.phone),

          _tile("Email", customer.email ?? "", Icons.email),

          _tile("Address", customer.address ?? "", Icons.location_on),

          _tile(
            "Status",
            customer.isActive ? "Active" : "Inactive",
            customer.isActive ? Icons.check_circle : Icons.cancel,
          ),

          if (customer.createdAt != null)
            _tile(
              "Created",
              customer.createdAt.toString(),
              Icons.calendar_today,
            ),
        ],
      ),
    );
  }

  Future<void> _call(BuildContext context) async {
    final opened = await ContactActionService.call(customer.mobile);
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the phone app.')),
    );
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final opened = await ContactActionService.openWhatsApp(
      phone: customer.mobile,
      name: customer.name,
      site: '',
    );
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
  }
}
