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
/// [date] يُستخدم يومه فقط (السنة/الشهر/اليوم)؛ الناتج بالتوقيت المحلي للجهاز.
/// للمقارنات والعرض الصحيحين استخدم [computeSunTimesUtc] مع مدينة محدّدة.
SunTimes computeSunTimes({
  required DateTime date,
  required double latitude,
  required double longitude,
}) {
  final utc = computeSunTimesUtc(
    date: date,
    latitude: latitude,
    longitude: longitude,
  );
  return SunTimes(
    sunrise: utc.sunrise?.toLocal(),
    sunset: utc.sunset?.toLocal(),
  );
}

/// نفس الحساب لكن الناتج **لحظات UTC** (instants) مستقلة عن منطقة الجهاز.
///
/// المقارنة بين اللحظات صحيحة مهما كانت منطقة الجهاز الزمنية، والعرض يتم
/// بتحويلها إلى منطقة المدينة المختارة (انظر `CityClock`).
SunTimes computeSunTimesUtc({
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
    sunrise: _fromUtcMinutesUtc(date, sunriseUtcMin),
    sunset: _fromUtcMinutesUtc(date, sunsetUtcMin),
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

/// نافذة سنن الجمعة كلحظات UTC: من مغرب الخميس إلى مغرب الجمعة.
///
/// [now] يُستخدم لتحديد أسبوع اليوم فقط؛ الناتج لحظات مطلقة تصلح للمقارنة على
/// أي جهاز، ويُعرض وقتها بمنطقة المدينة عبر `CityClock`.
({DateTime? start, DateTime? end}) fridaySunnahWindowUtc(
  DateTime now, {
  required double latitude,
  required double longitude,
}) {
  final DateTime today = DateTime.utc(now.year, now.month, now.day);
  final DateTime currentThursday = DateTime.utc(
    today.year,
    today.month,
    today.day - (today.weekday - DateTime.thursday),
  );
  final DateTime currentFriday =
      DateTime.utc(currentThursday.year, currentThursday.month, currentThursday.day + 1);
  return (
    start: computeSunTimesUtc(
      date: currentThursday,
      latitude: latitude,
      longitude: longitude,
    ).sunset,
    end: computeSunTimesUtc(
      date: currentFriday,
      latitude: latitude,
      longitude: longitude,
    ).sunset,
  );
}

/// نافذة سنن الجمعة بالتوقيت المحلي للجهاز (توافقية فقط).
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
  final utc = fridaySunnahWindowUtc(now,
      latitude: latitude, longitude: longitude);
  return (start: utc.start?.toLocal(), end: utc.end?.toLocal());
}

/// رقم اليوم في السنة (1..366) محسوبًا في تقويم UTC.
///
/// كل الحساب داخل UTC: نأخذ مكوّنات السنة/الشهر/اليوم كما هي ونبني تواريخ
/// `DateTime.utc`، لأن طرح تواريخ محلية يعني أن أي تغيير توقيت صيفي داخل السنة
/// يجعل الفرق 133.958 يومًا مثلًا، و`inDays` تقتطع الكسر فينقص رقم اليوم واحدًا
/// وتنزاح مواقيت الشمس بمقدار يوم. استخدام UTC يجعل كل يوم 24 ساعة بالضبط.
int dayOfYearUtc(DateTime date) {
  final DateTime start = DateTime.utc(date.year, 1, 1);
  final DateTime day = DateTime.utc(date.year, date.month, date.day);
  return day.difference(start).inDays + 1;
}

int _dayOfYear(DateTime date) => dayOfYearUtc(date);

DateTime _fromUtcMinutesUtc(DateTime date, double minutes) {
  final DateTime base = DateTime.utc(date.year, date.month, date.day);
  return base.add(Duration(minutes: minutes.round()));
}
