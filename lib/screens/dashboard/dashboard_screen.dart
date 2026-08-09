import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/roles.dart';
import '../../core/services/password_reset_service.dart';
import '../../providers/lead_provider.dart';
import '../../widgets/pwa_install_banner.dart';
import '../admin/activity_monitor_screen.dart';
import '../admin/leaderboard_screen.dart';
import '../admin/password_reset_requests_screen.dart';
import '../leads/edit_lead_screen.dart';
import '../leads/lead_list_screen.dart';
import '../users/manage_users_screen.dart';

/// The "Home" tab content shown inside [MainShell]'s bottom navigation.
/// This is body-only (no Scaffold/AppBar of its own) so it drops
/// straight into the shell's IndexedStack.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _canManage = false;
  int _pendingResetRequests = 0;

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
    final canManage = AppRoles.canManage(profile?['role']?.toString());
    if (mounted) setState(() => _canManage = canManage);
    if (!canManage) return;
    try {
      final pending = await PasswordResetService().getPendingRequests();
      if (mounted) setState(() => _pendingResetRequests = pending.length);
    } catch (_) {
      // Non-critical -- the dashboard card still works without a count.
    }
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _openLeads({
    String? status,
    bool overdueOnly = false,
    DateTime? createdAfter,
    String? createdLabel,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadListScreen(
          initialStatus: status,
          overdueOnly: overdueOnly,
          createdAfter: createdAfter,
          createdLabel: createdLabel,
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final leads = ref.watch(leadProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(leadProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
        children: [
          const PwaInstallBanner(),
          Text(
            'Sales overview',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a tile to see those leads',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metric(
                'Total leads',
                leads.length,
                Icons.groups,
                onTap: () => _openLeads(),
              ),
              _metric(
                'New',
                leads.where((lead) => lead.status == 'New').length,
                Icons.person_add,
                onTap: () => _openLeads(status: 'New'),
              ),
              _metric(
                'Follow-ups',
                leads.where((lead) => lead.status == 'Follow-up').length,
                Icons.calendar_today,
                onTap: () => _openLeads(status: 'Follow-up'),
              ),
              _metric(
                'Booked',
                leads.where((lead) => lead.status == 'Booked').length,
                Icons.home_work,
                onTap: () => _openLeads(status: 'Booked'),
              ),
              _metric(
                'Overdue follow-ups',
                leads.where((lead) => lead.isFollowUpOverdue).length,
                Icons.warning_amber_rounded,
                color: Colors.red,
                onTap: () => _openLeads(overdueOnly: true),
              ),
              _metric(
                'Added today',
                leads
                    .where((lead) =>
                        lead.createdAt != null && _isToday(lead.createdAt!))
                    .length,
                Icons.fiber_new_outlined,
                color: Colors.teal,
                onTap: () => _openLeads(
                  createdAfter: DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                  ),
                  createdLabel: 'Added today',
                ),
              ),
            ],
          ),
          if (_canManage) ...[
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
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.monitor_heart_outlined, color: Colors.white),
                ),
                title: const Text('Live activity monitor'),
                subtitle: const Text(
                  'See every call, feedback and WhatsApp message in real time',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(const ActivityMonitorScreen()),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.amber,
                  child: Icon(Icons.leaderboard_outlined, color: Colors.white),
                ),
                title: const Text('Employee performance'),
                subtitle: const Text(
                  'Calls made and leads converted, ranked by employee',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(const LeaderboardScreen()),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _pendingResetRequests > 0
                      ? Colors.red
                      : Colors.blueGrey,
                  child: const Icon(Icons.lock_reset, color: Colors.white),
                ),
                title: const Text('Password reset requests'),
                subtitle: Text(
                  _pendingResetRequests > 0
                      ? '$_pendingResetRequests waiting for your approval'
                      : 'No pending requests',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(const PasswordResetRequestsScreen()),
              ),
            ),
          ],
          const SizedBox(height: 28),
          InkWell(
            onTap: () => _openLeads(),
            child: Row(
              children: [
                Text(
                  'Recent leads',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditLeadScreen(lead: lead),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _metric(
    String title,
    int value,
    IconData icon, {
    Color? color,
    VoidCallback? onTap,
  }) => SizedBox(
    width: 170,
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(title),
            ],
          ),
        ),
      ),
    ),
  );
}
