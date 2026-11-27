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
    required this.pushedZikr,
    required this.pushedCount,
    this.addedFromWidget = 0,
  });

  final String zikr;
  final int count;
  final int lifetime;
  final int seenRevision;

  /// هل تبنّى التطبيق ذكراً جديداً جاء من الويدجت؟
  final bool adoptedZikr;

  /// الذكر/العدّاد الذي صار الويدجت يعرضه بعد أن يدفع التطبيق حالته.
  ///
  /// يُحفظ في التفضيلات، ويُستخدم في المزامنة التالية كخط أساس لحساب عدد
  /// الضغطات الجديدة فقط (حتى لا تُحسب الضغطات مرتين).
  final String pushedZikr;
  final int pushedCount;

  /// عدد الضغطات التي أُضيفت من الويدجت في هذه المزامنة.
  final int addedFromWidget;
}

/// يدمج ما فعله المستخدم في الويدجت مع ذاكرة التطبيق دون إرجاع ذكر قديم
/// ودون فقدان أي ضغطة.
///
/// نموذج العدّ:
/// * التطبيق يحتفظ بعدّاد لكل ذكر (`appCountForWidgetZikr` للذكر الذي يعرضه
///   الويدجت الآن).
/// * عند تغيير الذكر من الويدجت يُصفَّر عدّاد الويدجت، فكل ما فيه بعدها هو
///   **ضغطات جديدة** تُضاف إلى عدّاد ذلك الذكر المحفوظ.
/// * عند بقاء الذكر نفسه، تُحسب الضغطات الجديدة كفرق بين عدّاد الويدجت وما
///   دفعه التطبيق آخر مرة ([lastPushedCount]) — لا `max` ولا جمع كامل.
///
/// بذلك: 12 تسبيحة محفوظة + تغيير الذكر من الويدجت + 3 ضغطات ⇒ 15،
/// وإعادة المزامنة دون ضغطات جديدة ⇒ تبقى 15.
TasbihSyncPlan planTasbihSync({
  required WidgetTasbihSnapshot widget,
  required String appZikr,
  required int appCount,
  required int appLifetime,
  required int seenRevision,
  required int appCountForWidgetZikr,
  int lastPushedCount = 0,
  String lastPushedZikr = '',
}) {
  TasbihSyncPlan unchanged([int extra = 0]) => TasbihSyncPlan(
        zikr: appZikr,
        count: appCount,
        lifetime: appLifetime,
        seenRevision: seenRevision,
        adoptedZikr: false,
        pushedZikr: appZikr,
        pushedCount: appCount,
        addedFromWidget: extra,
      );

  // لا جديد من الويدجت: أي مراجعة صفرية أو لم تتقدّم عمّا رآه التطبيق.
  if (widget.revision <= 0 || widget.revision <= seenRevision) {
    return unchanged();
  }

  final String widgetZikr = widget.zikr.trim();
  final String zikr = widgetZikr.isEmpty ? appZikr : widgetZikr;
  final bool samePhrase = zikr == appZikr;

  // خط الأساس: ما كان الويدجت يعرضه قبل الضغطات الجديدة.
  // - ذكر جديد: الويدجت صُفِّر عند التبديل ⇒ الأساس صفر.
  // - نفس الذكر: الأساس هو آخر قيمة دفعها التطبيق لهذا الذكر.
  final int baseline;
  if (!samePhrase) {
    baseline = 0;
  } else if (lastPushedZikr == zikr) {
    baseline = lastPushedCount;
  } else {
    // لم ندفع لهذا الذكر بعد (ترقية من إصدار أقدم): نعتبر عدّاد الويدجت
    // انعكاساً لحالة التطبيق، فلا نضيف شيئاً من فرق سالب.
    baseline = appCount;
  }

  final int newPresses = math.max(0, widget.count - baseline);
  final int baseCount = samePhrase ? appCount : math.max(0, appCountForWidgetZikr);
  final int count = baseCount + newPresses;
  final int lifetime =
      math.max(appLifetime, math.max(widget.lifetime, appLifetime + newPresses));

  return TasbihSyncPlan(
    zikr: zikr,
    count: count,
    lifetime: lifetime,
    seenRevision: widget.revision,
    adoptedZikr: !samePhrase,
    pushedZikr: zikr,
    pushedCount: count,
    addedFromWidget: newPresses,
  );
}
