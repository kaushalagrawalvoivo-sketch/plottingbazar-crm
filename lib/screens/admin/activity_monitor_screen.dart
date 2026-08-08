import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/activity_service.dart';
import '../../models/activity_log_model.dart';

/// Admin-only live feed: shows what every employee is doing (calls logged,
/// feedback added, leads assigned/created, WhatsApp messages opened) as it
/// happens, using a Supabase Realtime stream -- no manual refresh needed.
class ActivityMonitorScreen extends StatefulWidget {
  const ActivityMonitorScreen({super.key});

  @override
  State<ActivityMonitorScreen> createState() => _ActivityMonitorScreenState();
}

class _ActivityMonitorScreenState extends State<ActivityMonitorScreen> {
  final _service = ActivityService();

  IconData _iconFor(String actionType) {
    switch (actionType) {
      case ActivityLogModel.callLogged:
        return Icons.call_outlined;
      case ActivityLogModel.feedbackAdded:
        return Icons.comment_outlined;
      case ActivityLogModel.leadAssigned:
        return Icons.person_add_alt_1_outlined;
      case ActivityLogModel.leadCreated:
        return Icons.groups_outlined;
      case ActivityLogModel.leadStatusChanged:
        return Icons.sync_alt_outlined;
      case ActivityLogModel.customerCreated:
        return Icons.person_outline;
      case ActivityLogModel.whatsappSent:
        return Icons.chat_outlined;
      default:
        return Icons.bolt_outlined;
    }
  }

  Color _colorFor(String actionType) {
    switch (actionType) {
      case ActivityLogModel.callLogged:
        return Colors.indigo;
      case ActivityLogModel.feedbackAdded:
        return Colors.teal;
      case ActivityLogModel.leadAssigned:
        return Colors.purple;
      case ActivityLogModel.leadCreated:
        return Colors.blue;
      case ActivityLogModel.leadStatusChanged:
        return Colors.orange;
      case ActivityLogModel.customerCreated:
        return Colors.green;
      case ActivityLogModel.whatsappSent:
        return Colors.green.shade700;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live activity monitor'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Row(
                children: [
                  Icon(Icons.circle, size: 10, color: Colors.green),
                  SizedBox(width: 6),
                  Text('Live'),
                ],
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<ActivityLogModel>>(
        stream: _service.streamRecentActivity(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load activity: ${snapshot.error}'),
              ),
            );
          }
          final activities = snapshot.data ?? [];
          if (activities.isEmpty) {
            return const Center(
              child: Text('No activity yet. Actions will appear here live.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final activity = activities[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _colorFor(activity.actionType),
                    child: Icon(
                      _iconFor(activity.actionType),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(activity.actorName),
                  subtitle: Text(activity.description),
                  trailing: Text(
                    activity.createdAt == null
                        ? ''
                        : DateFormat('hh:mm a\ndd MMM').format(activity.createdAt!),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
