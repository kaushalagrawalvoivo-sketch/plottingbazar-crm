import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/roles.dart';
import '../admin/activity_monitor_screen.dart';
import '../admin/leaderboard_screen.dart';
import '../auth/login_screen.dart';
import '../bookings/booking_list_screen.dart';
import '../inventory/plot_list_screen.dart';
import '../profile/profile_screen.dart';
import '../reports/reports_screen.dart';
import '../sites/site_list_screen.dart';
import '../users/manage_users_screen.dart';

/// Everything that doesn't fit on the bottom nav bar lives here: inventory,
/// reports, and (for admin/manager) the management screens, plus account
/// actions. Keeps the bottom dock to 5 primary destinations.
class MoreMenuScreen extends StatefulWidget {
  const MoreMenuScreen({super.key});

  @override
  State<MoreMenuScreen> createState() => _MoreMenuScreenState();
}

class _MoreMenuScreenState extends State<MoreMenuScreen> {
  bool _canManage = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final db = Supabase.instance.client;
    final userId = db.auth.currentUser?.id;
    if (userId == null) return;
    final profile = await db
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    if (mounted) {
      setState(() => _canManage = AppRoles.canManage(profile?['role']?.toString()));
    }
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
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
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _tile(Icons.grid_view_outlined, 'Inventory / Plots', () => _open(const PlotListScreen())),
          _tile(Icons.location_on_outlined, 'Sites', () => _open(const SiteListScreen())),
          _tile(Icons.assignment_turned_in_outlined, 'Bookings', () => _open(const BookingListScreen())),
          _tile(Icons.analytics_outlined, 'Reports', () => _open(const ReportsScreen())),
          if (_canManage) ...[
            const Divider(),
            _tile(Icons.manage_accounts_outlined, 'Manage users', () => _open(const ManageUsersScreen())),
            _tile(Icons.monitor_heart_outlined, 'Live activity monitor', () => _open(const ActivityMonitorScreen())),
            _tile(Icons.leaderboard_outlined, 'Employee performance', () => _open(const LeaderboardScreen())),
          ],
          const Divider(),
          _tile(Icons.person_outline, 'My profile', () => _open(const ProfileScreen())),
          _tile(Icons.logout, 'Logout', _logout),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
