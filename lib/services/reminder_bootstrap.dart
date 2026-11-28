import 'package:shared_preferences/shared_preferences.dart';

import 'sunna_reminders.dart';

/// نتيجة تهيئة/ترحيل تذكيرات صيام السنن.
class ReminderBootstrapResult {
  const ReminderBootstrapResult({
    required this.migrated,
    required this.scheduled,
  });

  /// هل نُفِّذ الترحيل في هذه الدعوة؟
  final bool migrated;

  /// هل جُدولت التذكيرات الأسبوعية؟ (يعني أن إعداد المستخدم مفعّل)
  final bool scheduled;
}

/// ترحيل تذكيرات الإثنين/الخميس من الجدولة اليومية القديمة إلى الأسبوعية.
///
/// يُشغَّل عند **بدء التطبيق** (لا عند فتح شاشة القضاء)، مرة واحدة لكل نسخة
/// ترحيل. الترحيل يلغي المعرّفين القديمين (201/202) ثم يعيد جدولتهما أسبوعياً
/// فقط إذا كان إعداد المستخدم مفعّلاً — فلا تُنشأ تذكيرات لمن أطفأها، ولا
/// تتكرر الإشعارات عند تشغيل التطبيق عدة مرات.
class ReminderBootstrap {
  ReminderBootstrap(
    this.prefs, [
    this._sink = const NotificationReminderSink(),
  ]);

  /// رقم نسخة الترحيل الحالية (ارفع الرقم عند تغيير منطق الجدولة لاحقاً).
  static const int migrationVersion = 2;

  /// مفتاح حفظ آخر نسخة ترحيل طُبِّقت.
  static const String migrationKey = 'sunna_reminders_migration';

  final SharedPreferences prefs;
  final ReminderSink _sink;

  Future<ReminderBootstrapResult> run({
    required String mondayTitle,
    required String thursdayTitle,
    required String body,
    bool force = false,
  }) async {
    final int appliedVersion = prefs.getInt(migrationKey) ?? 0;
    if (!force && appliedVersion >= migrationVersion) {
      return const ReminderBootstrapResult(migrated: false, scheduled: false);
    }

    final bool enabled = prefs.getBool('sunna_fast_reminder') ?? false;

    // إلغاء الجدولة القديمة (كانت يومية) بنفس المعرّفين قبل أي إعادة جدولة.
    await _sink.cancel(SunnaReminders.mondayId);
    await _sink.cancel(SunnaReminders.thursdayId);

    if (enabled) {
      await SunnaReminders(_sink).apply(
        enabled: true,
        mondayTitle: mondayTitle,
        thursdayTitle: thursdayTitle,
        body: body,
      );
    }

    await prefs.setInt(migrationKey, migrationVersion);
    return ReminderBootstrapResult(migrated: true, scheduled: enabled);
  }
}
