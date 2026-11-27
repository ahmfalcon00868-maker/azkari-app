import 'dart:math' as math;

/// حالة ويدجت السبحة كما هي مخزّنة على الشاشة الرئيسية.
class WidgetTasbihSnapshot {
  const WidgetTasbihSnapshot({
    this.zikr = '',
    this.count = 0,
    this.lifetime = 0,
    this.revision = 0,
  });

  final String zikr;
  final int count;
  final int lifetime;

  /// رقم مراجعة يزيده الجانب الأصلي عند كل تغيير من الويدجت نفسه.
  final int revision;

  static const WidgetTasbihSnapshot empty = WidgetTasbihSnapshot();
}

/// نتيجة دمج حالة الويدجت مع حالة التطبيق.
class TasbihSyncPlan {
  const TasbihSyncPlan({
    required this.zikr,
    required this.count,
    required this.lifetime,
    required this.seenRevision,
    required this.adoptedZikr,
  });

  final String zikr;
  final int count;
  final int lifetime;
  final int seenRevision;

  /// هل تبنّى التطبيق ذكراً جديداً جاء من الويدجت؟
  final bool adoptedZikr;
}

/// يدمج ما فعله المستخدم في الويدجت مع ذاكرة التطبيق دون إرجاع ذكر قديم.
///
/// القواعد:
/// * لا تغيير إذا لم تزد مراجعة الويدجت (`revision`) عن آخر مراجعة رآها التطبيق.
/// * إذا تغيّر الذكر من الويدجت يتبنّاه التطبيق مع عدّاد ذلك الذكر المحفوظ.
/// * إذا كان الذكر نفسه يُؤخذ الأكبر من العدّادين، والرصيد الإجمالي الأكبر.
TasbihSyncPlan planTasbihSync({
  required WidgetTasbihSnapshot widget,
  required String appZikr,
  required int appCount,
  required int appLifetime,
  required int seenRevision,
  required int appCountForWidgetZikr,
}) {
  if (widget.revision <= 0 || widget.revision <= seenRevision) {
    return TasbihSyncPlan(
      zikr: appZikr,
      count: appCount,
      lifetime: appLifetime,
      seenRevision: seenRevision,
      adoptedZikr: false,
    );
  }

  final String widgetZikr = widget.zikr.trim();
  final String zikr = widgetZikr.isEmpty ? appZikr : widgetZikr;
  final bool samePhrase = zikr == appZikr;
  final int count = samePhrase
      ? math.max(appCount, widget.count)
      : math.max(0, appCountForWidgetZikr);
  final int lifetime = math.max(appLifetime, widget.lifetime);

  return TasbihSyncPlan(
    zikr: zikr,
    count: count,
    lifetime: lifetime,
    seenRevision: widget.revision,
    adoptedZikr: !samePhrase,
  );
}
