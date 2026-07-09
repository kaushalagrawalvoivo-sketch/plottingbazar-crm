import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lead_model.dart';
import '../../providers/lead_provider.dart';
import '../../widgets/lead_card.dart';
import 'add_lead_screen.dart';
import 'edit_lead_screen.dart';

class LeadListScreen extends ConsumerStatefulWidget {
  const LeadListScreen({super.key});

  @override
  ConsumerState<LeadListScreen> createState() => _LeadListScreenState();
}

class _LeadListScreenState extends ConsumerState<LeadListScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _statusFilter = "All";

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(leadProvider.notifier).loadLeads();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leads = ref.watch(leadProvider);

    List<LeadModel> filtered = leads.where((lead) {
      final search = _searchController.text.toLowerCase();

      final matchesSearch =
          lead.name.toLowerCase().contains(search) ||
          lead.phone.toLowerCase().contains(search) ||
          lead.site.toLowerCase().contains(search);

      final matchesStatus =
          _statusFilter == "All" || lead.status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Lead Management"),
        centerTitle: true,
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddLeadScreen(),
            ),
          );

          ref.read(leadProvider.notifier).loadLeads();
        },
        child: const Icon(Icons.add),
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search Lead...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<String>(
              initialValue: _statusFilter,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Filter Status",
              ),
              items: const [
                DropdownMenuItem(value: "All", child: Text("All")),
                DropdownMenuItem(value: "New", child: Text("New")),
                DropdownMenuItem(value: "Follow-up", child: Text("Follow-up")),
                DropdownMenuItem(value: "Qualified", child: Text("Qualified")),
                DropdownMenuItem(value: "Booked", child: Text("Booked")),
                DropdownMenuItem(value: "Lost", child: Text("Lost")),
              ],
              onChanged: (value) {
                setState(() {
                  _statusFilter = value!;
                });
              },
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(leadProvider.notifier).loadLeads();
              },
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        "No Leads Found",
                        style: TextStyle(fontSize: 18),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final lead = filtered[index];

                        return LeadCard(
                          lead: lead,

                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditLeadScreen(
                                  lead: lead,
                                ),
                              ),
                            );

                            ref.read(leadProvider.notifier).loadLeads();
                          },

                          onDelete: () async {
                            if (lead.id == null) return;

                            await ref
                                .read(leadProvider.notifier)
                                .deleteLead(lead.id!);
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}