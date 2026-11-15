import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:just_audio/just_audio.dart';
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

String formatHijriAndGregorian(DateTime date, bool isEnglish) {
  const weekDaysAr = [
    'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
  ];
  const weekDaysEn = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];
  const hijriMonthsAr = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
  ];
  // تحويل تقريبي دقيق للتاريخ الهجري (خوارزمية الكويت)
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

  final dayName = isEnglish
      ? weekDaysEn[date.weekday - 1]
      : weekDaysAr[date.weekday - 1];
  final mName = hijriMonthsAr[(hMonth - 1).clamp(0, 11)];
  final gStr = '${date.day}/${date.month}/${date.year}';
  return isEnglish
      ? '$dayName • $hDay $mName $hYear AH • $gStr'
      : '$dayName • $hDay $mName $hYear هـ • $gStr';
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
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is String && event.isNotEmpty && mounted) {
        setState(() => _zikr = event);
      }
    });
    _autoHideTimer = Timer(const Duration(seconds: 5), () async {
      await FlutterOverlayWindow.closeOverlay();
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
      child: GestureDetector(
        onTap: () async {
          _autoHideTimer?.cancel();
          await FlutterOverlayWindow.closeOverlay();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF0288D1)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('💧', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _zikr,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'اسحب للتحريك • اضغط للإخفاء',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
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
  static const Color backgroundLight = Color(0xFFF4F8FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFDCE7F2);
  static const Color textPrimaryLight = Color(0xFF0F1E33);
  static const Color textSecondaryLight = Color(0xFF566B85);

  static const Color backgroundDark = Color(0xFF0B1320);
  static const Color surfaceDark = Color(0xFF132033);
  static const Color borderDark = Color(0xFF213552);
  static const Color primaryDark = Color(0xFF4FC3F7);
  static const Color textPrimaryDark = Color(0xFFF0F6FC);
  static const Color textSecondaryDark = Color(0xFF9CB2CC);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final prefs = await SharedPreferences.getInstance();
  runApp(AzkariApp(prefs: prefs));
  try {
    await NotificationService.instance.init();
  } catch (_) {}
}

class AzkariApp extends StatefulWidget {
  final SharedPreferences prefs;
  const AzkariApp({super.key, required this.prefs});

  @override
  State<AzkariApp> createState() => _AzkariAppState();
}

class _AzkariAppState extends State<AzkariApp> {
  late bool isDarkMode;
  late bool isEnglish;
  late bool buttonSoundEnabled;
  late bool hapticEnabled;
  late double fontScale;
  late String azkarFontFamily;
  late bool autoNext;
  late bool showProgress;
  late bool showSource;
  late bool dailyAudio;
  late bool morningReminder;
  late bool eveningReminder;
  late bool sleepReminder;
  late bool floatingEnabled;
  late int floatingIntervalMinutes;
  late int tasbihCount;
  late int tasbihLifetime;
  late String tasbihPhrase;
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
  Timer? _floatingTimer;

  String tr(String ar, String en) => isEnglish ? en : ar;

  void playTapFeedback({bool lightOnly = false}) {
    if (hapticEnabled) {
      if (lightOnly) {
        HapticFeedback.selectionClick();
      } else {
        HapticFeedback.lightImpact();
      }
    }
    if (buttonSoundEnabled) SystemSound.play(SystemSoundType.click);
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
    _loadPrefsFromDisk();
    azkarList = getInitialAzkarList();
    _restoreAzkarState();
    _syncReminders();
    _syncFloatingTimer();
  }

  void _loadPrefsFromDisk() {
    final p = widget.prefs;
    final today = DateTime.now().toIso8601String().split('T').first;

    isDarkMode = p.getBool('darkMode') ?? true;
    isEnglish = p.getBool('isEnglish') ?? false;
    buttonSoundEnabled = p.getBool('buttonSoundEnabled') ?? true;
    hapticEnabled = p.getBool('hapticEnabled') ?? true;
    fontScale = p.getDouble('fontScale') ?? 1.0;
    azkarFontFamily = p.getString('azkarFontFamily') ?? 'Scheherazade';
    autoNext = p.getBool('autoNext') ?? true;
    showProgress = p.getBool('showProgress') ?? true;
    showSource = p.getBool('showSource') ?? true;
    dailyAudio = p.getBool('dailyAudio') ?? true;
    morningReminder = p.getBool('morningReminder') ?? true;
    eveningReminder = p.getBool('eveningReminder') ?? true;
    sleepReminder = p.getBool('sleepReminder') ?? true;
    floatingEnabled = p.getBool('floatingEnabled') ?? false;
    floatingIntervalMinutes = p.getInt('floatingIntervalMinutes') ?? 15;
    tasbihCount = p.getInt('tasbihCount') ?? 0;
    tasbihLifetime = p.getInt('tasbihLifetime') ?? 0;
    tasbihPhrase =
        p.getString('tasbihPhrase') ?? 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ';

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
      final phrase =
          kRandomShortAzkar[Random().nextInt(kRandomShortAzkar.length)];
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        height: 155,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.topCenter,
        flag: OverlayFlag.defaultFlag,
      );
      await FlutterOverlayWindow.shareData(phrase);
    } catch (_) {}
  }

  void saveAllState() {
    final p = widget.prefs;
    p.setBool('darkMode', isDarkMode);
    p.setBool('isEnglish', isEnglish);
    p.setBool('buttonSoundEnabled', buttonSoundEnabled);
    p.setBool('hapticEnabled', hapticEnabled);
    p.setDouble('fontScale', fontScale);
    p.setString('azkarFontFamily', azkarFontFamily);
    p.setBool('autoNext', autoNext);
    p.setBool('showProgress', showProgress);
    p.setBool('showSource', showSource);
    p.setBool('dailyAudio', dailyAudio);
    p.setBool('morningReminder', morningReminder);
    p.setBool('eveningReminder', eveningReminder);
    p.setBool('sleepReminder', sleepReminder);
    p.setBool('floatingEnabled', floatingEnabled);
    p.setInt('floatingIntervalMinutes', floatingIntervalMinutes);
    p.setInt('tasbihCount', tasbihCount);
    p.setInt('tasbihLifetime', tasbihLifetime);
    p.setString('tasbihPhrase', tasbihPhrase);
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
    _syncReminders();
    _syncFloatingTimer();
    setState(() {});
  }

  bool shouldPlaySplashAudioToday() {
    if (!dailyAudio) return false;
    final today = DateTime.now().toIso8601String().split('T').first;
    return widget.prefs.getString('lastSplashAudioDate') != today;
  }

  void markSplashAudioPlayedToday() {
    final today = DateTime.now().toIso8601String().split('T').first;
    widget.prefs.setString('lastSplashAudioDate', today);
  }

  @override
  void dispose() {
    _floatingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surface = isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight;
    final primary = isDarkMode ? AppColors.primaryDark : AppColors.primaryBlue;
    final textPrimary =
        isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return MaterialApp(
      title: isEnglish ? 'Azkari' : 'أذكاري',
      debugShowCheckedModeBanner: false,
      locale: Locale(isEnglish ? 'en' : 'ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
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
  final AudioPlayer _audioPlayer = AudioPlayer();
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
    _playDailySplashAudio();

    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  Future<void> _playDailySplashAudio() async {
    if (!widget.appState.shouldPlaySplashAudioToday()) return;
    try {
      await _audioPlayer.setAsset('assets/audio/splash_ayah.mp3');
      await _audioPlayer.play();
      widget.appState.markSplashAudioPlayedToday();
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
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
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 108,
                                    height: 108,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: AppColors.skyBlue,
                                        width: 2,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text('💧',
                                        style: TextStyle(fontSize: 48)),
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
          : MainShellScreen(
              key: const ValueKey('main'),
              appState: widget.appState,
            ),
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
  int _currentIndex = 0;
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate(
        context,
        isEnglish: widget.appState.isEnglish,
      );
    });
  }

  void _openCategoryReader(String category, {int initialIndex = 0}) {
    widget.appState.playTapFeedback();
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
    s.playTapFeedback();
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
    s.playTapFeedback();
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
        'حمّل تطبيق «أذكاري» للأذكار اليومية والقرآن والسبحة بدون إنترنت:\n$kAppDownloadLink\nشارك تؤجر 💙',
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
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          s.playTapFeedback(lightOnly: true);
          setState(() => _currentIndex = idx);
        },
        backgroundColor: cardColor,
        indicatorColor: primary.withOpacity(0.16),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_rounded),
            label: s.tr('الرئيسية', 'Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_rounded),
            label: s.tr('القرآن', 'Quran'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_rounded),
            label: s.tr('كل الأذكار', 'All Azkar'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.scatter_plot_rounded),
            label: s.tr('السبحة', 'Tasbih'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_rounded),
            label: s.tr('الإعدادات', 'Settings'),
          ),
        ],
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
                      appBar: AppBar(title: Text(s.tr('المفضلة ⭐', 'Favorites ⭐'))),
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
              leading: Icon(Icons.spa_rounded, color: primary),
              title: Text(s.tr('واحة الذكر (دعاء الشعور والأسماء)', 'Islamic Oasis')),
              onTap: () {
                Navigator.pop(context);
                _openExplore();
              },
            ),
            ListTile(
              leading: Icon(Icons.explore_rounded, color: primary),
              title: Text(s.tr('القبلة والعادات والنسخ الاحتياطي',
                  'Qibla, Habits & Backup')),
              onTap: () {
                Navigator.pop(context);
                _openTools();
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
            ListTile(
              leading: Icon(Icons.language_rounded, color: primary),
              title: Text(s.tr('اللغة: العربية / English', 'Language: EN / AR')),
              trailing: Switch(
                value: s.isEnglish,
                onChanged: (v) {
                  s.isEnglish = v;
                  s.saveAllState();
                },
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
                UpdateService.checkForUpdate(context, isEnglish: s.isEnglish);
              },
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // أعلى الشاشة: بسم الله بالعثماني + التاريخ الهجري والميلادي + فيسبوك والقائمة أقصى اليسار
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                    style: TextStyle(
                      fontFamily: 'AmiriQuran',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatHijriAndGregorian(now, s.isEnglish),
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
                    s.playTapFeedback();
                    setState(() => _showSearch = !_showSearch);
                  },
                  icon: const Icon(Icons.search_rounded),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  onPressed: () {
                    s.playTapFeedback();
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
              hintText: s.tr('ابحث في الأذكار أو الأدعية أو المصدر...',
                  'Search Azkar or source...'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
          ),
          if (_searchQuery.trim().isNotEmpty)
            ...s.azkarList
                .where((z) =>
                    z.text.contains(_searchQuery) ||
                    z.source.contains(_searchQuery))
                .map(
                  (item) => Card(
                    color: cardColor,
                    margin: const EdgeInsets.only(top: 8),
                    child: ListTile(
                      title: Text(item.text,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
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
              child: _quickCard(cardColor, borderColor, '📖',
                  s.tr('القرآن الكريم', 'Quran'), () => setState(() => _currentIndex = 1)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickCard(cardColor, borderColor, '🌿',
                  s.tr('دعاء وشعورك', 'Mood Dua'), () => _openExplore(tab: 0)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickCard(cardColor, borderColor, '🧭',
                  s.tr('القبلة والأدوات', 'Qibla & Tools'), _openTools),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // المهام اليومية الأوتوماتيك 100% (تُفتح بالضغط وتُعلم تلقائياً عند الإتمام)
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.tr('المهام اليومية (تلقائية) ✅', 'Daily Tasks (Auto) ✅'),
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
      ('morning', '🌅', s.tr('أذكار الصباح', 'Morning Azkar')),
      ('evening', '🌙', s.tr('أذكار المساء', 'Evening Azkar')),
      ('prayer', '🕌', s.tr('أذكار الصلاة وبعدها', 'Prayer Azkar')),
      ('adhan', '📢', s.tr('أذكار الأذان', 'Adhan Azkar')),
      ('sleep', '🛌', s.tr('أذكار النوم', 'Sleep Azkar')),
      ('wakeup', '☀️', s.tr('أذكار الاستيقاظ', 'Wake-up Azkar')),
      ('mosque', '🕌', s.tr('أذكار المسجد', 'Mosque Azkar')),
      ('wudu', '💧', s.tr('أذكار الوضوء', 'Wudu Azkar')),
      ('daily', '🏠', s.tr('المنزل والسفر', 'Home & Travel')),
      ('food', '🍽️', s.tr('أذكار الطعام', 'Food Azkar')),
      ('khala', '🚿', s.tr('دخول الخلاء والخروج', 'Restroom Dua')),
      ('supplications', '🤲', s.tr('أذكار وأدعية عامة', 'General Azkar')),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(s.tr('كل الأذكار 📿', 'All Azkar 📿'),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: _showAddCustomZikrDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(s.tr('إضافة ذكر', 'Add Zikr')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (s.customAzkar.isNotEmpty) ...[
          Text(s.tr('أذكاري المخصصة (اضغط مطولاً أو بالأسهم للترتيب)',
              'My Custom Azkar'),
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
            childAspectRatio: 1.45,
          ),
          itemBuilder: (ctx, idx) {
            final (catKey, emoji, label) = allCategories[idx];
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                final exists =
                    s.azkarList.any((z) => z.category == catKey);
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
                    Text(emoji, style: const TextStyle(fontSize: 24)),
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
    final Map<String, List<(String, String, int)>> extras = {
      'adhan': [
        (
          'عند سماع المؤذن: يقول مثل ما يقول المؤذن إلا في الحيعلتين فيقول: لا حول ولا قوة إلا بالله.',
          'متفق عليه',
          1
        ),
        (
          'اللَّهُمَّ رَبَّ هَذِهِ الدَّعْوَةِ التَّامَّةِ، وَالصَّلَاةِ الْقَائِمَةِ، آتِ مُحَمَّدًا الْوَسِيلَةَ وَالْفَضِيلَةَ...',
          'رواه البخاري',
          1
        ),
      ],
      'mosque': [
        (
          'دخول المسجد: اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ.',
          'رواه مسلم',
          1
        ),
        (
          'الخروج من المسجد: اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ.',
          'رواه مسلم',
          1
        ),
      ],
      'wudu': [
        ('قبل الوضوء: بِسْمِ اللَّهِ.', 'رواه أبو داود', 1),
        (
          'بعد الوضوء: أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ.',
          'رواه مسلم',
          1
        ),
      ],
      'food': [
        ('قبل الطعام: بِسْمِ اللَّهِ (فإن نسي: بسم الله أوله وآخره).', 'رواه أبو داود', 1),
        (
          'بعد الطعام: الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلَا قُوَّةٍ.',
          'رواه الترمذي',
          1
        ),
      ],
      'khala': [
        (
          'عند الدخول: اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْخُبُثِ وَالْخَبَائِثِ.',
          'متفق عليه',
          1
        ),
        ('عند الخروج: غُفْرَانَكَ.', 'رواه أبو داود والترمذي', 1),
      ],
    };

    final list = extras[catKey] ?? extras['wudu']!;
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
                    Text(list[i].$1,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontSize: 19, height: 1.9)),
                    const SizedBox(height: 8),
                    Text('📜 ${list[i].$2}',
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
    final beforeCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final countCtrl = TextEditingController(text: '3');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('إضافة ذكر مخصص', 'Add Custom Zikr')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                    labelText: s.tr('اسم الذكر / العنوان', 'Title')),
              ),
              TextField(
                controller: beforeCtrl,
                decoration: InputDecoration(
                    labelText: s.tr('ما قبل الذكر (اختياري)', 'Before Zikr')),
              ),
              TextField(
                controller: textCtrl,
                maxLines: 3,
                decoration:
                    InputDecoration(labelText: s.tr('نص الذكر', 'Zikr Text')),
              ),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                    labelText: s.tr('ملاحظة أو وصف', 'Note / Description')),
              ),
              TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: s.tr('عدد مرات القراءة', 'Repeat Count')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.tr('إلغاء', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (textCtrl.text.trim().isEmpty) return;
              s.customAzkar.add({
                'title': titleCtrl.text.trim().isEmpty
                    ? s.tr('ذكر مخصص', 'Custom Zikr')
                    : titleCtrl.text.trim(),
                'before': beforeCtrl.text.trim(),
                'text': textCtrl.text.trim(),
                'note': noteCtrl.text.trim(),
                'target': int.tryParse(countCtrl.text.trim()) ?? 1,
              });
              s.saveAllState();
              Navigator.pop(ctx);
            },
            child: Text(s.tr('حفظ', 'Save')),
          ),
        ],
      ),
    );
  }

  Widget _quickCard(Color cardColor, Color borderColor, String emoji,
      String title, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasbihTab(BuildContext context, Color cardColor,
      Color borderColor, Color primary, Color textSecondary) {
    final s = widget.appState;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.tr('السبحة الإلكترونية', 'Electronic Tasbih'),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    tooltip: s.tr('تغيير الشكل', 'Change Skin'),
                    onPressed: _openTools,
                    icon: const Icon(Icons.palette_rounded),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      s.playTapFeedback();
                      s.tasbihCount = 0;
                      s.saveAllState();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(s.tr('تصفير', 'Reset')),
                  ),
                ],
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            value: kRandomShortAzkar.contains(s.tasbihPhrase)
                ? s.tasbihPhrase
                : kRandomShortAzkar.first,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
            items: kRandomShortAzkar
                .map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                s.tasbihPhrase = v;
                s.saveAllState();
              }
            },
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Text(
                  s.tasbihPhrase,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: primary),
                ),
                const SizedBox(height: 12),
                Text('${s.tasbihCount}',
                    style: const TextStyle(
                        fontSize: 64, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(
                  s.tr(
                    'الدورة الحالية (33): ${s.tasbihCount % 33 == 0 && s.tasbihCount > 0 ? 33 : s.tasbihCount % 33} / 33  •  الإجمالي: ${s.tasbihLifetime}',
                    'Cycle (33): ${s.tasbihCount % 33 == 0 && s.tasbihCount > 0 ? 33 : s.tasbihCount % 33} / 33  •  Total: ${s.tasbihLifetime}',
                  ),
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              s.tasbihCount += 1;
              s.tasbihLifetime += 1;
              // هزة قوية وصوت مميز عند مضاعفات 33 (33، 66، 99...) وهزة خفيفة جداً في العادي
              if (s.tasbihCount % 33 == 0) {
                if (s.hapticEnabled) HapticFeedback.heavyImpact();
                if (s.buttonSoundEnabled) SystemSound.play(SystemSoundType.alert);
              } else {
                s.playTapFeedback(lightOnly: true);
              }
              s.recordDailyActivity();
            },
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: s.sabhaColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppColors.skyBlue, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: s.sabhaColors.first.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📿', style: TextStyle(fontSize: 34)),
                  const SizedBox(height: 6),
                  Text(s.tr('سبّح', 'Tap'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab(BuildContext context, Color cardColor,
      Color borderColor, Color primary, Color textSecondary) {
    final s = widget.appState;
    final favs = s.azkarList.where((z) => z.favorite).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (favs.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text(s.tr('لا توجد أذكار مفضلة بعد', 'No favorites yet'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          )
        else
          ...favs.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
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
                      Text(item.categoryLabel,
                          style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      IconButton(
                        onPressed: () {
                          item.favorite = false;
                          s.saveAllState();
                        },
                        icon: const Icon(Icons.star_rounded,
                            color: AppColors.skyBlue),
                      ),
                    ],
                  ),
                  Text(item.text,
                      style: TextStyle(
                          fontFamily: s.azkarFontFamily,
                          fontSize: 19 * s.fontScale,
                          height: 1.9)),
                  const SizedBox(height: 8),
                  Text('📜 ${item.source}',
                      style: TextStyle(fontSize: 12, color: textSecondary)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSettingsTab(BuildContext context, Color cardColor,
      Color borderColor, Color primary, Color textSecondary) {
    final s = widget.appState;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(s.tr('الإعدادات ⚙️', 'Settings ⚙️'),
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
                title: Text(s.tr('الوضع الليلي الهادئ', 'Dark Navy Mode')),
                value: s.isDarkMode,
                onChanged: (v) {
                  s.isDarkMode = v;
                  s.saveAllState();
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(s.tr('اللغة الإنجليزية (English)', 'English Language')),
                value: s.isEnglish,
                onChanged: (v) {
                  s.isEnglish = v;
                  s.saveAllState();
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(s.tr('صوت الأزرار عند الضغط', 'Button Click Sound')),
                value: s.buttonSoundEnabled,
                onChanged: (v) {
                  s.buttonSoundEnabled = v;
                  s.saveAllState();
                },
              ),
              SwitchListTile(
                title: Text(s.tr('الاهتزاز (Haptic Feedback)', 'Haptic Feedback')),
                value: s.hapticEnabled,
                onChanged: (v) {
                  s.hapticEnabled = v;
                  s.saveAllState();
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: Text(s.tr('نوع خط الأذكار', 'Azkar Font Family')),
                subtitle: Wrap(
                  spacing: 8,
                  children: kQuranFonts.map((f) {
                    return ChoiceChip(
                      label: Text(f.$2),
                      selected: s.azkarFontFamily == f.$1,
                      onSelected: (_) {
                        s.azkarFontFamily = f.$1;
                        s.saveAllState();
                      },
                    );
                  }).toList(),
                ),
              ),
              ListTile(
                title: Text(s.tr('حجم خط الأذكار', 'Azkar Font Size')),
                subtitle: Slider(
                  value: s.fontScale,
                  min: 0.85,
                  max: 1.50,
                  divisions: 6,
                  label: '${(s.fontScale * 100).round()}%',
                  onChanged: (v) {
                    s.fontScale = v;
                    s.saveAllState();
                  },
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(s.tr('الانتقال التلقائي للذكر التالي',
                    'Auto-advance on completion')),
                value: s.autoNext,
                onChanged: (v) {
                  s.autoNext = v;
                  s.saveAllState();
                },
              ),
              SwitchListTile(
                title: Text(s.tr('إظهار شريط التقدم', 'Show Progress Bar')),
                value: s.showProgress,
                onChanged: (v) {
                  s.showProgress = v;
                  s.saveAllState();
                },
              ),
              SwitchListTile(
                title: Text(s.tr('إظهار مصدر الذكر', 'Show Source')),
                value: s.showSource,
                onChanged: (v) {
                  s.showSource = v;
                  s.saveAllState();
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(s.tr('تشغيل الصوت اليومي في البداية',
                    'Daily Startup Ayah Audio')),
                value: s.dailyAudio,
                onChanged: (v) {
                  s.dailyAudio = v;
                  s.saveAllState();
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(s.tr('الذكر العشوائي في الخلفية (5 ثوانٍ)',
                    'Floating Zikr Overlay')),
                value: s.floatingEnabled,
                onChanged: (v) async {
                  if (v) await s.showFloatingZikrNow();
                  s.floatingEnabled = v;
                  s.saveAllState();
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(s.tr('تذكير أذكار الصباح (06:00 ص)',
                    'Morning Reminder (6:00 AM)')),
                value: s.morningReminder,
                onChanged: (v) async {
                  await NotificationService.instance.requestPermissions();
                  s.morningReminder = v;
                  s.saveAllState();
                },
              ),
              SwitchListTile(
                title: Text(s.tr('تذكير أذكار المساء (05:00 م)',
                    'Evening Reminder (5:00 PM)')),
                value: s.eveningReminder,
                onChanged: (v) async {
                  await NotificationService.instance.requestPermissions();
                  s.eveningReminder = v;
                  s.saveAllState();
                },
              ),
              SwitchListTile(
                title: Text(s.tr('تذكير أذكار النوم (10:30 م)',
                    'Sleep Reminder (10:30 PM)')),
                value: s.sleepReminder,
                onChanged: (v) async {
                  await NotificationService.instance.requestPermissions();
                  s.sleepReminder = v;
                  s.saveAllState();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AchievementsScreen extends StatelessWidget {
  final _AzkariAppState appState;
  const AchievementsScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final s = appState;
    final isDark = s.isDarkMode;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final badges = [
      (
        '🌱',
        s.tr('بداية مباركة', 'Blessed Start'),
        s.tr('إتمام 10 أذكار', 'Complete 10 Azkar'),
        s.totalAzkarCompleted >= 10,
      ),
      (
        '🔥',
        s.tr('مواظب 7 أيام متواصلة', '7-Day Streak'),
        s.tr('الذكر لمدة 7 أيام بدون انقطاع', '7 consecutive days of Dhikr'),
        s.bestStreak >= 7,
      ),
      (
        '👑',
        s.tr('بطل الشهر (30 يوماً)', '30-Day Champion'),
        s.tr('مواظبة 30 يوماً متواصلة بدون توقف', '30 consecutive days without stopping'),
        s.bestStreak >= 30,
      ),
      (
        '💎',
        s.tr('ذاكر الله كثيراً', '1,000+ Dhikr'),
        s.tr('إجمالي الأذكار والتسبيح 1000+', '1,000+ total Azkar & Tasbih'),
        (s.totalAzkarCompleted + s.tasbihLifetime) >= 1000,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.tr('الإنجازات والمواظبة 🏆', 'Achievements 🏆'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF0288D1)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCol(s.tr('السلسلة الحالية', 'Streak'), '${s.currentStreak}'),
                _statCol(s.tr('أطول سلسلة', 'Best'), '${s.bestStreak}'),
                _statCol(
                    s.tr('الأذكار المكتملة', 'Completed'), '${s.totalAzkarCompleted}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...badges.map(
            (b) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: b.$4 ? AppColors.skyBlue : borderColor,
                  width: b.$4 ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(b.$1, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.$2,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(b.$3,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Icon(
                    b.$4 ? Icons.verified_rounded : Icons.lock_outline_rounded,
                    color: b.$4 ? AppColors.skyBlue : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String label, String val) {
    return Column(
      children: [
        Text(val,
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
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
  late int _currentIndex;
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isSharingImage = false;
  bool _promptedFriendsThisSession = false;

  bool _handsFreeMode = false;
  Timer? _handsFreeTimer;
  int _shareCardTheme = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _handsFreeTimer?.cancel();
    super.dispose();
  }

  void _toggleHandsFree(List<ZikrItem> items) {
    setState(() => _handsFreeMode = !_handsFreeMode);
    _handsFreeTimer?.cancel();
    if (!_handsFreeMode) return;

    _handsFreeTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_handsFreeMode) return;
      final current = items[_currentIndex];
      widget.appState.playTapFeedback();
      if (current.count < current.target) {
        current.count += 1;
        if (current.count == current.target) {
          widget.appState.totalAzkarCompleted += 1;
          widget.appState.recordDailyActivity();
        } else {
          widget.appState.saveAllState();
        }
        setState(() {});
      } else if (_currentIndex < items.length - 1) {
        setState(() => _currentIndex += 1);
      } else {
        setState(() => _handsFreeMode = false);
        _handsFreeTimer?.cancel();
      }
    });
  }

  List<Color> get _shareGradient {
    switch (_shareCardTheme) {
      case 1:
        return const [Color(0xFF0B1320), Color(0xFF1E293B)];
      case 2:
        return const [Color(0xFF78350F), Color(0xFFD97706)];
      default:
        return const [Color(0xFF0D47A1), Color(0xFF0288D1)];
    }
  }

  Future<void> _shareAsText(ZikrItem item) async {
    final text = '''${item.text}

📜 المصدر: ${item.source}

📲 حمّل تطبيق «أذكاري» مجانًا بدون إنترنت:
$kAppDownloadLink
شارك تؤجر 💙''';
    await Share.share(text);
  }

  Future<void> _shareAsImage(ZikrItem item) async {
    if (_isSharingImage) return;
    setState(() => _isSharingImage = true);
    try {
      await Future.delayed(const Duration(milliseconds: 80));
      final boundary = _shareCardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/azkari_share_${item.id}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'شارك تؤجر 💙 حمّل تطبيق أذكاري:\n$kAppDownloadLink',
      );
    } finally {
      if (mounted) setState(() => _isSharingImage = false);
    }
  }

  void _showCompletionCelebration(String categoryLabel) {
    final s = widget.appState;
    if (_promptedFriendsThisSession) return;
    _promptedFriendsThisSession = true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.greenAccent, size: 68),
            const SizedBox(height: 12),
            Text(
              'ما شاء الله عليك ربنا يبارك فيك ويحفظك من كل سوء',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            const Text(
              'قل: اللهم يا مقلب القلوب ثبت قلبي على دينك',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'حتى رسول الله ﷺ كان يدعو بهذا الدعاء',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'نسأل الله العفو والعافية لنا جميعاً',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Text(
              s.tr('هل تريد تذكير أصدقائك بـ $categoryLabel؟',
                  'Remind friends about $categoryLabel?'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _maybeShowRateDialog();
            },
            child: Text(s.tr('إغلاق', 'Close')),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Share.share(
                'تذكير: لا تنسَ $categoryLabel اليوم 🌿\nحمّل تطبيق أذكاري:\n$kAppDownloadLink',
              );
            },
            icon: const Icon(Icons.share_rounded),
            label: Text(s.tr('تذكير الأصدقاء', 'Remind Friends')),
          ),
        ],
      ),
    );
  }

  void _maybeShowRateDialog() {
    final s = widget.appState;
    if (s.hasRatedPromptShown || !s.isSecondDayOrLater() || !mounted) return;
    s.hasRatedPromptShown = true;
    s.saveAllState();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('ما رأيك في تطبيق أذكاري؟ ⭐', 'Enjoying Azkari? ⭐')),
        content: Text(
          s.tr(
            'يسعدنا تقييمك للتطبيق ومشاركته لنشر الخير.',
            'Your rating helps us improve and reach more people.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.tr('ليس الآن', 'Not Now')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(kAppDownloadLink);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(s.tr('قيّم الآن ⭐', 'Rate Now ⭐')),
          ),
        ],
      ),
    );
  }

  void _showShareMenu(ZikrItem item) {
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
              children: [
                Text(s.tr('استوديو مشاركة الذكر 🎨', 'Share Card Studio 🎨'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: Text(s.tr('أزرق ملكي', 'Royal Blue')),
                      selected: _shareCardTheme == 0,
                      onSelected: (_) {
                        setState(() => _shareCardTheme = 0);
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(s.tr('كحلي ليلي', 'Night Navy')),
                      selected: _shareCardTheme == 1,
                      onSelected: (_) {
                        setState(() => _shareCardTheme = 1);
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(s.tr('ذهبي هادئ', 'Gold')),
                      selected: _shareCardTheme == 2,
                      onSelected: (_) {
                        setState(() => _shareCardTheme = 2);
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.image_rounded,
                      color: AppColors.primaryBlue),
                  title: Text(s.tr('مشاركة كصورة لحالة واتساب والمنصات',
                      'Share as Image Card')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareAsImage(item);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.text_fields_rounded,
                      color: AppColors.midBlue),
                  title:
                      Text(s.tr('مشاركة كنص مع رابط التطبيق', 'Share as Text')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareAsText(item);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.appState;
    final items =
        s.azkarList.where((z) => z.category == widget.category).toList();
    final current = items[_currentIndex];
    final isDark = s.isDarkMode;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryBlue;

    final completedCount = items.where((z) => z.count >= z.target).length;
    final progress = items.isEmpty ? 0.0 : completedCount / items.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(current.categoryLabel),
        actions: [
          IconButton(
            tooltip: s.tr('القراءة التلقائية بدون لمس', 'Hands-Free Auto'),
            onPressed: () => _toggleHandsFree(items),
            icon: Icon(
              _handsFreeMode
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_outline_rounded,
              color: _handsFreeMode ? AppColors.skyBlue : null,
            ),
          ),
          IconButton(
            tooltip: s.tr('تصغير الخط', 'Decrease Font'),
            onPressed: () {
              s.fontScale = (s.fontScale - 0.1).clamp(0.85, 1.50);
              s.saveAllState();
              setState(() {});
            },
            icon: const Icon(Icons.text_decrease_rounded),
          ),
          IconButton(
            tooltip: s.tr('تكبير الخط', 'Increase Font'),
            onPressed: () {
              s.fontScale = (s.fontScale + 0.1).clamp(0.85, 1.50);
              s.saveAllState();
              setState(() {});
            },
            icon: const Icon(Icons.text_increase_rounded),
          ),
          IconButton(
            tooltip: s.tr('مشاركة الذكر', 'Share'),
            onPressed: () => _showShareMenu(current),
            icon: const Icon(Icons.share_rounded),
          ),
          IconButton(
            tooltip: s.tr('تصفير عداد القسم', 'Reset'),
            onPressed: () {
              for (final z in items) {
                z.count = 0;
              }
              setState(() => _currentIndex = 0);
              s.saveAllState();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            left: -2000,
            top: 0,
            child: RepaintBoundary(
              key: _shareCardKey,
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _shareGradient,
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      current.categoryLabel,
                      style: const TextStyle(
                        color: Color(0xFFBAE6FD),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.25), width: 1),
                      ),
                      child: Column(
                        children: [
                          Text(
                            current.text,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: s.azkarFontFamily,
                              color: Colors.white,
                              fontSize: 21,
                              height: 1.9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '📜 ${current.source}',
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color: Color(0xFFE0F2FE),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      textDirection: TextDirection.rtl,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                width: 28,
                                height: 28,
                                errorBuilder: (_, __, ___) => const Text('💧',
                                    style: TextStyle(fontSize: 20)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'أذكاري',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const GooglePlayIcon(size: 18),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'شارك تؤجر',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (s.showProgress) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.tr('الذكر ${_currentIndex + 1} من ${items.length}',
                            '${_currentIndex + 1} / ${items.length}')),
                        Text(s.tr('${(progress * 100).round()}% مكتمل',
                            '${(progress * 100).round()}% done')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  current.target == 1
                                      ? s.tr('مرة واحدة', 'Once')
                                      : s.tr('التكرار: ${current.target} مرات',
                                          'Repeat: ${current.target}x'),
                                  style: TextStyle(
                                      color: primary,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => _showShareMenu(current),
                                    icon: Icon(Icons.share_rounded, color: primary),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      current.favorite = !current.favorite;
                                      s.saveAllState();
                                      setState(() {});
                                    },
                                    icon: Icon(
                                      current.favorite
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: AppColors.skyBlue,
                                      size: 28,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                child: Text(
                                  current.text,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: s.azkarFontFamily,
                                    fontSize: 22 * s.fontScale,
                                    height: 2.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (s.showSource)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Text(
                                '📜 ${current.source}',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        s.playTapFeedback();
                        if (current.count < current.target) {
                          current.count += 1;
                          if (current.count == current.target) {
                            s.totalAzkarCompleted += 1;
                            final allDone = items.every((z) => z.count >= z.target);
                            s.recordDailyActivity(
                              completedCategory: allDone ? widget.category : null,
                            );
                            if (allDone) {
                              _showCompletionCelebration(current.categoryLabel);
                            } else {
                              _maybeShowRateDialog();
                            }
                          } else {
                            s.saveAllState();
                          }
                          setState(() {});
                          if (current.count >= current.target &&
                              s.autoNext &&
                              _currentIndex < items.length - 1) {
                            Future.delayed(const Duration(milliseconds: 300),
                                () {
                              if (mounted) {
                                setState(() => _currentIndex += 1);
                              }
                            });
                          }
                        } else if (_currentIndex < items.length - 1) {
                          setState(() => _currentIndex += 1);
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            current.count >= current.target
                                ? s.tr('اكتمل الذكر ✓ (اضغط للتالي)',
                                    'Completed ✓ (Next)')
                                : s.tr('تم الذكر (اضغط للعد)', 'Count Dhikr'),
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '${current.count} / ${current.target}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _currentIndex > 0
                              ? () => setState(() => _currentIndex -= 1)
                              : null,
                          child: Text(s.tr('→ الذكر السابق', '← Previous')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _currentIndex < items.length - 1
                              ? () => setState(() => _currentIndex += 1)
                              : null,
                          child: Text(s.tr('الذكر التالي ←', 'Next →')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}