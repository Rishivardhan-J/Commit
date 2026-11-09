import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications only. Hard cap: one gentle evening reminder per day, no
/// guilt copy. It is re-planned on every app open/commit, so a user who already
/// committed today is never nudged, and an absent user gets one nudge, not a flood.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    try {
      tzdata.initializeTimeZones();
      final name = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(requestAlertPermission: false),
        ),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> requestPermission() async {
    if (!_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  }

  Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
  }

  /// Next occurrence of [hour]:00: today if still ahead and the day isn't
  /// committed yet, otherwise tomorrow.
  static DateTime nextReminder(DateTime now, int hour, {required bool committedToday}) {
    var t = DateTime(now.year, now.month, now.day, hour);
    if (committedToday || !t.isAfter(now)) t = DateTime(now.year, now.month, now.day + 1, hour);
    return t;
  }

  Future<void> scheduleEvening({
    required int hour,
    required int streak,
    required bool committedToday,
  }) async {
    if (!_ready) return;
    await _plugin.cancel(id: 1);
    final when = nextReminder(DateTime.now(), hour, committedToday: committedToday);
    await _plugin.zonedSchedule(
      id: 1,
      title: 'Ready to commit today?',
      body: streak > 0 ? 'Day ${streak + 1} is one small commit away.' : 'One small commit starts a new streak.',
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('commit_daily', 'Daily commit',
            channelDescription: 'One gentle reminder to commit your day'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
