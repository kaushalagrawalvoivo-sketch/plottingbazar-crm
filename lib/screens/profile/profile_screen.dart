import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple self-service account screen: view your role/email, edit your
/// display name, and change your password. Anyone logged in can reach
/// this -- it only ever touches the current user's own row (role changes
/// stay admin-only, enforced by a database trigger, not just the UI).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _db = Supabase.instance.client;
  final _nameController = TextEditingController();
  bool _loading = true;
  bool _savingName = false;
  String _email = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;
    final profile = await _db
        .from('profiles')
        .select('full_name, email, role')
        .eq('id', userId)
        .maybeSingle();
    if (!mounted) return;
    setState(() {
      _nameController.text = profile?['full_name'] ?? '';
      _email = profile?['email'] ?? _db.auth.currentUser?.email ?? '';
      _role = profile?['role'] ?? 'sales';
      _loading = false;
    });
  }

  Future<void> _saveName() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null || _nameController.text.trim().isEmpty) return;
    setState(() => _savingName = true);
    try {
      await _db
          .from('profiles')
          .update({'full_name': _nameController.text.trim()})
          .eq('id', userId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Name updated.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not update name.')));
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changePassword() async {
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (v) => (v == null || v.length < 6)
                    ? 'At least 6 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (v) => v != newPasswordController.text
                    ? 'Passwords do not match'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _db.auth.updateUser(
        UserAttributes(password: newPasswordController.text),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update password: $e')));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    _nameController.text.isNotEmpty
                        ? _nameController.text[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 28, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _savingName ? null : _saveName,
                    child: Text(_savingName ? 'Saving...' : 'Save name'),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(_email),
                ),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Role'),
                  subtitle: Text(_role == 'admin' ? 'Admin' : 'Sales'),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _changePassword,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Change password'),
                ),
              ],
            ),
    );
  }
}
