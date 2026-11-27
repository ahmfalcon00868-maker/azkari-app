import 'package:flutter_test/flutter_test.dart';

import 'package:azkari/screens/tools_screen.dart' show QiblaCity, kQiblaCities;
import 'package:azkari/services/city_clock.dart';
import 'package:azkari/services/sun_times.dart';

QiblaCity cityNamed(String arName) =>
    kQiblaCities.firstWhere((c) => c.nameAr == arName);

void main() {
  group('قائمة المدن', () {
    test('المنيا موجودة بإحداثياتها ومنطقتها الزمنية', () {
      final minya = cityNamed('المنيا، مصر');
      expect(minya.nameEn, 'Minya, Egypt');
      expect(minya.lat, closeTo(28.1099, 0.01));
      expect(minya.lng, closeTo(30.7503, 0.01));
      expect(minya.timeZone, 'Africa/Cairo');
    });

    test('كل مدينة لها منطقة زمنية معروفة في قاعدة البيانات', () {
      for (final city in kQiblaCities) {
        expect(city.timeZone.trim(), isNotEmpty);
        // CityClock يعود لتوقيت الجهاز فقط إذا فشل find للمنطقة؛ هنا نتأكد
        // أن المنطقة نفسها موجودة فعلاً في قاعدة tz.
        final offset = CityClock.offsetAt(
            DateTime.utc(2026, 6, 21, 12), city.timeZone);
        expect(offset.inMinutes.abs(), lessThanOrEqualTo(14 * 60),
            reason: 'منطقة غير صالحة: ${city.timeZone}');
      }
    });

    test('مدن في مناطق زمنية مختلفة تُختبر', () {
      final zones = kQiblaCities.map((c) => c.timeZone).toSet();
      expect(zones.length, greaterThanOrEqualTo(5),
          reason: 'نريد تغطية مناطق متعددة لا منطقة واحدة');
      expect(zones, containsAll(<String>[
        'Africa/Cairo',
        'Asia/Riyadh',
        'Africa/Casablanca',
        'Europe/London',
      ]));
    });
  });

  group('ساعة المدينة بدل ساعة الجهاز', () {
    test('نفس اللحظة تُعرض بمناطق مختلفة بأوقات مختلفة', () {
      final instant = DateTime.utc(2026, 6, 21, 16, 59);

      expect(CityClock.format(instant, 'UTC'), '16:59');
      // القاهرة صيفاً UTC+3
      expect(CityClock.format(instant, 'Africa/Cairo'), '19:59');
      // الرياض UTC+3 دائماً
      expect(CityClock.format(instant, 'Asia/Riyadh'), '19:59');
      // الرباط صيفاً UTC+1
      expect(CityClock.format(instant, 'Africa/Casablanca'), '17:59');
      // لندن صيفاً UTC+1
      expect(CityClock.format(instant, 'Europe/London'), '17:59');
    });

    test('فرق التوقيت بين الرياض ولندن ساعتان في نفس اللحظة', () {
      final instant = DateTime.utc(2026, 6, 21, 12);
      final riyadh = CityClock.offsetAt(instant, 'Asia/Riyadh');
      final london = CityClock.offsetAt(instant, 'Europe/London');
      expect((riyadh - london).inHours, 2);
    });

    test('القاهرة تتغير إزاحتها بين الشتاء والصيف (توقيت صيفي)', () {
      final winter = CityClock.offsetAt(DateTime.utc(2026, 1, 15, 12), 'Africa/Cairo');
      final summer = CityClock.offsetAt(DateTime.utc(2026, 6, 21, 12), 'Africa/Cairo');
      expect((summer - winter).inHours, 1);
    });

    test('تاريخ المدينة قد يختلف عن تاريخ UTC', () {
      // 22:30 UTC = 01:30 من اليوم التالي في القاهرة (UTC+3 صيفاً)
      final instant = DateTime.utc(2026, 6, 21, 22, 30);
      final utcDate = CityClock.dateIn(instant, 'UTC');
      final cairoDate = CityClock.dateIn(instant, 'Africa/Cairo');
      expect(cairoDate.day, utcDate.day + 1);
    });
  });

  group('نافذة سنن الجمعة بتوقيت المدينة', () {
    test('البداية مغرب الخميس والنهاية مغرب الجمعة (لحظات صحيحة)', () {
      // يوم الجمعة 27 نوفمبر 2026 في القاهرة
      final window = fridaySunnahWindowUtc(
        DateTime.utc(2026, 11, 27, 8),
        latitude: 30.0444,
        longitude: 31.2357,
      );
      expect(window.start, isNotNull);
      expect(window.end, isNotNull);
      // كلاهما UTC
      expect(window.start!.isUtc, isTrue);
      expect(window.end!.isUtc, isTrue);

      final startLocalCity = CityClock.at(window.start!, 'Africa/Cairo');
      final endLocalCity = CityClock.at(window.end!, 'Africa/Cairo');

      expect(startLocalCity.weekday, DateTime.thursday);
      expect(endLocalCity.weekday, DateTime.friday);
      expect(endLocalCity.difference(startLocalCity).inHours, 24);
    });

    test('نافذة القاهرة والرباط تختلفان (إحداثيات مختلفة)', () {
      final cairo = fridaySunnahWindowUtc(DateTime.utc(2026, 11, 27, 8),
          latitude: 30.0444, longitude: 31.2357);
      final rabat = fridaySunnahWindowUtc(DateTime.utc(2026, 11, 27, 8),
          latitude: 34.0209, longitude: -6.8416);

      expect(cairo.start, isNot(equals(rabat.start)));
      // الرباط أبعد غرباً ⇒ مغربها (لحظة UTC) متأخرة عن القاهرة.
      expect(rabat.start!.isAfter(cairo.start!), isTrue);
    });

    test('الفتح/الإغلاق عند الحدود بدقة', () {
      final window = fridaySunnahWindowUtc(DateTime.utc(2026, 11, 27, 8),
          latitude: 28.1099, longitude: 30.7503); // المنيا
      final start = window.start!;
      final end = window.end!;

      bool open(DateTime nowUtc) => isFridaySunnahWindow(
            nowUtc,
            thursdayMaghrib: start,
            fridayMaghrib: end,
          );

      expect(open(start.subtract(const Duration(minutes: 1))), isFalse);
      expect(open(start), isTrue);
      expect(open(start.add(const Duration(hours: 3))), isTrue);
      expect(open(end.subtract(const Duration(minutes: 1))), isTrue);
      expect(open(end), isFalse);
      expect(open(end.add(const Duration(minutes: 1))), isFalse);
    });

    test('النتيجة لا تعتمد على منطقة الجهاز (لحظات مطلقة)', () {
      final window = fridaySunnahWindowUtc(DateTime.utc(2026, 11, 27, 8),
          latitude: 28.1099, longitude: 30.7503);
      final instant = window.start!.add(const Duration(minutes: 30));

      // نفس اللحظة معبَّراً عنها بـ UTC أو بتوقيت القاهرة أو الرياض.
      final asUtc = instant.toUtc();
      final asCairo = DateTime.utc(2026, 11, 26, 17, 30); // 19:30 القاهرة
      expect(asCairo.isAtSameMomentAs(asUtc), isTrue);
      expect(
        isFridaySunnahWindow(asCairo,
            thursdayMaghrib: window.start!, fridayMaghrib: window.end!),
        isTrue,
      );
    });

    test('مغرب المدينة يُعرض بتوقيت المدينة لا بتوقيت الجهاز', () {
      final window = fridaySunnahWindowUtc(DateTime.utc(2026, 11, 27, 8),
          latitude: 28.1099, longitude: 30.7503);
      final cairoLabel = CityClock.format(window.start!, 'Africa/Cairo');
      final utcLabel = CityClock.format(window.start!, 'UTC');
      expect(cairoLabel, isNot(utcLabel),
          reason: 'القاهرة UTC+2 شتاءً ⇒ ساعتان فرق');
      final cairoHour = int.parse(cairoLabel.split(':').first);
      final utcHour = int.parse(utcLabel.split(':').first);
      expect((cairoHour - utcHour) % 24, 2);
    });
  });

  group('حساب الشروق/الغروب (UTC) يطابق التوقيت المحلي سابقاً', () {
    test('computeSunTimes (محلي) = computeSunTimesUtc محوَّلاً', () {
      final utc = computeSunTimesUtc(
          date: DateTime(2026, 6, 21), latitude: 30.0444, longitude: 31.2357);
      final local = computeSunTimes(
          date: DateTime(2026, 6, 21), latitude: 30.0444, longitude: 31.2357);
      expect(local.sunset!.isAtSameMomentAs(utc.sunset!), isTrue);
      expect(local.sunrise!.isAtSameMomentAs(utc.sunrise!), isTrue);
    });
  });
}
