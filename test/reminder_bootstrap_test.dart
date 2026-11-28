import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:azkari/services/reminder_bootstrap.dart';
import 'package:azkari/services/sunna_reminders.dart';

/// جلسة إشعارات وهمية تسجّل كل استدعاء وتحاكي ما هو مجدول فعلياً.
class _FakeSink implements ReminderSink {
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

Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  group('ترحيل تذكيرات السنن عند بدء التطبيق', () {
    test('مفعّل + ترحيل مطلوب ⇒ يلغي القديم ثم يجدول أسبوعياً', () async {
      final prefs = await prefsWith({'sunna_fast_reminder': true});
      final sink = _FakeSink();

      final result = await ReminderBootstrap(prefs, sink).run(
        mondayTitle: 'الاثنين',
        thursdayTitle: 'الخميس',
        body: 'نص',
      );

      expect(result.migrated, isTrue);
      expect(result.scheduled, isTrue);
      // الإلغاء أولاً (تنظيف الجدولة اليومية القديمة) ثم الجدولة.
      expect(sink.cancelled, containsAll(<int>[201, 202]));
      expect(sink.scheduled, hasLength(2));
      expect(sink.active.keys.toSet(), <int>{201, 202});
      expect(sink.active[201]!['weekday'], DateTime.monday);
      expect(sink.active[201]!['hour'], 4);
      expect(sink.active[201]!['minute'], 30);
      expect(sink.active[202]!['weekday'], DateTime.thursday);
      expect(sink.active[202]!['minute'], 35);
      expect(prefs.getInt(ReminderBootstrap.migrationKey),
          ReminderBootstrap.migrationVersion);
    });

    test('مطفأ ⇒ يلغي القديم ولا ينشئ أي تذكير', () async {
      final prefs = await prefsWith({'sunna_fast_reminder': false});
      final sink = _FakeSink();

      final result = await ReminderBootstrap(prefs, sink).run(
        mondayTitle: 'm',
        thursdayTitle: 't',
        body: 'b',
      );

      expect(result.migrated, isTrue);
      expect(result.scheduled, isFalse);
      expect(sink.scheduled, isEmpty);
      expect(sink.active, isEmpty);
      expect(sink.cancelled, containsAll(<int>[201, 202]));
    });

    test('غياب الإعداد (مستخدم لم يفعّل) ⇒ لا تذكيرات', () async {
      final prefs = await prefsWith({});
      final sink = _FakeSink();

      await ReminderBootstrap(prefs, sink)
          .run(mondayTitle: 'm', thursdayTitle: 't', body: 'b');

      expect(sink.scheduled, isEmpty);
      expect(sink.active, isEmpty);
    });

    test('تشغيل التطبيق عدة مرات لا ينشئ إشعارات مكررة', () async {
      final prefs = await prefsWith({'sunna_fast_reminder': true});
      final sink = _FakeSink();
      final bootstrap = ReminderBootstrap(prefs, sink);

      await bootstrap.run(mondayTitle: 'm', thursdayTitle: 't', body: 'b');
      expect(sink.scheduled, hasLength(2));

      for (var i = 0; i < 4; i++) {
        final again =
            await bootstrap.run(mondayTitle: 'm', thursdayTitle: 't', body: 'b');
        expect(again.migrated, isFalse,
            reason: 'الترحيل يُنفَّذ مرة واحدة فقط لكل نسخة');
      }

      expect(sink.scheduled, hasLength(2), reason: 'لا جدولة إضافية');
      expect(sink.active.keys.toSet(), <int>{201, 202});
    });

    test('force يعيد التطبيق دون تكرار المعرّفات', () async {
      final prefs = await prefsWith({'sunna_fast_reminder': true});
      final sink = _FakeSink();
      final bootstrap = ReminderBootstrap(prefs, sink);

      await bootstrap.run(mondayTitle: 'm', thursdayTitle: 't', body: 'b');
      final result = await bootstrap.run(
        mondayTitle: 'm',
        thursdayTitle: 't',
        body: 'b',
        force: true,
      );

      expect(result.migrated, isTrue);
      // معرّفان فقط في النظام دائماً، مهما تكرر التطبيق.
      expect(sink.active.keys.toSet(), <int>{201, 202});
    });
  });
}
