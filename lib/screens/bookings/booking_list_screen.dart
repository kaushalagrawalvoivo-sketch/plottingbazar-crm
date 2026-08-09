import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/booking_provider.dart';
import '../../providers/plot_provider.dart';
import '../../providers/customer_provider.dart';
import 'add_booking_screen.dart';
import 'booking_details_screen.dart';
import 'edit_booking_screen.dart';

class BookingListScreen extends ConsumerStatefulWidget {
  const BookingListScreen({super.key});

  @override
  ConsumerState<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends ConsumerState<BookingListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(bookingProvider.notifier).loadBookings();
      ref.read(plotProvider.notifier).loadPlots();
      ref.read(customerProvider.notifier).loadCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Provider ko watch karo taaki UI refresh ho
    ref.watch(bookingProvider);
    final plots = ref.watch(plotProvider);
    final customers = ref.watch(customerProvider);

    final notifier = ref.read(bookingProvider.notifier);

    final filtered = notifier.search(_searchController.text);

    return Scaffold(
      appBar: AppBar(title: const Text("Bookings")),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddBookingScreen()),
          );

          await notifier.refresh();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Search Booking",
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: notifier.refresh,
              child: filtered.isEmpty
                  ? const Center(child: Text("No Bookings Found"))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final booking = filtered[index];

                        // Find Plot Name
                        final plotList = plots.where((p) => p.id == booking.plotId);
                        final plotName = plotList.isNotEmpty 
                            ? "${plotList.first.block}-${plotList.first.plotNo}" 
                            : "Unknown Plot";

                        // Find Customer Name
                        final customerList = customers.where((c) => c.id == booking.customerId);
                        final customerName = customerList.isNotEmpty 
                            ? customerList.first.name 
                            : "Unknown Customer";

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.home_work),
                            ),
                            title: Text("Plot : $plotName"),
                            subtitle: Text(
                              "$customerName  •  ₹ ${booking.salePrice.toStringAsFixed(0)}",
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                switch (value) {
                                  case "view":
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BookingDetailsScreen(
                                          booking: booking,
                                        ),
                                      ),
                                    );
                                    break;

                                  case "edit":
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EditBookingScreen(booking: booking),
                                      ),
                                    );
                                    await notifier.refresh();
                                    break;

                                  case "delete":
                                    if (booking.id != null) {
                                      await notifier.deleteBooking(
                                        bookingId: booking.id!,
                                        plotId: booking.plotId,
                                      );
                                    }
                                    break;
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: "view",
                                  child: Text("View"),
                                ),
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
          ),
        ],
      ),
    );
  }
}
