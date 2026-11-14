import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/azkar_data.dart';
import 'services/notification_service.dart';
import 'widgets/google_play_icon.dart';

const String kAppDownloadLink =
    'https://play.google.com/store/apps/details?id=com.azkari.app';

// ============================================================================
// نقطة دخول النافذة العائمة (Overlay) للأذكار العشوائية (5 ثوانٍ + سحب + ضغطة للإخفاء)
// ============================================================================
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
    // تظهر لمدة 5 ثوانٍ فقط ثم تختفي تلقائيًا
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

// ============================================================================
// الهوية البصرية الجديدة: الأزرق الملكي واللبني السماوي
// ============================================================================
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
  try { await NotificationService.instance.init(); } catch (_) {}
}

class AzkariApp extends StatefulWidget {
  final SharedPreferences prefs;
  const AzkariApp({super.key, required this.prefs});

  @override
  State<AzkariApp> createState() => _AzkariAppState();
}

class _AzkariAppState extends State<AzkariApp> {
  late bool isDarkMode;
  late double fontScale;
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
  late List<ZikrItem> azkarList;
  Timer? _floatingTimer;

  @override
  void initState() {
    super.initState();
    final p = widget.prefs;
    isDarkMode = p.getBool('darkMode') ?? false;
    fontScale = p.getDouble('fontScale') ?? 1.0;
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
    tasbihPhrase = p.getString('tasbihPhrase') ?? 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ';
    azkarList = getInitialAzkarList();
    _restoreAzkarState();
    _syncReminders();
    _syncFloatingTimer();
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
    p.setDouble('fontScale', fontScale);
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
      title: 'أذكاري',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
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

// ============================================================================
// 1. شاشة البداية باللون الأزرق + تشغيل الصوت مرة يومياً
// ============================================================================
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
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
                              const Text(
                                'أذكاري',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '﴿وَاذْكُرْ رَبَّكَ إِذَا نَسِيتَ﴾',
                                textAlign: TextAlign.center,
                                style: TextStyle(
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

// ============================================================================
// الهيكل الرئيسي والتنقل السفلي
// ============================================================================
class MainShellScreen extends StatefulWidget {
  final _AzkariAppState appState;
  const MainShellScreen({super.key, required this.appState});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  String _searchQuery = '';
  bool _showSearch = false;

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
      _buildTasbihTab(context, cardColor, borderColor, primary, textSecondary),
      _buildFavoritesTab(context, cardColor, borderColor, primary, textSecondary),
      _buildSettingsTab(context, cardColor, borderColor, primary, textSecondary),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: cardColor,
        indicatorColor: primary.withOpacity(0.16),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.scatter_plot_rounded), label: 'السبحة'),
          NavigationDestination(icon: Icon(Icons.star_rounded), label: 'المفضلة'),
          NavigationDestination(
              icon: Icon(Icons.settings_rounded), label: 'الإعدادات'),
        ],
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, Color cardColor, Color borderColor,
      Color primary, Color textSecondary) {
    final s = widget.appState;
    final hour = DateTime.now().hour;
    final isMorning = hour >= 3 && hour < 15;
    final activeCategory = isMorning ? 'morning' : 'evening';
    final activeItems =
        s.azkarList.where((z) => z.category == activeCategory).toList();
    final activeDone = activeItems.where((z) => z.count >= z.target).length;
    final progress =
        activeItems.isEmpty ? 0.0 : activeDone / activeItems.length;

    final categories = [
      ('morning', '🌅', 'أذكار الصباح'),
      ('evening', '🌙', 'أذكار المساء'),
      ('sleep', '🛌', 'أذكار النوم'),
      ('wakeup', '☀️', 'أذكار الاستيقاظ'),
      ('prayer', '🕌', 'بعد الصلاة'),
      ('daily', '🏠', 'المنزل والسفر'),
      ('supplications', '🤲', 'الأدعية الجامعة'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMorning
                      ? '🌅 صباح السكينة والطمأنينة'
                      : '🌙 مساء السكينة والذكر الحكيم',
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  isMorning ? 'طاب صباحك بذكر الله' : 'طاب مساؤك بذكر الله',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            IconButton.filledTonal(
              onPressed: () => setState(() => _showSearch = !_showSearch),
              icon: const Icon(Icons.search_rounded),
            ),
          ],
        ),
        if (_showSearch) ...[
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'ابحث في الأذكار أو الأدعية أو المصدر...',
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
                    child: const Text(
                      'موصى به الآن',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '$activeDone من ${activeItems.length} مكتمل',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isMorning ? 'أذكار الصباح' : 'أذكار المساء',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'حصن يومك بالذكر؛ قراءة هادئة ومصادر صحيحة موثقة.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
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
                    child: const Text('ابدأ الآن ←',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
        const SizedBox(height: 20),
        const Text('أقسام الأذكار والأدعية',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.builder(
          itemCount: categories.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, idx) {
            final (catKey, emoji, label) = categories[idx];
            final items =
                s.azkarList.where((z) => z.category == catKey).toList();
            final done = items.where((z) => z.count >= z.target).length;
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _openCategoryReader(catKey),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 26)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('$done/${items.length} مكتمل',
                            style: TextStyle(fontSize: 12, color: textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
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
              const Text('السبحة الإلكترونية',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  s.tasbihCount = 0;
                  s.saveAllState();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تصفير'),
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
                  'الدورة الحالية (33): ${s.tasbihCount % 33 == 0 && s.tasbihCount > 0 ? 33 : s.tasbihCount % 33} / 33  •  الإجمالي: ${s.tasbihLifetime}',
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              s.tasbihCount += 1;
              s.tasbihLifetime += 1;
              s.saveAllState();
            },
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF0288D1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppColors.skyBlue, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📿', style: TextStyle(fontSize: 34)),
                  SizedBox(height: 6),
                  Text('سبّح',
                      style: TextStyle(
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
        const Text('المفضلة ⭐',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (favs.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: const Column(
              children: [
                Text('⭐', style: TextStyle(fontSize: 40)),
                SizedBox(height: 12),
                Text('لا توجد أذكار مفضلة بعد',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      style:
                          TextStyle(fontSize: 19 * s.fontScale, height: 1.9)),
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
        const Text('الإعدادات ⚙️',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                title: const Text('الوضع الليلي الهادئ'),
                subtitle: const Text('كحلي داكن مع لبني مريح للعين'),
                value: s.isDarkMode,
                onChanged: (v) {
                  s.isDarkMode = v;
                  s.saveAllState();
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('حجم خط الأذكار'),
                subtitle: Slider(
                  value: s.fontScale,
                  min: 0.85,
                  max: 1.40,
                  divisions: 4,
                  label: '${(s.fontScale * 100).round()}%',
                  onChanged: (v) {
                    s.fontScale = v;
                    s.saveAllState();
                  },
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('الانتقال التلقائي للذكر التالي'),
                value: s.autoNext,
                onChanged: (v) {
                  s.autoNext = v;
                  s.saveAllState();
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('تشغيل الصوت اليومي في البداية'),
                subtitle: const Text('﴿وَاذْكُرْ رَبَّكَ إِذَا نَسِيتَ﴾ مرة يوميًا'),
                value: s.dailyAudio,
                onChanged: (v) {
                  s.dailyAudio = v;
                  s.saveAllState();
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('الذكر العشوائي في الخلفية (5 ثوانٍ)'),
                subtitle: const Text('يظهر فوق الشاشة ويمكن سحبه أو إخفاؤه بضغطة'),
                value: s.floatingEnabled,
                onChanged: (v) async {
                  if (v) {
                    await s.showFloatingZikrNow();
                  }
                  s.floatingEnabled = v;
                  s.saveAllState();
                },
              ),
              ListTile(
                title: const Text('تجربة الذكر العائم الآن'),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => s.showFloatingZikrNow(),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('تذكير أذكار الصباح (06:00 ص)'),
                value: s.morningReminder,
                onChanged: (v) async {
                  await NotificationService.instance.requestPermissions();
                  s.morningReminder = v;
                  s.saveAllState();
                },
              ),
              SwitchListTile(
                title: const Text('تذكير أذكار المساء (05:00 م)'),
                value: s.eveningReminder,
                onChanged: (v) async {
                  await NotificationService.instance.requestPermissions();
                  s.eveningReminder = v;
                  s.saveAllState();
                },
              ),
              SwitchListTile(
                title: const Text('تذكير أذكار النوم (10:30 م)'),
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

// ============================================================================
// شاشة قراءة الأذكار + المشاركة النصية والمصورة (مع اللوجو و Google Play و شارك تؤجر)
// ============================================================================
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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

  void _showShareMenu(ZikrItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('مشاركة الذكر',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.image_rounded, color: AppColors.primaryBlue),
                title: const Text('مشاركة كصورة لحالة واتساب والمنصات'),
                subtitle: const Text('تصميم أزرق أنيق مع شعار التطبيق وعبارة شارك تؤجر'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareAsImage(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_fields_rounded, color: AppColors.midBlue),
                title: const Text('مشاركة كنص مع رابط التطبيق'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareAsText(item);
                },
              ),
            ],
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
            tooltip: 'مشاركة الذكر',
            onPressed: () => _showShareMenu(current),
            icon: const Icon(Icons.share_rounded),
          ),
          IconButton(
            tooltip: 'تصفير عداد القسم',
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
          // بطاقة مخفية عالية الدقة تُحوَّل لصورة عند مشاركة الحالة
          Positioned(
            left: -2000,
            top: 0,
            child: RepaintBoundary(
              key: _shareCardKey,
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(28),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF0288D1)],
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
                            style: const TextStyle(
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
                    // الشريط السفلي: اللوجو الصغير + أذكاري + أيقونة Google Play + شارك تؤجر
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

          // واجهة القراءة الفعلية
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (s.showProgress) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الذكر ${_currentIndex + 1} من ${items.length}'),
                        Text('${(progress * 100).round()}% مكتمل'),
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
                                      ? 'مرة واحدة'
                                      : 'التكرار: ${current.target} مرات',
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
                                '📜 المصدر: ${current.source}',
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
                        HapticFeedback.lightImpact();
                        if (current.count < current.target) {
                          current.count += 1;
                          s.saveAllState();
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
                                ? 'اكتمل الذكر ✓ (اضغط للتالي)'
                                : 'تم الذكر (اضغط للعد)',
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
                          child: const Text('→ الذكر السابق'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _currentIndex < items.length - 1
                              ? () => setState(() => _currentIndex += 1)
                              : null,
                          child: const Text('الذكر التالي ←'),
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
