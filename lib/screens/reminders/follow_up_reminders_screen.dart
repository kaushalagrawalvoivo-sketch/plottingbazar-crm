import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/contact_action_service.dart';
import '../../core/services/notification_service.dart';
import '../../models/lead_model.dart';
import '../../providers/lead_provider.dart';
import '../leads/edit_lead_screen.dart';

class FollowUpRemindersScreen extends ConsumerStatefulWidget {
  const FollowUpRemindersScreen({super.key});

  @override
  ConsumerState<FollowUpRemindersScreen> createState() =>
      _FollowUpRemindersScreenState();
}

class _FollowUpRemindersScreenState
    extends ConsumerState<FollowUpRemindersScreen> {
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadLeads);
  }

  Future<void> _loadLeads() async {
    setState(() => _loading = true);
    try {
      await ref.read(leadProvider.notifier).loadLeads();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load follow-up reminders.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enableAndSync(List<LeadModel> leads) async {
    setState(() => _syncing = true);
    final allowed = await NotificationService.instance.requestPermission();
    if (allowed) {
      await NotificationService.instance.syncFollowUpReminders(leads);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allowed
                ? 'Follow-up alerts are synced for 9:00 AM local time.'
                : 'Notifications are not enabled. You can continue using the in-app list.',
          ),
        ),
      );
      setState(() => _syncing = false);
    }
  }

  Future<void> _notifyDue(List<LeadModel> dueLeads) async {
    final allowed = await NotificationService.instance.requestPermission();
    if (allowed) {
      await NotificationService.instance.showDueReminderSummary(dueLeads);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allowed
              ? 'Due follow-up notification sent.'
              : 'Enable notifications to receive device alerts.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leads = ref.watch(leadProvider);
    final reminders = leads.where((lead) => lead.followUpDate != null).toList()
      ..sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));

    final today = _dateOnly(DateTime.now());
    final due = reminders
        .where((lead) => !_dateOnly(lead.followUpDate!).isAfter(today))
        .toList();
    final upcoming = reminders
        .where((lead) => _dateOnly(lead.followUpDate!).isAfter(today))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-up Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh reminders',
            onPressed: _loadLeads,
          ),
        ],
      ),
      body: _loading && leads.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLeads,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _summaryCard(
                    context: context,
                    due: due.length,
                    upcoming: upcoming.length,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _syncing
                        ? null
                        : () => _enableAndSync(reminders),
                    icon: _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.notifications_active_outlined),
                    label: Text(
                      _syncing
                          ? 'Syncing alerts...'
                          : 'Enable & sync device alerts',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Android and iOS reminders are scheduled for 9:00 AM local time. Browser reminders stay available in this list.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (due.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          'Due now',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _notifyDue(due),
                          icon: const Icon(
                            Icons.notification_important_outlined,
                          ),
                          label: const Text('Notify'),
                        ),
                      ],
                    ),
                    ...due.map((lead) => _reminderTile(lead, today)),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Upcoming',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (upcoming.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No upcoming follow-ups scheduled.'),
                      ),
                    )
                  else
                    ...upcoming.map((lead) => _reminderTile(lead, today)),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard({
    required BuildContext context,
    required int due,
    required int upcoming,
  }) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.event_available_outlined, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                due == 0
                    ? 'No follow-ups due today'
                    : '$due follow-up${due == 1 ? '' : 's'} need attention',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text('$upcoming upcoming'),
          ],
        ),
      ),
    );
  }

  Widget _reminderTile(LeadModel lead, DateTime today) {
    final date = _dateOnly(lead.followUpDate!);
    final overdue = date.isBefore(today);
    final dueToday = date == today;
    final label = overdue
        ? 'Overdue · ${DateFormat('dd MMM').format(date)}'
        : dueToday
        ? 'Due today'
        : DateFormat('EEE, dd MMM').format(date);
    final color = overdue
        ? Colors.red
        : dueToday
        ? Colors.orange
        : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Icon(overdue ? Icons.warning_amber_rounded : Icons.event),
        ),
        title: Text(lead.name),
        subtitle: Text(
          '$label\n${lead.site.isEmpty ? lead.phone : '${lead.site} · ${lead.phone}'}',
        ),
        isThreeLine: true,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditLeadScreen(lead: lead)),
          );
          await _loadLeads();
        },
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: 'Call',
              icon: const Icon(Icons.call_outlined),
              onPressed: () => _call(lead),
            ),
            IconButton(
              tooltip: 'WhatsApp',
              icon: const Icon(Icons.chat_outlined),
              onPressed: () => _whatsApp(lead),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(LeadModel lead) async {
    final opened = await ContactActionService.call(lead.phone);
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the phone app.')),
    );
  }

  Future<void> _whatsApp(LeadModel lead) async {
    final opened = await ContactActionService.openWhatsApp(
      phone: lead.phone,
      name: lead.name,
      site: lead.site,
    );
    if (!mounted || opened) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
