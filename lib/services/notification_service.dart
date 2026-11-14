import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  NotificationService._();

  Future<void> init() async {
    try {
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('ic_notification');
    await _plugin.initialize(const InitializationSettings(android: androidInit));
    } catch (_) {}
  }

  Future<void> requestPermissions() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'azkari_reminders_channel',
      'تذكيرات أذكاري اليومية',
      channelDescription: 'تذكير أذكار الصباح والمساء والنوم بصوت أذكاري',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      sound: RawResourceAndroidNotificationSound('splash_ayah'),
      playSound: true,
    );

    try { await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, ); } catch (_) {}
  }

  Future<void> cancel(int id) async => _plugin.cancel(id);
}
