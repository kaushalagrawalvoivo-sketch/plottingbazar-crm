import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/password_reset_request_model.dart';

/// Backs the no-email "Forgot password" flow: a user submits a request
/// (works even signed out), and an admin/manager reviews + resolves it
/// from [PasswordResetRequestsScreen] by setting the new password
/// directly. See supabase/20260812_password_reset_requests.sql for the
/// table + RLS this relies on.
class PasswordResetService {
  final SupabaseClient _db = Supabase.instance.client;

  /// Anyone can call this, logged in or not -- it's how a user asks for
  /// help before they can sign back in.
  Future<void> submitRequest({required String email, String? note}) => _db
      .from('password_reset_requests')
      .insert({
        'email': email.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });

  /// Admin/manager only (enforced by RLS) -- the open queue shown in
  /// [PasswordResetRequestsScreen].
  Future<List<PasswordResetRequestModel>> getPendingRequests() async {
    final rows = await _db
        .from('password_reset_requests')
        .select()
        .eq('status', 'pending')
        .order('requested_at');
    return (rows as List)
        .map((row) =>
            PasswordResetRequestModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Marks a request resolved (admin set a new password for the user) or
  /// dismissed (e.g. spam / no matching account) -- either way it leaves
  /// the pending queue.
  Future<void> closeRequest(String id, {required bool resolved}) async {
    final userId = _db.auth.currentUser?.id;
    await _db.from('password_reset_requests').update({
      'status': resolved ? 'resolved' : 'dismissed',
      'resolved_at': DateTime.now().toIso8601String(),
      'resolved_by': userId,
    }).eq('id', id);
  }

  /// Looks up the profile matching an email so the admin can jump
  /// straight to resetting that user's password without retyping/
  /// searching for them in Manage Users.
  Future<Map<String, dynamic>?> findProfileByEmail(String email) => _db
      .from('profiles')
      .select('id, full_name, email, role')
      .ilike('email', email.trim())
      .maybeSingle();
}
