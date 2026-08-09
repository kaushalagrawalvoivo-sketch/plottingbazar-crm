import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/roles.dart';
import '../../providers/lead_provider.dart';
import '../../widgets/lead_card.dart';
import 'add_lead_screen.dart';
import 'edit_lead_screen.dart';
import 'import_leads_screen.dart';

class LeadListScreen extends ConsumerStatefulWidget {
  /// Optional initial status filter (e.g. 'New', 'Follow-up') so the
  /// dashboard's metric tiles can deep-link straight into a filtered view.
  final String? initialStatus;

  /// Show only leads whose follow-up date is overdue -- used by the
  /// dashboard's "Overdue follow-ups" tile.
  final bool overdueOnly;

  /// Show only leads assigned to this user id -- used by the employee
  /// performance leaderboard to drill into one employee's leads.
  final String? assignedToUserId;

  /// Display name of [assignedToUserId], shown in the app bar title.
  final String? assignedToLabel;

  /// Show only leads created at/after this moment -- used by the
  /// dashboard's "Added today" tile to drill into today's new leads.
  final DateTime? createdAfter;

  /// App bar title to use when [createdAfter] is set (e.g. "Added today").
  final String? createdLabel;

  const LeadListScreen({
    super.key,
    this.initialStatus,
    this.overdueOnly = false,
    this.assignedToUserId,
    this.assignedToLabel,
    this.createdAfter,
    this.createdLabel,
  });

  @override
  ConsumerState<LeadListScreen> createState() => _LeadListScreenState();
}

/// Values for the manager-only "who is this assigned to" filter, used to
/// spot unassigned leads at a glance before assigning more -- so nobody
/// double-assigns a lead that's already someone's.
enum _AssignmentFilter { all, unassigned, assigned }

class _LeadListScreenState extends ConsumerState<LeadListScreen> {
  final _search = TextEditingController();
  final Set<String> _selectedIds = {};
  late String _status;
  String? _role;
  bool _canManage = false;
  bool _selectionMode = false;
  bool _assigning = false;
  _AssignmentFilter _assignmentFilter = _AssignmentFilter.all;
  List<Map<String, dynamic>> _users = [];

  /// The lead the user tapped first (the "starting point"). "Select next
  /// N" counts forward from this lead's position in the visible list,
  /// instead of always starting from the top -- so the admin can scroll
  /// to wherever they left off, tap that lead, then grab the next batch
  /// from there.
  String? _anchorId;

  /// userId -> display name/email, built from [_users] once loaded, so
  /// every lead card can show who it's already assigned to.
  Map<String, String> get _userNames => {
    for (final user in _users)
      user['id'] as String:
          ((user['full_name'] as String?)?.trim().isNotEmpty == true
              ? (user['full_name'] as String).trim()
              : (user['email']?.toString() ?? 'Unknown')),
  };

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus ?? 'All';
    Future.microtask(() {
      ref.read(leadProvider.notifier).loadLeads();
      _loadRoleData();
    });
  }

  Future<void> _loadRoleData() async {
    final db = Supabase.instance.client;
    final userId = db.auth.currentUser?.id;
    if (userId == null) return;
    final profile = await db
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    final role = profile?['role']?.toString();
    if (!mounted) return;
    setState(() {
      _role = role;
      _canManage = AppRoles.canManage(role);
    });
    if (!_canManage) return;
    final users = await db
        .from('profiles')
        .select('id, full_name, email, role')
        .order('full_name');
    final assignable = List<Map<String, dynamic>>.from(
      users,
    ).where((u) => AppRoles.assignable.contains(u['role']?.toString())).toList();
    if (mounted) setState(() => _users = assignable);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSelectionMode() => setState(() {
    _selectionMode = !_selectionMode;
    _selectedIds.clear();
    _anchorId = null;
  });

  /// Selects every lead currently matching the search/status/assignment
  /// filters -- for the rare case the admin really does want everything.
  void _selectAllFiltered(List<dynamic> filteredLeads) {
    final ids = filteredLeads
        .map((lead) => lead.id as String?)
        .whereType<String>()
        .toList();
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(ids);
      _anchorId = ids.isEmpty ? null : ids.first;
    });
  }

  /// Selects [count] leads starting from [_anchorId]'s position in the
  /// visible list and moving forward -- e.g. tap lead #35 as the
  /// starting point, then "next 20" grabs #35-#54, not #1-#20.
  void _selectForwardFromAnchor(List<dynamic> filteredLeads, int count) {
    final ids = filteredLeads
        .map((lead) => lead.id as String?)
        .whereType<String>()
        .toList();
    final anchorIndex = _anchorId == null ? -1 : ids.indexOf(_anchorId);
    if (anchorIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Tap a lead's checkbox first to set the starting point.",
          ),
        ),
      );
      return;
    }
    final end = (anchorIndex + count).clamp(0, ids.length);
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(ids.sublist(anchorIndex, end));
    });
  }

  Future<void> _assignSelected() async {
    if (_selectedIds.isEmpty) return;

    // With zero sales/telecaller accounts, the dropdown below would render
    // with an empty (invisible) menu -- tapping it looks like it "doesn't
    // open" at all. Catch that up front with a clear explanation instead.
    if (_users.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No one to assign to'),
          content: const Text(
            'There are no Sales or Telecaller accounts yet. Add one from '
            '"Manage users" (role = Sales or Telecaller), then try '
            'assigning again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final names = _userNames;
    String? assignee;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: StatefulBuilder(
            builder: (_, setSheetState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Assign ${_selectedIds.length} lead${_selectedIds.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: assignee,
                  decoration: const InputDecoration(
                    labelText: 'Assign to user',
                  ),
                  items: _users.map((user) {
                    final name = (user['full_name'] as String?)?.trim();
                    final email = user['email']?.toString() ?? '';
                    return DropdownMenuItem(
                      value: user['id'] as String,
                      child: Text(name?.isNotEmpty == true ? name! : email),
                    );
                  }).toList(),
                  onChanged: (value) => setSheetState(() => assignee = value),
                ),
                const SizedBox(height: 8),
                // Shows how many of the selected leads already belong to
                // someone else, right before the admin confirms -- the
                // main guard against accidentally double-assigning leads.
                Builder(
                  builder: (_) {
                    final leads = ref.read(leadProvider);
                    final alreadyAssigned = leads
                        .where((lead) =>
                            lead.id != null &&
                            _selectedIds.contains(lead.id) &&
                            lead.assignedTo != null &&
                            lead.assignedTo != assignee)
                        .length;
                    if (alreadyAssigned == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '$alreadyAssigned of the selected lead${alreadyAssigned == 1 ? ' is' : 's are'} '
                        'already assigned to someone else and will be reassigned.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: assignee == null
                      ? null
                      : () => Navigator.pop(sheetContext, assignee),
                  child: const Text('Assign leads'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _assigning = true);
    try {
      await ref
          .read(leadProvider.notifier)
          .assignLeads(_selectedIds.toList(), selected);
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _anchorId = null;
        _selectionMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Leads assigned to ${names[selected] ?? 'user'} successfully.',
          ),
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not assign leads: $error')),
        );
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leads = ref.watch(leadProvider).where((lead) {
      final query = _search.text.toLowerCase();
      final matchesStatus = _status == 'All' || lead.status == _status;
      final matchesOverdue = !widget.overdueOnly || lead.isFollowUpOverdue;
      final matchesAssignee = widget.assignedToUserId == null ||
          lead.assignedTo == widget.assignedToUserId;
      final matchesCreated = widget.createdAfter == null ||
          (lead.createdAt != null &&
              !lead.createdAt!.isBefore(widget.createdAfter!));
      final matchesAssignmentFilter = switch (_assignmentFilter) {
        _AssignmentFilter.all => true,
        _AssignmentFilter.unassigned => lead.assignedTo == null,
        _AssignmentFilter.assigned => lead.assignedTo != null,
      };
      return matchesStatus &&
          matchesOverdue &&
          matchesAssignee &&
          matchesCreated &&
          matchesAssignmentFilter &&
          (lead.name.toLowerCase().contains(query) ||
              lead.phone.toLowerCase().contains(query) ||
              lead.site.toLowerCase().contains(query));
    }).toList();
    final userNames = _userNames;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '${_selectedIds.length} selected'
              : widget.overdueOnly
              ? 'Overdue follow-ups'
              : widget.assignedToUserId != null
              ? 'Leads · ${widget.assignedToLabel ?? 'Employee'}'
              : widget.createdAfter != null
              ? widget.createdLabel ?? 'Recently added'
              : 'Leads',
        ),
        actions: [
          if (_canManage && _selectionMode)
            PopupMenuButton<int>(
              tooltip: 'Select…',
              icon: const Icon(Icons.playlist_add_check),
              onSelected: (value) {
                if (value == -1) {
                  _selectAllFiltered(leads);
                } else {
                  _selectForwardFromAnchor(leads, value);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: -1,
                  child: Text('Select all (${leads.length})'),
                ),
                const PopupMenuDivider(),
                if (_anchorId == null)
                  const PopupMenuItem(
                    enabled: false,
                    child: Text(
                      'Tap a lead to set the starting point',
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                else
                  for (final count in const [10, 20, 30, 40, 50, 60, 70])
                    PopupMenuItem(
                      value: count,
                      child: Text('Next $count from here'),
                    ),
              ],
            ),
          if (_canManage)
            IconButton(
              tooltip: _selectionMode ? 'Cancel selection' : 'Select leads',
              onPressed: _toggleSelectionMode,
              icon: Icon(_selectionMode ? Icons.close : Icons.checklist),
            ),
        ],
      ),
      floatingActionButton: _selectionMode
          ? FloatingActionButton.extended(
              onPressed: _selectedIds.isEmpty || _assigning
                  ? null
                  : _assignSelected,
              icon: _assigning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: const Text('Assign selected'),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_canManage) ...[
                  FloatingActionButton.extended(
                    heroTag: 'import',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ImportLeadsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import from Excel'),
                  ),
                  const SizedBox(height: 12),
                ],
                FloatingActionButton.extended(
                  heroTag: 'add',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddLeadScreen()),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add lead'),
                ),
              ],
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search leads',
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    isDense: true,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items:
                        const [
                              'All',
                              'New',
                              'Follow-up',
                              'Qualified',
                              'Booked',
                              'Lost',
                            ]
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() => _status = value!),
                  ),
                ),
                if (_canManage) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<_AssignmentFilter>(
                      value: _assignmentFilter,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Assignment',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _AssignmentFilter.all,
                          child: Text('All'),
                        ),
                        DropdownMenuItem(
                          value: _AssignmentFilter.unassigned,
                          child: Text('Unassigned'),
                        ),
                        DropdownMenuItem(
                          value: _AssignmentFilter.assigned,
                          child: Text('Assigned'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _assignmentFilter = value!),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: leads.isEmpty
                ? const Center(child: Text('No leads found.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                    itemCount: leads.length,
                    itemBuilder: (_, index) {
                      final lead = leads[index];
                      final id = lead.id;
                      return LeadCard(
                        lead: lead,
                        role: _role,
                        selectionMode: _selectionMode,
                        selected: id != null && _selectedIds.contains(id),
                        // Only shown for admins/managers, who are the ones
                        // doing the assigning -- lets them see at a glance
                        // whether a lead is already someone's before they
                        // select it, so they don't duplicate-assign it.
                        showAssignment: _canManage,
                        assigneeName: lead.assignedTo == null
                            ? null
                            : (userNames[lead.assignedTo] ?? 'Unknown'),
                        onSelected: id == null
                            ? null
                            : (value) => setState(() {
                                if (value == true) {
                                  _selectedIds.add(id);
                                  // First tap in a fresh selection sets the
                                  // starting point for "Next N from here".
                                  _anchorId ??= id;
                                } else {
                                  _selectedIds.remove(id);
                                  if (_anchorId == id) {
                                    // Starting point was deselected -- fall
                                    // back to another selected lead, or
                                    // clear it if nothing's selected.
                                    _anchorId = _selectedIds.isEmpty
                                        ? null
                                        : _selectedIds.first;
                                  }
                                }
                              }),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditLeadScreen(lead: lead),
                          ),
                        ),
                        onDelete: lead.id == null
                            ? null
                            : () => ref
                                .read(leadProvider.notifier)
                                .deleteLead(lead.id!),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
