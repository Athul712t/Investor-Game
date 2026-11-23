import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import 'profile.dart';

/// Hour of day (0..23) the player is most active, from 24 counters. 19 when there is no history. Ties go to the later hour.
int usualHour(List<int> hours) {
  var best = 19, top = 0;
  for (var h = 0; h < hours.length && h < 24; h++) {
    if (hours[h] > 0 && hours[h] >= top) {
      best = h;
      top = hours[h];
    }
  }
  return best;
}

/// The next local time to remind at [hour]:00. Today when the player has not played yet and it is still ahead,
/// otherwise tomorrow. Never in the past and never within 10 minutes of [now].
DateTime nextReminder(DateTime now, int hour, String lastActiveDay) {
  var at = DateTime(now.year, now.month, now.day, hour);
  if (lastActiveDay == dayKey(now)) at = DateTime(now.year, now.month, now.day + 1, hour);
  while (at.difference(now) < const Duration(minutes: 10)) {
    at = DateTime(at.year, at.month, at.day + 1, hour);
  }
  return at;
}

String reminderBody(int streak) =>
    streak > 0 ? 'A minute of play keeps your $streak day streak going.' : 'Start a streak today. A minute is enough.';

String hourLabel(int hour) => '${hour % 12 == 0 ? 12 : hour % 12} ${hour < 12 ? 'am' : 'pm'}';

/// Talks to the platform. Implementations swallow their errors: a reminder must never break the app.
abstract class ReminderScheduler {
  Future<bool> requestPermission();
  Future<void> schedule(DateTime at, String title, String body);
  Future<void> cancel();
}

/// Used on the web and wherever there is no plugin.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> schedule(DateTime at, String title, String body) async {}
  @override
  Future<void> cancel() async {}
}

class LocalReminderScheduler implements ReminderScheduler {
  static const _id = 1;
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  Future<void> _init() => _ready ??= _plugin.initialize(
    settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );

  @override
  Future<bool> requestPermission() async {
    try {
      await _init();
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> schedule(DateTime at, String title, String body) async {
    try {
      await _init();
      await _plugin.zonedSchedule(
        id: _id,
        title: title,
        body: body,
        // The instant of the local time, expressed in UTC: the device's own hour is respected.
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'streak_reminder',
            'Daily reminder',
            channelDescription: 'One gentle nudge a day to keep your streak going.',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  @override
  Future<void> cancel() async {
    try {
      await _init();
      await _plugin.cancel(id: _id);
    } catch (_) {}
  }
}

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => kIsWeb ? const NoopReminderScheduler() : LocalReminderScheduler(),
);

class ReminderService {
  ReminderService(this._ref);
  final Ref _ref;

  /// Schedules (opted in) or cancels (opted out) the single reminder from the current profile.
  Future<void> sync({DateTime? now}) async {
    try {
      final p = _ref.read(profileProvider);
      final scheduler = _ref.read(reminderSchedulerProvider);
      if (!p.notify) return await scheduler.cancel();
      final at = nextReminder(now ?? DateTime.now(), usualHour(p.hours), p.lastActiveDay);
      await scheduler.schedule(at, 'Keep your streak alive', reminderBody(p.streak));
    } catch (_) {}
  }
}

/// Read once from main.dart: syncs now, then again whenever the player is active or flips the setting.
final reminderServiceProvider = Provider<ReminderService>((ref) {
  final service = ReminderService(ref);
  ref.listen(profileProvider, (a, b) {
    if (a?.lastActiveDay != b.lastActiveDay || a?.streak != b.streak || a?.notify != b.notify) service.sync();
  });
  return service;
});
