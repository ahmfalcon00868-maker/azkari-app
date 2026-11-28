import 'package:flutter_test/flutter_test.dart';

import 'package:azkari/services/reminder_schedule.dart';
import 'package:azkari/services/sun_times.dart';
import 'package:azkari/services/sunna_reminders.dart';
import 'package:azkari/services/widget_sync_logic.dart';

/// تنفيذ وهمي لجدولة الإشعارات: يسجّل كل استدعاء ويحاكي حالة النظام.
class _FakeReminderSink implements ReminderSink {
  final Map<int, Map<String, dynamic>> active = <int, Map<String, dynamic>>{};
  final List<int> cancelled = <int>[];
  final List<Map<String, dynamic>> scheduled = <Map<String, dynamic>>[];

  @override
  Future<void> scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int weekday,
    required int hour,
    required int minute,
  }) async {
    final spec = <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'weekday': weekday,
      'hour': hour,
      'minute': minute,
    };
    scheduled.add(spec);
    active[id] = spec;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    active.remove(id);
  }
}

void main() {
  group('nextWeeklyOccurrence — تذكير أسبوعي لا يومي', () {
    test('نفس اليوم قبل الموعد ⇒ اليوم', () {
      final now = DateTime(2026, 11, 23, 3, 0); // الاثنين
      expect(now.weekday, DateTime.monday);
      expect(
        nextWeeklyOccurrence(now, weekday: DateTime.monday, hour: 4, minute: 30),
        DateTime(2026, 11, 23, 4, 30),
      );
    });

    test('نفس اليوم بعد الموعد ⇒ الأسبوع القادم', () {
      final now = DateTime(2026, 11, 23, 5, 0);
      expect(
        nextWeeklyOccurrence(now, weekday: DateTime.monday, hour: 4, minute: 30),
        DateTime(2026, 11, 30, 4, 30),
      );
    });

    test('عند الموعد بالضبط ⇒ الأسبوع القادم (لا إطلاق فوري)', () {
      final now = DateTime(2026, 11, 23, 4, 30);
      expect(
        nextWeeklyOccurrence(now, weekday: DateTime.monday, hour: 4, minute: 30),
        DateTime(2026, 11, 30, 4, 30),
      );
    });

    test('يوم آخر في الأسبوع ⇒ الاثنين القادم', () {
      final now = DateTime(2026, 11, 25, 12, 0); // الأربعاء
      final next =
          nextWeeklyOccurrence(now, weekday: DateTime.monday, hour: 4, minute: 30);
      expect(next.weekday, DateTime.monday);
      expect(next, DateTime(2026, 11, 30, 4, 30));
    });

    test('الخميس: قبل الموعد اليوم، وبعده الأسبوع القادم', () {
      final early = DateTime(2026, 11, 26, 4, 0);
      final late = DateTime(2026, 11, 26, 5, 0);

      final fromEarly = nextWeeklyOccurrence(early,
          weekday: DateTime.thursday, hour: 4, minute: 35);
      final fromLate = nextWeeklyOccurrence(late,
          weekday: DateTime.thursday, hour: 4, minute: 35);

      expect(fromEarly, DateTime(2026, 11, 26, 4, 35));
      expect(fromLate, DateTime(2026, 12, 3, 4, 35));
      expect(fromLate.weekday, DateTime.thursday);
    });

    test('النتيجة دائماً في المستقبل وبيوم الأسبوع المطلوب', () {
      for (var day = 1; day <= 30; day++) {
        for (final weekday in [DateTime.monday, DateTime.thursday]) {
          final now = DateTime(2026, 11, day, 4, 45);
          final next = nextWeeklyOccurrence(now,
              weekday: weekday, hour: 4, minute: 30);
          expect(next.weekday, weekday);
          expect(next.isAfter(now), isTrue);
          expect(next.difference(now).inDays, lessThan(8));
        }
      }
    });
  });

  group('نافذة سنن الجمعة — مربوطة بالمغرب الفعلي', () {
    final thursdayMaghrib = DateTime(2026, 11, 26, 16, 57);
    final fridayMaghrib = DateTime(2026, 11, 27, 16, 56);

    bool window(DateTime now) => isFridaySunnahWindow(
          now,
          thursdayMaghrib: thursdayMaghrib,
          fridayMaghrib: fridayMaghrib,
        );

    test('الخميس قبل المغرب ⇒ خارج النافذة (حتى لو كانت الساعة 17:00)', () {
      expect(window(DateTime(2026, 11, 26, 16, 0)), isFalse);
      expect(window(DateTime(2026, 11, 26, 16, 56)), isFalse);
    });

    test('الخميس بعد المغرب ⇒ داخل النافذة', () {
      expect(window(thursdayMaghrib), isTrue);
      expect(window(DateTime(2026, 11, 26, 18, 0)), isTrue);
      expect(window(DateTime(2026, 11, 26, 23, 59)), isTrue);
    });

    test('الجمعة قبل المغرب ⇒ داخل النافذة', () {
      expect(window(DateTime(2026, 11, 27, 0, 30)), isTrue);
      expect(window(DateTime(2026, 11, 27, 12, 0)), isTrue);
      expect(window(DateTime(2026, 11, 27, 16, 55)), isTrue);
    });

    test('الجمعة بعد المغرب ⇒ خارج النافذة (حتى لو كانت الساعة 17:30)', () {
      expect(window(fridayMaghrib), isFalse);
      expect(window(DateTime(2026, 11, 27, 17, 30)), isFalse);
    });

    test('مغرب الصيف مختلف عن مغرب الشتاء (لا وقت ثابت)', () {
      final summer = maghribFor(DateTime(2026, 6, 15),
          latitude: 30.0444, longitude: 31.2357);
      final winter = maghribFor(DateTime(2026, 1, 15),
          latitude: 30.0444, longitude: 31.2357);
      expect(summer, isNotNull);
      expect(winter, isNotNull);
      expect(summer!.hour == winter!.hour && summer.minute == winter.minute,
          isFalse);
    });

    test('النافذة تُحسب تلقائياً لأسبوع اليوم المعطى', () {
      final friday = DateTime(2026, 11, 27, 12, 0);
      final w = fridaySunnahWindow(friday,
          latitude: 30.0444, longitude: 31.2357);
      expect(w.start, isNotNull);
      expect(w.end, isNotNull);
      expect(w.end!.isAfter(w.start!), isTrue);
      final hours = w.end!.difference(w.start!).inMinutes / 60.0;
      expect(hours, greaterThan(23));
      expect(hours, lessThan(25));
      expect(isFridaySunnahWindow(friday,
              thursdayMaghrib: w.start!, fridayMaghrib: w.end!),
          isTrue);
    });
  });

  group('حساب الشروق/الغروب محلياً', () {
    test('القاهرة 21 يونيو ≈ 16:00 UTC للغروب', () {
      final times = computeSunTimes(
          date: DateTime(2026, 6, 21), latitude: 30.0444, longitude: 31.2357);
      final sunset = times.sunset!.toUtc();
      expect(sunset.hour, inInclusiveRange(15, 16));
      expect(times.sunrise!.isBefore(times.sunset!), isTrue);
    });

    test('لندن 21 يونيو ≈ 20:20 UTC للغروب', () {
      final times = computeSunTimes(
          date: DateTime(2026, 6, 21), latitude: 51.5, longitude: -0.12);
      final sunset = times.sunset!.toUtc();
      expect(sunset.hour, 20);
      expect(sunset.minute, inInclusiveRange(10, 35));
    });

    test('المناطق القطبية صيفاً: لا غروب ⇒ null (لا نعرض نافذة خاطئة)', () {
      final times = computeSunTimes(
          date: DateTime(2026, 6, 21), latitude: 78.22, longitude: 15.65);
      expect(times.sunset, isNull);
      expect(
        fridaySunnahWindow(DateTime(2026, 6, 19),
                latitude: 78.22, longitude: 15.65)
            .start,
        isNull,
      );
    });

    test('إحداثيات غير صالحة لا تُسبب استثناء', () {
      expect(
        computeSunTimes(
                date: DateTime(2026, 6, 21), latitude: 200, longitude: 0)
            .sunset,
        isNull,
      );
    });
  });

  group('تذكيرات صيام السنن: تفعيل / إلغاء / إعادة تفعيل', () {
    test('التفعيل يجدول الاثنين 4:30 والخميس 4:35 فقط', () async {
      final sink = _FakeReminderSink();
      final reminders = SunnaReminders(sink);

      await reminders.apply(
        enabled: true,
        mondayTitle: 'صيام الإثنين',
        thursdayTitle: 'صيام الخميس',
        body: 'لا تنس صيام اليوم',
      );

      expect(sink.scheduled, hasLength(2));
      expect(sink.active.keys, containsAll(<int>[201, 202]));

      final monday = sink.active[201]!;
      expect(monday['weekday'], DateTime.monday);
      expect(monday['hour'], 4);
      expect(monday['minute'], 30);

      final thursday = sink.active[202]!;
      expect(thursday['weekday'], DateTime.thursday);
      expect(thursday['hour'], 4);
      expect(thursday['minute'], 35);
    });

    test('الإلغاء يزيل التذكيرين من النظام', () async {
      final sink = _FakeReminderSink();
      final reminders = SunnaReminders(sink);

      await reminders.apply(
        enabled: true,
        mondayTitle: 'm',
        thursdayTitle: 't',
        body: 'b',
      );
      expect(sink.active, hasLength(2));

      await reminders.apply(
        enabled: false,
        mondayTitle: 'm',
        thursdayTitle: 't',
        body: 'b',
      );

      expect(sink.cancelled, containsAll(<int>[201, 202]));
      expect(sink.active, isEmpty);
    });

    test('إعادة التفعيل تعيد الجدولة بنفس المعرّفين دون تكرار', () async {
      final sink = _FakeReminderSink();
      final reminders = SunnaReminders(sink);

      await reminders.apply(
          enabled: true, mondayTitle: 'm', thursdayTitle: 't', body: 'b');
      await reminders.apply(
          enabled: false, mondayTitle: 'm', thursdayTitle: 't', body: 'b');
      await reminders.apply(
          enabled: true, mondayTitle: 'm', thursdayTitle: 't', body: 'b');
      // تفعيل مكرر (مثلاً إعادة فتح الشاشة) لا يستحدث تذكيرات إضافية
      await reminders.apply(
          enabled: true, mondayTitle: 'm', thursdayTitle: 't', body: 'b');

      expect(sink.active.keys.toSet(), <int>{201, 202});
      expect(sink.scheduled, hasLength(6)); // 2 في كل تفعيل × 3 تفعيلات
      expect(
        sink.scheduled.map((e) => e['weekday']).toSet(),
        <int>{DateTime.monday, DateTime.thursday},
      );
    });
  });

  group('دمج ويدجت السبحة مع التطبيق', () {
    test('مراجعة أحدث وذكر مختلف ⇒ يتبنّى التطبيق ذكر الويدجت', () {
      final plan = planTasbihSync(
        widget: const WidgetTasbihSnapshot(
            zikr: 'أستغفر الله', count: 0, lifetime: 120, revision: 7),
        appZikr: 'سبحان الله وبحمده',
        appCount: 33,
        appLifetime: 100,
        seenRevision: 5,
        appCountsByPhrase: const {
          'أستغفر الله': 12,
          'سبحان الله وبحمده': 33,
        },
      );
      expect(plan.zikr, 'أستغفر الله');
      expect(plan.adoptedZikr, isTrue);
      expect(plan.count, 12); // رصيد ذلك الذكر المحفوظ في التطبيق
      expect(plan.lifetime, 100); // لا ضغطات جديدة ⇒ الإجمالي كما هو
      expect(plan.seenRevision, 7);
    });

    test('نفس الذكر ⇒ لا يُنقص العدّاد أبداً', () {
      final plan = planTasbihSync(
        widget: const WidgetTasbihSnapshot(
            zikr: 'سبحان الله وبحمده', count: 40, lifetime: 140, revision: 9),
        appZikr: 'سبحان الله وبحمده',
        appCount: 33,
        appLifetime: 100,
        seenRevision: 8,
        appCountsByPhrase: const {'سبحان الله وبحمده': 33},
      );
      expect(plan.zikr, 'سبحان الله وبحمده');
      expect(plan.count, 40);
      expect(plan.lifetime, 107); // 7 ضغطات جديدة فوق 100
      expect(plan.adoptedZikr, isFalse);
    });

    test('مراجعة قديمة/مساوية ⇒ لا يُرجَّع ذكر قديم فوق اختيار المستخدم', () {
      final plan = planTasbihSync(
        widget: const WidgetTasbihSnapshot(
            zikr: 'ذكر قديم', count: 5, lifetime: 5, revision: 4),
        appZikr: 'ذكر المستخدم الجديد',
        appCount: 3,
        appLifetime: 900,
        seenRevision: 4,
        appCountsByPhrase: const {'ذكر المستخدم الجديد': 3},
      );
      expect(plan.zikr, 'ذكر المستخدم الجديد');
      expect(plan.count, 3);
      expect(plan.lifetime, 900);
      expect(plan.seenRevision, 4);
      expect(plan.adoptedZikr, isFalse);
    });

    test('ويدجت بلا مراجعة (لم يُلمس) ⇒ لا تغيير', () {
      final plan = planTasbihSync(
        widget: WidgetTasbihSnapshot.empty,
        appZikr: 'الحمد لله',
        appCount: 10,
        appLifetime: 50,
        seenRevision: 0,
        appCountsByPhrase: const {'الحمد لله': 10},
      );
      expect(plan.zikr, 'الحمد لله');
      expect(plan.count, 10);
      expect(plan.lifetime, 50);
      expect(plan.seenRevision, 0);
    });

    test('ويدجت بذكر فارغ ومراجعة أحدث ⇒ يحتفظ بذكر التطبيق', () {
      final plan = planTasbihSync(
        widget: const WidgetTasbihSnapshot(
            zikr: '   ', count: 4, lifetime: 4, revision: 2),
        appZikr: 'الله أكبر',
        appCount: 2,
        appLifetime: 10,
        seenRevision: 1,
        appCountsByPhrase: const {'الله أكبر': 2},
      );
      expect(plan.zikr, 'الله أكبر');
      expect(plan.count, 4);
      expect(plan.adoptedZikr, isFalse);
      expect(plan.seenRevision, 2);
    });
  });
}
