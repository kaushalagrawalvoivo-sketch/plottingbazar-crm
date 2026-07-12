import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lead_provider.dart';
import '../bookings/booking_list_screen.dart';
import '../customers/customer_list_screen.dart';
import '../inventory/plot_list_screen.dart';
import '../leads/lead_list_screen.dart';
import '../reminders/follow_up_reminders_screen.dart';
import '../reports/reports_screen.dart';
import '../sites/site_list_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(leadProvider.notifier).loadLeads();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(leadProvider.notifier);
    ref.watch(leadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("PlottingBazaar CRM"),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _card(
                    "Total Leads",
                    notifier.totalLeads().toString(),
                    Colors.blue,
                    Icons.people,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _card(
                    "New",
                    notifier.countByStatus("New").toString(),
                    Colors.green,
                    Icons.person_add,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _card(
                    "Follow-up",
                    notifier.countByStatus("Follow-up").toString(),
                    Colors.orange,
                    Icons.calendar_today,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _card(
                    "Booked",
                    notifier.countByStatus("Booked").toString(),
                    Colors.purple,
                    Icons.home_work,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 55,
              child: FilledButton.icon(
                icon: const Icon(Icons.analytics_outlined),
                label: const Text("Reports & Exports"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportsScreen()),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 55,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text("Follow-up Reminders"),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FollowUpRemindersScreen(),
                    ),
                  );
                  await notifier.refresh();
                },
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 55,
              child: FilledButton.icon(
                icon: const Icon(Icons.people),
                label: const Text("Lead Management"),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LeadListScreen()),
                  );

                  await notifier.refresh();
                },
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 55,
              child: FilledButton.icon(
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text("Plot Inventory"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlotListScreen()),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 55,
              child: FilledButton.icon(
                icon: const Icon(Icons.person),
                label: const Text("Customer Management"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerListScreen(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 55,
              child: FilledButton.icon(
                icon: const Icon(Icons.location_city),
                label: const Text("Sites Management"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SiteListScreen()),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 55,
              child: FilledButton.icon(
                icon: const Icon(Icons.assignment_turned_in),
                label: const Text("Booking Management"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BookingListScreen(),
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

  Widget _card(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: [
            Icon(icon, color: color, size: 34),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(title),
          ],
        ),
      ),
    );
  }
}
