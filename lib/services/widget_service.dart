import 'package:home_widget/home_widget.dart';

/// مزامنة بيانات التطبيق مع تطبيقات الشاشة الرئيسية (Android Home Widgets).
///
/// الويدجت الأولى: «السبحة والذكر السريع» — عداد + ذكر + رصيد التطبيق.
/// الويدجت الثانية: «آية اليوم وورد الأذكار» — آية + حالة أذكار الصباح/المساء.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const String tasbihWidget = 'TasbihWidgetProvider';
  static const String ayahWidget = 'AyahWidgetProvider';

  static const String kZikrKey = 'widget_zikr';
  static const String kCountKey = 'widget_count';
  static const String kLifetimeKey = 'widget_lifetime';
  static const String kAyahKey = 'widget_ayah';
  static const String kAyahRefKey = 'widget_ayah_ref';
  static const String kMorningKey = 'widget_morning_done';
  static const String kEveningKey = 'widget_evening_done';
  static const String kAppLinkKey = 'widget_app_link';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await HomeWidget.setAppGroupId('com.flc.azkari');
    } catch (_) {}
  }

  /// يحدّث ويدجت السبحة بالذكر الحالي والعداد.
  Future<void> updateTasbih({
    required String zikr,
    required int count,
    required int lifetime,
    required String appLink,
  }) async {
    await init();
    try {
      await HomeWidget.saveWidgetData<String>(kZikrKey, zikr);
      await HomeWidget.saveWidgetData<int>(kCountKey, count);
      await HomeWidget.saveWidgetData<int>(kLifetimeKey, lifetime);
      await HomeWidget.saveWidgetData<String>(kAppLinkKey, appLink);
      await HomeWidget.updateWidget(
        name: tasbihWidget,
        androidName: tasbihWidget,
      );
    } catch (_) {}
  }

  /// يحدّث ويدجت آية اليوم وحالة الورد.
  Future<void> updateAyah({
    required String ayah,
    required String reference,
    required bool morningDone,
    required bool eveningDone,
    required String appLink,
  }) async {
    await init();
    try {
      await HomeWidget.saveWidgetData<String>(kAyahKey, ayah);
      await HomeWidget.saveWidgetData<String>(kAyahRefKey, reference);
      await HomeWidget.saveWidgetData<bool>(kMorningKey, morningDone);
      await HomeWidget.saveWidgetData<bool>(kEveningKey, eveningDone);
      await HomeWidget.saveWidgetData<String>(kAppLinkKey, appLink);
      await HomeWidget.updateWidget(
        name: ayahWidget,
        androidName: ayahWidget,
      );
    } catch (_) {}
  }

  /// يقرأ العداد الذي زاده المستخدم من ويدجت الشاشة الرئيسية.
  Future<({int count, int lifetime})> readTasbihFromWidget() async {
    await init();
    try {
      final count = await HomeWidget.getWidgetData<int>(kCountKey) ?? 0;
      final lifetime = await HomeWidget.getWidgetData<int>(kLifetimeKey) ?? 0;
      return (count: count, lifetime: lifetime);
    } catch (_) {
      return (count: 0, lifetime: 0);
    }
  }

  /// تحديث كامل بعد أي تغيير في السبحة أو الورد.
  Future<void> refreshAll() async {
    await updateTasbih(
      zikr: _lastZikr,
      count: _lastCount,
      lifetime: _lastLifetime,
      appLink: kAppLink,
    );
    await updateAyah(
      ayah: _lastAyah,
      reference: _lastAyahRef,
      morningDone: _lastMorning,
      eveningDone: _lastEvening,
      appLink: kAppLink,
    );
  }

  static const String kAppLink = 'https://apkpure.com/p/com.flc.azkari';

  // آخر قيم معروفة (لاستخدامها عند التحديث الشامل).
  String _lastZikr = '';
  int _lastCount = 0;
  int _lastLifetime = 0;
  String _lastAyah = '';
  String _lastAyahRef = '';
  bool _lastMorning = false;
  bool _lastEvening = false;

  Future<void> syncTasbih({
    required String zikr,
    required int count,
    required int lifetime,
  }) async {
    _lastZikr = zikr;
    _lastCount = count;
    _lastLifetime = lifetime;
    await updateTasbih(
      zikr: zikr,
      count: count,
      lifetime: lifetime,
      appLink: kAppLink,
    );
  }

  Future<void> syncAyah({
    required String ayah,
    required String reference,
    required bool morningDone,
    required bool eveningDone,
  }) async {
    _lastAyah = ayah;
    _lastAyahRef = reference;
    _lastMorning = morningDone;
    _lastEvening = eveningDone;
    await updateAyah(
      ayah: ayah,
      reference: reference,
      morningDone: morningDone,
      eveningDone: eveningDone,
      appLink: kAppLink,
    );
  }
}
