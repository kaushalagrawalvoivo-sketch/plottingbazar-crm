import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/roles.dart';
import '../core/services/contact_action_service.dart';
import '../models/lead_model.dart';
import '../providers/lead_provider.dart';
import '../screens/leads/edit_lead_screen.dart';

/// Compact, single-row lead tile. Tapping it (outside selection mode)
/// opens a bottom sheet with every action -- call, WhatsApp, view
/// details, delete -- instead of showing a row of buttons on every
/// card, so more leads fit on a mobile screen at once.
class LeadCard extends ConsumerWidget {
  final LeadModel lead;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool?>? onSelected;

  /// Current user's role, used only to decide whether Delete is offered
  /// in the action sheet (telecallers cannot delete).
  final String? role;

  /// Display name of whoever this lead is assigned to, or null if
  /// unassigned. Only meaningful when [showAssignment] is true (admin/
  /// manager views -- see LeadListScreen) so the person doing the
  /// assigning can see at a glance whether a lead is already someone's
  /// before selecting it -- the main guard against accidentally
  /// assigning the same lead twice.
  final String? assigneeName;

  /// Whether to render the assignment badge at all. Kept separate from
  /// [assigneeName] because "unassigned" is itself a value worth
  /// showing (in orange) to admins/managers, but regular users -- who
  /// only ever see their own leads anyway -- shouldn't see it.
  final bool showAssignment;

  const LeadCard({
    super.key,
    required this.lead,
    this.onTap,
    this.onDelete,
    this.selectionMode = false,
    this.selected = false,
    this.onSelected,
    this.role,
    this.assigneeName,
    this.showAssignment = false,
  });

  Color get statusColor {
    switch (lead.status) {
      case "Qualified":
        return Colors.green;
      case "Follow-up":
        return Colors.orange;
      case "Booked":
        return Colors.blue;
      case "Lost":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: selectionMode
            ? () => onSelected?.call(!selected)
            : () => _openActions(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (selectionMode) ...[
                Checkbox(value: selected, onChanged: onSelected),
                const SizedBox(width: 4),
              ] else ...[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor,
                  child: Text(
                    lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (lead.isFollowUpOverdue) ...[
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 13,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 3),
                        ],
                        Expanded(
                          child: Text(
                            '${lead.phone} • ${lead.site}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: lead.isFollowUpOverdue
                                  ? Colors.red
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (showAssignment) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            assigneeName == null
                                ? Icons.person_off_outlined
                                : Icons.person_outline,
                            size: 12,
                            color: assigneeName == null
                                ? Colors.orange.shade800
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              assigneeName ?? 'Unassigned',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: assigneeName == null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: assigneeName == null
                                    ? Colors.orange.shade800
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  lead.status,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
                backgroundColor: statusColor,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                lead.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${lead.phone} • ${lead.site}'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('View details'),
              onTap: () {
                Navigator.pop(sheetContext);
                onTap?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.call_outlined),
              title: const Text('Call'),
              onTap: () {
                Navigator.pop(sheetContext);
                _call(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openWhatsApp(context, ref);
              },
            ),
            if (AppRoles.canDelete(role) && lead.id != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onDelete?.call();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(BuildContext context, WidgetRef ref) async {
    // Navigate into the lead's details page and let it open the dialer --
    // that page is what listens for the user returning from the call and
    // then pops up the feedback/outcome/reminder sheet automatically.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditLeadScreen(lead: lead, autoCall: true),
      ),
    );
  }

  Future<void> _openWhatsApp(BuildContext context, WidgetRef ref) async {
    final opened = await ContactActionService.openWhatsApp(
      phone: lead.phone,
      name: lead.name,
      site: lead.site,
    );
    if (opened && lead.id != null) {
      ref.read(activityServiceProvider).log(
            actionType: 'whatsapp_sent',
            leadId: lead.id,
            description: '${lead.name}: WhatsApp text message opened',
          );
    }
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
  }
}
