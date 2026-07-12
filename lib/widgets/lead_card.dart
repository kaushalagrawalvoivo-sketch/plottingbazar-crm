import 'package:flutter/material.dart';

import '../core/services/contact_action_service.dart';
import '../models/lead_model.dart';

class LeadCard extends StatelessWidget {
  final LeadModel lead;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const LeadCard({super.key, required this.lead, this.onTap, this.onDelete});

  Color get statusColor {
    switch (lead.status) {
      case "Qualified":
        return Colors.green;
      case "Follow-up":
        return Colors.orange;
      case "Booked":
        return Colors.blue;
      case "Lost":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lead.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      lead.status,
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: statusColor,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(Icons.phone, size: 18),
                  const SizedBox(width: 8),
                  Text(lead.phone),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(Icons.location_city, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(lead.site)),
                ],
              ),

              if (lead.followUpDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Text(lead.followUpDate!.toString().split(' ').first),
                  ],
                ),
              ],

              const SizedBox(height: 14),

              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _call(context),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text("Call"),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openWhatsApp(context),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text("WhatsApp"),
                  ),
                  OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit"),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete),
                    label: const Text("Delete"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _call(BuildContext context) async {
    final opened = await ContactActionService.call(lead.phone);
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the phone app.')),
    );
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final opened = await ContactActionService.openWhatsApp(
      phone: lead.phone,
      name: lead.name,
      site: lead.site,
    );
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
  }
}
