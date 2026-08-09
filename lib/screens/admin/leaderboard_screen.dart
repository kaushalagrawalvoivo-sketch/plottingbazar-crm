import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin-only: ranks every sales employee by calls made and leads
/// converted, so the admin can see who's actually working the leads
/// without having to dig through individual lead histories.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _EmployeeStats {
  final String id;
  final String name;
  int assignedLeads = 0;
  int convertedLeads = 0;
  int callsThisWeek = 0;
  int callsAllTime = 0;

  _EmployeeStats(this.id, this.name);
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<_EmployeeStats> _stats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final weekAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String();

      final results = await Future.wait([
        _db.from('profiles').select('id, full_name, email, role'),
        _db.from('leads').select('id, assigned_to, status'),
        _db.from('call_logs').select('called_by, created_at'),
      ]);

      final profiles = List<Map<String, dynamic>>.from(results[0] as List);
      final leads = List<Map<String, dynamic>>.from(results[1] as List);
      final calls = List<Map<String, dynamic>>.from(results[2] as List);

      final statsById = <String, _EmployeeStats>{};
      for (final profile in profiles) {
        if (profile['role'] == 'admin') continue;
        final id = profile['id'] as String;
        final name = (profile['full_name'] as String?)?.trim().isNotEmpty == true
            ? profile['full_name'] as String
            : (profile['email'] as String? ?? 'Unknown');
        statsById[id] = _EmployeeStats(id, name);
      }

      for (final lead in leads) {
        final assignedTo = lead['assigned_to']?.toString();
        final stats = statsById[assignedTo];
        if (stats == null) continue;
        stats.assignedLeads++;
        if (lead['status'] == 'Booked') stats.convertedLeads++;
      }

      for (final call in calls) {
        final calledBy = call['called_by']?.toString();
        final stats = statsById[calledBy];
        if (stats == null) continue;
        stats.callsAllTime++;
        final createdAt = call['created_at']?.toString();
        if (createdAt != null && createdAt.compareTo(weekAgo) >= 0) {
          stats.callsThisWeek++;
        }
      }

      final sorted = statsById.values.toList()
        ..sort((a, b) => b.callsThisWeek.compareTo(a.callsThisWeek));

      if (mounted) setState(() => _stats = sorted);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load leaderboard: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employee performance')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!),
                  ),
                ],
              )
            : _stats.isEmpty
            ? ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No sales employees yet.'),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _stats.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final stats = _stats[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: index == 0
                            ? Colors.amber
                            : Theme.of(context).colorScheme.primaryContainer,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(stats.name),
                      subtitle: Text(
                        '${stats.assignedLeads} assigned  •  '
                        '${stats.convertedLeads} booked  •  '
                        '${stats.callsAllTime} calls total',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${stats.callsThisWeek}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'calls this week',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
