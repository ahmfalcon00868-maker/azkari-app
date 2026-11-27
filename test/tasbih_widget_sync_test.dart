import 'package:flutter_test/flutter_test.dart';

import 'package:azkari/services/widget_sync_logic.dart';

/// محاكاة لدورة الحياة الحقيقية: تطبيق + ويدجت + مزامنة في الاتجاهين.
///
/// التطبيق يدفع حالته إلى الويدجت بعد كل مزامنة (كما في `syncTasbihWidget`)
/// ولا يزيد المراجعة؛ الجانب الأصلي وحده يزيد المراجعة عند تغيير الذكر أو
/// الضغط على العدّاد.
class _Widget {
  _Widget({
    this.zikr = '',
    this.count = 0,
    this.lifetime = 0,
    this.revision = 0,
  });

  String zikr;
  int count;
  int lifetime;
  int revision;

  /// ضغطة واحدة على عدّاد الويدجت.
  void tap([int times = 1]) {
    for (var i = 0; i < times; i++) {
      count += 1;
      lifetime += 1;
      revision += 1;
    }
  }

  /// تغيير الذكر من الويدجت (يُصفّر العدّاد ويزيد المراجعة).
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
      );
}

class _App {
  _App({
    required this.zikr,
    required this.count,
    required this.lifetime,
    required Map<String, int> storedCounts,
  }) : counts = Map<String, int>.from(storedCounts) {
    counts[zikr] = count;
  }

  String zikr;
  int count;
  int lifetime;
  final Map<String, int> counts;

  int seenRevision = 0;
  int lastPushedCount = 0;
  String lastPushedZikr = '';

  /// مزامنة واحدة: سحب من الويدجت ثم دفع حالة التطبيق إليه.
  TasbihSyncPlan sync(_Widget widget) {
    final plan = planTasbihSync(
      widget: widget.snapshot(),
      appZikr: zikr,
      appCount: count,
      appLifetime: lifetime,
      seenRevision: seenRevision,
      appCountForWidgetZikr: counts[widget.zikr] ?? widget.count,
      lastPushedCount: lastPushedCount,
      lastPushedZikr: lastPushedZikr,
    );

    seenRevision = plan.seenRevision;
    zikr = plan.zikr;
    count = plan.count;
    lifetime = plan.lifetime;
    counts[zikr] = count;

    // الدفع إلى الويدجت (لا يزيد المراجعة).
    widget.zikr = zikr;
    widget.count = count;
    widget.lifetime = lifetime;
    lastPushedZikr = zikr;
    lastPushedCount = count;

    return plan;
  }

  /// تسبيح من داخل التطبيق (يتبعه دفع فوري إلى الويدجت كما في التطبيق).
  void tapInApp(_Widget widget) {
    count += 1;
    lifetime += 1;
    counts[zikr] = count;
    widget.zikr = zikr;
    widget.count = count;
    widget.lifetime = lifetime;
    lastPushedZikr = zikr;
    lastPushedCount = count;
  }
}

void main() {
  group('لا تُفقد ضغطات الويدجت بعد تغيير الذكر', () {
    test('12 تسبيحة محفوظة + تغيير الذكر من الويدجت + 3 ضغطات = 15', () {
      final app = _App(
        zikr: 'سبحان الله',
        count: 5,
        lifetime: 50,
        storedCounts: {'سبحان الله': 5, 'أستغفر الله': 12},
      );
      final widget = _Widget(zikr: 'سبحان الله', count: 5, lifetime: 50);
      app.sync(widget); // مزامنة أولى (تبني خط الأساس)

      // المستخدم يغيّر الذكر من الويدجت ثم يضغط 3 مرات قبل فتح التطبيق.
      widget.nextZikr('أستغفر الله');
      widget.tap(3);

      final plan = app.sync(widget);

      expect(plan.adoptedZikr, isTrue);
      expect(app.zikr, 'أستغفر الله');
      expect(plan.addedFromWidget, 3);
      expect(app.count, 15, reason: '12 محفوظة + 3 ضغطات جديدة');
      expect(app.counts['أستغفر الله'], 15);
      expect(app.counts['سبحان الله'], 5, reason: 'عدّاد الذكر السابق محفوظ');
      expect(widget.count, 15, reason: 'الويدجت يعرض الرصيد المدمج');
    });

    test('تكرار المزامنة لا يضاعف العدد', () {
      final app = _App(
        zikr: 'سبحان الله',
        count: 5,
        lifetime: 50,
        storedCounts: {'أستغفر الله': 12},
      );
      final widget = _Widget(zikr: 'سبحان الله', count: 5, lifetime: 50);
      app.sync(widget);

      widget.nextZikr('أستغفر الله');
      widget.tap(3);
      app.sync(widget);
      expect(app.count, 15);

      // ثلاث مزامنات إضافية دون أي ضغط جديد.
      for (var i = 0; i < 3; i++) {
        final plan = app.sync(widget);
        expect(plan.addedFromWidget, 0);
        expect(app.count, 15);
        expect(app.lifetime, 53);
      }
    });

    test('ضغطات جديدة بعد المزامنة تُضاف مرة واحدة فقط', () {
      final app = _App(
        zikr: 'أستغفر الله',
        count: 15,
        lifetime: 53,
        storedCounts: {'أستغفر الله': 15},
      );
      final widget = _Widget(zikr: 'أستغفر الله', count: 15, lifetime: 53);
      app.sync(widget);

      widget.tap(2); // 17
      expect(app.sync(widget).addedFromWidget, 2);
      expect(app.count, 17);

      // إعادة المزامنة بعد الدفع لا تضيف شيئاً.
      expect(app.sync(widget).addedFromWidget, 0);
      expect(app.count, 17);
    });

    test('التبديل بين أكثر من ذكر يحفظ عدّاد كل ذكر', () {
      final app = _App(
        zikr: 'سبحان الله',
        count: 10,
        lifetime: 100,
        storedCounts: {'سبحان الله': 10, 'أستغفر الله': 12, 'الحمد لله': 7},
      );
      final widget = _Widget(zikr: 'سبحان الله', count: 10, lifetime: 100);
      app.sync(widget);

      // إلى أستغفر الله + ضغطتان
      widget.nextZikr('أستغفر الله');
      widget.tap(2);
      app.sync(widget);
      expect(app.zikr, 'أستغفر الله');
      expect(app.count, 14); // 12 + 2

      // إلى الحمد لله + 5 ضغطات
      widget.nextZikr('الحمد لله');
      widget.tap(5);
      app.sync(widget);
      expect(app.zikr, 'الحمد لله');
      expect(app.count, 12); // 7 + 5
      expect(app.counts['أستغفر الله'], 14);

      // عودة إلى أستغفر الله دون ضغطات: يبقى 14
      widget.nextZikr('أستغفر الله');
      app.sync(widget);
      expect(app.zikr, 'أستغفر الله');
      expect(app.count, 14);
      expect(app.counts['الحمد لله'], 12);

      // وضغطة واحدة عليه ⇒ 15
      widget.tap();
      app.sync(widget);
      expect(app.count, 15);
    });
  });

  group('إجمالي التسبيحات (lifetime)', () {
    test('يزيد بعدد الضغطات من الويدجت مرة واحدة فقط', () {
      final app = _App(
        zikr: 'سبحان الله',
        count: 0,
        lifetime: 200,
        storedCounts: {},
      );
      final widget = _Widget(zikr: 'سبحان الله', count: 0, lifetime: 200);
      app.sync(widget);

      widget.tap(4);
      app.sync(widget);
      expect(app.lifetime, 204);

      // إعادة المزامنة لا تزيد الإجمالي
      app.sync(widget);
      app.sync(widget);
      expect(app.lifetime, 204);
    });

    test('لا ينقص إذا كان إجمالي التطبيق أكبر', () {
      final app = _App(
        zikr: 'سبحان الله',
        count: 3,
        lifetime: 1000,
        storedCounts: {'أستغفر الله': 0},
      );
      final widget = _Widget(zikr: 'سبحان الله', count: 3, lifetime: 100);
      app.sync(widget);

      widget.nextZikr('أستغفر الله');
      widget.tap(2);
      app.sync(widget);

      expect(app.count, 2); // 0 محفوظ + 2
      expect(app.lifetime, 1002); // إجمالي التطبيق + الضغطات الجديدة
    });

    test('التسبيح داخل التطبيق والويدجت يتجمعان في الإجمالي', () {
      final app = _App(
        zikr: 'سبحان الله',
        count: 0,
        lifetime: 10,
        storedCounts: {},
      );
      final widget = _Widget(zikr: 'سبحان الله', count: 0, lifetime: 10);
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

  group('حالات حدّية', () {
    test('ويدجت أقدم من آخر مراجعة لا يغيّر شيئاً', () {
      final app = _App(
        zikr: 'أستغفر الله',
        count: 15,
        lifetime: 60,
        storedCounts: {'أستغفر الله': 15},
      );
      app.seenRevision = 9;
      final widget = _Widget(
          zikr: 'ذكر قديم', count: 1, lifetime: 1, revision: 4);
      final plan = app.sync(widget);
      expect(plan.zikr, 'أستغفر الله');
      expect(plan.count, 15);
    });

    test('عدّاد الويدجت أقل من خط الأساس لا ينقص العدّاد', () {
      final app = _App(
        zikr: 'سبحان الله',
        count: 20,
        lifetime: 20,
        storedCounts: {'سبحان الله': 20},
      );
      final widget = _Widget(zikr: 'سبحان الله', count: 20, lifetime: 20);
      app.sync(widget);

      // مراجعة جديدة لكن العدّاد تراجع (إعادة تعيين في النظام مثلاً).
      widget.count = 5;
      widget.revision += 1;
      app.sync(widget);
      expect(app.count, 20);
    });
  });
}
