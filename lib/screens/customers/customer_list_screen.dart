import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/customer_provider.dart';
import '../../models/customer_model.dart';
import 'add_customer_screen.dart';
import 'customer_details_screen.dart';
import 'edit_customer_screen.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  String _search = "";

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(customerProvider.notifier).loadCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerProvider);

    final notifier = ref.read(customerProvider.notifier);

    final list = _search.isEmpty ? customers : notifier.search(_search);

    return Scaffold(
      appBar: AppBar(title: const Text("Customers")),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
          );

          notifier.refresh();
        },
      ),
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: "Search customer...",
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  setState(() {
                    _search = v;
                  });
                },
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text("No Customers Found"))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final CustomerModel customer = list[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(customer.name),
                            subtitle: Text(customer.mobile),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CustomerDetailsScreen(customer: customer),
                                ),
                              );
                            },
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == "edit") {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditCustomerScreen(
                                        customer: customer,
                                      ),
                                    ),
                                  );

                                  notifier.refresh();
                                }

                                if (value == "delete") {
                                  await notifier.deleteCustomer(customer.id!);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: "edit",
                                  child: Text("Edit"),
                                ),
                                PopupMenuItem(
                                  value: "delete",
                                  child: Text("Delete"),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
