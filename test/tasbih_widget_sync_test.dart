import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:azkari/services/widget_sync_logic.dart';

String stateBlob({
  int version = 2,
  Map<String, int> counts = const {},
  Map<String, int> seen = const {},
  int lifetime = 0,
  String zikr = '',
  Object? revision = 0,
}) {
  final map = <String, dynamic>{
    'v': version,
    'counts': counts,
    'seen': seen,
    'lifetime': lifetime,
    'zikr': zikr,
  };
  if (revision != null) map['revision'] = revision;
  return jsonEncode(map);
}

/// انقطاع محاكى (إغلاق التطبيق في منتصف العملية).
class _Crash implements Exception {
  @override
  String toString() => 'simulated crash';
}

/// «قرص» يحاكي `widget_sync_state` في SharedPreferences.
///
/// الكتابة فيه ذرّية: إمّا القيمة القديمة أو الجديدة بالكامل — وهذا ما نتحقق
/// منه: لا يمكن أن تُحفظ المراجعة دون العدّادات أو العكس.
class _Disk {
  String? blob;
  int legacySeenRevision = 0;
}

const String kA = 'سبحان الله';
const String kB = 'أستغفر الله';
const String kC = 'الحمد لله';

/// محاكاة الجانب الأصلي (Android) لويدجت السبحة.
///
/// مثل `TasbihWidgetProvider`: العدّاد المعروض يُصفَّر عند تبديل الذكر، لكن سجل
/// الضغطات ([totals]) يتراكم لكل ذكر ولا يتناقص أبدًا، والمراجعة تزيد عند كل
/// تغيير من الويدجت وحده.
class _Widget {
  _Widget({
    this.zikr = '',
    this.count = 0,
    this.lifetime = 0,
    this.revision = 0,
    Map<String, int>? totals,
    this.totalsSchema = 1,
    this.seededZikr = '',
  }) : totals = Map<String, int>.from(totals ?? const <String, int>{});

  String zikr;
  int count;
  int lifetime;
  int revision;
  final Map<String, int> totals;
  final int totalsSchema;
  final String seededZikr;

  /// ضغطة على عدّاد الويدجت (تُسجَّل في سجل الذكر الحالي).
  void tap([int times = 1]) {
    for (var i = 0; i < times; i++) {
      count += 1;
      lifetime += 1;
      totals[zikr] = (totals[zikr] ?? 0) + 1;
      revision += 1;
    }
  }

  /// تبديل الذكر من الويدجت: تصفير العرض فقط، والسجل يبقى كما هو.
  void nextZikr(String next) {
    zikr = next;
    count = 0;
    revision += 1;
  }

  WidgetTasbihSnapshot snapshot() => WidgetTasbihSnapshot(
        zikr: zikr,
        count: count,
        lifetime: lifetime,
        revision: revision,
        totals: Map<String, int>.from(totals),
        totalsSchema: totalsSchema,
        seededZikr: seededZikr,
      );
}

/// محاكاة التطبيق: عدّادات لكل ذكر + علامات مائية + إجمالي.
class _App {
  _App({
    required this.zikr,
    required this.count,
    required this.lifetime,
    required Map<String, int> storedCounts,
    Map<String, int>? watermarks,
    _Disk? disk,
    this.seenRevision = 0,
  })  : counts = Map<String, int>.from(storedCounts),
        seen = Map<String, int>.from(watermarks ?? const <String, int>{}),
        disk = disk ?? _Disk() {
    counts[zikr] = count;
  }

  String zikr;
  int count;
  int lifetime;
  Map<String, int> counts;
  Map<String, int> seen;
  final _Disk disk;

  /// المراجعة المستهلكة (تُحفظ داخل الحالة الذرّية مثل التطبيق تمامًا).
  int seenRevision;
  int lastPushedCount = 0;
  String lastPushedZikr = '';

  /// إعادة تشغيل التطبيق من الحالة المحفوظة.
  ///
  /// تستخدم نفس دوال الإنتاج: `WidgetSyncState.tryParse` و
  /// `WidgetSyncState.resolveRevision` (إذن اختبار «صفر ليس غيابًا» يمرّ على
  /// الكود الحقيقي لا على نسخة مقلّدة).
  factory _App.restore(_Disk disk, {String? fallbackZikr}) {
    final state = WidgetSyncState.tryParse(disk.blob);
    if (state == null) {
      return _App(
        zikr: fallbackZikr ?? '',
        count: 0,
        lifetime: 0,
        storedCounts: const {},
        disk: disk,
        seenRevision: disk.legacySeenRevision,
      );
    }
    final phrase = state.zikr.isNotEmpty ? state.zikr : (fallbackZikr ?? '');
    return _App(
      zikr: phrase,
      count: state.counts[phrase] ?? 0,
      lifetime: state.lifetime,
      storedCounts: state.counts,
      watermarks: state.watermarks,
      disk: disk,
      seenRevision:
          WidgetSyncState.resolveRevision(state, disk.legacySeenRevision),
    );
  }

  /// كتابة ذرّية واحدة تشمل المراجعة (كما في `persistWidgetSyncState`).
  void persist() {
    counts[zikr] = count;
    disk.blob = WidgetSyncState(
      counts: counts,
      watermarks: seen,
      lifetime: lifetime,
      zikr: zikr,
      revision: seenRevision,
    ).encode();
  }

  /// مزامنة واحدة: سحب من الويدجت ثم دفع حالة التطبيق إليه.
  ///
  /// [crashAfterRead] يحاكي إغلاق التطبيق بعد قراءة سجل الويدجت وقبل حفظ أي
  /// شيء: يجب أن يبقى القرص على حالته القديمة تمامًا.
  TasbihSyncPlan sync(_Widget widget, {bool crashAfterRead = false}) {
    final plan = planTasbihSync(
      widget: widget.snapshot(),
      appZikr: zikr,
      appCount: count,
      appLifetime: lifetime,
      seenRevision: seenRevision,
      appCountsByPhrase: counts,
      watermarks: seen,
      lastPushedCount: lastPushedCount,
      lastPushedZikr: lastPushedZikr,
    );

    if (crashAfterRead) {
      // لم نكتب شيئًا بعد: لا عدّادات ولا مراجعة ولا علامات مائية.
      throw _Crash();
    }

    seenRevision = plan.seenRevision;
    zikr = plan.zikr;
    count = plan.count;
    lifetime = plan.lifetime;
    counts = Map<String, int>.from(plan.countsByPhrase);
    seen = Map<String, int>.from(plan.watermarks);

    // نقلة واحدة: العدّادات + العلامات + الإجمالي + المراجعة + الذكر.
    persist();
    push(widget);
    return plan;
  }

  /// دفع حالة التطبيق إلى الويدجت (كما في `syncTasbihWidget`) — لا يزيد المراجعة
  /// ولا يمسّ سجل الضغطات.
  void push(_Widget widget) {
    widget.zikr = zikr;
    widget.count = count;
    widget.lifetime = lifetime;
    lastPushedZikr = zikr;
    lastPushedCount = count;
  }

  /// تسبيح من داخل التطبيق (يتبعه دفع فوري إلى الويدجت).
  void tapInApp(_Widget widget) {
    count += 1;
    lifetime += 1;
    counts[zikr] = count;
    push(widget);
  }
}

void main() {
  group('استعادة ضغطات الأذكار السابقة (سجل الضغطات)', () {
    test('A = 12 محفوظة، ثم B ثم العودة إلى A و3 ضغطات ⇒ 15', () {
      final app = _App(
        zikr: kA,
        count: 12,
        lifetime: 100,
        storedCounts: {kA: 12},
      );
      // ويدجت مُرقّى: سجله يبدأ من الرصيد المعروض للذكر الحالي.
      final widget = _Widget(
        zikr: kA,
        count: 12,
        lifetime: 100,
        totals: {kA: 12},
        seededZikr: kA,
      );
      app.sync(widget); // مزامنة أولى: تبني العلامة المائية دون إضافة شيء
      expect(app.count, 12);

      // المستخدم ينتقل إلى B ثم يعود إلى A ويضغط 3 مرات قبل فتح التطبيق.
      widget.nextZikr(kB);
      widget.nextZikr(kA);
      widget.tap(3);

      final plan = app.sync(widget);

      expect(plan.addedFromWidget, 3);
      expect(app.zikr, kA);
      expect(app.count, 15, reason: '12 محفوظة + 3 ضغطات بعد العودة');
      expect(app.counts[kA], 15);
      expect(app.counts[kB] ?? 0, 0, reason: 'B لم يُضغط عليه');
      expect(app.lifetime, 103);
      expect(widget.count, 15, reason: 'الويدجت يعرض الرصيد المدمج');
    });

    test('3 ضغطات على B ثم الانتقال إلى C وضغطتان ⇒ B +3 وC +2', () {
      final app = _App(
        zikr: kA,
        count: 6,
        lifetime: 20,
        storedCounts: {kA: 6},
      );
      final widget = _Widget(
        zikr: kA,
        count: 6,
        lifetime: 6,
        totals: {kA: 6},
        seededZikr: kA,
      );
      app.sync(widget);
      expect(app.count, 6);

      // كل هذا يحدث والتطبيق مغلق.
      widget.nextZikr(kB);
      widget.tap(3);
      widget.nextZikr(kC);
      widget.tap(2);

      final plan = app.sync(widget);

      expect(plan.addedFromWidget, 5);
      expect(app.zikr, kC, reason: 'التطبيق يتبع الذكر المعروض على الويدجت');
      expect(app.count, 2);
      expect(app.counts[kB], 3, reason: 'ضغطات B محفوظة رغم الانتقال منها');
      expect(app.counts[kC], 2);
      expect(app.counts[kA], 6, reason: 'عدّاد الذكر الأول لم يتأثر');
      expect(app.lifetime, 25);
    });

    test('الضغطات لا تضيع إذا أُغلق التطبيق قبل المزامنة', () {
      final app = _App(
        zikr: kA,
        count: 4,
        lifetime: 4,
        storedCounts: {kA: 4},
      );
      final widget = _Widget(
        zikr: kA,
        count: 4,
        lifetime: 4,
        totals: {kA: 4},
        seededZikr: kA,
      );
      app.sync(widget);

      // حالة محفوظة على القرص قبل الإغلاق (ما كتبه التطبيق آخر مرة).
      final savedCounts = Map<String, int>.from(app.counts);
      final savedSeen = Map<String, int>.from(app.seen);
      final savedLifetime = app.lifetime;

      // المستخدم يضغط من الويدجت بعد إغلاق التطبيق (عمليتان مختلفتان).
      widget.nextZikr(kB);
      widget.tap(3);
      widget.nextZikr(kC);
      widget.tap(2);

      // إعادة فتح التطبيق: نفس الحالة المحفوظة + السجل الأصلي كما هو.
      final reopened = _App(
        zikr: kA,
        count: savedCounts[kA] ?? 0,
        lifetime: savedLifetime,
        storedCounts: savedCounts,
        watermarks: savedSeen,
      );
      final plan = reopened.sync(widget);

      expect(plan.addedFromWidget, 5, reason: 'السجل الأصلي لم يُستهلك بعد');
      expect(reopened.counts[kB], 3);
      expect(reopened.counts[kC], 2);
      expect(reopened.lifetime, savedLifetime + 5);
    });

    test('إعادة المزامنة عدة مرات لا تضاعف ولا تفقد', () {
      final app = _App(
        zikr: kA,
        count: 0,
        lifetime: 0,
        storedCounts: {},
      );
      final widget = _Widget(zikr: kA, count: 0, lifetime: 0, totals: {});
      app.sync(widget);

      var expected = 0;
      for (var round = 1; round <= 5; round++) {
        widget.tap(2);
        expected += 2;
        final plan = app.sync(widget);
        expect(plan.addedFromWidget, 2, reason: 'الجولة $round');
        expect(app.count, expected);

        // مزامنات متكررة بدون أي ضغط جديد.
        for (var i = 0; i < 3; i++) {
          final repeat = app.sync(widget);
          expect(repeat.addedFromWidget, 0);
          expect(app.count, expected);
          expect(app.lifetime, expected);
        }
      }

      // تكرار بعد إعادة فتح التطبيق (State جديد من نفس المحفوظات).
      final reopened = _App(
        zikr: app.zikr,
        count: app.count,
        lifetime: app.lifetime,
        storedCounts: app.counts,
        watermarks: app.seen,
      );
      expect(reopened.sync(widget).addedFromWidget, 0);
      expect(reopened.count, expected);
    });

    test('الإجمالي يساوي مجموع الضغطات الفعلية عبر أذكار متعددة', () {
      final app = _App(
        zikr: kA,
        count: 0,
        lifetime: 0,
        storedCounts: {},
      );
      final widget = _Widget(zikr: kA, count: 0, lifetime: 0, totals: {});
      app.sync(widget);

      widget.tap(4); // A
      app.sync(widget);
      widget.nextZikr(kB);
      widget.tap(3); // B
      widget.nextZikr(kA);
      widget.tap(1); // A مرة أخرى
      app.sync(widget);

      final sum = app.counts.values.fold<int>(0, (a, b) => a + b);
      expect(app.counts[kA], 5);
      expect(app.counts[kB], 3);
      expect(app.lifetime, 8);
      expect(sum, app.lifetime, reason: 'الإجمالي = مجموع ضغطات الأذكار');
    });
  });

  group('الإجمالي وقيم العرض', () {
    test('يزيد بعدد الضغطات من الويدجت مرة واحدة فقط', () {
      final app = _App(
        zikr: kA,
        count: 0,
        lifetime: 200,
        storedCounts: {},
      );
      final widget = _Widget(zikr: kA, count: 0, lifetime: 200, totals: {});
      app.sync(widget);

      widget.tap(4);
      app.sync(widget);
      expect(app.lifetime, 204);

      app.sync(widget);
      app.sync(widget);
      expect(app.lifetime, 204);
    });

    test('التسبيح داخل التطبيق والويدجت يتجمعان في الإجمالي', () {
      final app = _App(
        zikr: kA,
        count: 0,
        lifetime: 10,
        storedCounts: {},
      );
      final widget = _Widget(zikr: kA, count: 0, lifetime: 10, totals: {});
      app.sync(widget);

      app.tapInApp(widget);
      app.tapInApp(widget);
      expect(app.lifetime, 12);

      widget.tap(3);
      app.sync(widget);

      expect(app.count, 5);
      expect(app.lifetime, 15, reason: '12 + 3 ضغطات من الويدجت');
    });
  });

  group('الانقطاع وإعادة التشغيل (ذرّية الحالة)', () {
    test('انقطاع بعد قراءة السجل وقبل الحفظ ⇒ لا ضياع ولا مضاعفة', () {
      final app = _App(
        zikr: kA,
        count: 5,
        lifetime: 5,
        storedCounts: {kA: 5},
      );
      final widget = _Widget(
        zikr: kA,
        count: 5,
        lifetime: 5,
        totals: {kA: 5},
        revision: 1,
        seededZikr: kA,
      );
      app.sync(widget);
      expect(app.count, 5);

      widget.tap(3); // ضغطات بعد آخر مزامنة ناجحة

      expect(
        () => app.sync(widget, crashAfterRead: true),
        throwsA(isA<_Crash>()),
      );

      // القرص لم يتغيّر: المراجعة لم تُستهلك والضغطات ما زالت في السجل الأصلي.
      final reopened = _App.restore(app.disk);
      final plan = reopened.sync(widget);
      expect(plan.addedFromWidget, 3);
      expect(reopened.count, 8);
      expect(reopened.lifetime, 8);
    });

    test('انقطاع بعد الحفظ ⇒ إعادة التشغيل لا تعيد استهلاك الضغطات', () {
      final app = _App(
        zikr: kA,
        count: 0,
        lifetime: 0,
        storedCounts: {},
      );
      final widget = _Widget(zikr: kA, count: 0, lifetime: 0, totals: {});
      app.sync(widget);

      widget.tap(4);
      expect(app.sync(widget).addedFromWidget, 4);
      expect(app.count, 4);

      // التطبيق «مات» بعد الكتابة مباشرة: يُستعاد من الحالة الذرّية.
      final reopened = _App.restore(app.disk);
      expect(reopened.seenRevision, app.seenRevision);
      expect(reopened.sync(widget).addedFromWidget, 0);
      expect(reopened.count, 4);
      expect(reopened.lifetime, 4);
    });

    test('المراجعة تُستعاد من الحالة الذرّية لا من المفتاح القديم', () {
      final app = _App(
        zikr: kA,
        count: 2,
        lifetime: 2,
        storedCounts: {kA: 2},
      );
      final widget = _Widget(
        zikr: kA,
        count: 2,
        lifetime: 2,
        totals: {kA: 2},
        revision: 7,
        seededZikr: kA,
      );
      app.sync(widget);
      expect(app.seenRevision, 7);

      // مفتاح قديم متأخر (5) يجب ألا يطغى على المراجعة الذرّية (7).
      app.disk.legacySeenRevision = 5;
      final reopened = _App.restore(app.disk);
      expect(reopened.seenRevision, 7);
      expect(reopened.sync(widget).addedFromWidget, 0);
    });

    test('إعادة التشغيل مرتين مع ضغطات بينهما لا تفقد ولا تضاعف', () {
      final disk = _Disk();
      var app = _App(
        zikr: kA,
        count: 0,
        lifetime: 0,
        storedCounts: {},
        disk: disk,
      );
      final widget = _Widget(zikr: kA, count: 0, lifetime: 0, totals: {});
      app.sync(widget);

      widget.tap(2);
      app.sync(widget);
      expect(app.count, 2);

      // إعادة تشغيل أولى + ضغطتان
      app = _App.restore(disk);
      widget.tap(2);
      expect(app.sync(widget).addedFromWidget, 2);
      expect(app.count, 4);

      // إعادة تشغيل ثانية بدون ضغطات
      app = _App.restore(disk);
      expect(app.sync(widget).addedFromWidget, 0);
      expect(app.count, 4);

      // إعادة تشغيل ثالثة + ضغطتان على ذكر آخر بعد التبديل
      app = _App.restore(disk);
      widget.nextZikr(kB);
      widget.tap(2);
      final plan = app.sync(widget);
      expect(plan.addedFromWidget, 2);
      expect(app.zikr, kB);
      expect(app.counts[kA], 4);
      expect(app.counts[kB], 2);
      expect(app.lifetime, 6);
    });

    test('مراجعة صفر في الحالة الحديثة لا يطغى عليها المفتاح القديم (5)', () {
      final disk = _Disk()
        ..blob = stateBlob(revision: 0, counts: {kA: 3}, seen: {kA: 3}, zikr: kA)
        ..legacySeenRevision = 5;

      final app = _App.restore(disk);
      expect(app.seenRevision, 0, reason: 'v=2 + حقل revision ⇒ القيمة 0 هي الصحيحة');

      // الويدجت ما زالت على المراجعة 0 ⇒ لا استهلاك جديد.
      final widget = _Widget(
        zikr: kA,
        count: 3,
        lifetime: 3,
        totals: {kA: 3},
        revision: 0,
        seededZikr: kA,
      );
      expect(app.sync(widget).addedFromWidget, 0);
      expect(app.count, 3);
    });

    test('حالة محفوظة من إصدار أقدم (بلا revision داخل الحالة) تُرقّى بأمان', () {
      final disk = _Disk()
        ..blob = jsonEncode(<String, dynamic>{
          'counts': {kA: 9},
          'seen': {kA: 9},
          'lifetime': 9,
          'zikr': kA,
        })
        ..legacySeenRevision = 3;

      final widget = _Widget(
        zikr: kA,
        count: 9,
        lifetime: 9,
        totals: {kA: 9},
        revision: 3,
        seededZikr: kA,
      );
      final app = _App.restore(disk);
      expect(app.seenRevision, 3, reason: 'يرجع للمفتاح القديم عند غيابه');
      expect(app.sync(widget).addedFromWidget, 0);
      expect(app.count, 9);

      widget.tap(1);
      expect(app.sync(widget).addedFromWidget, 1);
      expect(app.count, 10);
    });
  });

  group('حالات حدّية وتوافق خلفي', () {
    test('ويدجت أقدم من آخر مراجعة لا يغيّر شيئاً', () {
      final app = _App(
        zikr: kB,
        count: 15,
        lifetime: 60,
        storedCounts: {kB: 15},
      );
      app.seenRevision = 9;
      final widget = _Widget(
          zikr: 'ذكر قديم', count: 1, lifetime: 1, revision: 4);
      final plan = app.sync(widget);
      expect(plan.zikr, kB);
      expect(plan.count, 15);
      expect(plan.addedFromWidget, 0);
    });

    test('تحويل ويدجت بلا سجل ضغطات (إصدار أقدم) لا يفقد الضغطات', () {
      final app = _App(
        zikr: kA,
        count: 5,
        lifetime: 5,
        storedCounts: {kA: 5},
      );
      final widget = _Widget(
        zikr: kA,
        count: 5,
        lifetime: 5,
        totals: {},
        totalsSchema: 0,
      );
      app.sync(widget);
      expect(app.count, 5);

      widget.tap(2);
      final plan = app.sync(widget);
      expect(plan.addedFromWidget, 2);
      expect(app.count, 7);
    });

    test('عدّاد الويدجت أقل من خط الأساس لا ينقص العدّاد', () {
      final app = _App(
        zikr: kA,
        count: 20,
        lifetime: 20,
        storedCounts: {kA: 20},
      );
      final widget = _Widget(
        zikr: kA,
        count: 20,
        lifetime: 20,
        totals: {kA: 20},
        revision: 1,
        seededZikr: kA,
      );
      app.sync(widget);

      widget.count = 5; // إعادة تعيين للعرض فقط
      widget.revision += 1;
      app.sync(widget);
      expect(app.count, 20);
    });

    test('العلامة المائية لا تتراجع أبداً', () {
      final app = _App(
        zikr: kA,
        count: 10,
        lifetime: 10,
        storedCounts: {kA: 10},
      );
      final widget = _Widget(
        zikr: kA,
        count: 10,
        lifetime: 10,
        totals: {kA: 10},
        revision: 1,
        seededZikr: kA,
      );
      app.sync(widget);
      expect(app.seen[kA], 10);

      // سجل أصلي «تالف» أقل من العلامة: لا يُنقص العدّاد ولا العلامة.
      widget.totals[kA] = 3;
      widget.revision += 1;
      app.sync(widget);
      expect(app.count, 10);
      expect(app.seen[kA], 10);
    });

    test('بذور العلامات المائية تبدأ من صفر إلا للذكر المزروع', () {
      final seeds = seedWidgetWatermarks(
        totals: {kA: 12, kB: 3},
        appCountsByPhrase: {kA: 12},
        seededZikr: kA,
      );
      expect(seeds[kA], 12, reason: 'الذكر المزروع رصيده محسوب مسبقاً');
      expect(seeds[kB], 0, reason: 'ضغطات أي ذكر آخر جديدة بالكامل');
    });

    test('الترقية: رصيد الويدجت المزروع لا يُضاف مرتين', () {
      final app = _App(
        zikr: kA,
        count: 12,
        lifetime: 40,
        storedCounts: {kA: 12},
      );
      // ويدجت قديم حُدِّث: بذر سجله من العدّاد المعروض (12) للذكر A.
      final widget = _Widget(
        zikr: kA,
        count: 12,
        lifetime: 12,
        totals: {kA: 12},
        revision: 1,
        seededZikr: kA,
      );
      final plan = app.sync(widget);
      expect(plan.addedFromWidget, 0);
      expect(app.count, 12);
      expect(app.lifetime, 40);

      // وبعدها ضغطة جديدة تُحسب مرة واحدة.
      widget.tap(1);
      expect(app.sync(widget).addedFromWidget, 1);
      expect(app.count, 13);
    });
  });
}
