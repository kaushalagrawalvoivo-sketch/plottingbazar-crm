/// Central place for the four roles and what each is allowed to do.
/// Manager is intentionally treated identically to Admin everywhere in
/// this app (per product decision) except that it's shown as a separate
/// label in the UI. Telecaller is like Sales but cannot delete records.
class AppRoles {
  const AppRoles._();

  static const String admin = 'admin';
  static const String manager = 'manager';
  static const String sales = 'sales';
  static const String telecaller = 'telecaller';

  static const List<String> all = [admin, manager, sales, telecaller];

  /// Roles that leads/customers actually get assigned to (field staff).
  static const List<String> assignable = [sales, telecaller];

  static String label(String? role) {
    switch (role) {
      case admin:
        return 'Admin';
      case manager:
        return 'Manager';
      case telecaller:
        return 'Telecaller';
      case sales:
        return 'Sales';
      default:
        return role ?? 'Unknown';
    }
  }

  /// Full access: manage users, see everyone's data, all admin screens.
  static bool canManage(String? role) => role == admin || role == manager;

  /// Allowed to delete leads/customers. Telecallers can call and update
  /// status/feedback, but cannot delete records.
  static bool canDelete(String? role) =>
      role == admin || role == manager || role == sales;
}
