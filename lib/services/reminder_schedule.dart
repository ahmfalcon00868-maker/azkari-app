/// أول موعد قادم لتذكير أسبوعي متكرر.
///
/// [weekday] يوم الأسبوع (1 = الاثنين … 7 = الأحد)، [hour]/[minute] بالتوقيت
/// المحلي. إذا كان اليوم هو نفسه والساعة قد مضت (أو هي الآن) يُنتقل لأسبوع
/// قادم، حتى لا يُطلق الإشعار فوراً عند لحظة التفعيل.
DateTime nextWeeklyOccurrence(
  DateTime now, {
  required int weekday,
  required int hour,
  required int minute,
}) {
  assert(weekday >= DateTime.monday && weekday <= DateTime.sunday);
  assert(hour >= 0 && hour <= 23);
  assert(minute >= 0 && minute <= 59);

  DateTime candidate = DateTime(now.year, now.month, now.day, hour, minute);
  int guard = 0;
  while ((candidate.weekday != weekday || !candidate.isAfter(now)) && guard < 8) {
    candidate = DateTime(
      candidate.year,
      candidate.month,
      candidate.day + 1,
      hour,
      minute,
    );
    guard++;
  }
  return candidate;
}
