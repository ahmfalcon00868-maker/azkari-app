import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/azkar_data.dart';
import 'screens/explore_islamic_screen.dart';
import 'screens/quran_screen.dart';
import 'screens/tools_screen.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'widgets/google_play_icon.dart';

const String kAppDownloadLink =
    'https://github.com/ahmfalcon00868-maker/azkari-app/releases/latest';

const List<String> kSplashVerses = [
  '﴿وَاذْكُرْ رَبَّكَ إِذَا نَسِيتَ﴾',
  '﴿أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ﴾',
  '﴿فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ﴾',
  '﴿وَسَبِّحْ بِحَمْدِ رَبِّكَ قَبْلَ طُلُوعِ الشَّمْسِ وَقَبْلَ غُرُوبِهَا﴾',
  '﴿وَالذَّاكِرِينَ اللَّهَ كَثِيرًا وَالذَّاكِرَاتِ أَعَدَّ اللَّهُ لَهُمْ مَغْفِرَةً وَأَجْرًا عَظِيمًا﴾',
];

String stripAllTashkeel(String input) {
  return input.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '');
}

const List<String> kFloatingAzkarPool = [
  'سبحان الله وبحمده',
  'سبحان الله العظيم',
  'أستغفر الله العظيم وأتوب إليه',
  'الحمد لله رب العالمين',
  'لا إله إلا الله وحده لا شريك له',
  'الله أكبر كبيرا والحمد لله كثيرا',
  'لا حول ولا قوة إلا بالله العلي العظيم',
  'لا إله إلا أنت سبحانك إني كنت من الظالمين',
  'اللهم صل وسلم وبارك على نبينا محمد',
  'صل على رسول الله محمد',
  'صل على محمد وآل محمد',
  'حسبي الله لا إله إلا هو عليه توكلت',
  'سبحان الله والحمد لله ولا إله إلا الله والله أكبر',
  'اللهم إني أسألك الهدى والتقى والعفاف والغنى',
  'رب اغفر لي ولوالدي وللمؤمنين',
  'اللهم أعني على ذكرك وشكرك وحسن عبادتك',
  'يا حي يا قيوم برحمتك أستغيث',
  'اللهم إنك عفو تحب العفو فاعف عني',
  'رضيت بالله ربا وبالإسلام دينا وبمحمد صلى الله عليه وسلم نبيا',
  'اللهم بارك لنا في أوقاتنا وأعمالنا',
  'تذكير: حان وقت ذكر الله وأذكار الصباح والمساء',
  'تذكير: لا تنس الصلاة في وقتها والخشوع فيها',
  'تذكير: اقرأ وردك اليومي من القرآن الكريم',
  'اللهم ارزقنا حسن الخاتمة وثبت قلوبنا على دينك',
  'أصبحنا وأصبح الملك لله والحمد لله',
  'أمسينا وأمسى الملك لله والحمد لله',
  'باسمك اللهم أموت وأحيا',
  'سبحان الله وبحمده عدد خلقه ورضا نفسه وزنة عرشه ومداد كلماته',
  'اللهم اجعل القرآن ربيع قلوبنا ونور صدورنا',
  'ربنا آتنا في الدنيا حسنة وفي الآخرة حسنة وقنا عذاب النار',
  'اللهم اغفر للمسلمين والمسلمات الأحياء منهم والأموات',
  'أستغفر الله الذي لا إله إلا هو الحي القيوم وأتوب إليه',
];

class SoundEffectsService {
  static final SoundEffectsService instance = SoundEffectsService._();
  SoundEffectsService._();

  Future<void> init() async {}
  Future<void> playTap() async {}
  Future<void> playChime33() async {}
}

String toEnglishTranslit(String ar) {
  final clean = ar.replaceAll(RegExp(r'[ً-ٰٟ]'), '').trim();
  if (clean.contains('الله لا إله إلا هو الحي القيوم')) {
    return 'Allahu la ilaha illa Huwal-Hayyul-Qayyum... (Ayat Al-Kursi)';
  }
  if (clean.contains('قل هو الله أحد')) return 'Qul Huwa Allahu Ahad... (Al-Ikhlas)';
  if (clean.contains('قل أعوذ برب الفلق')) return 'Qul A’udhu bi-Rabbil-Falaq... (Al-Falaq)';
  if (clean.contains('قل أعوذ برب الناس')) return 'Qul A’udhu bi-Rabbin-Nas... (An-Nas)';
  if (clean.contains('أصبحنا وأصبح الملك لله')) return 'Asbahna wa asbahal-mulku lillah, wal-hamdulillahi...';
  if (clean.contains('أمسينا وأمسى الملك لله')) return 'Amsayna wa amsal-mulku lillah, wal-hamdulillahi...';
  if (clean.contains('اللهم أنت ربي لا إله إلا أنت')) return 'Allahumma Anta Rabbi la ilaha illa Anta... (Sayyid Al-Istighfar)';
  if (clean.contains('رضيت بالله ربا')) return 'Raditu billahi Rabban wa bil-Islami dinan wa bi-Muhammadin nabiyya.';
  if (clean.contains('حسبي الله لا إله إلا هو')) return 'Hasbiyallahu la ilaha illa Huwa alayhi tawakkaltu.';
  if (clean.contains('بسم الله الذي لا يضر مع اسمه')) return 'Bismillahil-ladhi la yadurru ma’asmihi shay’un fil-ardi wa la fis-sama’.';
  if (clean.contains('سبحان الله وبحمده')) return 'SubhanAllahi wa bihamdih.';
  if (clean.contains('أستغفر الله')) return 'Astaghfirullahal-Azim wa atubu ilayh.';
  if (clean.contains('اللهم صل')) return 'Allahumma salli wa sallim ala Nabiyyina Muhammad.';
  if (clean.contains('يا مقلب القلوب')) return 'Ya Muqallibal-qulubi thabbit qalbi ala dinik.';
  if (clean.contains('الحمد لله')) return 'Alhamdulillah.';
  if (clean.contains('لا إله إلا الله وحده لا شريك له')) return 'La ilaha illAllahu wahdahu la sharika lah...';
  if (clean.contains('أعوذ بكلمات الله التامات')) return 'A’udhu bi-kalimatillahit-tammati min sharri ma khalaq.';
  if (clean.contains('يا حي يا قيوم')) return 'Ya Hayyu Ya Qayyum bi-rahmatika astaghith.';
  if (clean.contains('اللهم عافني في بدني')) return 'Allahumma afini fi badani, Allahumma afini fi sam’i...';
  if (clean.contains('اللهم إني أعوذ بك من الهم')) return 'Allahumma inni a’udhu bika minal-hammi wal-hazan...';
  if (clean.contains('اللهم إني أسألك العفو والعافية')) return 'Allahumma inni as’alukal-afwa wal-afiyah fid-dunya wal-akhirah.';
  // General phonetic fallback
  const map = {
    'ا': 'a', 'أ': 'a', 'إ': 'i', 'آ': 'aa', 'ب': 'b', 'ت': 't', 'ث': 'th',
    'ج': 'j', 'ح': 'h', 'خ': 'kh', 'د': 'd', 'ذ': 'dh', 'ر': 'r', 'ز': 'z',
    'س': 's', 'ش': 'sh', 'ص': 's', 'ض': 'd', 'ط': 't', 'ظ': 'z', 'ع': '’',
    'غ': 'gh', 'ف': 'f', 'ق': 'q', 'ك': 'k', 'ل': 'l', 'م': 'm', 'ن': 'n',
    'ه': 'h', 'و': 'w', 'ي': 'y', 'ى': 'a', 'ة': 'h', 'ء': '’', 'ئ': 'y',
    'ؤ': 'w', ' ': ' ', '\n': '\n',
  };
  final buf = StringBuffer();
  for (final r in clean.runes) {
    final ch = String.fromCharCode(r);
    buf.write(map[ch] ?? '');
  }
  return buf.toString();
}


String translateShortZikr(String ar, String lang) {
  if (lang == 'ar') return ar;
  const enMap = {
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ': 'SubhanAllahi wa bihamdih (Glory and praise be to Allah)',
    'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ وَأَتُوبُ إِلَيْهِ': 'Astaghfirullahal-Azim wa atubu ilayh',
    'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ': 'Alhamdulillahi Rabbil-Alamin',
    'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ': 'Allahumma salli wa sallim ala Nabiyyina Muhammad',
    'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ': 'La hawla wa la quwwata illa billah',
    'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ': 'La ilaha illa Anta subhanaka inni kuntu minaz-zalimin',
    'سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ': 'SubhanAllah, Alhamdulillah, La ilaha illAllah, Allahu Akbar',
    'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ': 'HasbiyAllahu la ilaha illa Huwa alayhi tawakkaltu',
  };
  const trMap = {
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ': 'Subhanallahi ve bihamdih',
    'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ وَأَتُوبُ إِلَيْهِ': 'Estağfirullah el-Azim ve etübü ileyh',
    'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ': 'Elhamdülillahi Rabbil-Alemin',
    'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ': 'Allahümme salli ve sellim ala Nebiyyina Muhammed',
    'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ': 'La havle ve la kuvvete illa billah',
    'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ': 'La ilahe illa Ente subhaneke inni küntü minez-zalimin',
    'سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ': 'Subhanallah, Elhamdülillah, La ilahe illallah, Allahu Ekber',
    'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ': 'Hasbiyallahu la ilahe illa Hu aleyhi tevekkeltü',
  };
  if (lang == 'tr') return trMap[ar] ?? ar;
  return enMap[ar] ?? ar;
}

String lightTashkeel(String text) {
  return text.replaceAll(RegExp(r'[\u064E\u064F\u0650\u0652]'), '');
}

String formatHijriAndGregorian(DateTime date, String lang) {
  const weekDaysAr = [
    'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
  ];
  const weekDaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const weekDaysTr = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  const hijriMonthsAr = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
  ];
  const hijriMonthsEn = [
    'Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani', 'Jumada al-Ula', 'Jumada al-Akhirah',
    'Rajab', 'Sha’ban', 'Ramadan', 'Shawwal', 'Dhul-Qi’dah', 'Dhul-Hijjah'
  ];
  const hijriMonthsTr = [
    'Muharrem', 'Safer', 'Rebiülevvel', 'Rebiülahir', 'Cemaziyelevvel', 'Cemaziyelahir',
    'Recep', 'Şaban', 'Ramazan', 'Şevval', 'Zilkade', 'Zilhicce'
  ];
  final jd = (date.millisecondsSinceEpoch / 86400000).floor() + 2440588;
  final l = jd - 1948440 + 10632;
  final n = ((l - 1) / 10631).floor();
  final l2 = l - 10631 * n + 354;
  final j = ((10985 - l2) / 5316).floor() * ((50 * l2) / 17719).floor() +
      (l2 / 5670).floor() * ((43 * l2) / 15238).floor();
  final l3 = l2 -
      ((30 - j) / 15).floor() * ((17719 * j) / 50).floor() -
      (j / 16).floor() * ((15238 * j) / 43).floor() +
      29;
  final hMonth = ((24 * l3) / 709).floor();
  final hDay = l3 - ((709 * hMonth) / 24).floor();
  final hYear = 30 * n + j - 30;

  final wIdx = (date.weekday - 1).clamp(0, 6);
  final mIdx = (hMonth - 1).clamp(0, 11);
  final gStr = '${date.day}/${date.month}/${date.year}';
  if (lang == 'tr') {
    return '${weekDaysTr[wIdx]} • $hDay ${hijriMonthsTr[mIdx]} $hYear • $gStr';
  }
  if (lang == 'en') {
    return '${weekDaysEn[wIdx]} • $hDay ${hijriMonthsEn[mIdx]} $hYear AH • $gStr';
  }
  return '${weekDaysAr[wIdx]} • $hDay ${hijriMonthsAr[mIdx]} $hYear هـ • $gStr';
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _FloatingZikrOverlayWidget(),
    ),
  );
}

class _FloatingZikrOverlayWidget extends StatefulWidget {
  const _FloatingZikrOverlayWidget();

  @override
  State<_FloatingZikrOverlayWidget> createState() =>
      _FloatingZikrOverlayWidgetState();
}

class _FloatingZikrOverlayWidgetState
    extends State<_FloatingZikrOverlayWidget> {
  String _zikr = kRandomShortAzkar[0];
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _zikr = kRandomShortAzkar[Random().nextInt(kRandomShortAzkar.length)];
    _resetAutoHide();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is String && event.trim().isNotEmpty && mounted) {
        setState(() => _zikr = event);
        _resetAutoHide();
      }
    });
  }

  void _resetAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 6), () {
      FlutterOverlayWindow.closeOverlay();
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(top: 38, left: 16, right: 16),
        child: Align(
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => FlutterOverlayWindow.closeOverlay(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A192F), Color(0xFF0D47A1), Color(0xFF0288D1)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF38BDF8), width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0288D1).withOpacity(0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 34,
                      height: 34,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF38BDF8),
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'أذكاري • واذكر ربك إذا نسيت',
                          style: TextStyle(
                            color: Color(0xFFBAE6FD),
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _zikr,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'NotoKufi',
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                ],
              ),
            ),
          ),
      ),
    ),
    );
  }
}

class AppColors {
  static const Color primaryBlue = Color(0xFF0D47A1);
  static const Color skyBlue = Color(0xFF38BDF8);
  static const Color midBlue = Color(0xFF0288D1);

  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF5F7FA);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  static const Color backgroundDark = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF101010);
  static const Color borderDark = Color(0xFF222222);
  static const Color primaryDark = Color(0xFF4FC3F7);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFA0AEC0);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.azkari.azkari.channel.audio',
      androidNotificationChannelName: 'تلاوة القرآن الكريم • أذكاري',
      androidNotificationOngoing: true,
      notificationColor: const Color(0xFF0D47A1),
    );
  } catch (_) {}
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final prefs = await SharedPreferences.getInstance();
  try {
    await NotificationService.instance.init();
  } catch (_) {}
  runApp(AzkariApp(prefs: prefs));
}

class AzkariApp extends StatefulWidget {
  final SharedPreferences prefs;
  const AzkariApp({super.key, required this.prefs});

  @override
  State<AzkariApp> createState() => _AzkariAppState();
}

class _AzkariAppState extends State<AzkariApp> {
  late bool isDarkMode;
  late String appLang; // 'ar', 'en', 'tr'
  bool get isEnglish => appLang == 'en';
  bool get isTurkish => appLang == 'tr';
  set isEnglish(bool v) => appLang = v ? 'en' : 'ar';
  late bool buttonSoundEnabled;
  late bool hapticEnabled;
  late double fontScale;
  late String azkarFontFamily;
  late bool minimalTashkeel;
  late bool autoNext;
  late bool showProgress;
  late bool showSource;
  late bool collapseCompletedAzkar;
  late bool dailyAudio;
  late bool morningReminder;
  late bool eveningReminder;
  late bool sleepReminder;
  late bool floatingEnabled;
  late int floatingIntervalMinutes;
  late int tasbihCount;
  late int tasbihLifetime;
  late String tasbihPhrase;
  late Map<String, int> tasbihCountsByPhrase;
  late int currentStreak;
  late int bestStreak;
  late int totalAzkarCompleted;
  late String lastActiveDate;
  late String firstInstallDate;
  late bool hasRatedPromptShown;
  late bool taskMorningDone;
  late bool taskEveningDone;
  late bool taskSleepDone;
  late bool taskMulkDone;
  late bool taskKahfDone;
  late String tasksDate;
  late String fbUserName;
  late String fbUserPhoto;
  late List<ZikrItem> azkarList;
  late List<Map<String, dynamic>> customAzkar;
  late List<String> customTasbihPhrases;
  late bool onboardingDone;
  late String reminderMode; // 'notification' or 'overlay'
  late bool dailyAyahEnabled;
  late int dailyAyahIndex;
  late Map<int, Map<String, dynamic>> editedAzkarOverrides;
  late Set<int> deletedAzkarIds;
  late String lastDailyAyahDate;
  late String lastStartupAudioDate;
  late String lastDoubleRewardPromptDate;
  late List<String> activeDaysHistory;
  Timer? _floatingTimer;
  Timer? _saveDebounce;
  final ap.AudioPlayer _splashAudioPlayer = ap.AudioPlayer();
  final ap.AudioPlayer _salawatPlayer = ap.AudioPlayer();

  String tr(String ar, String en, [String? trText]) {
    if (appLang == 'tr') return trText ?? kEnToTrUi[en] ?? en;
    if (appLang == 'en') return en;
    return ar;
  }

  void showLanguagePicker(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              tr('اختر اللغة', 'Choose Language', 'Dil Seçin'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final item in const [
              ('ar', 'العربية', 'Arabic'),
              ('en', 'English', 'İngilizce'),
              ('tr', 'Türkçe', 'Turkish'),
            ])
              ListTile(
                leading: const Icon(Icons.public_rounded, color: AppColors.skyBlue),
                title: Text(item.$2, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: appLang == item.$1
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.skyBlue)
                    : null,
                onTap: () {
                  appLang = item.$1;
                  saveAllState(resyncTimers: false);
                  Navigator.pop(bCtx);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void playTapFeedback({bool stronger = false, bool silentChime = false}) {
    if (hapticEnabled) {
      if (stronger) {
        HapticFeedback.vibrate();
        Future.delayed(
          const Duration(milliseconds: 65),
          () => HapticFeedback.heavyImpact(),
        );
      } else {
        HapticFeedback.lightImpact();
      }
    }
  }

  List<Color> get sabhaColors {
    final skin = widget.prefs.getInt('sabhaSkin') ?? 0;
    switch (skin) {
      case 1:
        return const [Color(0xFF065F46), Color(0xFF10B981)];
      case 2:
        return const [Color(0xFF92400E), Color(0xFFD97706)];
      case 3:
        return const [Color(0xFF0F172A), Color(0xFF334155)];
      default:
        return const [Color(0xFF0D47A1), Color(0xFF0288D1)];
    }
  }

  @override
  void initState() {
    super.initState();
    SoundEffectsService.instance.init();
    _loadPrefsFromDisk();
    _rebuildAzkarList();
    _syncReminders();
    _syncFloatingTimer();
    _playStartupAyahAudio();
  }

  Future<void> _playStartupAyahAudio() async {
    final today = DateTime.now().toIso8601String().split('T').first;
    if (!dailyAudio || lastStartupAudioDate == today) return;
    lastStartupAudioDate = today;
    widget.prefs.setString('lastStartupAudioDate', today);
    try {
      await _splashAudioPlayer.play(ap.AssetSource('audio/splash_ayah.mp3'));
    } catch (_) {}
  }

  void _loadPrefsFromDisk() {
    final p = widget.prefs;
    final today = DateTime.now().toIso8601String().split('T').first;

    isDarkMode = p.getBool('darkMode') ?? true;
    appLang = p.getString('appLang') ?? ((p.getBool('isEnglish') ?? false) ? 'en' : 'ar');
    buttonSoundEnabled = p.getBool('buttonSoundEnabled') ?? true;
    hapticEnabled = p.getBool('hapticEnabled') ?? true;
    fontScale = p.getDouble('fontScale') ?? 1.0;
    azkarFontFamily = p.getString('azkarFontFamily') ?? 'NotoKufi';
    minimalTashkeel = p.getBool('minimalTashkeel') ?? true;
    autoNext = p.getBool('autoNext') ?? true;
    showProgress = p.getBool('showProgress') ?? true;
    showSource = p.getBool('showSource') ?? true;
    collapseCompletedAzkar = p.getBool('collapseCompletedAzkar') ?? false;
    dailyAudio = p.getBool('dailyAudio') ?? true;
    morningReminder = p.getBool('morningReminder') ?? true;
    eveningReminder = p.getBool('eveningReminder') ?? true;
    sleepReminder = p.getBool('sleepReminder') ?? true;
    floatingEnabled = p.getBool('floatingEnabled') ?? false;
    floatingIntervalMinutes = p.getInt('floatingIntervalMinutes') ?? 60;
    onboardingDone = p.getBool('onboardingDone') ?? false;
    reminderMode = p.getString('reminderMode') ?? 'notification';
    dailyAyahEnabled = p.getBool('dailyAyahEnabled') ?? true;
    dailyAyahIndex = p.getInt('dailyAyahIndex') ?? 0;
    customTasbihPhrases = p.getStringList('customTasbihPhrases') ?? [];

    editedAzkarOverrides = {};
    final edRaw = p.getString('editedAzkarOverrides');
    if (edRaw != null) {
      try {
        final decoded = jsonDecode(edRaw) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          final id = int.tryParse(k);
          if (id != null && v is Map<String, dynamic>) {
            editedAzkarOverrides[id] = v;
          }
        });
      } catch (_) {}
    }
    deletedAzkarIds = (p.getStringList('deletedAzkarIds') ?? [])
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .toSet();
    tasbihPhrase =
        p.getString('tasbihPhrase') ?? 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ';
    tasbihLifetime = p.getInt('tasbihLifetime') ?? 0;

    final mapRaw = p.getString('tasbihCountsByPhrase');
    tasbihCountsByPhrase = {};
    if (mapRaw != null) {
      try {
        final decoded = jsonDecode(mapRaw) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          tasbihCountsByPhrase[k] = (v as num).toInt();
        });
      } catch (_) {}
    }
    tasbihCount =
        tasbihCountsByPhrase[tasbihPhrase] ?? (p.getInt('tasbihCount') ?? 0);

    currentStreak = p.getInt('currentStreak') ?? 0;
    bestStreak = p.getInt('bestStreak') ?? 0;
    totalAzkarCompleted = p.getInt('totalAzkarCompleted') ?? 0;
    lastActiveDate = p.getString('lastActiveDate') ?? '';
    firstInstallDate = p.getString('firstInstallDate') ?? today;
    if (p.getString('firstInstallDate') == null) {
      p.setString('firstInstallDate', today);
    }
    hasRatedPromptShown = p.getBool('hasRatedPromptShown') ?? false;

    tasksDate = p.getString('tasksDate') ?? today;
    if (tasksDate != today) {
      taskMorningDone = false;
      taskEveningDone = false;
      taskSleepDone = false;
      taskMulkDone = false;
      taskKahfDone = false;
      tasksDate = today;
      p.setString('tasksDate', today);
    } else {
      taskMorningDone = p.getBool('taskMorningDone') ?? false;
      taskEveningDone = p.getBool('taskEveningDone') ?? false;
      taskSleepDone = p.getBool('taskSleepDone') ?? false;
      taskMulkDone = p.getBool('taskMulkDone') ?? false;
      taskKahfDone = p.getBool('taskKahfDone') ?? false;
    }

    lastDailyAyahDate = p.getString('lastDailyAyahDate') ?? '';
    lastStartupAudioDate = p.getString('lastStartupAudioDate') ?? '';
    lastDoubleRewardPromptDate = p.getString('lastDoubleRewardPromptDate') ?? '';
    activeDaysHistory = p.getStringList('activeDaysHistory') ?? [today];
    if (!activeDaysHistory.contains(today)) {
      activeDaysHistory.add(today);
      if (activeDaysHistory.length > 60) {
        activeDaysHistory = activeDaysHistory.sublist(activeDaysHistory.length - 60);
      }
      p.setStringList('activeDaysHistory', activeDaysHistory);
    }
    fbUserName = p.getString('fbUserName') ?? '';
    fbUserPhoto = p.getString('fbUserPhoto') ?? '';

    final customRaw = p.getString('customAzkar');
    if (customRaw != null) {
      try {
        customAzkar =
            (jsonDecode(customRaw) as List<dynamic>).cast<Map<String, dynamic>>();
      } catch (_) {
        customAzkar = [];
      }
    } else {
      customAzkar = [];
    }
  }

  void switchTasbihPhrase(String newPhrase) {
    tasbihCountsByPhrase[tasbihPhrase] = tasbihCount;
    tasbihPhrase = newPhrase;
    tasbihCount = tasbihCountsByPhrase[newPhrase] ?? 0;
    saveAllState();
  }

  void refreshAfterRestore() {
    _loadPrefsFromDisk();
    _restoreAzkarState();
    setState(() {});
  }

  void _restoreAzkarState() {
    final raw = widget.prefs.getString('azkarState');
    if (raw != null) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        for (final entry in decoded) {
          final matches = azkarList.where((z) => z.id == entry['id']);
          if (matches.isNotEmpty) {
            matches.first.count = entry['count'] ?? 0;
            matches.first.favorite = entry['favorite'] ?? matches.first.favorite;
          }
        }
      } catch (_) {}
    }
  }

  void recordDailyActivity({String? completedCategory}) {
    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;
    final yesterday =
        now.subtract(const Duration(days: 1)).toIso8601String().split('T').first;

    if (lastActiveDate != today) {
      if (lastActiveDate == yesterday) {
        currentStreak += 1;
      } else {
        currentStreak = 1;
      }
      if (currentStreak > bestStreak) bestStreak = currentStreak;
      lastActiveDate = today;
    }

    if (completedCategory == 'morning') taskMorningDone = true;
    if (completedCategory == 'evening') taskEveningDone = true;
    if (completedCategory == 'sleep') taskSleepDone = true;
    saveAllState();
  }

  bool isSecondDayOrLater() {
    final install = DateTime.tryParse(firstInstallDate);
    if (install == null) return false;
    return DateTime.now().difference(install).inHours >= 24;
  }

  Future<void> loginWithFacebook(BuildContext context) async {
    try {
      final result = await FacebookAuth.instance.login(
        permissions: ['public_profile'],
      );
      if (result.status == LoginStatus.success) {
        final userData = await FacebookAuth.instance.getUserData(
          fields: 'name,picture.width(200)',
        );
        fbUserName = (userData['name'] ?? '').toString();
        fbUserPhoto =
            ((userData['picture']?['data']?['url']) ?? '').toString();
        saveAllState();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr(
                'تم تسجيل الدخول بنجاح: $fbUserName',
                'Signed in as $fbUserName',
              )),
            ),
          );
        }
      } else if (context.mounted && result.status != LoginStatus.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(
              'تعذر تسجيل الدخول بفيسبوك',
              'Facebook login failed',
            )),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(
              'تحقق من الاتصال بالإنترنت وإعدادات فيسبوك',
              'Check internet connection and Facebook setup',
            )),
          ),
        );
      }
    }
  }

  Future<void> logoutFacebook() async {
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
    fbUserName = '';
    fbUserPhoto = '';
    saveAllState();
  }

  Future<void> _syncReminders() async {
    try {
      if (morningReminder) {
        await NotificationService.instance.scheduleDaily(
          id: 101,
          title: 'أذكاري • أذكار الصباح',
          body: '﴿وَاذْكُرْ رَبَّكَ إِذَا نَسِيتَ﴾ حان وقت أذكار الصباح',
          hour: 6,
          minute: 0,
        );
      } else {
        await NotificationService.instance.cancel(101);
      }
      if (eveningReminder) {
        await NotificationService.instance.scheduleDaily(
          id: 102,
          title: 'أذكاري • أذكار المساء',
          body: '﴿وَاذْكُرْ رَبَّكَ إِذَا نَسِيتَ﴾ حان وقت أذكار المساء',
          hour: 17,
          minute: 0,
        );
      } else {
        await NotificationService.instance.cancel(102);
      }
      if (sleepReminder) {
        await NotificationService.instance.scheduleDaily(
          id: 103,
          title: 'أذكاري • أذكار النوم',
          body: 'اختم يومك بأذكار النوم في سكينة وطمأنينة',
          hour: 22,
          minute: 30,
        );
      } else {
        await NotificationService.instance.cancel(103);
      }
    } catch (_) {}
  }

  void _syncFloatingTimer() {
    _floatingTimer?.cancel();
    _saveDebounce?.cancel();
    if (!floatingEnabled) return;
    _floatingTimer = Timer.periodic(
      Duration(minutes: floatingIntervalMinutes),
      (_) => showFloatingZikrNow(),
    );
  }

  Future<void> showFloatingZikrNow() async {
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        await FlutterOverlayWindow.requestPermission();
        return;
      }
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
      final rawPhrase =
          kFloatingAzkarPool[Random().nextInt(kFloatingAzkarPool.length)];
      final phrase = stripAllTashkeel(rawPhrase);
      if (phrase.contains('صل على') || phrase.contains('صلي على') || phrase.contains('محمد')) {
        try {
          await _salawatPlayer.stop();
          await _salawatPlayer.play(ap.AssetSource('audio/salawat.mp3'));
        } catch (_) {}
      }
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        height: 124,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.topCenter,
        flag: OverlayFlag.defaultFlag,
      );
      await FlutterOverlayWindow.shareData(phrase);
    } catch (_) {}
  }

  void _rebuildAzkarList() {
    final base = getInitialAzkarList()
        .where((z) => !deletedAzkarIds.contains(z.id))
        .map((z) {
      final ov = editedAzkarOverrides[z.id];
      if (ov != null) {
        return ZikrItem(
          id: z.id,
          category: z.category,
          categoryLabel: z.categoryLabel,
          text: ov['text'] as String? ?? z.text,
          source: ov['source'] as String? ?? z.source,
          target: ov['target'] as int? ?? z.target,
          count: z.count,
          favorite: z.favorite,
        );
      }
      return z;
    }).toList();
    azkarList = base;
    _restoreAzkarState();
  }

  void saveLightState() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 450), () {
      final p = widget.prefs;
      tasbihCountsByPhrase[tasbihPhrase] = tasbihCount;
      p.setInt('tasbihCount', tasbihCount);
      p.setInt('tasbihLifetime', tasbihLifetime);
      p.setString('tasbihCountsByPhrase', jsonEncode(tasbihCountsByPhrase));
      p.setInt('totalAzkarCompleted', totalAzkarCompleted);
      p.setInt('currentStreak', currentStreak);
      p.setInt('bestStreak', bestStreak);
      p.setString('lastActiveDate', lastActiveDate);
      p.setString(
        'azkarState',
        jsonEncode(azkarList.map((e) => e.toJson()).toList()),
      );
    });
  }

  void saveAzkarEditsOnly() {
    final p = widget.prefs;
    final mapEnc = <String, dynamic>{};
    editedAzkarOverrides.forEach((k, v) {
      mapEnc[k.toString()] = v;
    });
    p.setString('editedAzkarOverrides', jsonEncode(mapEnc));
    p.setStringList(
        'deletedAzkarIds', deletedAzkarIds.map((e) => e.toString()).toList());
    p.setString('customAzkar', jsonEncode(customAzkar));
    p.setString(
      'azkarState',
      jsonEncode(azkarList.map((e) => e.toJson()).toList()),
    );
  }

  void saveAllState({bool resyncTimers = true}) {
    final p = widget.prefs;
    tasbihCountsByPhrase[tasbihPhrase] = tasbihCount;
    p.setBool('darkMode', isDarkMode);
    p.setString('appLang', appLang);
    p.setBool('isEnglish', isEnglish);
    p.setBool('buttonSoundEnabled', buttonSoundEnabled);
    p.setBool('hapticEnabled', hapticEnabled);
    p.setDouble('fontScale', fontScale);
    p.setString('azkarFontFamily', azkarFontFamily);
    p.setBool('minimalTashkeel', minimalTashkeel);
    p.setBool('autoNext', autoNext);
    p.setBool('showProgress', showProgress);
    p.setBool('showSource', showSource);
    p.setBool('collapseCompletedAzkar', collapseCompletedAzkar);
    p.setBool('dailyAudio', dailyAudio);
    p.setBool('morningReminder', morningReminder);
    p.setBool('eveningReminder', eveningReminder);
    p.setBool('sleepReminder', sleepReminder);
    p.setBool('floatingEnabled', floatingEnabled);
    p.setInt('floatingIntervalMinutes', floatingIntervalMinutes);
    p.setInt('tasbihCount', tasbihCount);
    p.setInt('tasbihLifetime', tasbihLifetime);
    p.setString('tasbihPhrase', tasbihPhrase);
    p.setString('tasbihCountsByPhrase', jsonEncode(tasbihCountsByPhrase));
    p.setInt('currentStreak', currentStreak);
    p.setInt('bestStreak', bestStreak);
    p.setInt('totalAzkarCompleted', totalAzkarCompleted);
    p.setString('lastActiveDate', lastActiveDate);
    p.setBool('hasRatedPromptShown', hasRatedPromptShown);
    p.setBool('taskMorningDone', taskMorningDone);
    p.setBool('taskEveningDone', taskEveningDone);
    p.setBool('taskSleepDone', taskSleepDone);
    p.setBool('taskMulkDone', taskMulkDone);
    p.setBool('taskKahfDone', taskKahfDone);
    p.setString('tasksDate', tasksDate);
    p.setString('fbUserName', fbUserName);
    p.setString('fbUserPhoto', fbUserPhoto);
    p.setString('customAzkar', jsonEncode(customAzkar));
    p.setString(
      'azkarState',
      jsonEncode(azkarList.map((e) => e.toJson()).toList()),
    );
    p.setBool('onboardingDone', onboardingDone);
    p.setString('reminderMode', reminderMode);
    p.setBool('dailyAyahEnabled', dailyAyahEnabled);
    p.setInt('dailyAyahIndex', dailyAyahIndex);
    p.setStringList('customTasbihPhrases', customTasbihPhrases);
    final mapEnc = <String, dynamic>{};
    editedAzkarOverrides.forEach((k, v) {
      mapEnc[k.toString()] = v;
    });
    p.setString('editedAzkarOverrides', jsonEncode(mapEnc));
    p.setStringList(
        'deletedAzkarIds', deletedAzkarIds.map((e) => e.toString()).toList());
    if (resyncTimers) {
      _syncReminders();
      _syncFloatingTimer();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _floatingTimer?.cancel();
    _splashAudioPlayer.dispose();
    _salawatPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surface = isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight;
    final primary = isDarkMode ? AppColors.primaryDark : AppColors.primaryBlue;
    final textPrimary =
        isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return KeyedSubtree(
      key: ValueKey(appLang),
      child: MaterialApp(
      title: tr('أذكاري', 'Azkari', 'Zikirlerim'),
      debugShowCheckedModeBanner: false,
      locale: Locale(appLang),
      supportedLocales: const [Locale('ar'), Locale('en'), Locale('tr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
          primary: primary,
          secondary: AppColors.skyBlue,
          surface: surface,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bg,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: SplashWrapperScreen(appState: this),
      ),
    );
  }
}

class SplashWrapperScreen extends StatefulWidget {
  final _AzkariAppState appState;
  const SplashWrapperScreen({super.key, required this.appState});

  @override
  State<SplashWrapperScreen> createState() => _SplashWrapperScreenState();
}

class _SplashWrapperScreenState extends State<SplashWrapperScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late String _verse;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _verse = kSplashVerses[Random().nextInt(kSplashVerses.length)];
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.appState;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _showSplash
          ? Scaffold(
              key: const ValueKey('splash'),
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF0288D1)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.asset(
                                  'assets/images/app_icon.png',
                                  width: 108,
                                  height: 108,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.mosque_rounded,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                s.tr('أذكاري', 'Azkari'),
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _verse,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  fontFamily: 'AmiriQuran',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFBAE6FD),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : (!widget.appState.onboardingDone
              ? OnboardingScreen(key: const ValueKey('onboarding'), appState: widget.appState)
              : MainShellScreen(key: const ValueKey('main'), appState: widget.appState)),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  final _AzkariAppState appState;
  const MainShellScreen({super.key, required this.appState});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final PageController _pageController = PageController(initialPage: 0);
  final GlobalKey _navHomeKey = GlobalKey();
  final GlobalKey _navQuranKey = GlobalKey();
  final GlobalKey _navAzkarKey = GlobalKey();
  final GlobalKey _navTasbihKey = GlobalKey();
  final GlobalKey _navSettingsKey = GlobalKey();
  final GlobalKey _fbBtnKey = GlobalKey();
  final GlobalKey _tasksCardKey = GlobalKey();
  int _currentIndex = 0;
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate(
        context,
        isEnglish: widget.appState.isEnglish,
      );
      final today = DateTime.now().toIso8601String().split('T').first;
      if (widget.appState.dailyAyahEnabled &&
          widget.appState.lastDailyAyahDate != today) {
        widget.appState.lastDailyAyahDate = today;
        widget.appState.widget.prefs.setString('lastDailyAyahDate', today);
        _showDailyAyahDialog();
      } else {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _maybeShowRareDoubleRewardDialog();
        });
      }
      if (!(widget.appState.widget.prefs.getBool('seenHomeTour') ?? false)) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _startHomeSpotlightTour();
        });
      }
    });
  }

  void _startHomeSpotlightTour() {
    final s = widget.appState;
    s.widget.prefs.setBool('seenHomeTour', true);
    showSpotlightTour(
      context,
      nextLabel: s.tr('التالي', 'Next', 'İleri'),
      finishLabel: s.tr('تم', 'Done', 'Tamam'),
      skipLabel: s.tr('تخطي', 'Skip', 'Atla'),
      steps: [
        SpotlightStep(
          targetKey: _navHomeKey,
          title: s.tr('الشاشة الرئيسية', 'Home', 'Ana Sayfa'),
          body: s.tr('هنا تجد الذكر الموصى به الآن، ومهامك اليومية، والوصول السريع.', 'Find your recommended Azkar, daily tasks, and quick shortcuts here.', 'Önerilen zikirleri, günlük görevleri ve kısayolları burada bulun.'),
        ),
        SpotlightStep(
          targetKey: _navQuranKey,
          title: s.tr('القرآن الكريم', 'Noble Quran', 'Kur’an-ı Kerim'),
          body: s.tr('قراءة، تلاوة صوتية، تتبع كلمة بكلمة، وتفسير بدون إنترنت.', 'Read, listen with word-by-word tracking, and view explanations offline.', 'Çevrimdışı okuyun, kelime takibiyle dinleyin ve tefsiri görün.'),
        ),
        SpotlightStep(
          targetKey: _navAzkarKey,
          title: s.tr('كل الأذكار', 'All Azkar', 'Tüm Zikirler'),
          body: s.tr('أذكار الصباح والمساء والنوم والصلاة مع إمكانية التعديل والمشاركة.', 'Morning, Evening, Sleep & Prayer Azkar with editing and card sharing.', 'Sabah, Akşam, Uyku ve Namaz zikirlerini düzenleyin ve paylaşın.'),
        ),
        SpotlightStep(
          targetKey: _navTasbihKey,
          title: s.tr('السبحة الإلكترونية', 'Digital Tasbih', 'Dijital Tesbih'),
          body: s.tr('سبّح باهتزاز لطيف بدون إيقاف التلاوة مع حفظ عداد كل ذكر.', 'Count effortlessly with gentle haptics without pausing Quran audio.', 'Kur’an sesini durdurmadan nazik titreşimle tesbih çekin.'),
        ),
        SpotlightStep(
          targetKey: _navSettingsKey,
          title: s.tr('الإعدادات', 'Settings', 'Ayarlar'),
          body: s.tr('تحكم بالخطوط، الذكر العائم، والتحديثات من هنا.', 'Customize fonts, floating reminders, and app updates here.', 'Yazı tiplerini, yüzen zikri ve güncellemeleri buradan ayarlayın.'),
        ),
        SpotlightStep(
          targetKey: _fbBtnKey,
          title: s.tr('حسابك في أذكاري', 'Your Account', 'Hesabınız'),
          body: s.tr('سجّل دخولك بفيسبوك لربط اسمك وإنجازاتك في التطبيق.', 'Sign in with Facebook to link your profile and achievements.', 'Profilinizi ve başarılarınızı bağlamak için Facebook ile giriş yapın.'),
        ),
        SpotlightStep(
          targetKey: _tasksCardKey,
          title: s.tr('المهام والإنجازات', 'Tasks & Achievements', 'Görevler ve Başarılar'),
          body: s.tr('تابع مواظبتك اليومية، المستويات، وملصقات التفاعل المتحركة.', 'Track your daily streak, tiers, and animated progress stickers.', 'Günlük serinizi, seviyeleri ve animasyonlu rozetleri takip edin.'),
        ),
      ],
    );
  }

  void _maybeShowRareDoubleRewardDialog() {
    final s = widget.appState;
    final today = DateTime.now().toIso8601String().split('T').first;
    if (s.lastDoubleRewardPromptDate.isNotEmpty) {
      final last = DateTime.tryParse(s.lastDoubleRewardPromptDate);
      if (last != null && DateTime.now().difference(last).inDays < 7) {
        return;
      }
    }
    if (Random().nextInt(6) != 0) return;
    s.lastDoubleRewardPromptDate = today;
    s.widget.prefs.setString('lastDoubleRewardPromptDate', today);
    showDoubleRewardShareDialog(context, s);
  }

  Future<void> _showDailyAyahDialog() async {
    final s = widget.appState;
    try {
      await QuranDataRepository.ensureLoaded();
      final qList = QuranDataRepository.surahs;
      final tList = QuranDataRepository.tafsirSurahs;
      if (qList.isEmpty || !mounted) return;

      final flatAyahs = <Map<String, dynamic>>[];
      for (int sIdx = 0; sIdx < qList.length; sIdx++) {
        final surah = qList[sIdx] as Map<String, dynamic>;
        final tSurah = sIdx < tList.length ? tList[sIdx] as Map<String, dynamic> : null;
        final ayahs = (surah['ayahs'] ?? []) as List<dynamic>;
        final tAyahs = tSurah != null ? ((tSurah['ayahs'] ?? []) as List<dynamic>) : <dynamic>[];
        final sNum = (surah['number'] as int?) ?? (sIdx + 1);
        for (int aIdx = 0; aIdx < ayahs.length; aIdx++) {
          final a = ayahs[aIdx] as Map<String, dynamic>;
          final tText = aIdx < tAyahs.length
              ? ((tAyahs[aIdx] as Map<String, dynamic>)['text'] ?? '').toString()
              : '';
          final cleanAyahText = stripLeadingBasmala(
            sNum,
            aIdx,
            (a['text'] ?? '').toString(),
          );
          flatAyahs.add({
            'surah': surah['name'] ?? '',
            'surahEn': surah['englishName'] ?? '',
            'num': a['numberInSurah'] ?? (aIdx + 1),
            'text': cleanAyahText,
            'tafsir': tText,
          });
        }
      }
      if (flatAyahs.isEmpty || !mounted) return;

      int idx = s.dailyAyahIndex % flatAyahs.length;
      final qFont = s.widget.prefs.getString('quranFontFamily') ?? 'AmiriQuran';
      final qScale = s.widget.prefs.getDouble('quranFontScale') ?? 1.0;

      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDState) {
            final item = flatAyahs[idx];
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item['surah']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.skyBlue,
                      ),
                    ),
                    if (s.appLang != 'ar')
                      Text(
                        '${item['surahEn']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        child: Text(
                          '${item['text']} ﴿${item['num']}﴾',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: qFont,
                            fontSize: 22 * qScale,
                            height: 1.9,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setDState(() {
                              idx = (idx - 1 + flatAyahs.length) % flatAyahs.length;
                            });
                            s.dailyAyahIndex = idx;
                            s.widget.prefs.setInt('dailyAyahIndex', idx);
                          },
                          icon: const Icon(Icons.chevron_left_rounded),
                          label: Text(s.tr('السابق', 'Prev', 'Önceki')),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setDState(() {
                              idx = (idx + 1) % flatAyahs.length;
                            });
                            s.dailyAyahIndex = idx;
                            s.widget.prefs.setInt('dailyAyahIndex', idx);
                          },
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: Text(s.tr('التالي', 'Next', 'Sonraki')),
                        ),
                      ],
                    ),
                    const Divider(),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () {
                            showDialog(
                              context: ctx,
                              builder: (infoCtx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22)),
                                title: Text(s.tr('معلومات عن الميزة', 'About Feature', 'Özellik Hakkında')),
                                content: Text(
                                  s.tr(
                                    'هذه الميزة تساعدك على قراءة آية من القرآن بالتسلسل عند بدء تشغيل التطبيق.\n\nيمكنك إيقاف تفعيل الميزة من الإعدادات في وقت لاحق أو من الزر بالأسفل.\n\nملاحظة: الخط وحجم الخط المستخدمان هنا هما نفس إعدادات صفحة القرآن.',
                                    'Shows a sequential Quran Ayah on startup using your Quran font settings. You can disable it anytime below or in Settings.',
                                    'Uygulama açılışında sırayla bir Kur’an ayeti gösterir. İstediğiniz zaman aşağıdan veya Ayarlar’dan kapatabilirsiniz.',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      s.dailyAyahEnabled = false;
                                      s.saveAllState(resyncTimers: false);
                                      Navigator.pop(infoCtx);
                                      Navigator.pop(ctx);
                                    },
                                    child: Text(s.tr('إيقاف الميزة', 'Disable', 'Kapat'),
                                        style: const TextStyle(color: Colors.redAccent)),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(infoCtx),
                                    child: Text(s.tr('متابعة', 'Continue', 'Devam')),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text(s.tr('معلومات عن الميزة', 'Info', 'Bilgi')),
                        ),
                        TextButton(
                          onPressed: () {
                            final tafsir = (item['tafsir'] as String).isNotEmpty
                                ? item['tafsir'] as String
                                : s.tr('التفسير غير متوفر لهذه الآية.', 'Tafsir unavailable.');
                            showDialog(
                              context: ctx,
                              builder: (tCtx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22)),
                                title: Text(s.tr('تفسير الآية', 'Tafsir', 'Tefsir')),
                                content: SingleChildScrollView(child: Text(tafsir)),
                                actions: [
                                  FilledButton(
                                    onPressed: () => Navigator.pop(tCtx),
                                    child: Text(s.tr('إغلاق', 'Close', 'Kapat')),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text(s.tr('تفسير الآية', 'Tafsir', 'Tefsir')),
                        ),
                        FilledButton(
                          onPressed: () {
                            s.dailyAyahIndex = (idx + 1) % flatAyahs.length;
                            s.widget.prefs.setInt('dailyAyahIndex', s.dailyAyahIndex);
                            Navigator.pop(ctx);
                          },
                          child: Text(s.tr('تم', 'Done', 'Tamam')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } catch (_) {}
  }

  void _openCategoryReader(String category, {int initialIndex = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AzkarReaderScreen(
          appState: widget.appState,
          category: category,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _openExplore({int tab = 0}) {
    final s = widget.appState;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExploreIslamicScreen(
          isEnglish: s.isEnglish,
          isDarkMode: s.isDarkMode,
          initialTab: tab,
        ),
      ),
    );
  }

  void _openTools() {
    final s = widget.appState;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ToolsHubScreen(
          prefs: s.widget.prefs,
          isEnglish: s.isEnglish,
          isDarkMode: s.isDarkMode,
          onStateChanged: () => s.refreshAfterRestore(),
        ),
      ),
    );
  }

  void _shareAppWithFriend() {
    final s = widget.appState;
    Share.share(
      s.tr(
        'حمّل تطبيق «أذكاري» للأذكار اليومية والقرآن والسبحة بدون إنترنت:\n$kAppDownloadLink\nشارك تؤجر ',
        'Download Azkari app for daily Azkar, Quran & offline Tasbih:\n$kAppDownloadLink',
      ),
    );
  }

  Future<void> _rateApp() async {
    final uri = Uri.parse(kAppDownloadLink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openAchievementsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AchievementsScreen(appState: widget.appState),
      ),
    );
  }

  void _openSurahDirectly(int surahNum) {
    final s = widget.appState;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FutureBuilder<void>(
          future: QuranDataRepository.ensureLoaded(),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return SurahReaderScreen(
              initialSurahNumber: surahNum,
              prefs: s.widget.prefs,
              isDarkMode: s.isDarkMode,
              isEnglish: s.isEnglish,
              initialFontScale: s.fontScale,
              onSurahCompleted: () {
                if (surahNum == 67) s.taskMulkDone = true;
                if (surahNum == 18) s.taskKahfDone = true;
                s.recordDailyActivity();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _assetIcon(String path, IconData fallback, {double size = 34}) {
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(fallback, size: size * 0.85, color: AppColors.skyBlue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.appState;
    final isDark = s.isDarkMode;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryBlue;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final pages = [
      _buildHomeTab(context, cardColor, borderColor, primary, textSecondary),
      QuranHomeScreen(
        prefs: s.widget.prefs,
        isDarkMode: s.isDarkMode,
        isEnglish: s.isEnglish,
        appLang: s.appLang,
        fontScale: s.fontScale,
      ),
      _buildAllAzkarTab(context, cardColor, borderColor, primary, textSecondary),
      _buildTasbihTab(context, cardColor, borderColor, primary, textSecondary),
      _buildSettingsTab(context, cardColor, borderColor, primary, textSecondary),
    ];

    final drawerContent = _buildLeftDrawer(context, cardColor, primary);

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: s.isEnglish ? null : drawerContent,
      drawer: s.isEnglish ? drawerContent : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) {
                  if (_currentIndex != idx) {
                    setState(() => _currentIndex = idx);
                  }
                },
                children: pages,
              ),
            ),
            StreamBuilder(
              stream: QuranAudioManager.instance.player.playerStateStream,
              builder: (context, snap) {
                final mgr = QuranAudioManager.instance;
                final player = mgr.player;
                final pState = snap.data;
                final active = player.audioSource != null &&
                    mgr.currentSurahNumber != null &&
                    pState != null &&
                    pState.processingState.name != 'idle' &&
                    pState.processingState.name != 'completed';
                if (!active) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: (s.isDarkMode ? const Color(0xFF0F172A) : Colors.white)
                        .withOpacity(0.95),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: AppColors.skyBlue.withOpacity(0.45), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.graphic_eq_rounded,
                          color: AppColors.skyBlue, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SurahReaderScreen(
                                  prefs: s.widget.prefs,
                                  initialSurahNumber: mgr.currentSurahNumber!,
                                  isEnglish: s.isEnglish,
                                  appLang: s.appLang,
                                  isDarkMode: s.isDarkMode,
                                  initialFontScale: s.fontScale,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s.appLang == 'ar'
                                    ? mgr.currentSurahName
                                    : (mgr.currentSurahNameEn.isNotEmpty
                                        ? mgr.currentSurahNameEn
                                        : mgr.currentSurahName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                s.appLang == 'ar'
                                    ? mgr.currentReciterName
                                    : (mgr.currentReciterNameEn.isNotEmpty
                                        ? mgr.currentReciterNameEn
                                        : mgr.currentReciterName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          if (pState.playing) {
                            await player.pause();
                          } else {
                            await player.play();
                          }
                        },
                        icon: Icon(
                          pState.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: AppColors.skyBlue,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          await player.stop();
                        },
                        icon: const Icon(Icons.close_rounded, size: 19),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: (s.isDarkMode ? const Color(0xFF0B1220) : Colors.white)
                .withOpacity(0.90),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: (s.isDarkMode ? Colors.white : AppColors.primaryBlue)
                  .withOpacity(0.16),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(s.isDarkMode ? 0.50 : 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: NavigationBar(
              height: 62,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) {
                setState(() => _currentIndex = idx);
                if (_pageController.hasClients) {
                  _pageController.animateToPage(
                    idx,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
              indicatorColor: primary.withOpacity(0.18),
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.home_rounded, key: _navHomeKey),
                  label: s.tr('الرئيسية', 'Home'),
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_rounded, key: _navQuranKey),
                  label: s.tr('القرآن', 'Quran'),
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_view_rounded, key: _navAzkarKey),
                  label: s.tr('الأذكار', 'Azkar'),
                ),
                NavigationDestination(
                  icon: Icon(Icons.scatter_plot_rounded, key: _navTasbihKey),
                  label: s.tr('السبحة', 'Tasbih'),
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_rounded, key: _navSettingsKey),
                  label: s.tr('الإعدادات', 'Settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftDrawer(BuildContext context, Color cardColor, Color primary) {
    final s = widget.appState;
    return Drawer(
      backgroundColor: cardColor,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF0288D1)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white24,
                        backgroundImage: s.fbUserPhoto.isNotEmpty
                            ? NetworkImage(s.fbUserPhoto)
                            : null,
                        child: s.fbUserPhoto.isEmpty
                            ? const Icon(Icons.person_rounded,
                                color: Colors.white, size: 28)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.fbUserName.isNotEmpty
                              ? s.fbUserName
                              : s.tr('ضيف أذكاري', 'Azkari Guest'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0D47A1),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        if (s.fbUserName.isEmpty) {
                          s.loginWithFacebook(context);
                        } else {
                          s.logoutFacebook();
                        }
                      },
                      icon: const Icon(Icons.facebook_rounded),
                      label: Text(
                        s.fbUserName.isEmpty
                            ? s.tr('تسجيل الدخول بفيسبوك', 'Login with Facebook')
                            : s.tr('تسجيل الخروج', 'Sign Out'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.star_rounded, color: primary),
              title: Text(s.tr('المفضلة', 'Favorites')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(s.tr('المفضلة', 'Favorites'))),
                      body: _buildFavoritesTab(
                        context,
                        cardColor,
                        Colors.grey.withOpacity(0.2),
                        primary,
                        Colors.grey,
                      ),
                    ),
                  ),
                );
              },
            ),


            ListTile(
              leading: Icon(Icons.emoji_events_rounded, color: primary),
              title: Text(
                  s.tr('الإنجازات والمهام اليومية', 'Achievements & Tasks')),
              subtitle: Text(
                s.tr('المواظبة الحالية: ${s.currentStreak} يوم',
                    'Current streak: ${s.currentStreak} days'),
              ),
              onTap: () {
                Navigator.pop(context);
                _openAchievementsScreen();
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => s.showLanguagePicker(context),
                      icon: Icon(Icons.public_rounded, color: primary),
                      label: Text(
                        s.appLang == 'tr'
                            ? 'Türkçe'
                            : (s.appLang == 'en' ? 'English' : 'العربية'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: s.tr('تبديل المظهر', 'Toggle Theme'),
                    onPressed: () {
                      s.isDarkMode = !s.isDarkMode;
                      s.saveAllState(resyncTimers: false);
                    },
                    icon: Icon(
                      s.isDarkMode
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                s.buttonSoundEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: primary,
              ),
              title: Text(s.tr('صوت الأزرار', 'Button Sound')),
              trailing: Switch(
                value: s.buttonSoundEnabled,
                onChanged: (v) {
                  s.buttonSoundEnabled = v;
                  s.saveAllState();
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.share_rounded, color: primary),
              title: Text(s.tr('مشاركة التطبيق مع صديق', 'Share with a Friend')),
              onTap: () {
                Navigator.pop(context);
                _shareAppWithFriend();
              },
            ),
            ListTile(
              leading: Icon(Icons.star_rate_rounded, color: primary),
              title: Text(s.tr('قيّم التطبيق', 'Rate App')),
              onTap: () {
                Navigator.pop(context);
                _rateApp();
              },
            ),
            ListTile(
              leading: Icon(Icons.system_update_rounded, color: primary),
              title: Text(s.tr('التحقق من التحديثات', 'Check for Updates')),
              onTap: () {
                Navigator.pop(context);
                UpdateService.checkForUpdate(
                  context,
                  isEnglish: s.isEnglish,
                  showNoUpdateMessage: true,
                );
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  Text(
                    s.tr('تواصل معنا', 'Follow Us'),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        tooltip: 'Facebook',
                        onPressed: () => launchUrl(
                            Uri.parse('https://facebook.com'),
                            mode: LaunchMode.externalApplication),
                        icon: _assetIcon('assets/images/social_facebook.png',
                            Icons.facebook_rounded,
                            size: 28),
                      ),
                      IconButton(
                        tooltip: 'Instagram',
                        onPressed: () => launchUrl(
                            Uri.parse('https://instagram.com'),
                            mode: LaunchMode.externalApplication),
                        icon: _assetIcon('assets/images/social_instagram.png',
                            Icons.camera_alt_rounded,
                            size: 28),
                      ),
                      IconButton(
                        tooltip: 'TikTok',
                        onPressed: () => launchUrl(
                            Uri.parse('https://tiktok.com'),
                            mode: LaunchMode.externalApplication),
                        icon: _assetIcon('assets/images/social_tiktok.png',
                            Icons.audiotrack_rounded,
                            size: 28),
                      ),
                      IconButton(
                        tooltip: 'Email',
                        onPressed: () => launchUrl(
                            Uri.parse('mailto:support@azkari.app'),
                            mode: LaunchMode.externalApplication),
                        icon: _assetIcon('assets/images/social_email.png',
                            Icons.email_rounded,
                            size: 28),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, Color cardColor, Color borderColor,
      Color primary, Color textSecondary) {
    final s = widget.appState;
    final now = DateTime.now();
    final hour = now.hour;
    final isMorning = hour >= 3 && hour < 15;
    final activeCategory = isMorning ? 'morning' : 'evening';
    final activeItems =
        s.azkarList.where((z) => z.category == activeCategory).toList();
    final activeDone = activeItems.where((z) => z.count >= z.target).length;
    final progress =
        activeItems.isEmpty ? 0.0 : activeDone / activeItems.length;
    final isFriday = now.weekday == DateTime.friday;
    final normQuery = normalizeArabicForSearch(_searchQuery);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.appLang == 'ar'
                        ? 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'
                        : 'Bismillahirrahmanirrahim',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: s.appLang == 'ar' ? 'AmiriQuran' : null,
                      fontSize: s.appLang == 'ar' ? 20 : 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatHijriAndGregorian(now, s.appLang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (s.fbUserName.isEmpty) {
                      s.loginWithFacebook(context);
                    }
                  },
                  key: _fbBtnKey,
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: primary.withOpacity(0.18),
                    backgroundImage: s.fbUserPhoto.isNotEmpty
                        ? NetworkImage(s.fbUserPhoto)
                        : null,
                    child: s.fbUserPhoto.isEmpty
                        ? const Icon(Icons.facebook_rounded, size: 18)
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  onPressed: () {
                                    setState(() => _showSearch = !_showSearch);
                  },
                  icon: const Icon(Icons.search_rounded),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  onPressed: () {
                                    if (s.isEnglish) {
                      _scaffoldKey.currentState?.openDrawer();
                    } else {
                      _scaffoldKey.currentState?.openEndDrawer();
                    }
                  },
                  icon: const Icon(Icons.menu_rounded),
                ),
              ],
            ),
          ],
        ),
        if (_showSearch) ...[
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: s.tr('ابحث في الأذكار (بدون تشكيل)...',
                  'Search Azkar...'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
          ),
          if (normQuery.isNotEmpty)
            ...s.azkarList
                .where((z) =>
                    normalizeArabicForSearch(z.text).contains(normQuery) ||
                    normalizeArabicForSearch(z.source).contains(normQuery) ||
                    normalizeArabicForSearch(z.categoryLabel).contains(normQuery))
                .map(
                  (item) => Card(
                    color: cardColor,
                    margin: const EdgeInsets.only(top: 8),
                    child: ListTile(
                      title: Text(
                        s.minimalTashkeel ? lightTashkeel(item.text) : item.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${item.categoryLabel} • ${item.source}'),
                      onTap: () {
                        final catItems = s.azkarList
                            .where((z) => z.category == item.category)
                            .toList();
                        _openCategoryReader(item.category,
                            initialIndex: catItems.indexOf(item));
                      },
                    ),
                  ),
                ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF0288D1)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s.tr('موصى به الآن', 'Recommended Now'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    s.tr('$activeDone من ${activeItems.length} مكتمل',
                        '$activeDone / ${activeItems.length} done'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isMorning
                    ? s.tr('أذكار الصباح', 'Morning Azkar')
                    : s.tr('أذكار المساء', 'Evening Azkar'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                s.tr('حصن يومك بالذكر؛ قراءة هادئة ومصادر صحيحة موثقة.',
                    'Fortify your day with authentic daily remembrance.'),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _openCategoryReader(activeCategory),
                    child: Text(s.tr('ابدأ الآن ←', 'Start Now →'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.skyBlue),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _quickCard(
                cardColor,
                borderColor,
                _assetIcon('assets/images/icon_quran.png', Icons.menu_book_rounded),
                s.tr('القرآن الكريم', 'Quran'),
                () => setState(() => _currentIndex = 1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickCard(
                cardColor,
                borderColor,
                _assetIcon('assets/images/icon_dua.png', Icons.spa_rounded),
                s.tr('دعاء وشعورك', 'Mood Dua'),
                () => _openExplore(tab: 0),
              ),
            ),

          ],
        ),
        const SizedBox(height: 14),
        Container(
          key: _tasksCardKey,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.tr('المهام اليومية (تلقائية)', 'Daily Tasks (Auto)'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: _openAchievementsScreen,
                    child: Text(s.tr('الإنجازات 🏆', 'Achievements 🏆')),
                  ),
                ],
              ),
              _autoTaskTile(
                s.tr('أذكار الصباح', 'Morning Azkar'),
                s.taskMorningDone,
                () => _openCategoryReader('morning'),
              ),
              _autoTaskTile(
                s.tr('أذكار المساء', 'Evening Azkar'),
                s.taskEveningDone,
                () => _openCategoryReader('evening'),
              ),
              _autoTaskTile(
                s.tr('أذكار النوم', 'Sleep Azkar'),
                s.taskSleepDone,
                () => _openCategoryReader('sleep'),
              ),
              _autoTaskTile(
                s.tr('قراءة سورة الملك يومياً', 'Read Surah Al-Mulk'),
                s.taskMulkDone,
                () => _openSurahDirectly(67),
              ),
              if (isFriday)
                _autoTaskTile(
                  s.tr('قراءة سورة الكهف (يوم الجمعة)',
                      'Surah Al-Kahf (Friday)'),
                  s.taskKahfDone,
                  () => _openSurahDirectly(18),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _autoTaskTile(String title, bool done, VoidCallback onTap) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
        color: done ? Colors.greenAccent : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          decoration: done ? TextDecoration.lineThrough : null,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: onTap,
    );
  }

  Widget _buildAllAzkarTab(BuildContext context, Color cardColor,
      Color borderColor, Color primary, Color textSecondary) {
    final s = widget.appState;
    final allCategories = [
      ('morning', Icons.wb_sunny_rounded, s.tr('أذكار الصباح', 'Morning Azkar')),
      ('evening', Icons.nights_stay_rounded, s.tr('أذكار المساء', 'Evening Azkar')),
      ('prayer', Icons.mosque_rounded, s.tr('أذكار الصلاة وبعدها', 'Prayer Azkar')),
      ('adhan', Icons.campaign_rounded, s.tr('أذكار الأذان', 'Adhan Azkar')),
      ('sleep', Icons.bedtime_rounded, s.tr('أذكار النوم', 'Sleep Azkar')),
      ('wakeup', Icons.light_mode_rounded, s.tr('أذكار الاستيقاظ', 'Wake-up Azkar')),
      ('mosque', Icons.account_balance_rounded, s.tr('أذكار المسجد', 'Mosque Azkar')),
      ('wudu', Icons.water_drop_rounded, s.tr('أذكار الوضوء', 'Wudu Azkar')),
      ('daily', Icons.home_rounded, s.tr('المنزل والسفر', 'Home & Travel')),
      ('food', Icons.restaurant_rounded, s.tr('أذكار الطعام', 'Food Azkar')),
      ('khala', Icons.clean_hands_rounded, s.tr('دخول الخلاء والخروج', 'Restroom Dua')),
      ('supplications', Icons.favorite_rounded, s.tr('أذكار وأدعية عامة', 'General Azkar')),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _assetIcon('assets/images/icon_azkar.png', Icons.auto_awesome,
                    size: 30),
                const SizedBox(width: 8),
                Text(s.tr('كل الأذكار', 'All Azkar'),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showAddCustomZikrDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(s.tr('إضافة ذكر', 'Add Zikr')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (s.customAzkar.isNotEmpty) ...[
          Text(s.tr('أذكاري المخصصة (رتّبها بالأسهم)', 'My Custom Azkar'),
              style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...s.customAzkar.asMap().entries.map((entry) {
            final idx = entry.key;
            final z = entry.value;
            return Card(
              color: cardColor,
              child: ListTile(
                title: Text(z['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${z['before'] != '' ? '${z['before']}\n' : ''}${z['text']}\n(${z['target'] ?? 1}x) ${z['note'] ?? ''}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      onPressed: idx > 0
                          ? () {
                              final item = s.customAzkar.removeAt(idx);
                              s.customAzkar.insert(idx - 1, item);
                              s.saveAllState();
                            }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                      onPressed: idx < s.customAzkar.length - 1
                          ? () {
                              final item = s.customAzkar.removeAt(idx);
                              s.customAzkar.insert(idx + 1, item);
                              s.saveAllState();
                            }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 18),
                      onPressed: () {
                        s.customAzkar.removeAt(idx);
                        s.saveAllState();
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
        ],
        GridView.builder(
          itemCount: allCategories.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
          ),
          itemBuilder: (ctx, idx) {
            final (catKey, iconData, label) = allCategories[idx];
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                final exists = s.azkarList.any((z) => z.category == catKey);
                if (exists) {
                  _openCategoryReader(catKey);
                } else {
                  _openBuiltInExtraCategory(catKey, label);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(iconData, color: AppColors.skyBlue, size: 26),
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _openBuiltInExtraCategory(String catKey, String label) {
    final s = widget.appState;
    final Map<String, List<(String, String)>> extrasAr = {
      'adhan': [
        (
          'عند سماع المؤذن: يقول مثل ما يقول المؤذن إلا في الحيعلتين فيقول: لا حول ولا قوة إلا بالله.',
          'متفق عليه',
        ),
        (
          'اللهم رب هذه الدعوة التامة، والصلاة القائمة، آت محمداً الوسيلة والفضيلة، وابعثه مقاماً محموداً الذي وعدته.',
          'رواه البخاري',
        ),
      ],
      'mosque': [
        ('دخول المسجد: اللهم افتح لي أبواب رحمتك.', 'رواه مسلم'),
        ('الخروج من المسجد: اللهم إني أسألك من فضلك.', 'رواه مسلم'),
      ],
      'wudu': [
        ('قبل الوضوء: بسم الله.', 'رواه أبو داود'),
        (
          'بعد الوضوء: أشهد أن لا إله إلا الله وحده لا شريك له، وأشهد أن محمداً عبده ورسوله.',
          'رواه مسلم',
        ),
      ],
      'food': [
        ('قبل الطعام: بسم الله (فإن نسي: بسم الله أوله وآخره).', 'رواه أبو داود'),
        (
          'بعد الطعام: الحمد لله الذي أطعمني هذا ورزقنيه من غير حول مني ولا قوة.',
          'رواه الترمذي',
        ),
      ],
      'khala': [
        ('عند الدخول: اللهم إني أعوذ بك من الخبث والخبائث.', 'متفق عليه'),
        ('عند الخروج: غفرانك.', 'رواه أبو داود والترمذي'),
      ],
    };

    final Map<String, List<(String, String)>> extrasEn = {
      'adhan': [
        ('Repeat what the Mu’adhdhin says, except at Hayya alas-Salah/Falah say: La hawla wa la quwwata illa billah.', 'Agreed upon'),
        ('Allahumma Rabba hadhihid-da’watit-tammah, was-salatil-qa’imah, ati Muhammadanil-wasilata wal-fadilah.', 'Sahih Al-Bukhari'),
      ],
      'mosque': [
        ('Entering the Mosque: Allahumma-ftah li abwaba rahmatik (O Allah, open the doors of Your mercy for me).', 'Sahih Muslim'),
        ('Leaving the Mosque: Allahumma inni as’aluka min fadlik (O Allah, I ask You from Your bounty).', 'Sahih Muslim'),
      ],
      'wudu': [
        ('Before Wudu: Bismillah (In the name of Allah).', 'Abu Dawud'),
        ('After Wudu: Ash-hadu an la ilaha illAllahu wahdahu la sharika lah, wa ash-hadu anna Muhammadan abduhu wa rasuluh.', 'Sahih Muslim'),
      ],
      'food': [
        ('Before Eating: Bismillah (If forgotten: Bismillahi awwalahu wa akhirah).', 'Abu Dawud'),
        ('After Eating: Alhamdulillahil-ladhi at’amani hadha wa razaqanihi min ghayri hawlin minni wa la quwwah.', 'At-Tirmidhi'),
      ],
      'khala': [
        ('Entering Restroom: Allahumma inni a’udhu bika minal-khubuthi wal-khaba’ith.', 'Agreed upon'),
        ('Leaving Restroom: Ghufranaka (I seek Your forgiveness).', 'Abu Dawud & At-Tirmidhi'),
      ],
    };

    final Map<String, List<(String, String)>> extrasTr = {
      'adhan': [
        ('Ezanı işitince müezzinin söylediklerini tekrar et; Hayye ales-salah / felah kısmında "La havle ve la kuvvete illa billah" de.', 'Müttefekun Aleyh'),
        ('Allahümme Rabbe hazihid-da’vetit-tammeh ves-salatil-kaimeh, ati Muhammedenil-vesilete vel-fazileh.', 'Buhari'),
      ],
      'mosque': [
        ('Camiye Girerken: Allahümmeftah li ebvabe rahmetik (Allah’ım, bana rahmet kapılarını aç).', 'Müslim'),
        ('Camiden Çıkarken: Allahümme inni es’elüke min fadlik (Allah’ım, Senin lütfundan dilerim).', 'Müslim'),
      ],
      'wudu': [
        ('Abdestten Önce: Bismillah.', 'Ebu Davud'),
        ('Abdestten Sonra: Eşhedü en la ilahe illallahu vahdehu la şerike leh ve eşhedü enne Muhammeden abdühu ve resulüh.', 'Müslim'),
      ],
      'food': [
        ('Yemekten Önce: Bismillah (Unutulursa: Bismillahi evvelehu ve ahireh).', 'Ebu Davud'),
        ('Yemekten Sonra: Elhamdülillahillezi et’ameni haza ve rezekanihi min gayri havlin minni ve la kuvveh.', 'Tirmizi'),
      ],
      'khala': [
        ('Tuvalete Girerken: Allahümme inni euzü bike minel-hubsi vel-habais.', 'Müttefekun Aleyh'),
        ('Tuvaletten Çıkarken: Gufraneke (Allah’ım bağışlamanı dilerim).', 'Ebu Davud & Tirmizi'),
      ],
    };

    final activeMap = s.isTurkish
        ? extrasTr
        : (s.isEnglish ? extrasEn : extrasAr);
    final list = activeMap[catKey] ?? activeMap['wudu']!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(label)),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (ctx, i) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      list[i].$1,
                      textDirection:
                          (s.isEnglish || s.isTurkish) ? TextDirection.ltr : TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: (s.isEnglish || s.isTurkish) ? null : s.azkarFontFamily,
                        fontSize: 18 * s.fontScale,
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(list[i].$2,
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCustomZikrDialog() {
    final s = widget.appState;
    final titleCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    final targetCtrl = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(s.tr('إضافة ذكر مخصص', 'Add Custom Zikr', 'Özel Zikir Ekle')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: s.tr('العنوان', 'Title', 'Başlık'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: s.tr('نص الذكر', 'Zikr Text', 'Zikir Metni'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: s.tr('عدد التكرار', 'Repeat Count', 'Tekrar Sayısı'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.tr('إلغاء', 'Cancel', 'İptal')),
          ),
          FilledButton(
            onPressed: () {
              final txt = textCtrl.text.trim();
              if (txt.isEmpty) return;
              s.customAzkar.add({
                'title': titleCtrl.text.trim().isEmpty
                    ? s.tr('ذكر مخصص', 'Custom Zikr', 'Özel Zikir')
                    : titleCtrl.text.trim(),
                'before': '',
                'text': txt,
                'note': '',
                'target': (int.tryParse(targetCtrl.text.trim()) ?? 1).clamp(1, 999),
              });
              s.saveAllState(resyncTimers: false);
              Navigator.pop(ctx);
            },
            child: Text(s.tr('إضافة', 'Add', 'Ekle')),
          ),
        ],
      ),
    );
  }

  Widget _quickCard(
    Color cardColor,
    Color borderColor,
    Widget iconWidget,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            iconWidget,
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasbihTab(BuildContext context, Color cardColor,
      Color borderColor, Color primary, Color textSecondary) {
    final s = widget.appState;
    final cycleVal = s.tasbihCount % 33;
    final cycleProgress = (s.tasbihCount > 0 && cycleVal == 0) ? 1.0 : cycleVal / 33.0;
    final allPhrases = [
      ...kRandomShortAzkar,
      ...s.customTasbihPhrases.where((c) => !kRandomShortAzkar.contains(c)),
    ];
    final currentVal = allPhrases.contains(s.tasbihPhrase) ? s.tasbihPhrase : allPhrases.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _assetIcon('assets/images/icon_tasbih.png', Icons.scatter_plot_rounded, size: 28),
                  const SizedBox(width: 8),
                  Text(s.tr('السبحة الإلكترونية', 'Tasbih', 'Tesbih'),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  s.tasbihCount = 0;
                  s.saveAllState(resyncTimers: false);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(s.tr('تصفير', 'Reset', 'Sıfırla')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: currentVal,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  items: allPhrases
                      .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            s.appLang != 'ar'
                                ? translateShortZikr(p, s.appLang)
                                : (s.minimalTashkeel ? lightTashkeel(p) : p),
                            overflow: TextOverflow.ellipsis,
                          )))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) s.switchTasbihPhrase(v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  final ctrl = TextEditingController();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      title: Text(s.tr('إضافة ذكر للسبحة', 'Add Tasbih Zikr', 'Tesbihe Zikir Ekle')),
                      content: TextField(
                        controller: ctrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: s.tr('اكتب الذكر هنا...', 'Enter Zikr...', 'Zikri yazın...'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(s.tr('إلغاء', 'Cancel', 'İptal')),
                        ),
                        FilledButton(
                          onPressed: () {
                            final txt = ctrl.text.trim();
                            if (txt.isNotEmpty) {
                              if (!s.customTasbihPhrases.contains(txt)) {
                                s.customTasbihPhrases.add(txt);
                              }
                              s.switchTasbihPhrase(txt);
                              s.saveAllState(resyncTimers: false);
                            }
                            Navigator.pop(ctx);
                          },
                          child: Text(s.tr('إضافة', 'Add', 'Ekle')),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: Text(s.tr('إضافة', 'Add', 'Ekle')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Text(
                  s.appLang != 'ar'
                      ? translateShortZikr(s.tasbihPhrase, s.appLang)
                      : (s.minimalTashkeel ? lightTashkeel(s.tasbihPhrase) : s.tasbihPhrase),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: s.appLang != 'ar' ? null : s.azkarFontFamily,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.tr(
                    'الدورة: $cycleVal / 33  •  الإجمالي: ${s.tasbihLifetime}',
                    'Cycle: $cycleVal / 33  •  Total: ${s.tasbihLifetime}',
                    'Tur: $cycleVal / 33  •  Toplam: ${s.tasbihLifetime}',
                  ),
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          RoundedSquareCounterButton(
            progress: cycleProgress,
            title: '${s.tasbihCount}',
            subtitle: s.tr('سبّح', 'Tap', 'Dokun'),
            gradientColors: s.sabhaColors,
            borderGlowColor: AppColors.skyBlue,
            size: 190,
            onTap: () {
              s.tasbihCount += 1;
              s.tasbihLifetime += 1;
              s.playTapFeedback(stronger: s.tasbihCount % 33 == 0);
              s.saveLightState();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab(BuildContext context, Color cardColor,
      Color borderColor, Color primary, Color textSecondary) {
    final s = widget.appState;
    final favs = s.azkarList.where((z) => z.favorite).toList();
    if (favs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, size: 48, color: AppColors.skyBlue),
              const SizedBox(height: 12),
              Text(s.tr('لا توجد أذكار مفضلة بعد', 'No favorites yet', 'Henüz favori yok')),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favs.length,
      itemBuilder: (ctx, i) {
        final item = favs[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.categoryForLang(s.appLang),
                      style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 12.5)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      item.favorite = false;
                      s.saveLightState();
                      setState(() {});
                    },
                    icon: const Icon(Icons.star_rounded, color: AppColors.skyBlue),
                  ),
                ],
              ),
              Text(
                s.isTurkish
                    ? item.turkishText
                    : (s.isEnglish ? item.englishText : item.text),
                style: TextStyle(
                  fontFamily: s.appLang == 'ar' ? s.azkarFontFamily : null,
                  fontSize: 17 * s.fontScale,
                  height: 1.8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab(BuildContext context, Color cardColor,
      Color borderColor, Color primary, Color textSecondary) {
    final s = widget.appState;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text(s.tr('الإعدادات', 'Settings', 'Ayarlar'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: Text(s.tr('صوت النقرات والتسبيح اللطيف', 'Tap & Tasbih Sounds', 'Dokunma ve Tesbih Sesleri')),
                value: s.buttonSoundEnabled,
                onChanged: (v) {
                  s.buttonSoundEnabled = v;
                  s.saveAllState(resyncTimers: false);
                },
              ),
              SwitchListTile(
                title: Text(s.tr('الاهتزاز', 'Haptic Feedback', 'Titreşim')),
                value: s.hapticEnabled,
                onChanged: (v) {
                  s.hapticEnabled = v;
                  s.saveAllState(resyncTimers: false);
                },
              ),
              SwitchListTile(
                title: Text(s.tr('آية اليوم عند فتح التطبيق', 'Daily Ayah on Startup', 'Açılışta Günün Ayeti')),
                value: s.dailyAyahEnabled,
                onChanged: (v) {
                  s.dailyAyahEnabled = v;
                  s.saveAllState(resyncTimers: false);
                },
              ),
              SwitchListTile(
                title: Text(s.tr('الذكر العائم فوق التطبيقات', 'Floating Zikr Overlay', 'Uygulamalar Üzerinde Zikir')),
                value: s.floatingEnabled,
                onChanged: (v) {
                  s.floatingEnabled = v;
                  s.saveAllState();
                },
              ),
              if (s.floatingEnabled)
                ListTile(
                  title: Text(s.tr('مدة ظهور الذكر العائم', 'Floating Reminder Interval', 'Zikir Gösterim Aralığı')),
                  subtitle: Wrap(
                    spacing: 8,
                    children: [5, 10, 15, 30, 60].map((mins) {
                      return ChoiceChip(
                        label: Text(
                          mins == 60
                              ? s.tr('ساعة', '1h', '1 sa')
                              : s.tr('$mins د', '${mins}m', '${mins} dk'),
                        ),
                        selected: s.floatingIntervalMinutes == mins,
                        onSelected: (_) {
                          s.floatingIntervalMinutes = mins;
                          s.saveAllState();
                        },
                      );
                    }).toList(),
                  ),
                ),
              const Divider(height: 1),
              if (s.appLang == 'ar') ...[
                SwitchListTile(
                  title: Text(s.tr('تشكيل مبسط ومريح في الأذكار', 'Light Tashkeel in Azkar')),
                  value: s.minimalTashkeel,
                  onChanged: (v) {
                    s.minimalTashkeel = v;
                    s.saveAllState(resyncTimers: false);
                  },
                ),
                ListTile(
                  title: Text(s.tr('نوع خط الأذكار', 'Azkar Font Family')),
                  subtitle: Wrap(
                    spacing: 8,
                    children: kQuranFonts.map((f) {
                      return ChoiceChip(
                        label: Text(fontLabelForLang(f.$1, s.appLang)),
                        selected: s.azkarFontFamily == f.$1,
                        onSelected: (_) {
                          s.azkarFontFamily = f.$1;
                          s.saveAllState(resyncTimers: false);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
              ListTile(
                title: Text(s.tr('حجم خط الأذكار', 'Azkar Font Size', 'Zikir Yazı Boyutu')),
                subtitle: Slider(
                  value: s.fontScale,
                  min: 0.85,
                  max: 1.50,
                  divisions: 6,
                  label: '${(s.fontScale * 100).round()}%',
                  onChanged: (v) {
                    s.fontScale = v;
                    s.saveAllState(resyncTimers: false);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.route_rounded, color: primary),
                title: Text(s.tr('إعادة الجولة التعليمية', 'Replay App Tour', 'Uygulama Turunu Tekrarla')),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 15),
                onTap: () {
                  s.widget.prefs.setBool('seenHomeTour', false);
                  s.widget.prefs.setBool('seenQuranHomeTour', false);
                  s.widget.prefs.setBool('seenSurahTour', false);
                  setState(() => _currentIndex = 0);
                  if (_pageController.hasClients) {
                    _pageController.jumpToPage(0);
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _startHomeSpotlightTour();
                  });
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.info_outline_rounded, color: primary),
                title: Text(s.tr('إصدار التطبيق', 'App Version', 'Uygulama Sürümü')),
                trailing: const Text('2.3.0',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.support_agent_rounded, color: primary),
                title: Text(s.tr('تواصل معنا', 'Contact Us', 'Bize Ulaşın')),
                subtitle: const Text('support@azkari.app'),
                onTap: () => launchUrl(
                  Uri.parse('mailto:support@azkari.app'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.privacy_tip_outlined, color: primary),
                title: Text(s.tr('سياسة الخصوصية وحذف البيانات', 'Privacy Policy', 'Gizlilik Politikası')),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => launchUrl(
                  Uri.parse(
                      'https://docs.google.com/document/d/1CRS1CVXWhUAgwBNWYXHooPk2JyUAiS6CSepioB6oZgA/edit?usp=drivesdk'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> showDoubleRewardShareDialog(
    BuildContext context, _AzkariAppState s) async {
  int countdown = 5;
  Timer? timer;
  bool disposed = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDState) {
        timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
          if (disposed) {
            t.cancel();
            return;
          }
          if (countdown > 0) {
            setDState(() => countdown -= 1);
          } else {
            t.cancel();
          }
        });

        final canTap = countdown == 0;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            s.tr(
              'هل تريد مضاعفة أجرك؟ 😍',
              'Want to double your reward? 😍',
              'Sevabını katlamak ister misin? 😍',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.tr(
                  'شارك التطبيق لغيرك، وكل حسنة يكسبها غيرك لك مثلها 😁',
                  'Share the app with others, and every good deed they earn brings you the same reward 😁',
                  'Uygulamayı başkalarıyla paylaş, onların kazandığı her sevap sana da yazılsın 😁',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14.5, height: 1.6),
              ),
              if (!canTap) ...[
                const SizedBox(height: 14),
                Text(
                  '$countdown',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.skyBlue,
                  ),
                ),
              ],
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: canTap ? Colors.red.shade600 : Colors.grey,
                foregroundColor: Colors.white,
              ),
              onPressed: !canTap
                  ? null
                  : () {
                      disposed = true;
                      timer?.cancel();
                      Navigator.pop(ctx);
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        builder: (c2) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                          title: Text(
                            s.tr(
                              'لقد ضيعت أجراً عظيماً 😢',
                              'You missed a great reward 😢',
                              'Büyük bir sevabı kaçırdın 😢',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          actionsAlignment: MainAxisAlignment.spaceEvenly,
                          actions: [
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(c2),
                              child: Text(s.tr('أعلم بذلك', 'I know', 'Biliyorum')),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.pop(c2);
                                Share.share(
                                  s.tr(
                                    'تطبيق أذكاري: رفيقك اليومي للقرآن والأذكار والسبحة بدون إعلانات\n$kAppDownloadLink',
                                    'Azkari App: Your ad-free daily Quran, Azkar & Tasbih companion\n$kAppDownloadLink',
                                    'Zikirlerim: Reklamsız günlük Kur’an, Zikir ve Tesbih rehberin\n$kAppDownloadLink',
                                  ),
                                );
                              },
                              child: Text(s.tr('مضاعفة الأجر', 'Double Reward', 'Sevabı Katla')),
                            ),
                          ],
                        ),
                      );
                    },
              child: Text(
                canTap
                    ? s.tr('إلغاء', 'Cancel', 'İptal')
                    : '${s.tr('إلغاء', 'Cancel', 'İptal')} ($countdown)',
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: canTap ? Colors.green.shade600 : Colors.grey,
                foregroundColor: Colors.white,
              ),
              onPressed: !canTap
                  ? null
                  : () {
                      disposed = true;
                      timer?.cancel();
                      Navigator.pop(ctx);
                      Share.share(
                        s.tr(
                          'تطبيق أذكاري: رفيقك اليومي للقرآن والأذكار والسبحة بدون إعلانات\n$kAppDownloadLink',
                          'Azkari App: Your ad-free daily Quran, Azkar & Tasbih companion\n$kAppDownloadLink',
                          'Zikirlerim: Reklamsız günlük Kur’an, Zikir ve Tesbih rehberin\n$kAppDownloadLink',
                        ),
                      );
                    },
              child: Text(
                canTap
                    ? s.tr('مضاعفة الأجر', 'Double Reward', 'Sevabı Katla')
                    : '${s.tr('مضاعفة الأجر', 'Double Reward', 'Sevabı Katla')} ($countdown)',
              ),
            ),
          ],
        );
      },
    ),
  );
  disposed = true;
  timer?.cancel();
}

class AchievementsScreen extends StatelessWidget {
  final _AzkariAppState appState;
  const AchievementsScreen({super.key, required this.appState});

  String _companionDurationText(_AzkariAppState s) {
    final start = DateTime.tryParse(s.firstInstallDate) ?? DateTime.now();
    final now = DateTime.now();
    int totalDays = now.difference(start).inDays;
    if (totalDays < 1) totalDays = 1;
    final years = totalDays ~/ 365;
    final months = (totalDays % 365) ~/ 30;
    final days = (totalDays % 365) % 30;

    final parts = <String>[];
    if (years > 0) parts.add(s.tr('$years سنة', '$years yr', '$years yıl'));
    if (months > 0) parts.add(s.tr('$months شهر', '$months mo', '$months ay'));
    if (days > 0 || parts.isEmpty) {
      parts.add(s.tr('$days يوم', '$days day(s)', '$days gün'));
    }
    return parts.join(' • ');
  }

  (String, Color, int, int) _tierInfo(_AzkariAppState s) {
    final score = s.totalAzkarCompleted + s.tasbihLifetime;
    if (score >= 100000) {
      return (s.tr('المستوى الألماسي', 'Diamond Tier', 'Elmas Seviye'), const Color(0xFF38BDF8), 100000, 6);
    }
    if (score >= 35000) {
      return (s.tr('المستوى البلاتيني', 'Platinum Tier', 'Platin Seviye'), const Color(0xFFCBD5E1), 100000, 5);
    }
    if (score >= 10000) {
      return (s.tr('المستوى الذهبي', 'Gold Tier', 'Altın Seviye'), const Color(0xFFFBBF24), 35000, 4);
    }
    if (score >= 2500) {
      return (s.tr('المستوى الفضي', 'Silver Tier', 'Gümüş Seviye'), const Color(0xFF94A3B8), 10000, 3);
    }
    if (score >= 500) {
      return (s.tr('المستوى البرونزي', 'Bronze Tier', 'Bronz Seviye'), const Color(0xFFD97706), 2500, 2);
    }
    return (s.tr('المستوى الخشبي', 'Wooden Tier', 'Ahşap Seviye'), const Color(0xFFA16207), 500, 1);
  }

  @override
  Widget build(BuildContext context) {
    final s = appState;
    final isDark = s.isDarkMode;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final (tierName, tierColor, nextGoal, tierLevel) = _tierInfo(s);
    final score = s.totalAzkarCompleted + s.tasbihLifetime;
    final tierProgress = (score / nextGoal).clamp(0.0, 1.0);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.tr('الإنجازات والمواظبة', 'Achievements & Streak', 'Başarılar ve Seri')),
        actions: [
          IconButton(
            tooltip: s.tr('مضاعفة الأجر', 'Double Reward', 'Sevabı Katla'),
            onPressed: () => showDoubleRewardShareDialog(context, s),
            icon: const Icon(Icons.share_rounded, color: AppColors.skyBlue),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account & Companion Duration Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tierColor.withOpacity(0.22),
                  AppColors.primaryBlue.withOpacity(0.18),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: tierColor.withOpacity(0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: tierColor.withOpacity(0.25),
                      child: Icon(Icons.workspace_premium_rounded, color: tierColor, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tierName,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: tierColor,
                            ),
                          ),
                          Text(
                            s.fbUserName.isNotEmpty
                                ? s.tr('مرتبط بحساب: ${s.fbUserName}', 'Linked: ${s.fbUserName}', 'Bağlı: ${s.fbUserName}')
                                : s.tr('اربط حسابك لحفظ إنجازاتك سحابياً', 'Link account to sync progress', 'İlerlemeni kaydetmek için bağla'),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: tierProgress,
                    minHeight: 8,
                    color: tierColor,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$score / $nextGoal',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: AppColors.skyBlue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s.tr('منذ متى تعرف أذكاري:', 'With Azkari for:', 'Zikirlerim ile geçen süre:')} ${_companionDurationText(s)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Streak & Freeze Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/flame_$tierLevel.gif',
                      width: 52,
                      height: 52,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.amber,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.tr('المواظبة الحالية: ${s.currentStreak} يوم',
                                'Current Streak: ${s.currentStreak} days',
                                'Mevcut Seri: ${s.currentStreak} gün'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            s.tr('أفضل مواظبة: ${s.bestStreak} يوم • إجمالي الأذكار: ${s.totalAzkarCompleted}',
                                'Best: ${s.bestStreak} days • Total Azkar: ${s.totalAzkarCompleted}',
                                'En iyi: ${s.bestStreak} gün • Toplam: ${s.totalAzkarCompleted}'),
                            style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.skyBlue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.ac_unit_rounded, color: AppColors.skyBlue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.tr(
                            'يوم تجميد مجاني أسبوعياً يحفظ مواظبتك عند الانشغال',
                            '1 weekly Streak Freeze protects your streak on busy days',
                            'Haftalık 1 Seri Dondurma hakkı yoğun günlerde serini korur',
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // 30-Day Activity Heatmap
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.tr('سجل النشاط (آخر 30 يوماً)', 'Activity Heatmap (Last 30 Days)', 'Aktivite Haritası (Son 30 Gün)'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 30,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 10,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemBuilder: (_, idx) {
                    final day = now.subtract(Duration(days: 29 - idx)).toIso8601String().split('T').first;
                    final active = s.activeDaysHistory.contains(day);
                    return Container(
                      decoration: BoxDecoration(
                        color: active ? AppColors.skyBlue : Colors.grey.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Weekly & Daily Tasks
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    s.tr('تحديات اليوم والأسبوع', 'Daily & Weekly Challenges', 'Günlük ve Haftalık Görevler'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                ),
                CheckboxListTile(
                  title: Text(s.tr('أذكار الصباح', 'Morning Azkar', 'Sabah Zikirleri')),
                  value: s.taskMorningDone,
                  onChanged: null,
                ),
                CheckboxListTile(
                  title: Text(s.tr('أذكار المساء', 'Evening Azkar', 'Akşam Zikirleri')),
                  value: s.taskEveningDone,
                  onChanged: null,
                ),
                CheckboxListTile(
                  title: Text(s.tr('أذكار النوم', 'Sleep Azkar', 'Uyku Zikirleri')),
                  value: s.taskSleepDone,
                  onChanged: null,
                ),
                CheckboxListTile(
                  title: Text(s.tr('تحدي 300 تسبيحة', '300 Tasbih Challenge', '300 Tesbih Görevi')),
                  value: s.tasbihLifetime >= 300,
                  onChanged: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  final _AzkariAppState appState;
  const OnboardingScreen({super.key, required this.appState});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0; // 0 = welcome, 1 = language, 2 = reminder mode

  void _showFrequencyDialog(String mode) {
    final s = widget.appState;
    final options = <(String, String, int)>[
      (s.tr('أقصى حد', 'Maximum', 'Maksimum'), s.tr('كل 5 دقائق', 'Every 5 min', 'Her 5 dk'), 5),
      (s.tr('مكثف', 'Frequent', 'Sık'), s.tr('كل 10 دقائق', 'Every 10 min', 'Her 10 dk'), 10),
      (s.tr('سريع', 'Quick', 'Hızlı'), s.tr('كل 15 دقيقة', 'Every 15 min', 'Her 15 dk'), 15),
      (s.tr('متوازن', 'Balanced', 'Dengeli'), s.tr('كل 30 دقيقة', 'Every 30 min', 'Her 30 dk'), 30),
      (s.tr('عادي', 'Standard', 'Standart'), s.tr('كل ساعة', 'Every 1 hour', 'Her 1 saat'), 60),
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          s.tr('معدل تكرار التذكير', 'Reminder Frequency'),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.skyBlue.withOpacity(0.35)),
                ),
                title: Text(opt.$1,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(opt.$2),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  s.reminderMode = mode;
                  s.floatingEnabled = mode == 'overlay';
                  s.floatingIntervalMinutes = opt.$3;
                  s.saveAllState();
                  Navigator.pop(ctx);
                  if (mounted) setState(() => _step = 3);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.appState;
    final isDark = s.isDarkMode;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final card = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _step == 0
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: 112,
                        height: 112,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.mosque_rounded,
                          size: 72,
                          color: AppColors.skyBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      s.tr('أهلاً بك في أذكاري', 'Welcome to Azkari'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      s.tr(
                        'رفيقك اليومي لأذكار الصباح والمساء والقرآن الكريم والسبحة الإلكترونية بدون إعلانات وبأعلى سلاسة.',
                        'Your daily companion for Azkar, Quran, and Tasbih.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.7,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        for (final tour in [
                          (Icons.auto_awesome_rounded, s.tr('أذكار وذكر عائم', 'Azkar & Overlay', 'Zikir & Yüzen')),
                          (Icons.menu_book_rounded, s.tr('القرآن وتتبع الكلمة', 'Quran Word Sync', 'Kur’an Takibi')),
                          (Icons.emoji_events_rounded, s.tr('إنجازات ومواظبة', 'Streaks & Tiers', 'Başarılar')),
                        ])
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.skyBlue.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  Icon(tour.$1, color: AppColors.skyBlue, size: 22),
                                  const SizedBox(height: 6),
                                  Text(
                                    tour.$2,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      onPressed: () => s.showLanguagePicker(context),
                      icon: const Icon(Icons.public_rounded,
                          color: AppColors.skyBlue),
                      label: Text(
                        s.appLang == 'tr'
                            ? 'Dil: Türkçe'
                            : (s.appLang == 'en'
                                ? 'Language: English'
                                : 'اللغة: العربية'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999)),
                        ),
                        onPressed: () {
                          setState(() => _step = 2);
                        },
                        child: Text(
                          s.tr('متابعة', 'Continue'),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                )
              : _step == 1
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.public_rounded,
                            size: 64, color: AppColors.skyBlue),
                        const SizedBox(height: 20),
                        const Text(
                          'اختر اللغة / Choose Language',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999)),
                            ),
                            onPressed: () {
                              s.isEnglish = false;
                              s.saveAllState(resyncTimers: false);
                              setState(() => _step = 2);
                            },
                            child: const Text('العربية',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999)),
                            ),
                            onPressed: () {
                              s.isEnglish = true;
                              s.saveAllState(resyncTimers: false);
                              setState(() => _step = 2);
                            },
                            child: const Text('English',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  : _step == 3
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                width: 88,
                                height: 88,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.account_circle_rounded,
                                  size: 72,
                                  color: AppColors.skyBlue,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              s.tr(
                                'ربط الحساب أم الدخول كزائر؟',
                                'Sign in or Continue as Guest?',
                                'Giriş Yap veya Misafir Devam Et?',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.tr(
                                'اربط حسابك لحفظ ملفك أو تابع كزائر فوراً وابدأ جولتك في التطبيق.',
                                'Link your account or jump right in as a guest.',
                                'Hesabınızı bağlayın veya misafir olarak hemen başlayın.',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.6,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1877F2),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999)),
                                ),
                                onPressed: () async {
                                  await s.loginWithFacebook(context);
                                  s.onboardingDone = true;
                                  s.saveAllState();
                                },
                                icon: const Icon(Icons.facebook_rounded),
                                label: Text(
                                  s.tr(
                                    'تسجيل الدخول بفيسبوك',
                                    'Sign in with Facebook',
                                    'Facebook ile Giriş Yap',
                                  ),
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999)),
                                ),
                                onPressed: () {
                                  s.onboardingDone = true;
                                  s.saveAllState();
                                },
                                icon: const Icon(Icons.person_outline_rounded),
                                label: Text(
                                  s.tr(
                                    'المتابعة كزائر',
                                    'Continue as Guest',
                                    'Misafir Olarak Devam Et',
                                  ),
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        s.tr('طريقة التذكير', 'Reminder Style'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      // Option 1: Notification Shade Preview
                      InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => _showFrequencyDialog('notification'),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                                color: AppColors.skyBlue.withOpacity(0.5)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.notifications_active_rounded,
                                      color: AppColors.skyBlue),
                                  const SizedBox(width: 10),
                                  Text(
                                    s.tr('مركز الإشعارات', 'Notification Bar'),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.redAccent.withOpacity(0.8),
                                      width: 2),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        'assets/images/app_icon.png',
                                        width: 30,
                                        height: 30,
                                        errorBuilder: (_, __, ___) => const Icon(
                                            Icons.mosque_rounded,
                                            color: Colors.white,
                                            size: 24),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.tr('أذكاري • الآن',
                                                'Azkari • Now'),
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            s.tr('سبحان الله وبحمده',
                                                'SubhanAllah wa bihamdih'),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Option 2: Floating Overlay Preview
                      InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () async {
                          try {
                            final granted = await FlutterOverlayWindow
                                .isPermissionGranted();
                            if (!granted) {
                              await FlutterOverlayWindow.requestPermission();
                            }
                          } catch (_) {}
                          if (mounted) {
                            _showFrequencyDialog('overlay');
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                                color: Colors.greenAccent.withOpacity(0.5)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.layers_rounded,
                                      color: Colors.greenAccent),
                                  const SizedBox(width: 10),
                                  Text(
                                    s.tr('فوق التطبيقات الأخرى',
                                        'Floating Over Apps'),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1E293B),
                                      Color(0xFF0F172A)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0D47A1),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                                color: const Color(0xFF38BDF8),
                                                width: 1.5),
                                          ),
                                          child: Text(
                                            s.tr('اللهم ارحمني',
                                                'O Allah, have mercy'),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.arrow_back_rounded,
                                          color: Colors.redAccent,
                                          size: 28,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: const [
                                        Icon(Icons.play_circle_fill_rounded,
                                            color: Colors.redAccent, size: 26),
                                        Icon(Icons.mail_rounded,
                                            color: Colors.blueAccent, size: 26),
                                        Icon(Icons.map_rounded,
                                            color: Colors.green, size: 26),
                                        Icon(Icons.camera_alt_rounded,
                                            color: Colors.white70, size: 26),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class AzkarReaderScreen extends StatefulWidget {
  final _AzkariAppState appState;
  final String category;
  final int initialIndex;

  const AzkarReaderScreen({
    super.key,
    required this.appState,
    required this.category,
    this.initialIndex = 0,
  });

  @override
  State<AzkarReaderScreen> createState() => _AzkarReaderScreenState();
}

class _AzkarReaderScreenState extends State<AzkarReaderScreen> {
  bool _isEditMode = false;
  late DateTime _enteredAt;
  bool _celebrationShown = false;

  @override
  void initState() {
    super.initState();
    _enteredAt = DateTime.now();
  }

  String _formatDuration(Duration d) {
    final s = widget.appState;
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    if (mins == 0) {
      return s.tr('$secs ثانية', '$secs sec');
    }
    return s.tr('$mins دقيقة و $secs ثانية', '${mins}m ${secs}s');
  }

  void _showExitDurationSnackBar(String catLabel) {
    final spent = DateTime.now().difference(_enteredAt);
    if (spent.inSeconds < 2) return;
    final s = widget.appState;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
        content: Text(
          s.tr(
            'استغرقت ${_formatDuration(spent)} في $catLabel',
            'Spent ${_formatDuration(spent)} in $catLabel',
          ),
        ),
      ),
    );
  }

  void _openAzkarPageSettings() {
    final s = widget.appState;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.tr('إعدادات صفحة الأذكار ', 'Azkar Page Settings '),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: kQuranFonts.map((f) {
                    return ChoiceChip(
                      label: Text(fontLabelForLang(f.$1, s.appLang)),
                      selected: s.azkarFontFamily == f.$1,
                      onSelected: (_) {
                        s.azkarFontFamily = f.$1;
                        s.saveAllState(resyncTimers: false);
                        setSheetState(() {});
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
                Slider(
                  value: s.fontScale,
                  min: 0.85,
                  max: 1.50,
                  divisions: 6,
                  label: '${(s.fontScale * 100).round()}%',
                  onChanged: (v) {
                    s.fontScale = v;
                    s.saveAllState(resyncTimers: false);
                    setSheetState(() {});
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.tr('تشكيل مبسط ومريح', 'Light Tashkeel')),
                  value: s.minimalTashkeel,
                  onChanged: (v) {
                    s.minimalTashkeel = v;
                    s.saveAllState(resyncTimers: false);
                    setSheetState(() {});
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.tr('إظهار المصدر والفضل', 'Show Source')),
                  value: s.showSource,
                  onChanged: (v) {
                    s.showSource = v;
                    s.saveAllState(resyncTimers: false);
                    setSheetState(() {});
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.tr('طيّ الذكر المكتمل تلقائياً',
                      'Auto-collapse Completed', 'Tamamlanan Zikri Küçült')),
                  value: s.collapseCompletedAzkar,
                  onChanged: (v) {
                    s.collapseCompletedAzkar = v;
                    s.saveAllState(resyncTimers: false);
                    setSheetState(() {});
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareZikrAsImage(String zikrText, String catLabel) async {
    final s = widget.appState;
    final themes = <(String, List<Color>, Color)>[
      (s.tr('أزرق ليلي', 'Midnight', 'Gece'), const [Color(0xFF0A192F), Color(0xFF0D47A1)], Colors.white),
      (s.tr('سماوي', 'Sky Blue', 'Gökyüzü'), const [Color(0xFF0284C7), Color(0xFF38BDF8)], Colors.white),
      (s.tr('أسود نقي', 'Pure Black', 'Siyah'), const [Color(0xFF09090B), Color(0xFF1E293B)], Colors.white),
      (s.tr('زمردي', 'Emerald', 'Zümrüt'), const [Color(0xFF064E3B), Color(0xFF10B981)], Colors.white),
      (s.tr('ذهبي داكن', 'Royal Gold', 'Altın'), const [Color(0xFF451A03), Color(0xFFB45309)], Colors.white),
      (s.tr('أبيض نقي', 'Clean White', 'Beyaz'), const [Color(0xFFF8FAFC), Color(0xFFE2E8F0)], const Color(0xFF0F172A)),
    ];
    int selectedTheme = 0;
    final cardKey = GlobalKey();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          final theme = themes[selectedTheme];
          final textColor = theme.$3;
          final isLightCard = textColor != Colors.white;
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.tr('تخصيص بطاقة الذكر', 'Customize Zikr Card', 'Zikir Kartını Özelleştir'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  RepaintBoundary(
                    key: cardKey,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: theme.$2,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isLightCard ? Colors.black12 : Colors.white24,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            catLabel,
                            style: TextStyle(
                              color: textColor.withOpacity(0.75),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            zikrText,
                            textAlign: TextAlign.center,
                            textDirection: s.appLang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                            style: TextStyle(
                              fontFamily: s.appLang == 'ar' ? s.azkarFontFamily : null,
                              color: textColor,
                              fontSize: 17.5,
                              height: 1.75,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Divider(color: textColor.withOpacity(0.18), height: 1),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/images/app_icon.png',
                                  width: 28,
                                  height: 28,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.mosque_rounded,
                                    color: textColor,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'أذكاري - واذكر ربك إذا نسيت (Azkari)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.play_arrow_rounded, color: Color(0xFF38BDF8), size: 11),
                                              SizedBox(width: 2),
                                              Text('Google Play', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.apple_rounded, color: Colors.white, size: 11),
                                              SizedBox(width: 2),
                                              Text('App Store', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.skyBlue.withOpacity(0.22),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.skyBlue.withOpacity(0.6)),
                                ),
                                child: Text(
                                  s.tr('شارك تؤجر', 'Share for Reward', 'Paylaş Kazan'),
                                  style: TextStyle(
                                    color: isLightCard ? AppColors.primaryBlue : Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: List.generate(themes.length, (idx) {
                      final isSel = idx == selectedTheme;
                      return GestureDetector(
                        onTap: () => setDState(() => selectedTheme = idx),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: themes[idx].$2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? AppColors.skyBlue : Colors.grey,
                              width: isSel ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Share.share('$zikrText\n\nأذكاري - واذكر ربك إذا نسيت (Azkari)\n$kAppDownloadLink');
                          },
                          icon: const Icon(Icons.text_fields_rounded, size: 18),
                          label: Text(s.tr('نص', 'Text', 'Metin')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            try {
                              final boundary = cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                              if (boundary != null) {
                                final img = await boundary.toImage(pixelRatio: 2.5);
                                final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
                                if (bytes != null) {
                                  final dir = await getTemporaryDirectory();
                                  final file = File('${dir.path}/azkari_card.png');
                                  await file.writeAsBytes(bytes.buffer.asUint8List());
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await Share.shareXFiles(
                                    [XFile(file.path)],
                                    text: '$catLabel • أذكاري (Azkari)\n$kAppDownloadLink',
                                  );
                                  return;
                                }
                              }
                            } catch (_) {}
                            if (ctx.mounted) Navigator.pop(ctx);
                            Share.share('$zikrText\n$kAppDownloadLink');
                          },
                          icon: const Icon(Icons.image_rounded, size: 18),
                          label: Text(s.tr('صورة', 'Image', 'Görsel')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmResetAll(List<ZikrItem> items) {
    final s = widget.appState;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(s.tr('تأكيد التصفير', 'Confirm Reset')),
        content: Text(s.tr(
          'هل أنت متأكد من تصفير جميع العدادات في هذا القسم؟',
          'Reset all counters in this category?',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.tr('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              for (final z in items) {
                z.count = 0;
              }
              _celebrationShown = false;
              s.saveAzkarEditsOnly();
              Navigator.pop(ctx);
              setState(() {});
            },
            child: Text(s.tr('تصفير', 'Reset')),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditZikrDialog({ZikrItem? existing, required String catLabel}) {
    final s = widget.appState;
    String initialPre = '';
    String initialBody = existing?.text ?? '';
    if (existing != null && existing.text.contains('\n')) {
      final parts = existing.text.split('\n');
      initialPre = parts.first;
      initialBody = parts.sublist(1).join('\n');
    }

    final preCtrl = TextEditingController(text: initialPre);
    final bodyCtrl = TextEditingController(text: initialBody);
    final noteCtrl = TextEditingController(text: existing?.source ?? '');
    final targetCtrl =
        TextEditingController(text: '${existing?.target ?? 1}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          existing == null
              ? s.tr('إضافة ذكر جديد', 'Add Zikr')
              : s.tr('تعديل الذكر', 'Edit Zikr'),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: preCtrl,
                decoration: InputDecoration(
                  labelText: s.tr('ما قبل الذكر (اختياري)', 'Intro (Optional)'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: s.tr('نص الذكر', 'Zikr Text'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: s.tr('ملاحظة / الفضل (اختياري)', 'Note / Virtue'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: s.tr('عدد الحبات / التكرار', 'Repeat Count'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () {
                s.deletedAzkarIds.add(existing.id);
                s.azkarList.removeWhere((z) => z.id == existing.id);
                s.saveAzkarEditsOnly();
                Navigator.pop(ctx);
                setState(() {});
              },
              child: Text(s.tr('حذف', 'Delete'),
                  style: const TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.tr('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final body = bodyCtrl.text.trim();
              if (body.isEmpty) return;
              final pre = preCtrl.text.trim();
              final fullText = pre.isNotEmpty ? '$pre\n$body' : body;
              final target = (int.tryParse(targetCtrl.text.trim()) ?? 1).clamp(1, 9999);
              final source = noteCtrl.text.trim();

              if (existing != null) {
                s.editedAzkarOverrides[existing.id] = {
                  'text': fullText,
                  'source': source,
                  'target': target,
                };
                final idx = s.azkarList.indexWhere((z) => z.id == existing.id);
                if (idx != -1) {
                  s.azkarList[idx] = ZikrItem(
                    id: existing.id,
                    category: existing.category,
                    categoryLabel: existing.categoryLabel,
                    text: fullText,
                    source: source,
                    target: target,
                    count: existing.count.clamp(0, target),
                    favorite: existing.favorite,
                  );
                }
              } else {
                final newId = DateTime.now().millisecondsSinceEpoch;
                s.azkarList.add(
                  ZikrItem(
                    id: newId,
                    category: widget.category,
                    categoryLabel: catLabel,
                    text: fullText,
                    source: source,
                    target: target,
                  ),
                );
              }
              s.saveAzkarEditsOnly();
              Navigator.pop(ctx);
              setState(() {});
            },
            child: Text(s.tr('تأكيد', 'Save')),
          ),
        ],
      ),
    );
  }

  void _showCompletionCelebration(String categoryLabel) {
    if (_celebrationShown) return;
    _celebrationShown = true;
    final s = widget.appState;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Done',
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, _, __) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim.value),
          child: Opacity(
            opacity: anim.value,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: IgnorePointer(child: _ConfettiBurstWidget()),
                ),
                Center(
                  child: AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    title: Text(
                      s.tr('تقبّل الله منك!', 'May Allah accept!'),
                      textAlign: TextAlign.center,
                    ),
                    content: Text(
                      s.tr(
                        'أتممت $categoryLabel بحمد الله. بارك الله في وقتك وزادك طمأنينة.',
                        'You completed $categoryLabel.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    actionsAlignment: MainAxisAlignment.center,
                    actions: [
                      FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(s.tr('الحمد لله', 'Alhamdulillah')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.appState;
    final items =
        s.azkarList.where((z) => z.category == widget.category).toList();
    final isDark = s.isDarkMode;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final cardColor = isDark ? const Color(0xFF0E0E0E) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF222222) : const Color(0xFFE2E8F0);
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryBlue;
    final catLabel = items.isNotEmpty
        ? (items.first.categoryForLang(s.appLang))
        : s.tr('الأذكار', 'Azkar');

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _showExitDurationSnackBar(catLabel);
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: Text(catLabel),
          actions: [
            IconButton(
              tooltip: s.tr('إضافة ذكر جديد', 'Add Zikr'),
              onPressed: () => _showAddOrEditZikrDialog(catLabel: catLabel),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
            if (_isEditMode && s.deletedAzkarIds.isNotEmpty)
              IconButton(
                tooltip: s.tr('استعادة الأذكار المحذوفة', 'Restore Deleted'),
                onPressed: () {
                  s.deletedAzkarIds.clear();
                  s._rebuildAzkarList();
                  s.saveAzkarEditsOnly();
                  setState(() {});
                },
                icon: const Icon(Icons.restore_from_trash_rounded,
                    color: Colors.amber),
              ),
            IconButton(
              tooltip: s.tr('تعديل الأذكار', 'Edit Azkar'),
              onPressed: () {
                            setState(() => _isEditMode = !_isEditMode);
              },
              icon: Icon(
                _isEditMode ? Icons.check_rounded : Icons.edit_rounded,
                color: _isEditMode ? Colors.greenAccent : null,
              ),
            ),
            IconButton(
              tooltip: s.tr('تصفير العدادات', 'Reset All'),
              onPressed: items.isEmpty ? null : () => _confirmResetAll(items),
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: s.tr('إعدادات العرض', 'Display Settings'),
              onPressed: _openAzkarPageSettings,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),

        body: items.isEmpty
            ? Center(
                child: Text(s.tr('لا توجد أذكار في هذا القسم', 'No Azkar here')),
              )
            : Column(
                children: [
                  Builder(builder: (_) {
                    final doneCount = items.where((z) => z.count >= z.target).length;
                    final pct = items.isEmpty ? 0.0 : doneCount / items.length;
                    return Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                s.tr(
                                  'تم $doneCount من ${items.length}',
                                  'Done $doneCount of ${items.length}',
                                  'Tamamlanan: $doneCount / ${items.length}',
                                ),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                ),
                              ),
                              Text(
                                '${(pct * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 5,
                              backgroundColor: borderColor,
                              valueColor: AlwaysStoppedAnimation<Color>(primary),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  Expanded(
                    child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
                itemCount: items.length + 1,
                itemBuilder: (context, index) {
                  if (index == items.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          side: BorderSide(color: primary.withOpacity(0.45)),
                        ),
                        onPressed: () => _showAddOrEditZikrDialog(catLabel: catLabel),
                        icon: Icon(Icons.add_rounded, color: primary),
                        label: Text(
                          s.tr('إضافة مربع ذكر جديد', 'Add New Zikr Card'),
                          style: TextStyle(color: primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }
                  final item = items[index];
                  final rawText = s.minimalTashkeel
                      ? lightTashkeel(item.text)
                      : item.text;
                  final parts = rawText.split('\n');
                  final hasIntro = parts.length > 1;
                  final intro = hasIntro ? parts.first : null;
                  final body = hasIntro ? parts.sublist(1).join('\n') : rawText;
                  final done = item.count >= item.target;
                  final progress =
                      item.target > 0 ? (item.count / item.target).clamp(0.0, 1.0) : 1.0;

                  if (s.collapseCompletedAzkar && done && !_isEditMode) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F1D1D).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: const Color(0xFF991B1B).withOpacity(0.45)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${index + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.redAccent),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.isTurkish
                                  ? item.turkishText
                                  : (s.isEnglish ? item.englishText : body),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${item.target} / ${item.target}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent),
                          ),
                        ],
                      ),
                    );
                  }

                  return RepaintBoundary(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: borderColor,
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${index + 1} / ${items.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                              Row(
                                children: [
                                  if (_isEditMode)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _showAddOrEditZikrDialog(
                                        existing: item,
                                        catLabel: catLabel,
                                      ),
                                      icon: const Icon(Icons.edit_rounded,
                                          size: 20, color: Colors.amber),
                                    ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: s.tr('مشاركة', 'Share', 'Paylaş'),
                                    onPressed: () {
                                      final shareBody = s.isTurkish
                                          ? item.turkishText
                                          : (s.isEnglish ? item.englishText : item.text);
                                      showModalBottomSheet(
                                        context: context,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(22)),
                                        ),
                                        builder: (shCtx) => SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                leading: const Icon(Icons.text_fields_rounded,
                                                    color: AppColors.skyBlue),
                                                title: Text(s.tr('مشاركة كنص',
                                                    'Share as Text', 'Metin Olarak Paylaş')),
                                                onTap: () {
                                                  Navigator.pop(shCtx);
                                                  Share.share('$shareBody\n\n— ${s.tr("تطبيق أذكاري", "Azkari App", "Zikirlerim")}');
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.image_rounded,
                                                    color: AppColors.skyBlue),
                                                title: Text(s.tr('مشاركة كبطاقة',
                                                    'Share as Image Card', 'Kart Olarak Paylaş')),
                                                onTap: () {
                                                  Navigator.pop(shCtx);
                                                  _shareZikrAsImage(shareBody, catLabel);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.share_rounded,
                                        size: 20, color: AppColors.skyBlue),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      item.favorite = !item.favorite;
                                      s.saveLightState();
                                      setState(() {});
                                    },
                                    icon: Icon(
                                      item.favorite
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      size: 22,
                                      color: AppColors.skyBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (intro != null && !s.isEnglish && !s.isTurkish) ...[
                            Text(
                              intro,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: s.azkarFontFamily,
                                fontSize: 15 * s.fontScale,
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (s.isEnglish || s.isTurkish) ...[
                            Text(
                              body,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'AmiriQuran',
                                fontSize: 19 * s.fontScale,
                                height: 1.85,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              toEnglishTranslit(body),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.skyBlue,
                                fontSize: 13.5 * s.fontScale,
                                height: 1.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              s.isTurkish ? item.turkishText : item.englishText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.5 * s.fontScale,
                                height: 1.6,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ] else
                            Text(
                              body,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: s.azkarFontFamily,
                                fontSize: 19 * s.fontScale,
                                height: 1.9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (s.showSource && item.source.isNotEmpty && !s.isEnglish && !s.isTurkish) ...[
                            const SizedBox(height: 10),
                            Text(
                              item.source,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          _PillCounterButton(
                            count: item.count,
                            target: item.target,
                            progress: progress,
                            done: done,
                            colors: s.sabhaColors,
                            onTap: () {
                              if (item.count < item.target) {
                                item.count += 1;
                                final justFinished = item.count == item.target;
                                s.playTapFeedback(stronger: justFinished, silentChime: true);
                                if (justFinished) {
                                  s.totalAzkarCompleted += 1;
                                  final allDone =
                                      items.every((z) => z.count >= z.target);
                                  if (allDone) {
                                    _showCompletionCelebration(catLabel);
                                  }
                                }
                                s.saveLightState();
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PillCounterButton extends StatefulWidget {
  final int count;
  final int target;
  final double progress;
  final bool done;
  final List<Color> colors;
  final VoidCallback onTap;

  const _PillCounterButton({
    required this.count,
    required this.target,
    required this.progress,
    required this.done,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_PillCounterButton> createState() => _PillCounterButtonState();
}

class _PillCounterButtonState extends State<_PillCounterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final remaining = (widget.target - widget.count).clamp(0, widget.target);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: widget.done
                  ? const [Color(0xFF7F1D1D), Color(0xFF991B1B)]
                  : widget.colors,
            ),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: (widget.done
                              ? const Color(0xFF7F1D1D)
                              : widget.colors.last)
                          .withOpacity(0.45),
                      blurRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: widget.progress,
                heightFactor: 1.0,
                child: Container(
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
              Center(
                child: Text(
                  widget.done
                      ? '${widget.target} / ${widget.target}'
                      : '$remaining',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfettiBurstWidget extends StatefulWidget {
  const _ConfettiBurstWidget();

  @override
  State<_ConfettiBurstWidget> createState() => _ConfettiBurstWidgetState();
}

class _ConfettiBurstWidgetState extends State<_ConfettiBurstWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    const palette = [
      Color(0xFF38BDF8),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFFA855F7),
    ];
    _pieces = List.generate(42, (_) {
      return _ConfettiPiece(
        x: rng.nextDouble(),
        speed: 0.4 + rng.nextDouble() * 0.7,
        size: 6 + rng.nextDouble() * 6,
        color: palette[rng.nextInt(palette.length)],
        drift: (rng.nextDouble() - 0.5) * 0.25,
      );
    });
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _ConfettiPainter(_pieces, _ctrl.value),
      ),
    );
  }
}

class _ConfettiPiece {
  final double x;
  final double speed;
  final double size;
  final Color color;
  final double drift;
  _ConfettiPiece({
    required this.x,
    required this.speed,
    required this.size,
    required this.color,
    required this.drift,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final dx = (p.x + p.drift * t) * size.width;
      final dy = (t * p.speed) * size.height;
      paint.color = p.color.withOpacity((1.0 - t).clamp(0.0, 1.0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(dx, dy), width: p.size, height: p.size * 0.6),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}

class RoundedSquareCounterButton extends StatefulWidget {
  final double progress;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color borderGlowColor;
  final double size;
  final VoidCallback onTap;

  const RoundedSquareCounterButton({
    super.key,
    required this.progress,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.borderGlowColor,
    this.size = 180,
    required this.onTap,
  });

  @override
  State<RoundedSquareCounterButton> createState() =>
      _RoundedSquareCounterButtonState();
}

class _RoundedSquareCounterButtonState
    extends State<RoundedSquareCounterButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size;
    final double radius = s * 0.30;
    final double strokeWidth = max(5.0, s * 0.036);
    final double clampedProgress = widget.progress.clamp(0.0, 1.0);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: SizedBox(
          width: s + 16,
          height: s + 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Raised 3D button body with shadow
              AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                width: s - 6,
                height: s - 6,
                transform: Matrix4.translationValues(0, _isPressed ? 4 : 0, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.gradientColors,
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 1.5,
                  ),
                  boxShadow: _isPressed
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: widget.gradientColors.last.withOpacity(0.55),
                            blurRadius: 0,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: widget.borderGlowColor.withOpacity(
                              isDark ? 0.32 : 0.28,
                            ),
                            blurRadius: 20,
                            spreadRadius: 1,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.6 : 0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: s * 0.24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: s * 0.09,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.88),
                      ),
                    ),
                  ],
                ),
              ),
              // Progress line wrapping around the rounded square
              IgnorePointer(
                child: CustomPaint(
                  size: Size(s + 12, s + 12),
                  painter: _RoundedSquareProgressPainter(
                    progress: clampedProgress,
                    radius: radius + 4,
                    strokeWidth: strokeWidth,
                    activeColor: widget.borderGlowColor,
                    trackColor: isDark
                        ? Colors.white.withOpacity(0.10)
                        : Colors.black.withOpacity(0.08),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundedSquareProgressPainter extends CustomPainter {
  final double progress;
  final double radius;
  final double strokeWidth;
  final Color activeColor;
  final Color trackColor;

  _RoundedSquareProgressPainter({
    required this.progress,
    required this.radius,
    required this.strokeWidth,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double inset = strokeWidth / 2 + 2;
    final Rect rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(rrect, trackPaint);

    if (progress <= 0) return;

    // Build path starting from top-center so it wraps cleanly clockwise
    final Path basePath = Path()..addRRect(rrect);
    final ui.PathMetric? metric = basePath.computeMetrics().firstOrNull;
    if (metric == null) return;

    final double totalLen = metric.length;
    // Start near top-center (approx 1/8th offset depending on RRect start)
    final double startOffset = totalLen * 0.125;
    final double drawLen = totalLen * progress.clamp(0.0, 1.0);

    final Path activePath = Path();
    if (startOffset + drawLen <= totalLen) {
      activePath.addPath(
        metric.extractPath(startOffset, startOffset + drawLen),
        Offset.zero,
      );
    } else {
      activePath.addPath(
        metric.extractPath(startOffset, totalLen),
        Offset.zero,
      );
      activePath.addPath(
        metric.extractPath(0, (startOffset + drawLen) - totalLen),
        Offset.zero,
      );
    }

    final Paint glowPaint = Paint()
      ..color = activeColor.withOpacity(0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ;
    canvas.drawPath(activePath, glowPaint);

    final Paint activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(activePath, activePaint);
  }

  @override
  bool shouldRepaint(covariant _RoundedSquareProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class _InstagramVectorIcon extends StatelessWidget {
  const _InstagramVectorIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: const LinearGradient(
          colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.8),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TikTokVectorIcon extends StatelessWidget {
  const _TikTokVectorIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white24),
      ),
      child: const Center(
        child: Icon(
          Icons.audiotrack_rounded,
          color: Color(0xFF25F4EE),
          size: 18,
        ),
      ),
    );
  }
}

const Map<String, String> kEnToTrUi = {
  'Home': 'Ana Sayfa',
  'Quran': 'Kur’an',
  'Azkar': 'Zikirler',
  'All Azkar': 'Tüm Zikirler',
  'Tasbih': 'Tesbih',
  'Settings': 'Ayarlar',
  'Welcome to Azkari': 'Zikirlerim’e Hoş Geldiniz',
  'Your daily companion for Azkar, Quran, and Tasbih.': 'Zikirler, Kur’an ve Tesbih için günlük manevi rehberiniz.',
  'Continue': 'Devam Et',
  'Reminder Style': 'Hatırlatma Yöntemi',
  'Notification Bar': 'Bildirim Çubuğu',
  'Quiet notification in status bar': 'Bildirim çubuğunda sessiz hatırlatma',
  'Floating Over Apps': 'Uygulamalar Üzerinde',
  'Floating Zikr card over other apps': 'Diğer uygulamaların üzerinde şık zikir penceresi',
  'Reminder Frequency': 'Hatırlatma Sıklığı',
  'Qibla, Habits & Backup': 'Kıble, Alışkanlıklar ve Yedekleme',
  'Achievements & Tasks': 'Başarılar ve Görevler',
  'Button Sound': 'Tuş Sesi',
  'Share with a Friend': 'Arkadaşınla Paylaş',
  'Rate App': 'Uygulamayı Değerlendir',
  'Check for Updates': 'Güncellemeleri Kontrol Et',
  'Follow Us': 'Bizi Takip Edin',
  'Tap & Tasbih Sounds': 'Dokunma ve Tesbih Sesleri',
  'Haptic Feedback': 'Titreşim',
  'Light Tashkeel in Azkar': 'Zikirlerde Sade Hareke',
  'Azkar Font Family': 'Zikir Yazı Tipi',
  'Azkar Font Size': 'Zikir Yazı Boyutu',
  'App Version': 'Uygulama Sürümü',
  'Contact Us': 'Bize Ulaşın',
  'Privacy Policy': 'Gizlilik Politikası',
  'Add': 'Ekle',
  'Reset': 'Sıfırla',
  'Tap': 'Dokun',
  'Done': 'Tamam',
  'Edit Azkar': 'Zikirleri Düzenle',
  'Restore Deleted': 'Silinenleri Geri Yükle',
  'Reset All': 'Tümünü Sıfırla',
  'Display Settings': 'Görünüm Ayarları',
  'Add Zikr': 'Zikir Ekle',
  'Add New Zikr Card': 'Yeni Zikir Kartı Ekle',
  'Edit Zikr': 'Zikri Düzenle',
  'Confirm Reset': 'Sıfırlamayı Onayla',
  'Reset all counters in this category?': 'Bu bölümdeki tüm sayaçlar sıfırlansın mı?',
  'Cancel': 'İptal',
  'Save': 'Kaydet',
  'Delete': 'Sil',
  'Next': 'Sonraki',
  'Prev': 'Önceki',
  'Tafsir': 'Tefsir',
  'Info': 'Bilgi',
  'Alhamdulillah': 'Elhamdülillah',
};