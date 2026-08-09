import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/call_log_service.dart';
import '../../core/services/contact_action_service.dart';
import '../../core/services/feedback_service.dart';
import '../../core/services/notification_service.dart';
import '../../models/call_log_model.dart';
import '../../models/lead_feedback_model.dart';
import '../../models/lead_model.dart';
import '../../providers/lead_provider.dart';

class EditLeadScreen extends ConsumerStatefulWidget {
  const EditLeadScreen({super.key, required this.lead, this.autoCall = false});
  final LeadModel lead;

  /// When true, immediately opens the phone dialer for this lead as soon
  /// as the screen appears (used when "Call" is tapped from the lead list,
  /// so the same post-call feedback/reminder flow below applies there too).
  final bool autoCall;

  @override
  ConsumerState<EditLeadScreen> createState() => _EditLeadScreenState();
}

/// Merged timeline item so calls and feedback can render in one list,
/// sorted by time, without either screen needing to know about the other.
class _TimelineItem {
  final DateTime time;
  final bool isCall;
  final CallLogModel? call;
  final LeadFeedbackModel? feedback;
  _TimelineItem.call(this.call)
    : time = call!.createdAt ?? DateTime.now(),
      isCall = true,
      feedback = null;
  _TimelineItem.feedback(this.feedback)
    : time = feedback!.createdAt ?? DateTime.now(),
      isCall = false,
      call = null;
}

class _EditLeadScreenState extends ConsumerState<EditLeadScreen>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _site;
  late final TextEditingController _budget;
  late String _status;
  String? _source;
  String? _purpose;
  bool _saving = false;

  final _callLogService = CallLogService();
  final _feedbackService = FeedbackService();
  final _feedbackController = TextEditingController();
  DateTime? _nextFollowUp;
  TimeOfDay? _nextFollowUpTime;
  bool _historyLoading = true;
  bool _savingFeedback = false;
  List<CallLogModel> _callLogs = [];
  List<LeadFeedbackModel> _feedbackList = [];

  /// True from the moment the phone dialer is opened until the app is
  /// resumed (i.e. the user has returned after the call ended/was
  /// cancelled). Only then do we show the post-call sheet -- showing it
  /// immediately, before the call happens, was the bug.
  bool _awaitingCallReturn = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.lead.name);
    _phone = TextEditingController(text: widget.lead.phone);
    _site = TextEditingController(text: widget.lead.site);
    _budget = TextEditingController(
      text: widget.lead.budget == null ? '' : widget.lead.budget!.toStringAsFixed(0),
    );
    _status = widget.lead.status;
    _source = widget.lead.source;
    _purpose = widget.lead.purpose;
    _loadHistory();
    WidgetsBinding.instance.addObserver(this);
    if (widget.autoCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _call();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    _phone.dispose();
    _site.dispose();
    _budget.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _awaitingCallReturn) {
      _awaitingCallReturn = false;
      // Wait a beat for the UI to finish resuming before popping up the
      // sheet, so it doesn't appear while the dialer is still animating away.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPostCallSheet();
      });
    }
  }

  Future<void> _loadHistory() async {
    final leadId = widget.lead.id;
    if (leadId == null) {
      setState(() => _historyLoading = false);
      return;
    }
    setState(() => _historyLoading = true);
    try {
      final results = await Future.wait([
        _callLogService.getCallLogs(leadId),
        _feedbackService.getFeedback(leadId),
      ]);
      if (!mounted) return;
      setState(() {
        _callLogs = results[0] as List<CallLogModel>;
        _feedbackList = results[1] as List<LeadFeedbackModel>;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not load call/feedback history.')));
      }
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  List<_TimelineItem> get _timeline {
    final items = <_TimelineItem>[
      ..._callLogs.map(_TimelineItem.call),
      ..._feedbackList.map(_TimelineItem.feedback),
    ];
    items.sort((a, b) => b.time.compareTo(a.time));
    return items;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final previousStatus = widget.lead.status;
    try {
      await ref.read(leadProvider.notifier).updateLead(
            widget.lead.copyWith(
              name: _name.text.trim(),
              phone: _phone.text.trim(),
              site: _site.text.trim(),
              status: _status,
              source: _source,
              purpose: _purpose,
              budget: double.tryParse(_budget.text.trim()),
            ),
            previousStatus: previousStatus,
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _call() async {
    final opened = await ContactActionService.call(_phone.text);
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the phone app.')));
      return;
    }
    // Don't show the outcome/feedback sheet yet -- the dialer is only just
    // opening, the call hasn't happened. Wait until the app resumes (the
    // user came back after the call ended) via didChangeAppLifecycleState.
    _awaitingCallReturn = true;
  }

  Future<void> _openWhatsApp() async {
    await ContactActionService.openWhatsApp(
      phone: _phone.text,
      name: _name.text,
      site: _site.text,
    );
    await ref.read(activityServiceProvider).log(
          actionType: 'whatsapp_sent',
          leadId: widget.lead.id,
          description: '${_name.text}: WhatsApp text message opened',
        );
  }

  /// Free-tier media send: picks a photo/video/audio/document and opens the
  /// native share sheet so the user can attach it directly inside WhatsApp.
  Future<void> _sendMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    final files = result.files
        .where((f) => f.path != null)
        .map((f) => XFile(f.path!))
        .toList();
    if (files.isEmpty) return;

    final shared = await ContactActionService.shareFiles(
      files: files,
      caption: 'Namaste ${_name.text}, PlottingBazaar CRM se bhej rahe hain.',
    );
    if (!mounted) return;
    if (shared) {
      await ref.read(activityServiceProvider).log(
            actionType: 'whatsapp_sent',
            leadId: widget.lead.id,
            description:
                '${_name.text}: shared ${files.length} file(s) (pick WhatsApp in the share sheet)',
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose WhatsApp in the share sheet to attach it.')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sharing was cancelled or not supported here.')));
    }
  }

  Future<void> _showPostCallSheet() async {
    final leadId = widget.lead.id;
    if (leadId == null) return;
    String outcome = CallLogModel.outcomes.first;
    final notesController = TextEditingController();
    final durationController = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (_, setSheetState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('How did the call go?', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(_name.text, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: outcome,
                  decoration: const InputDecoration(labelText: 'Call outcome'),
                  items: CallLogModel.outcomes
                      .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                      .toList(),
                  onChanged: (v) => setSheetState(() => outcome = v ?? outcome),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (seconds, optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Call notes (optional)',
                  ),
                ),
                const Divider(height: 28),
                Text('Feedback', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _feedbackController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'What did the customer say? Next steps?',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          _nextFollowUp ?? DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setSheetState(() => _nextFollowUp = picked);
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _nextFollowUp == null
                        ? 'Set follow-up / reminder date'
                        : DateFormat('dd MMM yyyy').format(_nextFollowUp!),
                  ),
                ),
                if (_nextFollowUp != null) ...[
                  const SizedBox(height: 10),
                  Text('Reminder time', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  _reminderTimeChips(setSheetState),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Save'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: const Text('Not now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted) return;
    // Reflect any date/time picked inside the sheet on the page underneath.
    setState(() {});
    if (saved != true) return;

    await _callLogService.addCallLog(
      CallLogModel(
        leadId: leadId,
        outcome: outcome,
        durationSeconds: int.tryParse(durationController.text.trim()),
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      ),
    );
    await ref.read(activityServiceProvider).log(
          actionType: 'call_logged',
          leadId: leadId,
          description: '${_name.text}: call outcome "$outcome"',
        );

    // Reuses the same save path as the always-visible feedback section
    // below, so feedback text and the follow-up reminder (with its own
    // chosen time, not a hardcoded 9 AM) get saved and the on-device
    // reminder is scheduled right away.
    await _saveFeedback(showEmptyWarning: false);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Call logged.')));
    }
  }

  /// Quick-pick chips for a reminder time, plus a custom option -- so
  /// every lead's reminder doesn't fire at the same fixed 9 AM. Accepts
  /// either the page's own setState or a bottom sheet's setSheetState so
  /// it can be reused in both places.
  Widget _reminderTimeChips(void Function(VoidCallback) rebuild) {
    const options = [
      TimeOfDay(hour: 9, minute: 0),
      TimeOfDay(hour: 12, minute: 0),
      TimeOfDay(hour: 15, minute: 0),
      TimeOfDay(hour: 18, minute: 0),
    ];
    final isCustom =
        _nextFollowUpTime != null && !options.contains(_nextFollowUpTime);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option.format(context)),
            selected: _nextFollowUpTime == option,
            onSelected: (_) => rebuild(() => _nextFollowUpTime = option),
          ),
        ActionChip(
          avatar: const Icon(Icons.more_time, size: 16),
          label: Text(isCustom ? _nextFollowUpTime!.format(context) : 'Custom'),
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _nextFollowUpTime ?? const TimeOfDay(hour: 9, minute: 0),
            );
            if (picked != null) rebuild(() => _nextFollowUpTime = picked);
          },
        ),
      ],
    );
  }

  DateTime _combinedFollowUp() {
    final date = _nextFollowUp!;
    final time = _nextFollowUpTime ?? const TimeOfDay(hour: 9, minute: 0);
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _saveFeedback({bool showEmptyWarning = true}) async {
    final leadId = widget.lead.id;
    if (leadId == null) return;
    final text = _feedbackController.text.trim();
    final hasFollowUp = _nextFollowUp != null;

    // Previously this silently did nothing whenever the feedback text box
    // was empty -- even if a follow-up date/time WAS set -- which is why
    // reminders looked like they "weren't saving". Now a follow-up alone
    // is enough to save.
    if (text.isEmpty && !hasFollowUp) {
      if (showEmptyWarning && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add feedback text or set a follow-up date to save.'),
          ),
        );
      }
      return;
    }

    setState(() => _savingFeedback = true);
    try {
      final combinedFollowUp = hasFollowUp ? _combinedFollowUp() : null;
      final savedText = text.isEmpty ? 'Follow-up scheduled' : text;

      await _feedbackService.addFeedback(
        LeadFeedbackModel(
          leadId: leadId,
          feedback: savedText,
          nextFollowUpDate: combinedFollowUp,
        ),
      );
      await ref.read(activityServiceProvider).log(
            actionType: 'feedback_added',
            leadId: leadId,
            description: '${_name.text}: $savedText',
          );

      // Keep the lead's own follow-up date in sync with the latest
      // feedback, so it also shows up correctly on the Reminders screen
      // and lead card -- and actually schedule the on-device reminder
      // right now. This used to only happen if someone separately opened
      // the Reminders tab and tapped "sync", which is why reminders
      // looked like they weren't saving at all.
      if (combinedFollowUp != null) {
        final updatedLead = widget.lead.copyWith(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          site: _site.text.trim(),
          status: _status,
          source: _source,
          purpose: _purpose,
          budget: double.tryParse(_budget.text.trim()),
          followUpDate: combinedFollowUp,
        );
        await ref.read(leadProvider.notifier).updateLead(updatedLead);
        await NotificationService.instance.requestPermission();
        await NotificationService.instance.scheduleReminder(updatedLead);
      }

      _feedbackController.clear();
      if (mounted) {
        setState(() {
          _nextFollowUp = null;
          _nextFollowUpTime = null;
        });
      }
      await _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              combinedFollowUp != null
                  ? 'Feedback saved and reminder set for ${DateFormat('dd MMM, hh:mm a').format(combinedFollowUp)}.'
                  : 'Feedback saved.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingFeedback = false);
    }
  }

  Future<void> _pickFollowUpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextFollowUp ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _nextFollowUp = picked);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lead details')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _field(_name, 'Customer name'),
          const SizedBox(height: 14),
          _field(_phone, 'Phone number'),
          const SizedBox(height: 14),
          _field(_site, 'Interested site'),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: LeadModel.statusItems(_status)
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _status = v!),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _source,
            decoration: const InputDecoration(labelText: 'Lead source'),
            items: LeadModel.sourceItems(_source)
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _source = v),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _purpose,
            decoration: const InputDecoration(labelText: 'Purpose'),
            items: LeadModel.purposes
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (v) => setState(() => _purpose = v),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _budget,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Budget in ₹'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.lead.id == null ? null : _call,
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openWhatsApp,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _sendMedia,
            icon: const Icon(Icons.attach_file),
            label: const Text('Send photo / video / audio / doc via WhatsApp'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Updating...' : 'Update lead'),
          ),
          const Divider(height: 40),

          if (widget.lead.id != null) ...[
            Text('Add feedback', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'What happened / next steps',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickFollowUpDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _nextFollowUp == null
                    ? 'Set next follow-up / reminder (optional)'
                    : DateFormat('dd MMM yyyy').format(_nextFollowUp!),
              ),
            ),
            if (_nextFollowUp != null) ...[
              const SizedBox(height: 10),
              Text('Reminder time', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              _reminderTimeChips(setState),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _savingFeedback ? null : () => _saveFeedback(),
                child: Text(_savingFeedback ? 'Saving...' : 'Save feedback / reminder'),
              ),
            ),
            const SizedBox(height: 24),
            Text('History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (_historyLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ))
            else if (_timeline.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No calls or feedback logged yet.'),
              )
            else
              ..._timeline.map(_timelineTile),
          ],
        ],
      ),
    ),
  );

  Widget _timelineTile(_TimelineItem item) {
    final time = DateFormat('dd MMM, hh:mm a').format(item.time);
    if (item.isCall) {
      final call = item.call!;
      return Card(
        child: ListTile(
          leading: const Icon(Icons.call_outlined),
          title: Text('Call: ${call.outcome}'),
          subtitle: Text(
            [
              if (call.durationSeconds != null) '${call.durationSeconds}s',
              if (call.notes != null && call.notes!.isNotEmpty) call.notes!,
              time,
            ].join(' - '),
          ),
        ),
      );
    }
    final feedback = item.feedback!;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.comment_outlined),
        title: Text(feedback.feedback),
        subtitle: Text(
          feedback.nextFollowUpDate != null
              ? 'Next follow-up: ${DateFormat('dd MMM yyyy').format(feedback.nextFollowUpDate!)}  -  $time'
              : time,
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) => TextFormField(
    controller: controller,
    validator: (v) => v == null || v.trim().isEmpty ? '$label is required' : null,
    decoration: InputDecoration(labelText: label),
  );
}
