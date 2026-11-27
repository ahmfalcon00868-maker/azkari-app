import 'dart:math' as math;

/// حساب الشروق والغروب محلياً (خوارزمية NOAA) بدون أي اتصال بالإنترنت.
class SunTimes {
  const SunTimes({this.sunrise, this.sunset});

  /// بالتوقيت المحلي للجهاز، أو `null` في المناطق القطبية حيث لا شروق/غروب.
  final DateTime? sunrise;
  final DateTime? sunset;
}

/// الشروق والغروب لتاريخ ميلادي معيّن عند إحداثيات معيّنة.
///
/// [date] يُستخدم يومه فقط (السنة/الشهر/اليوم)؛ الناتج بالتوقيت المحلي.
SunTimes computeSunTimes({
  required DateTime date,
  required double latitude,
  required double longitude,
}) {
  if (latitude < -90 || latitude > 90) return const SunTimes();

  final double gamma =
      2 * math.pi / 365 * (_dayOfYear(date) - 1 + (12 - 12) / 24);
  final double eqTime = 229.18 *
      (0.000075 +
          0.001868 * math.cos(gamma) -
          0.032077 * math.sin(gamma) -
          0.014615 * math.cos(2 * gamma) -
          0.040849 * math.sin(2 * gamma));
  final double decl = 0.006918 -
      0.399912 * math.cos(gamma) +
      0.070257 * math.sin(gamma) -
      0.006758 * math.cos(2 * gamma) +
      0.000907 * math.sin(2 * gamma) -
      0.002697 * math.cos(3 * gamma) +
      0.00148 * math.sin(3 * gamma);

  const double zenith = 90.833 * math.pi / 180;
  final double latRad = latitude * math.pi / 180;
  final double cosHourAngle =
      math.cos(zenith) / (math.cos(latRad) * math.cos(decl)) -
          math.tan(latRad) * math.tan(decl);
  if (cosHourAngle < -1 || cosHourAngle > 1) return const SunTimes();

  final double ha = math.acos(cosHourAngle) * 180 / math.pi;
  final double sunriseUtcMin = 720 - 4 * (longitude + ha) - eqTime;
  final double sunsetUtcMin = 720 - 4 * (longitude - ha) - eqTime;

  return SunTimes(
    sunrise: _fromUtcMinutes(date, sunriseUtcMin),
    sunset: _fromUtcMinutes(date, sunsetUtcMin),
  );
}

/// مغرب اليوم (الغروب) بالتوقيت المحلي، أو `null` في المناطق القطبية.
DateTime? maghribFor(
  DateTime date, {
  required double latitude,
  required double longitude,
}) =>
    computeSunTimes(date: date, latitude: latitude, longitude: longitude)
        .sunset;

/// نافذة سنن الجمعة: تبدأ بمغرب الخميس وتنتهي بمغرب الجمعة.
bool isFridaySunnahWindow(
  DateTime now, {
  required DateTime thursdayMaghrib,
  required DateTime fridayMaghrib,
}) =>
    !now.isBefore(thursdayMaghrib) && now.isBefore(fridayMaghrib);

/// مغرب الخميس ومغرب الجمعة لأسبوع [now] الحالي (نفس أسبوع اليوم).
///
/// يعيد `null` في أي طرف إذا تعذّر حساب الغروب (مناطق قطبية).
({DateTime? start, DateTime? end}) fridaySunnahWindow(
  DateTime now, {
  required double latitude,
  required double longitude,
}) {
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime currentThursday =
      DateTime(today.year, today.month, today.day - (today.weekday - DateTime.thursday));
  final DateTime currentFriday =
      DateTime(currentThursday.year, currentThursday.month, currentThursday.day + 1);
  return (
    start: maghribFor(currentThursday,
        latitude: latitude, longitude: longitude),
    end: maghribFor(currentFriday, latitude: latitude, longitude: longitude),
  );
}

/// اليوم من السنة (1..366).
int _dayOfYear(DateTime date) {
  final DateTime start = DateTime(date.year, 1, 1);
  final DateTime day = DateTime(date.year, date.month, date.day);
  return day.difference(start).inDays + 1;
}

DateTime _fromUtcMinutes(DateTime date, double minutes) {
  final DateTime base = DateTime.utc(date.year, date.month, date.day);
  return base.add(Duration(minutes: minutes.round())).toLocal();
}
