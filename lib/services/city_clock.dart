import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// ساعة المدينة: تحويل اللحظات المطلقة (UTC) إلى توقيت **المدينة المختارة**
/// بدل توقيت الجهاز، مع تثبيت قاعدة بيانات المناطق الزمنية مرة واحدة.
class CityClock {
  static bool _ready = false;

  static void ensureInitialized() {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
    } catch (_) {}
    _ready = true;
  }

  /// لحظة [instant] بتوقيت المنطقة [timeZone]، أو توقيت الجهاز إذا كانت
  /// المنطقة غير معروفة في قاعدة البيانات.
  static tz.TZDateTime at(DateTime instant, String timeZone) {
    ensureInitialized();
    final utcInstant = instant.toUtc();
    try {
      return tz.TZDateTime.from(utcInstant, tz.getLocation(timeZone));
    } catch (_) {
      return tz.TZDateTime.from(utcInstant, tz.local);
    }
  }

  /// "HH:mm" بتوقيت المدينة.
  static String format(DateTime instant, String timeZone) {
    final local = at(instant, timeZone);
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// اليوم (1 = الاثنين … 7 = الأحد) ورقم اليوم في توقيت المدينة.
  static ({int weekday, int day, int month, int year}) dateIn(
    DateTime instant,
    String timeZone,
  ) {
    final local = at(instant, timeZone);
    return (
      weekday: local.weekday,
      day: local.day,
      month: local.month,
      year: local.year,
    );
  }

  /// إزاحة المنطقة عن UTC بالساعات في لحظة معيّنة (للتشخيص والاختبارات).
  static Duration offsetAt(DateTime instant, String timeZone) =>
      at(instant, timeZone).timeZoneOffset;
}
