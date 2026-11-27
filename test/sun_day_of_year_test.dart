import 'package:flutter_test/flutter_test.dart';

import 'package:azkari/services/sun_times.dart';

// القاهرة: خط عرض/طول تقريبيان، ومنطقتها الزمنية UTC+2 شتاءً وUTC+3 صيفًا.
const double kCairoLat = 30.0444;
const double kCairoLng = 31.2357;

/// تواريخ تغيّر التوقيت الصيفي في مصر لعام 2026 (يبدأ الجمعة الأخيرة من أبريل
/// وينتهي الخميس الأخير من أكتوبر).
const DateTime kDstStart = DateTime(2026, 4, 24);
const DateTime kDstEnd = DateTime(2026, 10, 29);

void main() {
  group('dayOfYearUtc — حساب اليوم في السنة', () {
    test('قيم معروفة في سنة عادية (2026)', () {
      expect(dayOfYearUtc(DateTime(2026, 1, 1)), 1);
      expect(dayOfYearUtc(DateTime(2026, 1, 31)), 31);
      expect(dayOfYearUtc(DateTime(2026, 3, 1)), 60);
      expect(dayOfYearUtc(DateTime(2026, 4, 24)), 114);
      expect(dayOfYearUtc(DateTime(2026, 5, 15)), 135);
      expect(dayOfYearUtc(DateTime(2026, 7, 1)), 182);
      expect(dayOfYearUtc(DateTime(2026, 10, 29)), 302);
      expect(dayOfYearUtc(DateTime(2026, 11, 2)), 306);
      expect(dayOfYearUtc(DateTime(2026, 12, 31)), 365);
    });

    test('قيم معروفة في سنة كبيسة (2028)', () {
      expect(dayOfYearUtc(DateTime(2028, 1, 1)), 1);
      expect(dayOfYearUtc(DateTime(2028, 2, 29)), 60);
      expect(dayOfYearUtc(DateTime(2028, 3, 1)), 61);
      expect(dayOfYearUtc(DateTime(2028, 12, 31)), 366);
    });

    test('كل يوم يزيد الرقم بواحد بالضبط على طول السنة (لا أثر لتغيير التوقيت)',
        () {
      var expected = 1;
      for (var month = 1; month <= 12; month++) {
        final daysInMonth = DateTime.utc(2026, month + 1, 0).day;
        for (var day = 1; day <= daysInMonth; day++) {
          final value = dayOfYearUtc(DateTime(2026, month, day));
          expect(value, expected,
              reason: '2026-$month-$day يجب أن يكون اليوم $expected');
          expected += 1;
        }
      }
      expect(expected - 1, 365);
    });

    test('التواريخ بعد تغيير التوقيت الصيفي تُحسب بالفرق التقويمي نفسه', () {
      // من 24 أبريل (بداية التوقيت الصيفي) إلى 15 مايو = 21 يوماً تقويمياً.
      expect(
        dayOfYearUtc(DateTime(2026, 5, 15)) - dayOfYearUtc(kDstStart),
        21,
      );
      // من 29 أكتوبر (نهاية التوقيت الصيفي) إلى 2 نوفمبر = 4 أيام.
      expect(
        dayOfYearUtc(DateTime(2026, 11, 2)) - dayOfYearUtc(kDstEnd),
        4,
      );
      // ومن 1 يناير إلى تاريخ ما بعد التوقيت الصيفي يطابق الحساب التقويمي.
      expect(
        DateTime.utc(2026, 5, 15).difference(DateTime.utc(2026)).inDays + 1,
        dayOfYearUtc(DateTime(2026, 5, 15)),
      );
    });

    test('لا يتأثر بنوع DateTime المُدخل (محلي أو UTC)', () {
      for (final int month in [3, 5, 11]) {
        for (final int day in [1, 15, 28]) {
          expect(
            dayOfYearUtc(DateTime(2026, month, day)),
            dayOfYearUtc(DateTime.utc(2026, month, day)),
            reason: '2026-$month-$day',
          );
        }
      }
    });
  });

  group('مواقيت الشمس بعد تغييرات التوقيت الصيفي', () {
    test('غروب القاهرة في تواريخ بعد التوقيت الصيفي يقع في نطاق معقول', () {
      for (final DateTime date in [
        DateTime.utc(2026, 5, 15), // بعد بدء التوقيت الصيفي
        DateTime.utc(2026, 7, 1),
        DateTime.utc(2026, 11, 2), // بعد انتهاء التوقيت الصيفي
      ]) {
        final utc = computeSunTimesUtc(
          date: date,
          latitude: kCairoLat,
          longitude: kCairoLng,
        );
        expect(utc.sunrise, isNotNull);
        expect(utc.sunset, isNotNull);
        expect(utc.sunrise!.isUtc, isTrue);
        expect(utc.sunset!.isUtc, isTrue);

        final sunriseMinutes = utc.sunrise!.hour * 60 + utc.sunrise!.minute;
        final sunsetMinutes = utc.sunset!.hour * 60 + utc.sunset!.minute;
        final dayLength = sunsetMinutes - sunriseMinutes;

        expect(sunriseMinutes, inInclusiveRange(60, 300),
            reason: 'شروق القاهرة UTC بين 01:00 و05:00');
        expect(sunsetMinutes, inInclusiveRange(840, 1140),
            reason: 'غروب القاهرة UTC بين 14:00 و19:00');
        expect(dayLength, inInclusiveRange(600, 870),
            reason: 'طول النهار بين 10 و14.5 ساعة');
      }
    });

    test('طول اليوم يتغير بسلاسة بين يومين متتاليين بعد تغيير التوقيت', () {
      final a = computeSunTimesUtc(
        date: DateTime.utc(2026, 10, 28),
        latitude: kCairoLat,
        longitude: kCairoLng,
      );
      final b = computeSunTimesUtc(
        date: DateTime.utc(2026, 10, 29),
        latitude: kCairoLat,
        longitude: kCairoLng,
      );
      final diff = b.sunset!.difference(a.sunset!).inMinutes;
      expect(diff, inInclusiveRange(-60, 60),
          reason: 'لا قفزة ساعة في حساب الشمس عند تغيير التوقيت المدني');
    });

    test('نافذة سنن الجمعة بعد التوقيت الصيفي تبقى ~24 ساعة', () {
      final window = fridaySunnahWindowUtc(
        DateTime.utc(2026, 7, 3),
        latitude: kCairoLat,
        longitude: kCairoLng,
      );
      expect(window.start, isNotNull);
      expect(window.end, isNotNull);
      final hours =
          window.end!.difference(window.start!).inMinutes / 60.0;
      expect(hours, inInclusiveRange(23.0, 24.5));
      expect(window.start!.weekday, DateTime.thursday);
      expect(window.end!.weekday, DateTime.friday);
    });
  });
}
