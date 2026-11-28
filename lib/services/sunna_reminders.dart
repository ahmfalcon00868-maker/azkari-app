import 'notification_service.dart';

/// واجهة مختصرة لجدولة الإشعارات تسمح باختبار المنطق بدون أي إضافات نظام.
abstract class ReminderSink {
  Future<void> scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int weekday,
    required int hour,
    required int minute,
  });

  Future<void> cancel(int id);
}

/// التنفيذ الحقيقي عبر خدمة الإشعارات.
class NotificationReminderSink implements ReminderSink {
  const NotificationReminderSink();

  @override
  Future<void> scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int weekday,
    required int hour,
    required int minute,
  }) =>
      NotificationService.instance.scheduleWeekly(
        id: id,
        title: title,
        body: body,
        weekday: weekday,
        hour: hour,
        minute: minute,
      );

  @override
  Future<void> cancel(int id) => NotificationService.instance.cancel(id);
}

/// تذكيرات صيام الإثنين والخميس — أسبوعية لا يومية.
class SunnaReminders {
  SunnaReminders([this._sink = const NotificationReminderSink()]);

  final ReminderSink _sink;

  static const int mondayId = 201;
  static const int thursdayId = 202;
  static const int hour = 4;
  static const int mondayMinute = 30;
  static const int thursdayMinute = 35;

  /// يفعّل/يلغي التذكيرين معاً. التفعيل آمن للتكرار: يُعيد استخدام نفس المعرّفين.
  Future<void> apply({
    required bool enabled,
    required String mondayTitle,
    required String thursdayTitle,
    required String body,
  }) async {
    if (enabled) {
      await _sink.scheduleWeekly(
        id: mondayId,
        title: mondayTitle,
        body: body,
        weekday: DateTime.monday,
        hour: hour,
        minute: mondayMinute,
      );
      await _sink.scheduleWeekly(
        id: thursdayId,
        title: thursdayTitle,
        body: body,
        weekday: DateTime.thursday,
        hour: hour,
        minute: thursdayMinute,
      );
    } else {
      await _sink.cancel(mondayId);
      await _sink.cancel(thursdayId);
    }
  }
}
