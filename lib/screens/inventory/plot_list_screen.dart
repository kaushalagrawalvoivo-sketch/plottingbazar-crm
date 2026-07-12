import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/plot_model.dart';
import '../../providers/plot_provider.dart';
import 'add_plot_screen.dart';
import 'edit_plot_screen.dart';
import 'plot_details_screen.dart';

class PlotListScreen extends ConsumerStatefulWidget {
  const PlotListScreen({super.key});

  @override
  ConsumerState<PlotListScreen> createState() => _PlotListScreenState();
}

class _PlotListScreenState extends ConsumerState<PlotListScreen> {
  String _search = "";

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(plotProvider.notifier).loadPlots();
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Booked":
        return Colors.red;
      case "Hold":
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final plots = ref.watch(plotProvider);
    final notifier = ref.read(plotProvider.notifier);

    final list = _search.isEmpty ? plots : notifier.search(_search);

    return Scaffold(
      appBar: AppBar(title: const Text("Plot Inventory")),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPlotScreen()),
          );

          await notifier.refresh();
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
                  hintText: "Search Plot...",
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _search = value;
                  });
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const Text("Available"),
                            Text(
                              notifier.availablePlots().toString(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const Text("Booked"),
                            Text(
                              notifier.bookedPlots().toString(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const Text("Hold"),
                            Text(
                              notifier.holdPlots().toString(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text("No Plots Found"))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final PlotModel plot = list[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            title: Text("Plot ${plot.plotNo}"),
                            subtitle: Text(
                              "Block ${plot.block} • ${plot.area} Sq.Ft.",
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlotDetailsScreen(plot: plot),
                                ),
                              );
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(plot.status),
                                  backgroundColor: _statusColor(plot.status),
                                  labelStyle: const TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == "edit") {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              EditPlotScreen(plot: plot),
                                        ),
                                      );
                                      await notifier.refresh();
                                    }

                                    if (value == "delete") {
                                      await notifier.deletePlot(plot.id!);
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
