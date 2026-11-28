import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:azkari/services/widget_sync_logic.dart';
import 'package:azkari/services/widget_sync_store.dart';

const String kA = 'سبحان الله';
const String kB = 'أستغفر الله';

String stateJson({
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

void main() {
  group('WidgetSyncState — تحليل الحالة الذرّية', () {
    test('يفكّ الحقول الحديثة كاملة', () {
      final state = WidgetSyncState.tryParse(stateJson(
        counts: {kA: 15},
        seen: {kA: 15},
        lifetime: 15,
        zikr: kA,
        revision: 9,
      ))!;
      expect(state.isModern, isTrue);
      expect(state.hasRevision, isTrue);
      expect(state.counts[kA], 15);
      expect(state.watermarks[kA], 15);
      expect(state.lifetime, 15);
      expect(state.zikr, kA);
      expect(state.revision, 9);
    });

    test('نص فارغ أو تالف أو غير كائن ⇒ null', () {
      expect(WidgetSyncState.tryParse(null), isNull);
      expect(WidgetSyncState.tryParse('   '), isNull);
      expect(WidgetSyncState.tryParse('{oops'), isNull);
      expect(WidgetSyncState.tryParse('[1,2,3]'), isNull);
    });

    test('encode ثم tryParse يعيدان نفس القيم', () {
      const original = WidgetSyncState(
        counts: {kA: 3, kB: 2},
        watermarks: {kA: 3},
        lifetime: 5,
        zikr: kA,
        revision: 7,
      );
      final parsed = WidgetSyncState.tryParse(original.encode())!;
      expect(parsed.counts, original.counts);
      expect(parsed.watermarks, original.watermarks);
      expect(parsed.lifetime, 5);
      expect(parsed.zikr, kA);
      expect(parsed.revision, 7);
      expect(parsed.isModern, isTrue);
    });
  });

  group('resolveRevision — صفر ليس غيابًا', () {
    test('v=2 و revision=0 مع مفتاح قديم = 5 ⇒ صفر من الحالة الحديثة', () {
      final state = WidgetSyncState.tryParse(stateJson(revision: 0))!;
      expect(WidgetSyncState.resolveRevision(state, 5), 0);
    });

    test('v=2 و revision=7 مع مفتاح قديم = 5 ⇒ 7', () {
      final state = WidgetSyncState.tryParse(stateJson(revision: 7))!;
      expect(WidgetSyncState.resolveRevision(state, 5), 7);
    });

    test('v=2 بلا حقل revision ⇒ المفتاح القديم', () {
      final state = WidgetSyncState.tryParse(stateJson(revision: null))!;
      expect(state.isModern, isTrue);
      expect(state.hasRevision, isFalse);
      expect(WidgetSyncState.resolveRevision(state, 5), 5);
    });

    test('حالة قديمة (v مفقود) مع revision ⇒ المفتاح القديم', () {
      final state = WidgetSyncState.tryParse(stateJson(version: 0, revision: 9))!;
      expect(state.isModern, isFalse);
      expect(WidgetSyncState.resolveRevision(state, 5), 5);
    });

    test('لا حالة أصلًا ⇒ المفتاح القديم', () {
      expect(WidgetSyncState.resolveRevision(null, 5), 5);
    });
  });

  group('WidgetSyncStore — إثبات الحفظ على القرص', () {
    late Directory tempDir;
    late SharedPreferences prefs;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('azkari_sync_test');
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    WidgetSyncStore newStore() => WidgetSyncStore(
          prefs: prefs,
          directoryProvider: () async => tempDir,
        );

    test('الكتابة تعيد true ويظهر المحتوى في الملف على القرص', () async {
      final store = newStore();
      final payload = stateJson(counts: {kA: 2}, zikr: kA, revision: 4);

      expect(await store.write(payload), isTrue);
      expect(await store.rawFileContents(), payload);
    });

    test('إعادة إنشاء المتجر (إعادة تشغيل) تقرأ نفس الحالة', () async {
      final payload = stateJson(counts: {kA: 6}, seen: {kA: 6}, revision: 6);
      expect(await newStore().write(payload), isTrue);

      // متجر جديد فوق نفس المجلد ونفس التفضيلات.
      expect(await newStore().read(), payload);
    });

    test('الملف يتقدّم على نسخة التفضيلات', () async {
      final store = newStore();
      final filePayload = stateJson(counts: {kA: 9}, revision: 9);
      await store.write(filePayload);

      // نسخة تفضيلات قديمة/مختلفة.
      await prefs.setString('widget_sync_state', stateJson(revision: 1));
      expect(await store.read(), filePayload);
    });

    test('غياب الملف ⇒ يرجع لنسخة التفضيلات', () async {
      final store = newStore();
      final payload = stateJson(counts: {kB: 3}, revision: 3);
      await store.write(payload);
      await store.deleteFileForTests();

      expect(await store.read(), payload);
    });

    test('ملف تالف ⇒ يتجاهله ويقرأ نسخة التفضيلات', () async {
      final store = newStore();
      final payload = stateJson(counts: {kA: 1}, revision: 1);
      await store.write(payload);

      final file = File('${tempDir.path}/widget_sync_state.json');
      await file.writeAsString('{ تالف', flush: true);

      expect(await store.read(), payload);
    });

    test('لا ملف ولا تفضيلات ⇒ null', () async {
      expect(await newStore().read(), isNull);
    });

    test('النسخة الاحتياطية تحمل القيمة نفسها للتحقق', () async {
      final payload = stateJson(counts: {kA: 5}, revision: 12);
      await newStore().write(payload);
      expect(prefs.getString('widget_sync_state'), payload);
    });
  });
}
