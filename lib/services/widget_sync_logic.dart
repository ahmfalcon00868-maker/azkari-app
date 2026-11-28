import 'dart:convert';
import 'dart:math' as math;

/// حالة ويدجت السبحة كما هي مخزّنة على الشاشة الرئيسية.
class WidgetTasbihSnapshot {
  const WidgetTasbihSnapshot({
    this.zikr = '',
    this.count = 0,
    this.lifetime = 0,
    this.revision = 0,
    this.totals = const <String, int>{},
    this.totalsSchema = 0,
    this.seededZikr = '',
  });

  /// الذكر المعروض الآن على الويدجت.
  final String zikr;

  /// العدّاد المعروض (يُصفَّر عند تبديل الذكر — للعرض فقط).
  final int count;

  /// مجموع ضغطات الويدجت مدى الحياة (قيمة عرض/إحصاء).
  final int lifetime;

  /// رقم مراجعة يزيده الجانب الأصلي عند كل تغيير من الويدجت نفسه.
  final int revision;

  /// **سجل الضغطات الدائم لكل ذكر**: `ذكر → مجموع ضغطات الودجت لهذا الذكر`.
  ///
  /// هذا هو المصدر الموثوق لاستعادة الضغطات، لأن العدّاد المعروض يُصفَّر عند
  /// تبديل الذكر ولا يحمل أثر ما ضُغط على الأذكار السابقة.
  final Map<String, int> totals;

  /// إصدار بنية السجل (1 = موجود). صفر يعني ويدجت من إصدار أقدم.
  final int totalsSchema;

  /// الذكر الذي بُذر رصيده من العدّاد المعروض لحظة الترقية (فارغ عادةً).
  final String seededZikr;

  /// هل الويدجت يوفّر سجل الضغطات لكل ذكر؟
  bool get hasTotals => totalsSchema >= 1 && totals.isNotEmpty;

  static const WidgetTasbihSnapshot empty = WidgetTasbihSnapshot();
}

/// نتيجة دمج حالة الويدجت مع حالة التطبيق (غير قابلة للتعديل).
class TasbihSyncPlan {
  const TasbihSyncPlan({
    required this.zikr,
    required this.count,
    required this.countsByPhrase,
    required this.lifetime,
    required this.watermarks,
    required this.seenRevision,
    required this.adoptedZikr,
    required this.pushedZikr,
    required this.pushedCount,
    this.addedFromWidget = 0,
  });

  /// الذكر الحالي في التطبيق بعد الدمج.
  final String zikr;

  /// عدّاد الذكر الحالي.
  final int count;

  /// عدّادات كل الأذكار بعد إضافة ضغطات الودجت (تُحفظ ككتلة واحدة).
  final Map<String, int> countsByPhrase;

  /// الإجمالي العام بعد إضافة ضغطات الودجت.
  final int lifetime;

  /// العلامات المائية: `ذكر → آخر مجموع استهلكه التطبيق من سجل الويدجت`.
  ///
  /// تُحفظ مع [countsByPhrase] في نفس الكتابة، فلا تُفقد ضغطة ولا تتضاعف حتى لو
  /// أُغلق التطبيق فوراً بعد المزامنة.
  final Map<String, int> watermarks;

  /// المراجعة التي رآها التطبيق بعد هذه المزامنة.
  final int seenRevision;

  /// هل تبنّى التطبيق ذكراً جديداً جاء من الويدجت؟
  final bool adoptedZikr;

  /// الذكر/العدّاد الذي صار الويدجت يعرضه بعد أن يدفع التطبيق حالته.
  final String pushedZikr;
  final int pushedCount;

  /// عدد الضغطات التي أُضيفت من الويدجت في هذه المزامنة (مجموع كل الأذكار).
  final int addedFromWidget;

  TasbihSyncPlan copyWith({int? addedFromWidget}) => TasbihSyncPlan(
        zikr: zikr,
        count: count,
        countsByPhrase: countsByPhrase,
        lifetime: lifetime,
        watermarks: watermarks,
        seenRevision: seenRevision,
        adoptedZikr: adoptedZikr,
        pushedZikr: pushedZikr,
        pushedCount: pushedCount,
        addedFromWidget: addedFromWidget ?? this.addedFromWidget,
      );
}

/// العلامات المائية الابتدائية عند أول مزامنة بعد الترقية.
///
/// الغرض: ألّا تُحسب ضغطات قديمة سبق أن استوعبها التطبيق مرة ثانية. لكل ذكر في
/// السجل نبدأ من: آخر عدّاد دُفع للويدجت لنفس الذكر، وإلا عدّاد التطبيق المحفوظ
/// لذلك الذكر (وهو صفر للأذكار الجديدة).
Map<String, int> seedWidgetWatermarks({
  required Map<String, int> totals,
  required Map<String, int> appCountsByPhrase,
  String seededZikr = '',
}) {
  final String seeded = seededZikr.trim();
  final Map<String, int> out = <String, int>{};
  totals.forEach((phrase, total) {
    final String key = phrase.trim();
    if (key.isEmpty) return;
    // الذكر المزروع فقط يبدأ من رصيد التطبيق (ضغطاته محسوبة سابقاً)؛ أي ذكر
    // آخر يبدأ من صفر لأن كل ضغطاته تمّت في الويدجت ولم يستوعبها التطبيق بعد.
    out[key] = (key == seeded)
        ? math.min(appCountsByPhrase[key] ?? 0, total)
        : 0;
  });
  return out;
}

/// يدمج ما فعله المستخدم في الويدجت مع ذاكرة التطبيق دون إرجاع ذكر قديم، ودون
/// فقدان أي ضغطة، ودون مضاعفة.
///
/// نموذج العدّ (سجل أحداث على الجانب الأصلي):
/// * الجانب الأصلي (Android) يحتفظ بمجموع الضغطات **لكل ذكر** في
///   `widget_totals`، والمجاميع لا تتناقص أبداً ولا تُصفَّر عند تبديل الذكر.
/// * التطبيق يحفظ «علامة مائية» لكل ذكر = آخر مجموع استهلكه فعلاً.
/// * الضغطات الجديدة للذكر = `total - watermark` (لا سالب)، فتُضاف لعدّاد ذلك
///   الذكر مهما تعددت عمليات التبديل: A → B → A، أو B ثم C.
/// * بعد الاستهلاك تُرفع العلامة المائية إلى المجموع نفسه وتُحفظ مع العدّادات في
///   كتابة واحدة ⇒ إعادة المزامنة لا تضيف شيئاً، والإغلاق قبل الحفظ لا يفقد
///   شيئاً لأن السجل الأصلي لم يُستهلك.
///
/// حالات مرجعية: 12 محفوظة + 3 ضغطات بعد التبديل ⇒ 15؛ و3 على B ثم 2 على C ⇒
/// B +3 وC +2 والإجمالي +5.
TasbihSyncPlan planTasbihSync({
  required WidgetTasbihSnapshot widget,
  required String appZikr,
  required int appCount,
  required int appLifetime,
  required int seenRevision,
  required Map<String, int> appCountsByPhrase,
  Map<String, int> watermarks = const <String, int>{},
  int lastPushedCount = 0,
  String lastPushedZikr = '',
}) {
  final Map<String, int> counts = Map<String, int>.from(appCountsByPhrase);
  // العدّاد الحيّ للتطبيق هو الأصح للذكر الحالي.
  counts[appZikr] = appCount;

  TasbihSyncPlan unchanged() => TasbihSyncPlan(
        zikr: appZikr,
        count: appCount,
        countsByPhrase: Map<String, int>.unmodifiable(counts),
        lifetime: appLifetime,
        watermarks: Map<String, int>.unmodifiable(
          Map<String, int>.from(watermarks),
        ),
        seenRevision: seenRevision,
        adoptedZikr: false,
        pushedZikr: appZikr,
        pushedCount: appCount,
      );

  // لا جديد من الويدجت: أي مراجعة صفرية أو لم تتقدّم عمّا رآه التطبيق.
  if (widget.revision <= 0 || widget.revision <= seenRevision) {
    return unchanged();
  }

  final String widgetZikr = widget.zikr.trim();
  final String zikr = widgetZikr.isEmpty ? appZikr : widgetZikr;

  int added = 0;
  Map<String, int> newWatermarks = Map<String, int>.from(watermarks);

  if (widget.hasTotals) {
    final Map<String, int> base = watermarks.isEmpty
        ? seedWidgetWatermarks(
            totals: widget.totals,
            appCountsByPhrase: appCountsByPhrase,
            seededZikr: widget.seededZikr,
          )
        : Map<String, int>.from(watermarks);
    newWatermarks = Map<String, int>.from(base);
    widget.totals.forEach((phrase, total) {
      final String key = phrase.trim();
      if (key.isEmpty) return;
      final int seen = base[key] ?? 0;
      final int diff = total - seen;
      if (diff > 0) {
        counts[key] = (counts[key] ?? 0) + diff;
        added += diff;
        newWatermarks[key] = total;
      } else {
        // العلامة لا تتراجع أبداً حتى لو عاد السجل لأي سبب.
        newWatermarks[key] = math.max(seen, total);
      }
    });
  } else {
    // توافق خلفي: ويدجت بدون سجل ضغطات (إصدار أقدم) — نعتمد فرق العدّاد.
    final bool samePhrase = zikr == appZikr;
    final int baseline;
    if (!samePhrase) {
      baseline = appCountsByPhrase[zikr] ?? 0;
    } else if (lastPushedZikr == zikr) {
      baseline = lastPushedCount;
    } else {
      baseline = appCount;
    }
    final int presses = math.max(0, widget.count - baseline);
    if (presses > 0) {
      counts[zikr] = (counts[zikr] ?? 0) + presses;
      added = presses;
    }
  }

  final int count = counts[zikr] ?? 0;
  return TasbihSyncPlan(
    zikr: zikr,
    count: count,
    countsByPhrase: Map<String, int>.unmodifiable(counts),
    lifetime: appLifetime + added,
    watermarks: Map<String, int>.unmodifiable(newWatermarks),
    seenRevision: widget.revision,
    adoptedZikr: zikr != appZikr,
    pushedZikr: zikr,
    pushedCount: count,
    addedFromWidget: added,
  );
}


/// الحالة الذرّية لمزامنة الويدجت كما تُخزَّن في `widget_sync_state`.
///
/// الغرض: أن يكون العدّاد والعلامات المائية والإجمالي والذكر **والمراجعة
/// المستهلكة** في قيمة واحدة، وأن يُستعاد التمييز بين «مراجعة صفر حديثة» و
/// «لا مراجعة في الحالة» — وهذا فرق جوهري: صفر قد يكون قيمة صحيحة.
class WidgetSyncState {
  const WidgetSyncState({
    this.schemaVersion = 2,
    required this.counts,
    required this.watermarks,
    this.lifetime = 0,
    this.zikr = '',
    this.revision,
  });

  /// إصدار بنية الحالة؛ 2 يعني أن المراجعة تُحفظ داخلها.
  final int schemaVersion;
  final Map<String, int> counts;
  final Map<String, int> watermarks;
  final int lifetime;
  final String zikr;

  /// `null` = الحالة لا تحمل حقل مراجعة أصلًا (حالة قديمة).
  final int? revision;

  /// حالة حديثة تحتوي المراجعة.
  bool get isModern => schemaVersion >= 2;

  /// هل المراجعة داخل الحالة موثوقة؟ (v=2 **و** وجود الحقل، ولو كانت صفرًا)
  bool get hasRevision => isModern && revision != null;

  /// المراجعة المستهلكة: من الحالة الحديثة إن حملت الحقل، وإلا المفتاح القديم.
  static int resolveRevision(WidgetSyncState? state, int legacyRevision) {
    if (state != null && state.hasRevision) return state.revision!;
    return legacyRevision;
  }

  String encode() => jsonEncode(<String, dynamic>{
        'v': schemaVersion,
        'counts': counts,
        'seen': watermarks,
        'lifetime': lifetime,
        'zikr': zikr,
        'revision': revision,
      });

  static WidgetSyncState? tryParse(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final counts = _intMap(decoded['counts']);
      final seen = _intMap(decoded['seen']);
      final version = decoded['v'];
      final lifetime = decoded['lifetime'];
      final revision = decoded['revision'];
      final zikr = decoded['zikr'];
      return WidgetSyncState(
        schemaVersion: version is num ? version.toInt() : 0,
        counts: counts,
        watermarks: seen,
        lifetime: lifetime is num ? lifetime.toInt() : 0,
        zikr: zikr is String ? zikr : '',
        revision: revision is num ? revision.toInt() : null,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, int> _intMap(dynamic value) {
    if (value is! Map) return const <String, int>{};
    final out = <String, int>{};
    value.forEach((k, v) {
      if (v is num) out[k.toString()] = v.toInt();
    });
    return out;
  }
}
