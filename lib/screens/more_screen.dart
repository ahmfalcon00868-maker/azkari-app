import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/city_clock.dart';
import '../services/khushu_service.dart';
import '../services/sun_times.dart';
import '../services/sunna_reminders.dart';
import 'tools_screen.dart' show kQiblaCities, QiblaCity;

/// هوية أذكاري داخل تبويب «المزيد».
class MoreColors {
  static const Color night = Color(0xFF0A192F);
  static const Color deepBlue = Color(0xFF0D47A1);
  static const Color sky = Color(0xFF0288D1);
  static const Color lightSky = Color(0xFF38BDF8);
  static const Color goldLight = Color(0xFFFDE047);
  static const Color gold = Color(0xFFF59E0B);
  static const String appLink = 'https://apkpure.com/p/com.flc.azkari';

  static Color bg(bool dark) => dark ? const Color(0xFF000000) : Colors.white;
  static Color card(bool dark) =>
      dark ? const Color(0xFF0B1626) : const Color(0xFFF8FAFC);
  static Color border(bool dark) =>
      dark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);
  static Color text(bool dark) =>
      dark ? Colors.white : const Color(0xFF0F172A);
  static Color textSoft(bool dark) =>
      dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
}

/// ترجمة محلية مختصرة (ar / en / tr).
String _t(String lang, String ar, String en, String tr) {
  if (lang == 'en') return en;
  if (lang == 'tr') return tr;
  return ar;
}

/// إحصائيات تُمرَّر من حالة التطبيق لعرض ملخص الجمعة.
class MoreStats {
  const MoreStats({
    required this.tasbihLifetime,
    required this.streak,
    required this.azkarDoneToday,
    required this.azkarTotalToday,
    required this.azkarDaysThisWeek,
  });

  final int tasbihLifetime;
  final int streak;
  final int azkarDoneToday;
  final int azkarTotalToday;
  final int azkarDaysThisWeek;
}

/// مفتاح أسبوع الجمعة (السنة-رقم الأسبوع) لتخزين قائمة التحقق.
String fridayWeekKey(DateTime now) {
  final thursday = now.add(Duration(days: (4 - now.weekday)));
  final firstDay = DateTime(thursday.year, 1, 1);
  final week = ((thursday.difference(firstDay).inDays) / 7).floor() + 1;
  return '${thursday.year}-W$week';
}

/// اليوم الهجري التقريبي (خوارزمية كويتية) لمعرفة الأيام البيض 13-14-15.
int hijriDayOf(DateTime date) {
  final jd = _gregorianToJdn(date.year, date.month, date.day);
  final l = jd - 1948440 + 10632;
  final n = ((l - 1) / 10631).floor();
  var l2 = l - 10631 * n + 354;
  final j =
      ((10985 - l2) / 5316).floor() * ((50 * l2) / 17719).floor() +
          (l2 / 5670).floor() * ((43 * l2) / 15238).floor();
  l2 = l2 -
      ((30 - j) / 15).floor() * ((17719 * j) / 50).floor() -
      (j / 16).floor() * ((15238 * j) / 43).floor() +
      29;
  final m = ((24 * l2) / 709).floor();
  final d = l2 - ((709 * m) / 24).floor();
  return d.clamp(1, 30);
}

int _gregorianToJdn(int y, int m, int d) {
  final a = ((14 - m) / 12).floor();
  final y2 = y + 4800 - a;
  final m2 = m + 12 * a - 3;
  return d +
      ((153 * m2 + 2) / 5).floor() +
      365 * y2 +
      (y2 / 4).floor() -
      (y2 / 100).floor() +
      (y2 / 400).floor() -
      32045;
}

/// تبويب «المزيد»: شبكة أقسام هادئة + المزايا الخمس الجديدة.
class MoreHubScreen extends StatefulWidget {
  const MoreHubScreen({
    super.key,
    required this.prefs,
    required this.appLang,
    required this.isDarkMode,
    required this.stats,
    required this.onOpenSettings,
  });

  final SharedPreferences prefs;
  final String appLang;
  final bool isDarkMode;
  final MoreStats stats;
  final VoidCallback onOpenSettings;

  @override
  State<MoreHubScreen> createState() => _MoreHubScreenState();
}

class _MoreHubScreenState extends State<MoreHubScreen> {
  String get lang => widget.appLang;
  bool get dark => widget.isDarkMode;

  Timer? _fridayBoundaryTimer;
  Timer? _fridayWatchTimer;
  String? _lastFridayState;

  @override
  void initState() {
    super.initState();
    _syncFridayDefaults();
    _lastFridayState = _fridayStateKey();
    _scheduleFridayWatch();
  }

  @override
  void dispose() {
    _fridayBoundaryTimer?.cancel();
    _fridayWatchTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickCity() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: MoreColors.card(dark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                _t(lang, 'مدينتك لحساب وقت المغرب', 'Your city for maghrib time',
                    'Meğrib vakti için şehriniz'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            for (var i = 0; i < kQiblaCities.length; i++)
              ListTile(
                dense: true,
                leading: const Icon(Icons.location_city_rounded,
                    size: 20, color: MoreColors.sky),
                title: Text(lang == 'en' ? kQiblaCities[i].nameEn : kQiblaCities[i].nameAr,
                    style: const TextStyle(fontSize: 13.5)),
                trailing: (widget.prefs.getInt('qiblaCityIdx') ?? 0) == i
                    ? const Icon(Icons.check_circle_rounded,
                        size: 18, color: MoreColors.sky)
                    : null,
                onTap: () {
                  widget.prefs.setInt('qiblaCityIdx', i);
                  Navigator.pop(ctx);
                  setState(() {});
                },
              ),
          ],
        ),
      ),
    );
  }

  void _syncFridayDefaults() {
    final cityDate = _cityToday;
    final key = fridayWeekKey(DateTime(cityDate.year, cityDate.month, cityDate.day));
    if (widget.prefs.getString('friday_checklist_week') != key) {
      widget.prefs.setString('friday_checklist_week', key);
      widget.prefs.setBool('friday_kahf', false);
      widget.prefs.setBool('friday_salawat', false);
      widget.prefs.setBool('friday_tabkeer', false);
      widget.prefs.setBool('friday_saah', false);
    }
  }

  /// المدينة المستخدمة لحساب المغرب (نفس مدينة القبلة لتفادي ازدواج الإعداد).
  QiblaCity get _city {
    final idx = widget.prefs.getInt('qiblaCityIdx') ?? 0;
    if (idx < 0 || idx >= kQiblaCities.length) return kQiblaCities.first;
    return kQiblaCities[idx];
  }

  /// تاريخ اليوم في **توقيت المدينة** (لا توقيت الجهاز).
  ({int weekday, int day, int month, int year}) get _cityToday =>
      CityClock.dateIn(DateTime.now().toUtc(), _city.timeZone);

  /// مغرب الخميس ومغرب الجمعة لهذا الأسبوع كـ**لحظات UTC** لموقع المدينة.
  ({DateTime? start, DateTime? end}) get _fridayWindow {
    final c = _city;
    final today = _cityToday;
    return fridaySunnahWindowUtc(
      DateTime.utc(today.year, today.month, today.day),
      latitude: c.lat,
      longitude: c.lng,
    );
  }

  /// بصمة حالة كارت الجمعة: (يوم الجمعة؟ + هل النافذة مفتوحة؟)
  String _fridayStateKey() {
    final isFriday = _cityToday.weekday == DateTime.friday;
    return '$isFriday-${_isSunnahWindowOpen()}';
  }

  bool _isSunnahWindowOpen() {
    final w = _fridayWindow;
    if (w.start == null || w.end == null) return false;
    return isFridaySunnahWindow(
      DateTime.now().toUtc(),
      thursdayMaghrib: w.start!,
      fridayMaghrib: w.end!,
    );
  }

  /// إعادة بناء تلقائية عند بداية النافذة ونهايتها، مع فحص كل دقيقة حتى لو
  /// بقيت الشاشة مفتوحة دون تفاعل (أو تغيّرت ساعة الجهاز).
  void _scheduleFridayWatch() {
    _fridayBoundaryTimer?.cancel();
    final w = _fridayWindow;
    final nowUtc = DateTime.now().toUtc();
    DateTime? target;
    if (w.start != null && nowUtc.isBefore(w.start!)) {
      target = w.start;
    } else if (w.end != null && nowUtc.isBefore(w.end!)) {
      target = w.end;
    }
    if (target != null) {
      final delay = target.difference(nowUtc) + const Duration(seconds: 1);
      _fridayBoundaryTimer = Timer(delay, () {
        if (!mounted) return;
        setState(() {});
        _scheduleFridayWatch();
      });
    }
    _fridayWatchTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final stateKey = _fridayStateKey();
      if (_lastFridayState != stateKey) {
        _lastFridayState = stateKey;
        setState(() {});
        _scheduleFridayWatch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final city = _city;
    final now = CityClock.at(DateTime.now().toUtc(), city.timeZone);
    final showFriday = now.weekday == DateTime.friday;
    final window = _fridayWindow;
    final showSunnah = _isSunnahWindowOpen();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        _header(),
        const SizedBox(height: 14),
        if (showFriday) ...[
          FridaySummaryCard(
            prefs: widget.prefs,
            lang: lang,
            isDarkMode: dark,
            stats: widget.stats,
          ),
          const SizedBox(height: 12),
        ],
        if (showSunnah) ...[
          FridaySunnahCard(
            prefs: widget.prefs,
            lang: lang,
            isDarkMode: dark,
            thursdayMaghribLabel: CityClock.format(window.start!, city.timeZone),
            fridayMaghribLabel: CityClock.format(window.end!, city.timeZone),
            cityAr: city.nameAr,
            cityEn: city.nameEn,
            timeZone: city.timeZone,
            onChangeCity: _pickCity,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
        ],
        _sectionTitle(_t(lang, 'العبادات اليومية', 'Daily worship', 'Günlük ibadet')),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.psychology_alt_rounded,
          title: _t(lang, 'كيف تشعر؟', 'How do you feel?', 'Nasıl hissediyorsun?'),
          subtitle: _t(lang, 'آية ودعاء وذكر يلامس حالتك',
              'A verse, dua and zikr for your state', 'Halini anlatan ayet, dua ve zikir'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => FeelingsScreen(lang: lang, isDarkMode: dark),
          )),
        ),
        _tile(
          icon: Icons.event_busy_rounded,
          title: _t(lang, 'متتبع القضاء وصيام السنن',
              'Qada & Sunnah Fasting Tracker', 'Kaza ve Sünnet Oruç Takibi'),
          subtitle: _t(lang, 'أيام القضاء، الإثنين والخميس، والأيام البيض',
              'Qada days, Mon/Thu and the white days', 'Kaza günleri, Pazartesi/Perşembe ve eyyam-ı biz'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => QadaTrackerScreen(
              prefs: widget.prefs,
              lang: lang,
              isDarkMode: dark,
            ),
          )),
        ),
        _khushuTile(),
        const SizedBox(height: 18),
        _sectionTitle(_t(lang, 'الأذكار والأدعية', 'Azkar & duas', 'Zikir ve dualar')),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.menu_book_rounded,
          title: _t(lang, 'ورد الأذكار', 'Azkar wird', 'Zikir virdi'),
          subtitle: _t(lang, 'صباح ومساء ونوم وصلاة', 'Morning, evening, sleep & prayer',
              'Sabah, akşam, uyku ve namaz'),
          onTap: () => _showInfo(
            _t(lang, 'ورد الأذكار', 'Azkar wird', 'Zikir virdi'),
            _t(lang, 'افتح تبويب «الأذكار» من الشريط السفلي لمتابعة وردك اليومي.',
                'Open the Azkar tab from the bottom bar to follow your daily wird.',
                'Günlük virdiniz için alt çubuktan Zikir sekmesini açın.'),
          ),
        ),
        _tile(
          icon: Icons.favorite_rounded,
          title: _t(lang, 'المفضلة', 'Favorites', 'Favoriler'),
          subtitle: _t(lang, 'أذكارك المحفوظة', 'Your saved azkar', 'Kaydedilen zikirler'),
          onTap: () => _showInfo(
            _t(lang, 'المفضلة', 'Favorites', 'Favoriler'),
            _t(lang, 'اضغط القلب بجانب أي ذكر لإضافته إلى المفضلة.',
                'Tap the heart next to any zikr to add it to favorites.',
                'Bir zikrin yanındaki kalbe dokunarak favorilere ekleyin.'),
          ),
        ),
        const SizedBox(height: 18),
        _sectionTitle(_t(lang, 'القرآن والحديث', 'Quran & hadith', 'Kur’an ve hadis')),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.auto_stories_rounded,
          title: _t(lang, 'القرآن الكريم', 'The Noble Quran', 'Kur’an-ı Kerim'),
          subtitle: _t(lang, 'قراءة وتلاوة وتفسير بدون إنترنت',
              'Read, listen and tafseer offline', 'Çevrimdışı oku, dinle ve tefsir'),
          onTap: () => _showInfo(
            _t(lang, 'القرآن الكريم', 'The Noble Quran', 'Kur’an-ı Kerim'),
            _t(lang, 'افتح تبويب «القرآن» لاختيار السورة والقارئ.',
                'Open the Quran tab to pick a surah and reciter.',
                'Sure ve kari seçmek için Kur’an sekmesini açın.'),
          ),
        ),
        _tile(
          icon: Icons.lightbulb_outline_rounded,
          title: _t(lang, 'استكشف الإسلام', 'Explore Islam', 'İslam’ı keşfet'),
          subtitle: _t(lang, 'بطاقات ومعرفة مبسطة', 'Cards & simple knowledge', 'Kartlar ve sade bilgi'),
          onTap: () => _showInfo(
            _t(lang, 'استكشف الإسلام', 'Explore Islam', 'İslam’ı keşfet'),
            _t(lang, 'ستجد هذا القسم داخل الصفحة الرئيسية.',
                'You will find this section on the home page.',
                'Bu bölümü ana sayfada bulacaksınız.'),
          ),
        ),
        const SizedBox(height: 18),
        _sectionTitle(_t(lang, 'الأدوات والإعدادات', 'Tools & settings', 'Araçlar ve ayarlar')),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.settings_rounded,
          title: _t(lang, 'الإعدادات', 'Settings', 'Ayarlar'),
          subtitle: _t(lang, 'المظهر، اللغة، الخط، التذكيرات والنسخ الاحتياطي',
              'Theme, language, font, reminders & backup',
              'Tema, dil, yazı tipi, hatırlatmalar ve yedek'),
          onTap: widget.onOpenSettings,
        ),
        _tile(
          icon: Icons.widgets_rounded,
          title: _t(lang, 'ويدجت الشاشة الرئيسية',
              'Home screen widgets', 'Ana ekran widgetları'),
          subtitle: _t(lang, 'السبحة السريعة وآية اليوم',
              'Quick tasbih & ayah of the day', 'Hızlı tesbih ve günün ayeti'),
          onTap: () => _showInfo(
            _t(lang, 'ويدجت الشاشة الرئيسية', 'Home screen widgets', 'Ana ekran widgetları'),
            _t(lang,
                'اضغط مطولاً على شاشة الهاتف ثم «الويدجت» واختر «أذكاري» لإضافة ويدجت السبحة أو آية اليوم.',
                'Long-press your home screen, choose Widgets, then Azkari to add the tasbih or ayah widget.',
                'Ana ekrana uzun basın, Widget seçin ve Azkari’yi seçerek tesbih veya ayet widgetını ekleyin.'),
          ),
        ),
        const SizedBox(height: 18),
        _sectionTitle(_t(lang, 'المساهمة والتواصل', 'Contribute & contact', 'Katkı ve iletişim')),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.workspace_premium_rounded,
          title: _t(lang, 'أذكاري PRO', 'Azkari PRO', 'Azkari PRO'),
          subtitle: _t(lang, 'ادعم التطبيق وافتح مزايا إضافية',
              'Support the app and unlock extras', 'Uygulamayı destekleyin ve ekstraları açın'),
          gold: true,
          onTap: () => _showInfo(
            _t(lang, 'أذكاري PRO', 'Azkari PRO', 'Azkari PRO'),
            _t(lang, 'شاشة الاشتراك متاحة من الصفحة الرئيسية.',
                'The subscription screen is available from the home page.',
                'Abonelik ekranı ana sayfadan açılır.'),
          ),
        ),
        _tile(
          icon: Icons.share_rounded,
          title: _t(lang, 'شارك التطبيق', 'Share the app', 'Uygulamayı paylaş'),
          subtitle: _t(lang, 'الدال على الخير كفاعله',
              'Who guides to good is like the doer', 'Hayra vesile olan yapan gibidir'),
          onTap: () => Share.share(_t(
            lang,
            'حمّل تطبيق «أذكاري» للقرآن والأذكار والسبحة بدون إنترنت:\n${MoreColors.appLink}',
            'Download Azkari for offline Quran, azkar and tasbih:\n${MoreColors.appLink}',
            'Azkari: çevrimdışı Kur’an, zikir ve tesbih:\n${MoreColors.appLink}',
          )),
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [MoreColors.deepBlue, MoreColors.sky],
            ),
          ),
          child: const Icon(Icons.apps_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(lang, 'المزيد', 'More', 'Daha fazla'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: MoreColors.text(dark),
                ),
              ),
              Text(
                _t(lang, 'كل ما تحتاجه في مكان واحد',
                    'Everything you need in one place',
                    'İhtiyacınız olan her şey bir arada'),
                style: TextStyle(fontSize: 12, color: MoreColors.textSoft(dark)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: MoreColors.textSoft(dark),
          ),
        ),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool gold = false,
  }) {
    final tint = gold ? MoreColors.gold : MoreColors.lightSky;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: MoreColors.card(dark),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MoreColors.border(dark)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: tint.withOpacity(0.14),
                  ),
                  child: Icon(icon, color: tint, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: MoreColors.text(dark),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: MoreColors.textSoft(dark),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: MoreColors.textSoft(dark)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _khushuTile() {
    final prefKey = 'khushu_pref_enabled';
    final enabled = widget.prefs.getBool(prefKey) ??
        KhushuService.active.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: MoreColors.card(dark),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MoreColors.border(dark)),
        ),
        child: SwitchListTile.adaptive(
          value: enabled,
          onChanged: (v) async {
            widget.prefs.setBool(prefKey, v);
            await KhushuService.toggle(value: v);
            setState(() {});
          },
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: MoreColors.lightSky.withOpacity(0.14),
            ),
            child: const Icon(Icons.dark_mode_rounded,
                color: MoreColors.lightSky, size: 21),
          ),
          title: Text(
            _t(lang, 'قفل الخشوع', 'Khushu lock', 'Huşu kilidi'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: MoreColors.text(dark),
            ),
          ),
          subtitle: Text(
            _t(lang, 'يمنع انطفاء الشاشة ويخفي الشريط السفلي أثناء القراءة',
                'Keeps the screen on and hides the bottom bar while reading',
                'Okurken ekranı açık tutar ve alt çubuğu gizler'),
            style: TextStyle(fontSize: 11.5, color: MoreColors.textSoft(dark)),
          ),
        ),
      ),
    );
  }

  void _showInfo(String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title),
        content: Text(body, style: const TextStyle(height: 1.6, fontSize: 13)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t(lang, 'حسناً', 'OK', 'Tamam')),
          ),
        ],
      ),
    );
  }
}

/// بطاقة «ملخص الجمعة» — تظهر يوم الجمعة فقط. المشاركة بذكر فقط بلا أرقام.
class FridaySummaryCard extends StatelessWidget {
  const FridaySummaryCard({
    super.key,
    required this.prefs,
    required this.lang,
    required this.isDarkMode,
    required this.stats,
  });

  final SharedPreferences prefs;
  final String lang;
  final bool isDarkMode;
  final MoreStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFF0B1F33), MoreColors.night]
              : [const Color(0xFFE0F2FE), Colors.white],
        ),
        border: Border.all(color: MoreColors.lightSky.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: MoreColors.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t(lang, 'صندوق حسناتك هذا الأسبوع',
                      'Your deeds box this week',
                      'Bu haftaki iyilik kutusu'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat(Icons.fingerprint_rounded, '${stats.tasbihLifetime}',
                  _t(lang, 'تسبيحة', 'tasbih', 'tesbih')),
              _stat(Icons.local_fire_department_rounded, '${stats.streak}',
                  _t(lang, 'يوم متتابع', 'day streak', 'gün serisi')),
              _stat(Icons.check_circle_rounded, '${stats.azkarDoneToday}',
                  _t(lang, 'ذكر اليوم', 'azkar today', 'bugünkü zikir')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // حفظ الإخلاص: نشارك ذكراً ورابط التطبيق فقط، بلا أرقام.
                Share.share(_t(
                  lang,
                  '«فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ»\n'
                  'جمعة مباركة، واذكر ربك إذا نسيت.\n${MoreColors.appLink}',
                  '“So remember Me; I will remember you…”\n'
                  'Blessed Friday. Remember your Lord.\n${MoreColors.appLink}',
                  '“Beni anın ki ben de sizi anayım…”\n'
                  'Mübarek cuma. Rabbinizi anın.\n${MoreColors.appLink}',
                ));
              },
              icon: const Icon(Icons.share_rounded, size: 17),
              label: Text(_t(lang, 'شارك ذكراً جميلاً', 'Share a beautiful zikr',
                  'Güzel bir zikir paylaş')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) => Expanded(
        child: Column(
          children: [
            Icon(icon, size: 18, color: MoreColors.lightSky),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900)),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10.5,
                    color: MoreColors.textSoft(isDarkMode))),
          ],
        ),
      );
}

/// بطاقة «سنن يوم الجمعة» — تظهر من مغرب الخميس حتى مغرب الجمعة فقط.
class FridaySunnahCard extends StatelessWidget {
  const FridaySunnahCard({
    super.key,
    required this.prefs,
    required this.lang,
    required this.isDarkMode,
    required this.thursdayMaghribLabel,
    required this.fridayMaghribLabel,
    required this.cityAr,
    required this.cityEn,
    required this.timeZone,
    required this.onChanged,
    this.onChangeCity,
  });

  final SharedPreferences prefs;
  final String lang;
  final bool isDarkMode;

  /// مغرب الخميس (بداية النافذة) ومغرب الجمعة (نهايتها) بتوقيت **المدينة**.
  final String thursdayMaghribLabel;
  final String fridayMaghribLabel;
  final String cityAr;
  final String cityEn;

  /// المنطقة الزمنية للمدينة (تُعرض للتوضيح: الوقت ليس بتوقيت الجهاز).
  final String timeZone;
  final VoidCallback onChanged;
  final VoidCallback? onChangeCity;

  static const List<List<String>> _items = [
    ['friday_kahf', 'سورة الكهف', 'Surah Al-Kahf', 'Kehf Suresi'],
    ['friday_salawat', 'الإكثار من الصلاة على النبي', 'Abundant salawat', 'Bol salavat'],
    ['friday_tabkeer', 'التبكير إلى الصلاة', 'Going early to prayer', 'Namaza erken gitmek'],
    ['friday_saah', 'الدعاء في ساعة الاستجابة', 'Dua in the hour of response', 'İcabet saatinde dua'],
  ];

  /// نص يوضح النافذة الفعلية (مغرب الخميس ← مغرب الجمعة) والمدينة المستخدمة.
  String _windowLabel() {
    final start = thursdayMaghribLabel;
    final end = fridayMaghribLabel;
    final cityName = lang == 'en' ? cityEn : cityAr;
    final city = '$cityName · $timeZone';
    if (lang == 'en') {
      return 'From Thursday maghrib $start to Friday maghrib $end — $city';
    }
    if (lang == 'tr') {
      return 'Perşembe meğribi $start — Cuma meğribi $end';
    }
    return 'من مغرب الخميس $start إلى مغرب الجمعة $end — $city';
  }

  @override
  Widget build(BuildContext context) {
    final done = _items.where((e) => prefs.getBool(e[0]) ?? false).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: MoreColors.card(isDarkMode),
        border: Border.all(color: MoreColors.gold.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.nightlight_round, color: MoreColors.gold, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t(lang, 'سنن يوم الجمعة', 'Friday sunnahs', 'Cuma sünnetleri'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Text('$done/${_items.length}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: MoreColors.gold)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.wb_twilight_rounded,
                  size: 14, color: MoreColors.sky),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _windowLabel(),
                  style: TextStyle(
                      fontSize: 10.5, color: MoreColors.textSoft(isDarkMode)),
                ),
              ),
              if (onChangeCity != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: _t(lang, 'تغيير المدينة', 'Change city', 'Şehri değiştir'),
                  onPressed: onChangeCity,
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ..._items.map((item) {
            final id = item[0];
            final label = lang == 'en'
                ? item[2]
                : (lang == 'tr' ? item[3] : item[1]);
            return CheckboxListTile.adaptive(
              value: prefs.getBool(id) ?? false,
              onChanged: (v) {
                prefs.setBool(id, v ?? false);
                onChanged();
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: MoreColors.sky,
              title: Text(label, style: const TextStyle(fontSize: 13)),
            );
          }),
        ],
      ),
    );
  }
}

/// ميزة «كيف تشعر؟»: آية + دعاء نبوي + ذكر قصير + مشاركة.
class FeelingsScreen extends StatelessWidget {
  const FeelingsScreen({super.key, required this.lang, required this.isDarkMode});

  final String lang;
  final bool isDarkMode;

  static const List<Map<String, String>> _feelings = [
    {
      'key': 'sad',
      'icon': 'sad',
      'ar': 'حزين',
      'en': 'Sad',
      'tr': 'Üzgün',
      'ayah': '﴿وَلَا تَهِنُوا وَلَا تَحْزَنُوا وَأَنتُمُ الْأَعْلَوْنَ إِن كُنتُم مُّؤْمِنِينَ﴾',
      'ayahRef': 'آل عمران: 139',
      'dua': '«اللهم إني عبدك، ابن عبدك، ابن أمتك… أسألك بكل اسم سميت به نفسك أن تجعل القرآن ربيع قلبي ونور صدري وجلاء حزني وذهاب همي»',
      'duaRef': 'رواه أحمد',
      'zikr': 'لا حول ولا قوة إلا بالله',
    },
    {
      'key': 'anxious',
      'icon': 'anxious',
      'ar': 'قلق',
      'en': 'Anxious',
      'tr': 'Endişeli',
      'ayah': '﴿أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ﴾',
      'ayahRef': 'الرعد: 28',
      'dua': '«اللهم إني أعوذ بك من الهم والحزن، والعجز والكسل، والبخل والجبن، وضلع الدين وغلبة الرجال»',
      'duaRef': 'رواه البخاري',
      'zikr': 'حسبي الله ونعم الوكيل',
    },
    {
      'key': 'worried',
      'icon': 'worried',
      'ar': 'مهموم',
      'en': 'Distressed',
      'tr': 'Sıkıntılı',
      'ayah': '﴿وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ﴾',
      'ayahRef': 'الطلاق: 3',
      'dua': '«لا إله إلا الله العظيم الحليم، لا إله إلا الله رب العرش العظيم، لا إله إلا الله رب السماوات ورب الأرض ورب العرش الكريم»',
      'duaRef': 'متفق عليه',
      'zikr': 'يا حي يا قيوم برحمتك أستغيث',
    },
    {
      'key': 'grateful',
      'icon': 'grateful',
      'ar': 'ممتن',
      'en': 'Grateful',
      'tr': 'Minnettar',
      'ayah': '﴿وَإِذْ تَأَذَّنَ رَبُّكُمْ لَئِن شَكَرْتُمْ لَأَزِيدَنَّكُمْ﴾',
      'ayahRef': 'إبراهيم: 7',
      'dua': '«اللهم أعني على ذكرك وشكرك وحسن عبادتك»',
      'duaRef': 'رواه أبو داود',
      'zikr': 'الحمد لله رب العالمين',
    },
    {
      'key': 'angry',
      'icon': 'angry',
      'ar': 'غاضب',
      'en': 'Angry',
      'tr': 'Öfkeli',
      'ayah': '﴿وَالْكَاظِمِينَ الْغَيْظَ وَالْعَافِينَ عَنِ النَّاسِ﴾',
      'ayahRef': 'آل عمران: 134',
      'dua': '«أعوذ بالله من الشيطان الرجيم»',
      'duaRef': 'متفق عليه',
      'zikr': 'اللهم اهدني لأحسن الأخلاق',
    },
    {
      'key': 'lost',
      'icon': 'lost',
      'ar': 'تائه',
      'en': 'Lost',
      'tr': 'Kaybolmuş',
      'ayah': '﴿وَمَن يَهْدِ اللَّهُ فَهُوَ الْمُهْتَدِ﴾',
      'ayahRef': 'الإسراء: 97',
      'dua': '«ربنا آتنا من لدنك رحمة وهيئ لنا من أمرنا رشدا»',
      'duaRef': 'الكهف: 10',
      'zikr': 'اللهم إني أسألك الهدى والتقى والعفاف والغنى',
    },
    {
      'key': 'sick',
      'icon': 'sick',
      'ar': 'مريض',
      'en': 'Ill',
      'tr': 'Hasta',
      'ayah': '﴿وَإِذَا مَرِضْتُ فَهُوَ يَشْفِينِ﴾',
      'ayahRef': 'الشعراء: 80',
      'dua': '«اللهم رب الناس، أذهب البأس، اشف أنت الشافي، لا شفاء إلا شفاؤك»',
      'duaRef': 'متفق عليه',
      'zikr': 'أسأل الله العظيم رب العرش العظيم أن يشفيك',
    },
  ];

  IconData _icon(String key) {
    switch (key) {
      case 'sad':
        return Icons.sentiment_dissatisfied_rounded;
      case 'anxious':
        return Icons.bolt_rounded;
      case 'worried':
        return Icons.cloud_rounded;
      case 'grateful':
        return Icons.favorite_rounded;
      case 'angry':
        return Icons.local_fire_department_rounded;
      case 'lost':
        return Icons.explore_off_rounded;
      case 'sick':
        return Icons.healing_rounded;
      default:
        return Icons.sentiment_neutral_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = MoreColors.text(isDarkMode);
    return Directionality(
      textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: MoreColors.bg(isDarkMode),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(_t(lang, 'كيف تشعر؟', 'How do you feel?', 'Nasıl hissediyorsun?')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              _t(lang, 'اختر ما يلامس حالك الآن',
                  'Choose what touches your state now',
                  'Şu anki halinize dokunanı seçin'),
              style: TextStyle(fontSize: 13, color: MoreColors.textSoft(isDarkMode)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _feelings.map((f) {
                final label = lang == 'en' ? f['en']! : (lang == 'tr' ? f['tr']! : f['ar']!);
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showFeeling(context, f),
                  child: Container(
                    width: 104,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: MoreColors.card(isDarkMode),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MoreColors.border(isDarkMode)),
                    ),
                    child: Column(
                      children: [
                        Icon(_icon(f['key']!),
                            color: MoreColors.lightSky, size: 24),
                        const SizedBox(height: 6),
                        Text(label,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: text)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeeling(BuildContext context, Map<String, String> f) {
    final label = lang == 'en' ? f['en']! : (lang == 'tr' ? f['tr']! : f['ar']!);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MoreColors.bg(isDarkMode),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon(f['key']!), color: MoreColors.lightSky),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              _card(
                title: _t(lang, 'آية', 'Verse', 'Ayet'),
                body: f['ayah']!,
                footer: f['ayahRef']!,
                accent: MoreColors.lightSky,
                serif: true,
              ),
              const SizedBox(height: 10),
              _card(
                title: _t(lang, 'دعاء نبوي', 'Prophetic dua', 'Peygamber duası'),
                body: f['dua']!,
                footer: f['duaRef']!,
                accent: MoreColors.gold,
              ),
              const SizedBox(height: 10),
              _card(
                title: _t(lang, 'ذكر قصير', 'Short zikr', 'Kısa zikir'),
                body: f['zikr']!,
                footer: '',
                accent: MoreColors.sky,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: MoreColors.sky,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Share.share(
                      '${f['ayah']!}\n${f['ayahRef']!}\n\n${f['dua']!}\n${f['duaRef']!}\n\n${f['zikr']!}\n\n${MoreColors.appLink}',
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text(_t(lang, 'مشاركة', 'Share', 'Paylaş')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required String body,
    required String footer,
    required Color accent,
    bool serif = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MoreColors.card(isDarkMode),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: accent)),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: serif ? 16 : 13.5,
              height: 1.8,
              fontFamily: serif && lang == 'ar' ? 'AmiriQuran' : null,
              color: MoreColors.text(isDarkMode),
            ),
          ),
          if (footer.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(footer,
                style: TextStyle(
                    fontSize: 11, color: MoreColors.textSoft(isDarkMode))),
          ],
        ],
      ),
    );
  }
}

/// «متتبع القضاء وصيام السنن»: أيام القضاء + تذكير الإثنين والخميس والأيام البيض.
class QadaTrackerScreen extends StatefulWidget {
  const QadaTrackerScreen({
    super.key,
    required this.prefs,
    required this.lang,
    required this.isDarkMode,
  });

  final SharedPreferences prefs;
  final String lang;
  final bool isDarkMode;

  @override
  State<QadaTrackerScreen> createState() => _QadaTrackerScreenState();
}

class _QadaTrackerScreenState extends State<QadaTrackerScreen> {
  String get lang => widget.lang;
  final SunnaReminders _reminders = SunnaReminders();

  /// ملاحظة: ترحيل/إعادة جدولة تذكيرات السنن صارت عند بدء التطبيق
  /// (انظر `ReminderBootstrap`)، وليس عند فتح هذه الشاشة.

  int get _owed => widget.prefs.getInt('qada_days_total') ?? 0;
  int get _done => widget.prefs.getInt('qada_days_done') ?? 0;

  void _set({int? total, int? done}) {
    if (total != null) widget.prefs.setInt('qada_days_total', total < 0 ? 0 : total);
    if (done != null) widget.prefs.setInt('qada_days_done', done < 0 ? 0 : done);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (_owed - _done).clamp(0, 100000);
    final now = DateTime.now();
    final hijriDay = hijriDayOf(now);
    final isWhiteDay = hijriDay >= 13 && hijriDay <= 15;
    final reminderOn = widget.prefs.getBool('sunna_fast_reminder') ?? false;

    return Scaffold(
      backgroundColor: MoreColors.bg(widget.isDarkMode),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_t(lang, 'القضاء وصيام السنن', 'Qada & sunnah fasting',
            'Kaza ve sünnet oruç')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: MoreColors.card(widget.isDarkMode),
              border: Border.all(color: MoreColors.border(widget.isDarkMode)),
            ),
            child: Column(
              children: [
                Text(
                  _t(lang, 'أيام القضاء المتبقية', 'Remaining qada days',
                      'Kalan kaza günleri'),
                  style: TextStyle(
                      fontSize: 13, color: MoreColors.textSoft(widget.isDarkMode)),
                ),
                const SizedBox(height: 6),
                Text('$remaining',
                    style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: MoreColors.lightSky)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => _set(total: _owed - 1),
                      child: const Icon(Icons.remove_rounded, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _t(lang, 'إجمالي: $_owed', 'Total: $_owed', 'Toplam: $_owed'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _set(total: _owed + 1),
                      child: const Icon(Icons.add_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: MoreColors.sky,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: remaining == 0 ? null : () => _set(done: _done + 1),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(_t(lang, 'إتمام يوم قضاء', 'Complete a qada day',
                        'Bir kaza günü tamamla')),
                  ),
                ),
                Text(
                  _t(lang, 'أُتممتَ $_done يوماً', 'Completed: $_done', 'Tamamlanan: $_done'),
                  style: TextStyle(
                      fontSize: 11.5,
                      color: MoreColors.textSoft(widget.isDarkMode)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: MoreColors.card(widget.isDarkMode),
              border: Border.all(color: MoreColors.gold.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_available_rounded,
                        color: MoreColors.gold, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _t(lang, 'صيام السنن', 'Sunnah fasting', 'Sünnet oruç'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _t(
                    lang,
                    'الإثنين والخميس أسبوعياً، والأيام البيض 13 و14 و15 من كل شهر هجري.',
                    'Mondays and Thursdays weekly, plus the white days 13, 14 and 15 of each Hijri month.',
                    'Her hafta Pazartesi ve Perşembe, ayrıca her hicri ayın 13, 14 ve 15. günleri.',
                  ),
                  style: const TextStyle(fontSize: 12.5, height: 1.7),
                ),
                if (isWhiteDay) ...[
                  const SizedBox(height: 8),
                  Text(
                    _t(lang, 'اليوم من الأيام البيض ($hijriDay هجري) — نوى لك صياماً.',
                        'Today is a white day ($hijriDay Hijri).',
                        'Bugün eyyam-ı bizden ($hijriDay hicri).'),
                    style: const TextStyle(
                        fontSize: 12,
                        color: MoreColors.gold,
                        fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: reminderOn,
                  onChanged: (v) async {
                    // 1) نحفظ اختيار المستخدم 2) نطبّق الجدولة الأسبوعية (أو نلغيها).
                    await widget.prefs.setBool('sunna_fast_reminder', v);
                    await _reminders.apply(
                      enabled: v,
                      mondayTitle: _t(lang, 'صيام الإثنين', 'Monday fasting',
                          'Pazartesi orucu'),
                      thursdayTitle: _t(lang, 'صيام الخميس', 'Thursday fasting',
                          'Perşembe orucu'),
                      body: _t(lang, 'لا تنس صيام اليوم إن شاء الله.',
                          'Do not forget today\u2019s fast.',
                          'Bugünkü orucu unutmayın.'),
                    );
                    if (!mounted) return;
                    setState(() {});
                  },
                  subtitle: Text(
                    _t(
                      lang,
                      'تذكير أسبوعي: الإثنين ٤:٣٠ ص والخميس ٤:٣٥ ص فقط',
                      'Weekly only: Monday 4:30 AM and Thursday 4:35 AM',
                      'Haftalık: Pazartesi 04:30 ve Perşembe 04:35',
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                  title: Text(
                    _t(lang, 'تذكير هادئ بالصيام', 'Gentle fasting reminder',
                        'Nazik oruç hatırlatması'),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
                Text(
                  _t(lang,
                      'ملاحظة: التذكيرات أسبوعية (الإثنين والخميس) في موعد الإمساك التقريبي؛ راجع وقت الإمساك في مدينتك.',
                      'Note: reminders are weekly (Monday & Thursday) at an approximate pre-dawn time; confirm your local fasting time.',
                      'Not: hatırlatmalar haftalıktır (Pazartesi ve Perşembe) yaklaşık imsak vaktinde; yerel imsak vaktinizi kontrol edin.'),
                  style: TextStyle(
                      fontSize: 10.5,
                      color: MoreColors.textSoft(widget.isDarkMode)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// أداة مساعدة للاختبارات: تحويل قائمة إلى JSON آمن.
String encodeChecklist(Map<String, bool> map) => jsonEncode(map);
