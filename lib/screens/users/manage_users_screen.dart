import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final rows = await _db
          .from('profiles')
          .select('id, full_name, email, role, created_at')
          .order('created_at');
      if (mounted)
        setState(() => _users = List<Map<String, dynamic>>.from(rows));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load users: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeRole(Map<String, dynamic> user, String role) async {
    try {
      await _db.from('profiles').update({'role': role}).eq('id', user['id']);
      if (!mounted) return;
      setState(
        () => _users = _users
            .map(
              (item) =>
                  item['id'] == user['id'] ? {...item, 'role': role} : item,
            )
            .toList(),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User role updated.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update role: $error')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manage users')),
    body: RefreshIndicator(
      onRefresh: _loadUsers,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 180),
                Center(child: Text('No users found.')),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final user = _users[index];
                final name = (user['full_name'] as String?)?.trim();
                final email = user['email']?.toString() ?? '';
                final role = user['role']?.toString() == 'admin'
                    ? 'admin'
                    : 'sales';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (name?.isNotEmpty == true ? name! : email)
                            .substring(0, 1)
                            .toUpperCase(),
                      ),
                    ),
                    title: Text(
                      name?.isNotEmpty == true ? name! : 'Unnamed user',
                    ),
                    subtitle: Text(email),
                    trailing: DropdownButton<String>(
                      value: role,
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(value: 'sales', child: Text('Sales')),
                      ],
                      onChanged: (value) => value == null || value == role
                          ? null
                          : _changeRole(user, value),
                    ),
                  ),
                );
              },
            ),
    ),
  );
}
