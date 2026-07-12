import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../models/lead_model.dart';

/// Manages free, device-local follow-up notifications.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timeZoneReady = false;

  static const _androidDetails = AndroidNotificationDetails(
    'follow_up_reminders',
    'Follow-up reminders',
    channelDescription: 'Reminders for leads that need a follow-up',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _notificationDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('ic_stat_notification');
    const apple = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: apple,
          macOS: apple,
          linux: LinuxInitializationSettings(
            defaultActionName: 'Open follow-up',
          ),
          windows: WindowsInitializationSettings(
            appName: 'PlottingBazaar CRM',
            appUserModelId: 'com.plottingbazaar.crm',
            guid: '9f8764aa-32fe-4470-b980-08f6f6508583',
          ),
          web: WebInitializationSettings(),
        ),
      );
      _initialized = true;
    } catch (error) {
      // Notifications should never prevent the CRM from opening.
      debugPrint('Notification initialization failed: $error');
    }
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (!_initialized) return false;

    try {
      if (kIsWeb) {
        final webPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              WebFlutterLocalNotificationsPlugin
            >();
        if (webPlugin == null) return false;
        if (webPlugin.permissionStatus == WebNotificationPermission.granted) {
          return true;
        }
        return await webPlugin.requestNotificationsPermission() ?? false;
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return await _plugin
                  .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin
                  >()
                  ?.requestNotificationsPermission() ??
              true;
        case TargetPlatform.iOS:
          return await _plugin
                  .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin
                  >()
                  ?.requestPermissions(alert: true, badge: true, sound: true) ??
              true;
        case TargetPlatform.macOS:
          return await _plugin
                  .resolvePlatformSpecificImplementation<
                    MacOSFlutterLocalNotificationsPlugin
                  >()
                  ?.requestPermissions(alert: true, badge: true, sound: true) ??
              true;
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          return true;
      }
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return false;
    }
  }

  /// Replaces scheduled reminders with one 9 AM local-time reminder per future
  /// lead follow-up. Web browsers do not support scheduled notifications.
  Future<void> syncFollowUpReminders(List<LeadModel> leads) async {
    await initialize();
    if (!_initialized || kIsWeb) return;

    try {
      await _configureTimeZone();
      await _plugin.cancelAll();

      final now = tz.TZDateTime.now(tz.local);
      for (final lead in leads) {
        final followUp = lead.followUpDate;
        if (followUp == null) continue;

        final reminderAt = tz.TZDateTime(
          tz.local,
          followUp.year,
          followUp.month,
          followUp.day,
          9,
        );
        if (!reminderAt.isAfter(now)) continue;

        await _plugin.zonedSchedule(
          id: _stableNotificationId(lead),
          title: 'Follow-up: ${lead.name}',
          body: lead.site.trim().isEmpty
              ? 'It is time to contact this lead.'
              : 'Contact this lead about ${lead.site}.',
          scheduledDate: reminderAt,
          notificationDetails: _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: lead.id,
        );
      }
    } catch (error) {
      debugPrint('Unable to schedule follow-up reminders: $error');
    }
  }

  Future<void> showDueReminderSummary(List<LeadModel> leads) async {
    await initialize();
    if (!_initialized || leads.isEmpty) return;

    try {
      final names = leads.take(2).map((lead) => lead.name).join(', ');
      final remaining = leads.length - 2;
      await _plugin.show(
        id: 910001,
        title: '${leads.length} follow-up${leads.length == 1 ? '' : 's'} due',
        body: remaining > 0
            ? '$names and $remaining more need attention.'
            : names,
        notificationDetails: _notificationDetails,
      );
    } catch (error) {
      debugPrint('Unable to show follow-up reminder: $error');
    }
  }

  Future<void> _configureTimeZone() async {
    if (_timeZoneReady) return;

    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (error) {
      debugPrint(
        'Using UTC for reminders because timezone lookup failed: $error',
      );
    }
    _timeZoneReady = true;
  }

  int _stableNotificationId(LeadModel lead) {
    final text = lead.id ?? '${lead.name}|${lead.phone}|${lead.followUpDate}';
    var hash = 17;
    for (final codeUnit in text.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x3fffffff;
    }
    return hash;
  }
}
