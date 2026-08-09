import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/roles.dart';

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
      if (mounted) {
        setState(() => _users = List<Map<String, dynamic>>.from(rows));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load users: $error')));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update role: $error')),
        );
      }
    }
  }

  /// Calls the `admin-users` Supabase Edge Function, which is the only
  /// place that holds the service-role key needed to actually create or
  /// delete a login account. Throws a readable message on failure.
  Future<Map<String, dynamic>> _callAdminUsersFunction(
    Map<String, dynamic> body,
  ) async {
    final response = await _db.functions.invoke(
      'admin-users',
      body: body,
    );
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw data['error'].toString();
    }
    if (response.status != 200) {
      throw 'Request failed (${response.status}).';
    }
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<void> _openAddUserDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String role = AppRoles.sales;
    bool saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Add user'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null) ...[
                    Text(error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),
                  ],
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => v == null || !v.contains('@')
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Temporary password',
                      helperText: 'At least 6 characters',
                    ),
                    validator: (v) => v == null || v.length < 6
                        ? 'At least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: AppRoles.all
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(AppRoles.label(r)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => role = v ?? role),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await _callAdminUsersFunction({
                          'action': 'create',
                          'fullName': nameController.text.trim(),
                          'email': emailController.text.trim(),
                          'password': passwordController.text,
                          'role': role,
                        });
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          error = e.toString();
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create user'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    await _loadUsers();
  }

  Future<void> _openEditUserDialog(Map<String, dynamic> user) async {
    final nameController = TextEditingController(
      text: (user['full_name'] as String?) ?? '',
    );
    final passwordController = TextEditingController();
    String role = AppRoles.all.contains(user['role']?.toString())
        ? user['role'].toString()
        : AppRoles.sales;
    bool saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Edit user'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) ...[
                  Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                ],
                Text(
                  user['email']?.toString() ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: AppRoles.all
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(AppRoles.label(r)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => role = v ?? role),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Reset password (optional)',
                    helperText: 'Leave blank to keep the current password',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final newPassword = passwordController.text;
                      if (newPassword.isNotEmpty && newPassword.length < 6) {
                        setDialogState(
                          () => error = 'Password must be at least 6 characters.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await _callAdminUsersFunction({
                          'action': 'update',
                          'userId': user['id'],
                          'fullName': nameController.text.trim(),
                          'role': role,
                          if (newPassword.isNotEmpty) 'password': newPassword,
                        });
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          error = e.toString();
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    await _loadUsers();
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    final name = (user['full_name'] as String?)?.trim();
    final label = name?.isNotEmpty == true
        ? name!
        : (user['email']?.toString() ?? 'this user');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove user?'),
        content: Text(
          'This permanently deletes the login for "$label". They will no '
          'longer be able to sign in. Leads already assigned to them are '
          'not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _callAdminUsersFunction({'action': 'delete', 'userId': user['id']});
      if (!mounted) return;
      setState(() => _users.removeWhere((item) => item['id'] == user['id']));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User removed.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not remove user: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _db.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Add user',
            onPressed: _openAddUserDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddUserDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add user'),
      ),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                itemCount: _users.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final user = _users[index];
                  final name = (user['full_name'] as String?)?.trim();
                  final email = user['email']?.toString() ?? '';
                  final role = AppRoles.all.contains(user['role']?.toString())
                      ? user['role'].toString()
                      : AppRoles.sales;
                  final isSelf = user['id'] == currentUserId;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          () {
                            final initial = name?.isNotEmpty == true
                                ? name!
                                : (email.isNotEmpty ? email : '?');
                            return initial.substring(0, 1).toUpperCase();
                          }(),
                        ),
                      ),
                      title: Text(
                        name?.isNotEmpty == true ? name! : 'Unnamed user',
                      ),
                      subtitle: Text(
                        isSelf ? '$email (you)' : email,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButton<String>(
                            value: role,
                            items: AppRoles.all
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(AppRoles.label(r)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                value == null || value == role
                                ? null
                                : _changeRole(user, value),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit user',
                            onPressed: () => _openEditUserDialog(user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: isSelf
                                ? 'You cannot remove your own account'
                                : 'Remove user',
                            onPressed:
                                isSelf ? null : () => _confirmDeleteUser(user),
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
