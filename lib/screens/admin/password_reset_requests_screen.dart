import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/password_reset_service.dart';
import '../../models/password_reset_request_model.dart';

/// Admin/manager queue for the no-email "Forgot password" flow. A user's
/// request shows up here; the admin sets a new password directly (via the
/// same admin-users Edge Function "Manage users" uses) and closes the
/// request. Nothing here ever sends an email -- admin action is what
/// actually resets the password.
class PasswordResetRequestsScreen extends StatefulWidget {
  const PasswordResetRequestsScreen({super.key});

  @override
  State<PasswordResetRequestsScreen> createState() =>
      _PasswordResetRequestsScreenState();
}

class _PasswordResetRequestsScreenState
    extends State<PasswordResetRequestsScreen> {
  final _service = PasswordResetService();
  final _db = Supabase.instance.client;
  bool _loading = true;
  List<PasswordResetRequestModel> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final requests = await _service.getPendingRequests();
      if (mounted) setState(() => _requests = requests);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load requests: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dismiss(PasswordResetRequestModel request) async {
    try {
      await _service.closeRequest(request.id, resolved: false);
      if (mounted) {
        setState(() => _requests.removeWhere((r) => r.id == request.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not dismiss request: $e')),
        );
      }
    }
  }

  Future<void> _resolve(PasswordResetRequestModel request) async {
    // Find the matching login account by email so the admin doesn't have
    // to leave this screen and search Manage Users manually.
    Map<String, dynamic>? profile;
    try {
      profile = await _service.findProfileByEmail(request.email);
    } catch (_) {
      profile = null;
    }

    if (!mounted) return;

    if (profile == null) {
      final dismiss = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No matching account'),
          content: Text(
            'No user in "Manage users" has the email "${request.email}". '
            'Double-check with them, or create/fix their account first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Dismiss request'),
            ),
          ],
        ),
      );
      if (dismiss == true) await _dismiss(request);
      return;
    }

    final passwordController = TextEditingController();
    bool saving = false;
    String? error;
    final name = (profile['full_name'] as String?)?.trim();

    final didReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Set new password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                name?.isNotEmpty == true
                    ? '$name (${request.email})'
                    : request.email,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (request.note != null && request.note!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Note: ${request.note}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  helperText: 'At least 6 characters',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (passwordController.text.length < 6) {
                        setDialogState(
                          () => error = 'At least 6 characters.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final response = await _db.functions.invoke(
                          'admin-users',
                          body: {
                            'action': 'update',
                            'userId': profile!['id'],
                            'password': passwordController.text,
                          },
                        );
                        final data = response.data;
                        if (data is Map && data['error'] != null) {
                          throw data['error'].toString();
                        }
                        if (response.status != 200) {
                          throw 'Request failed (${response.status}).';
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
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
                  : const Text('Set password'),
            ),
          ],
        ),
      ),
    );

    if (didReset != true || !mounted) return;
    await _service.closeRequest(request.id, resolved: true);
    if (!mounted) return;
    setState(() => _requests.removeWhere((r) => r.id == request.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Password reset requests')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _requests.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(child: Text('No pending requests.')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _requests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final request = _requests[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.lock_reset),
                      ),
                      title: Text(request.email),
                      subtitle: Text(
                        (request.note?.isNotEmpty == true)
                            ? request.note!
                            : 'Requested ${_formatDate(request.requestedAt)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Dismiss',
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => _dismiss(request),
                          ),
                          FilledButton(
                            onPressed: () => _resolve(request),
                            child: const Text('Reset'),
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

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}
