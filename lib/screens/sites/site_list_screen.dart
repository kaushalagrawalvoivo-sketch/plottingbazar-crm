import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/site_model.dart';
import '../../providers/site_provider.dart';
import 'add_site_screen.dart';

class SiteListScreen extends ConsumerStatefulWidget {
  const SiteListScreen({super.key});

  @override
  ConsumerState<SiteListScreen> createState() => _SiteListScreenState();
}

class _SiteListScreenState extends ConsumerState<SiteListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(siteProvider.notifier).loadSites();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(siteProvider);

    final filtered = sites.where((site) {
      final q = _searchController.text.toLowerCase();

      return site.name.toLowerCase().contains(q) ||
          site.location.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Sites")),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSiteScreen()),
          );

          await ref.read(siteProvider.notifier).refresh();
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search Site...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(siteProvider.notifier).refresh(),
              child: filtered.isEmpty
                  ? const Center(child: Text("No Sites Found"))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final SiteModel site = filtered[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: site.isActive
                                  ? Colors.green
                                  : Colors.grey,
                              child: const Icon(
                                Icons.location_city,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(site.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(site.location),
                                Text(
                                  "₹ ${site.pricePerSqft.toStringAsFixed(2)} / sqft",
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                if (site.id == null) return;

                                await ref
                                    .read(siteProvider.notifier)
                                    .deleteSite(site.id!);
                              },
                            ),
                          ),
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
