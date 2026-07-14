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

class DashboardScreen extends ConsumerStatefulWidget { const DashboardScreen({super.key}); @override ConsumerState<DashboardScreen> createState() => _DashboardScreenState(); }
class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selected = 0;
  @override void initState() { super.initState(); Future.microtask(() => ref.read(leadProvider.notifier).loadLeads()); }
  Future<void> _logout() async { await Supabase.instance.client.auth.signOut(); if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false); }
  Future<void> _open(Widget page) async { await Navigator.push(context, MaterialPageRoute(builder: (_) => page)); if (mounted) ref.read(leadProvider.notifier).refresh(); }
  @override Widget build(BuildContext context) {
    final leads = ref.watch(leadProvider);
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final shell = Row(children: [if (wide) _Sidebar(selected: _selected, onSelect: (i) { setState(() => _selected = i); _navigate(i); }, onLogout: _logout), Expanded(child: _home(leads))]);
    return Scaffold(drawer: wide ? null : Drawer(child: SafeArea(child: _Sidebar(selected: _selected, onSelect: (i) { Navigator.pop(context); setState(() => _selected = i); _navigate(i); }, onLogout: _logout))), body: shell);
  }
  void _navigate(int index) { switch (index) { case 1: _open(const LeadListScreen()); break; case 2: _open(const CustomerListScreen()); break; case 3: _open(const PlotListScreen()); break; case 4: _open(const SiteListScreen()); break; case 5: _open(const BookingListScreen()); break; case 6: _open(const ReportsScreen()); break; case 7: _open(const FollowUpRemindersScreen()); break; } }
  Widget _home(List leads) => SafeArea(child: RefreshIndicator(onRefresh: () => ref.read(leadProvider.notifier).refresh(), child: ListView(padding: const EdgeInsets.all(24), children: [
    Builder(builder: (context) => Row(children: [if (MediaQuery.sizeOf(context).width < 960) IconButton(onPressed: () => Scaffold.of(context).openDrawer(), icon: const Icon(Icons.menu)), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Good day', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 4), Text('Here is your sales overview', style: Theme.of(context).textTheme.bodyMedium)])), CircleAvatar(child: Text((Supabase.instance.client.auth.currentUser?.email ?? 'U')[0].toUpperCase()))])),
    const SizedBox(height: 28), Text('Overview', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 16),
    Wrap(spacing: 16, runSpacing: 16, children: [_Metric('Total leads', leads.length, Icons.groups_outlined, const Color(0xffEEF2FF)), _Metric('New', leads.where((l) => l.status == 'New').length, Icons.person_add_alt_1_outlined, const Color(0xffECFDF3)), _Metric('Follow-ups', leads.where((l) => l.status == 'Follow-up').length, Icons.event_available_outlined, const Color(0xffFFF7E8)), _Metric('Booked', leads.where((l) => l.status == 'Booked').length, Icons.home_work_outlined, const Color(0xffF5F0FF))]),
    const SizedBox(height: 32), Row(children: [Text('Recent leads', style: Theme.of(context).textTheme.headlineSmall), const Spacer(), TextButton(onPressed: () => _open(const LeadListScreen()), child: const Text('View all'))]), const SizedBox(height: 12), Card(child: leads.isEmpty ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No leads assigned to you yet.'))) : Column(children: leads.take(6).map<Widget>((lead) => ListTile(leading: CircleAvatar(child: Text(lead.name.isEmpty ? '?' : lead.name[0].toUpperCase())), title: Text(lead.name), subtitle: Text('${lead.phone} · ${lead.site}'), trailing: _Status(lead.status))).toList())),
  ]));
}
class _Sidebar extends StatelessWidget { const _Sidebar({required this.selected, required this.onSelect, required this.onLogout}); final int selected; final ValueChanged<int> onSelect; final VoidCallback onLogout; @override Widget build(BuildContext context) { const entries = [(Icons.space_dashboard_outlined, 'Dashboard'), (Icons.groups_outlined, 'Leads'), (Icons.person_outline, 'Customers'), (Icons.grid_view_outlined, 'Inventory'), (Icons.location_on_outlined, 'Sites'), (Icons.assignment_turned_in_outlined, 'Bookings'), (Icons.analytics_outlined, 'Reports'), (Icons.notifications_active_outlined, 'Reminders')]; return Container(width: 256, color: const Color(0xff101828), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.fromLTRB(24, 24, 12, 28), child: Text('PlottingBazaar\nCRM', style: TextStyle(color: Colors.white, fontSize: 21, height: 1.12, fontWeight: FontWeight.w800))), ...entries.indexed.map((item) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: ListTile(dense: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), selected: selected == item.$1, selectedTileColor: const Color(0xff344054), leading: Icon(item.$2.$1, color: Colors.white70), title: Text(item.$2.$2, style: const TextStyle(color: Colors.white)), onTap: () => onSelect(item.$1)))), const Spacer(), Padding(padding: const EdgeInsets.all(12), child: ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), leading: const Icon(Icons.logout, color: Color(0xffFECACA)), title: const Text('Logout', style: TextStyle(color: Color(0xffFECACA))), onTap: onLogout))])); } }
class _Metric extends StatelessWidget { const _Metric(this.label, this.value, this.icon, this.tint); final String label; final int value; final IconData icon; final Color tint; @override Widget build(BuildContext context) => SizedBox(width: 210, child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [CircleAvatar(backgroundColor: tint, child: Icon(icon, color: const Color(0xff344054))), const SizedBox(width: 13), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), Text(label, style: Theme.of(context).textTheme.bodySmall)])])))); }
class _Status extends StatelessWidget { const _Status(this.value); final String value; @override Widget build(BuildContext context) => Chip(label: Text(value), visualDensity: VisualDensity.compact, side: BorderSide.none); }
