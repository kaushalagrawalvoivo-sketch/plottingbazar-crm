import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/lead_provider.dart';
import '../auth/login_screen.dart';
import '../bookings/booking_list_screen.dart';
import '../customers/customer_list_screen.dart';
import '../inventory/plot_list_screen.dart';
import '../leads/lead_list_screen.dart';
import '../reminders/follow_up_reminders_screen.dart';
import '../reports/reports_screen.dart';
import '../sites/site_list_screen.dart';
import '../users/manage_users_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isAdmin = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(leadProvider.notifier).loadLeads());
    Future.microtask(_loadRole);
  }

  Future<void> _loadRole() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    if (mounted) setState(() => _isAdmin = profile?['role'] == 'admin');
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await ref.read(leadProvider.notifier).refresh();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final leads = ref.watch(leadProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('PlottingBazaar CRM')),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Color(0xff101828)),
                child: Text(
                  'PlottingBazaar\\nCRM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _nav(
                Icons.groups_outlined,
                'Leads',
                () => _open(const LeadListScreen()),
              ),
              _nav(
                Icons.person_outline,
                'Customers',
                () => _open(const CustomerListScreen()),
              ),
              _nav(
                Icons.grid_view_outlined,
                'Inventory',
                () => _open(const PlotListScreen()),
              ),
              _nav(
                Icons.location_on_outlined,
                'Sites',
                () => _open(const SiteListScreen()),
              ),
              _nav(
                Icons.assignment_turned_in_outlined,
                'Bookings',
                () => _open(const BookingListScreen()),
              ),
              _nav(
                Icons.analytics_outlined,
                'Reports',
                () => _open(const ReportsScreen()),
              ),
              _nav(
                Icons.notifications_active_outlined,
                'Reminders',
                () => _open(const FollowUpRemindersScreen()),
              ),
              if (_isAdmin)
                _nav(
                  Icons.manage_accounts_outlined,
                  'Manage users',
                  () => _open(const ManageUsersScreen()),
                ),
              const Divider(),
              _nav(Icons.logout, 'Logout', _logout),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(leadProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Sales overview',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric('Total leads', leads.length, Icons.groups),
                _metric(
                  'New',
                  leads.where((lead) => lead.status == 'New').length,
                  Icons.person_add,
                ),
                _metric(
                  'Follow-ups',
                  leads.where((lead) => lead.status == 'Follow-up').length,
                  Icons.calendar_today,
                ),
                _metric(
                  'Booked',
                  leads.where((lead) => lead.status == 'Booked').length,
                  Icons.home_work,
                ),
              ],
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.manage_accounts_outlined),
                  ),
                  title: const Text('Manage users'),
                  subtitle: const Text(
                    'View users and update their access role',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(const ManageUsersScreen()),
                ),
              ),
            ],
            const SizedBox(height: 28),
            Text('Recent leads', style: Theme.of(context).textTheme.titleLarge),
            Card(
              child: leads.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No leads assigned to you.')),
                    )
                  : Column(
                      children: leads
                          .take(6)
                          .map<Widget>(
                            (lead) => ListTile(
                              title: Text(lead.name),
                              subtitle: Text('${lead.phone} - ${lead.site}'),
                              trailing: Chip(label: Text(lead.status)),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nav(IconData icon, String label, VoidCallback onTap) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    onTap: () {
      Navigator.pop(context);
      onTap();
    },
  );
  Widget _metric(String title, int value, IconData icon) => SizedBox(
    width: 170,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 10),
            Text(
              '$value',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            Text(title),
          ],
        ),
      ),
    ),
  );
}
