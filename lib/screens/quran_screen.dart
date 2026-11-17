import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuranReciter {
  final String id;
  final String nameAr;
  final String nameEn;
  final String everyAyahFolder;
  final int quranComId;
  const QuranReciter(
      this.id, this.nameAr, this.nameEn, this.everyAyahFolder, this.quranComId);
}

const List<QuranReciter> kReciters = [
  QuranReciter('ar.ahmedajamy', 'أحمد العجمي', 'Ahmed Al-Ajamy', 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net', 0),
  QuranReciter('ar.saadalghamdi', 'سعد الغامدي', 'Saad Al-Ghamdi', 'Ghamadi_40kbps', 0),
  QuranReciter('ar.abdulbasitmurattal', 'عبد الباسط عبد الصمد', 'Abdul Basit', 'Abdul_Basit_Murattal_192kbps', 2),
  QuranReciter('ar.abdurrahmaansudais', 'عبد الرحمن السديس', 'Abdurrahman As-Sudais', 'Abdurrahmaan_As-Sudais_192kbps', 3),
  QuranReciter('ar.hudhaify', 'علي الحذيفي', 'Ali Al-Hudhaify', 'Hudhaify_128kbps', 0),
  QuranReciter('ar.alijaber', 'علي جابر', 'Ali Jaber', 'Ali_Jaber_64kbps', 0),
  QuranReciter('ar.mahermuaiqly', 'ماهر المعيقلي', 'Maher Al-Muaiqly', 'MaherAlMuaiqly128kbps', 10),
  QuranReciter('ar.minshawi', 'محمد صديق المنشاوي', 'Muhammad Al-Minshawi', 'Minshawy_Murattal_128kbps', 9),
  QuranReciter('ar.husary', 'محمود خليل الحصري', 'Mahmoud Al-Husary', 'Husary_128kbps', 6),
  QuranReciter('ar.mahmoudbanna', 'محمود علي البنا', 'Mahmoud Ali Al-Banna', 'mahmoud_ali_al_banna_32kbps', 0),
  QuranReciter('ar.alafasy', 'مشاري راشد العفاسي', 'Mishary Alafasy', 'Alafasy_128kbps', 7),
  QuranReciter('ar.nasseralqatami', 'ناصر القطامي', 'Nasser Al-Qatami', 'Nasser_Alqatami_128kbps', 0),
  QuranReciter('ar.yasseraldossari', 'ياسر الدوسري', 'Yasser Al-Dosari', 'Yasser_Ad-Dussary_128kbps', 0),
];


String transliterateQuranWord(String rawWord, {bool turkish = false}) {
  // Strip Quranic stop/waqf symbols
  final w = rawWord
      .replaceAll(RegExp(r'[\u06D6-\u06ED\u0640]'), '')
      .trim();
  if (w.isEmpty) return '';

  final bare = w
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll('ٱ', 'ا');

  // Exact common Quranic words for natural reading
  const exactCommon = {
    'بسم': 'bism',
    'الله': 'Allahi',
    'لله': 'lillahi',
    'الرحمن': 'ar-Rahmani',
    'الرحيم': 'ar-Rahimi',
    'الحمد': 'al-hamdu',
    'رب': 'Rabbi',
    'العالمين': 'al-alamin',
    'مالك': 'Maliki',
    'ملك': 'Maliki',
    'يوم': 'yawmi',
    'الدين': 'ad-din',
    'اياك': 'iyyaka',
    'نعبد': 'na’budu',
    'نستعين': 'nasta’in',
    'اهدنا': 'ihdina',
    'الصراط': 'as-sirata',
    'المستقيم': 'al-mustaqim',
    'صراط': 'sirata',
    'الذين': 'alladhina',
    'انعمت': 'an’amta',
    'عليهم': 'alayhim',
    'غير': 'ghayri',
    'المغضوب': 'al-maghdubi',
    'ولا': 'wa la',
    'الضالين': 'ad-dallin',
    'الم': 'Alif-Lam-Mim',
    'قل': 'qul',
    'هو': 'Huwa',
    'احد': 'Ahad',
    'الصمد': 'as-Samad',
  };
  if (exactCommon.containsKey(bare)) {
    final res = exactCommon[bare]!;
    if (turkish) {
      return res
          .replaceAll('dh', 'z')
          .replaceAll('sh', 'ş')
          .replaceAll('gh', 'ğ')
          .replaceAll('th', 's')
          .replaceAll('wa la', 've la')
          .replaceAll('al-', 'el-').replaceAll('an’amta', 'en’amte');
    }
    return res;
  }

  final Map<String, String> cons = turkish
      ? const {
          'ب': 'b', 'ت': 't', 'ث': 's', 'ج': 'c', 'ح': 'h', 'خ': 'h',
          'د': 'd', 'ذ': 'z', 'ر': 'r', 'ز': 'z', 'س': 's', 'ش': 'ş',
          'ص': 's', 'ض': 'd', 'ط': 't', 'ظ': 'z', 'ع': 'a', 'غ': 'ğ',
          'ف': 'f', 'ق': 'k', 'ك': 'k', 'ل': 'l', 'م': 'm', 'ن': 'n',
          'ه': 'h', 'ة': 'h', 'و': 'v', 'ي': 'y', 'ى': 'a', 'ء': '’',
          'أ': 'e', 'إ': 'i', 'آ': 'a', 'ا': 'a', 'ٱ': 'a', 'ؤ': 'u', 'ئ': 'y',
        }
      : const {
          'ب': 'b', 'ت': 't', 'ث': 'th', 'ج': 'j', 'ح': 'h', 'خ': 'kh',
          'د': 'd', 'ذ': 'dh', 'ر': 'r', 'ز': 'z', 'س': 's', 'ش': 'sh',
          'ص': 's', 'ض': 'd', 'ط': 't', 'ظ': 'z', 'ع': 'a', 'غ': 'gh',
          'ف': 'f', 'ق': 'q', 'ك': 'k', 'ل': 'l', 'م': 'm', 'ن': 'n',
          'ه': 'h', 'ة': 'h', 'و': 'w', 'ي': 'y', 'ى': 'a', 'ء': '’',
          'أ': 'a', 'إ': 'i', 'آ': 'aa', 'ا': 'a', 'ٱ': 'a', 'ؤ': 'u', 'ئ': 'y',
        };

  final runes = w.runes.toList();
  final buf = StringBuffer();
  for (int i = 0; i < runes.length; i++) {
    final ch = String.fromCharCode(runes[i]);
    if (ch == 'َ') {
      buf.write('a');
    } else if (ch == 'ِ') {
      buf.write('i');
    } else if (ch == 'ُ') {
      buf.write('u');
    } else if (ch == 'ً') {
      buf.write('an');
    } else if (ch == 'ٍ') {
      buf.write('in');
    } else if (ch == 'ٌ') {
      buf.write('un');
    } else if (ch == 'ٰ') {
      buf.write('a');
    } else if (ch == 'ْ' || ch == 'ّ') {
      // sukun / shadda handled softly
    } else if (cons.containsKey(ch)) {
      buf.write(cons[ch]);
    }
  }
  final out = buf.toString();
  return out.isEmpty ? bare : out;
}

String stripLeadingBasmala(int surahNumber, int ayahIndex, String text) {
  if (surahNumber == 1 || surahNumber == 9 || ayahIndex != 0) return text;
  final words = text.trim().split(RegExp(r'\s+'));
  if (words.length <= 4) return text;
  String norm(String w) => w
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
      .replaceAll('ٱ', 'ا');
  if (norm(words[0]) == 'بسم' &&
      norm(words[1]) == 'الله' &&
      (norm(words[2]) == 'الرحمن' || norm(words[2]) == 'الرحمان') &&
      norm(words[3]) == 'الرحيم') {
    return words.sublist(4).join(' ').trim();
  }
  return text;
}

const List<(String, String)> kQuranFonts = [
  ('AmiriQuran', 'عثماني (أميري)'),
  ('Lateef', 'خط لطيف'),
  ('Scheherazade', 'خط شهرزاد'),
  ('NotoKufi', 'نوتو كوفي'),
];

String fontLabelForLang(String id, String lang) {
  const enMap = {
    'AmiriQuran': 'Uthmani (Amiri)',
    'Lateef': 'Lateef Font',
    'Scheherazade': 'Scheherazade',
    'NotoKufi': 'Noto Kufi',
  };
  const trMap = {
    'AmiriQuran': 'Osmani (Amiri)',
    'Lateef': 'Latif Hat',
    'Scheherazade': 'Şehrazat Hat',
    'NotoKufi': 'Noto Kufi',
  };
  if (lang == 'tr') return trMap[id] ?? id;
  if (lang == 'en') return enMap[id] ?? id;
  return kQuranFonts.firstWhere((f) => f.$1 == id, orElse: () => kQuranFonts.first).$2;
}

String normalizeLatinForSearch(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r"[\s\-'’`.,_]"), '')
      .replaceAll('aa', 'a')
      .replaceAll('ee', 'i')
      .replaceAll('ii', 'i')
      .replaceAll('oo', 'u')
      .replaceAll('uu', 'u');
}

String normalizeArabicForSearch(String input) {
  return input
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ٱ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .trim()
      .toLowerCase();
}

class QuranDataRepository {
  static List<dynamic>? _surahs;
  static List<dynamic>? _tafsirSurahs;

  static Future<void> ensureLoaded() async {
    if (_surahs != null && _tafsirSurahs != null) return;
    final qStr = await rootBundle.loadString('assets/data/quran_uthmani.json');
    final tStr = await rootBundle.loadString('assets/data/tafsir_muyassar.json');
    final qJson = jsonDecode(qStr) as Map<String, dynamic>;
    final tJson = jsonDecode(tStr) as Map<String, dynamic>;
    _surahs = qJson['data']['surahs'] as List<dynamic>;
    _tafsirSurahs = tJson['data']['surahs'] as List<dynamic>;
  }

  static List<dynamic> get surahs => _surahs ?? [];
  static List<dynamic> get tafsirSurahs => _tafsirSurahs ?? [];
}

class QuranAudioManager {
  static final QuranAudioManager instance = QuranAudioManager._();
  QuranAudioManager._();

  final AudioPlayer player = AudioPlayer();
  int? currentSurahNumber;
  String? currentReciterId;
  String currentSurahName = '';
  String currentSurahNameEn = '';
  String currentReciterName = '';
  String currentReciterNameEn = '';
  final Map<String, String> translationsCache = {};
  Uri? cachedArtUri;
  int? playingAyahIndex;
  int playStartAyahIndex = 0;
  double ayahProgress = 0.0;
  int currentPositionMs = 0;
  // Map<"surah:ayah", List<[wordPos, startMs, endMs]>>
  final Map<String, List<List<int>>> wordSegments = {};
  final Map<String, String> exactAudioUrls = {};
}

class QuranHomeScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final bool isDarkMode;
  final bool isEnglish;
  final String appLang;
  final double fontScale;
  final VoidCallback? onSurahCompleted;

  const QuranHomeScreen({
    super.key,
    required this.prefs,
    required this.isDarkMode,
    required this.isEnglish,
    this.appLang = 'ar',
    required this.fontScale,
    this.onSurahCompleted,
  });

  @override
  State<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

class _QuranHomeScreenState extends State<QuranHomeScreen> {
  bool _loading = true;
  String _search = '';
  bool _downloadingAll = false;
  int _downloadDoneCount = 0;

  String tr(String ar, String en, [String? trText]) {
    if (widget.appLang == 'tr') return trText ?? _kQuranEnToTr[en] ?? en;
    if (widget.appLang == 'en' || widget.isEnglish) return en;
    return ar;
  }

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      await QuranDataRepository.ensureLoaded();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _downloadAllSurahsForReciter() async {
    if (_downloadingAll) return;
    final reciterId = widget.prefs.getString('quranReciterId') ?? 'ar.hudhaify';
    setState(() {
      _downloadingAll = true;
      _downloadDoneCount = 0;
    });
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/quran_audio/$reciterId');
    if (!await folder.exists()) await folder.create(recursive: true);

    for (int s = 1; s <= 114; s++) {
      if (!_downloadingAll || !mounted) break;
      final f = File('${folder.path}/surah_$s.mp3');
      if (!await f.exists()) {
        try {
          final url =
              'https://cdn.islamic.network/quran/audio-surah/128/$reciterId/$s.mp3';
          final res =
              await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
          if (res.statusCode == 200) {
            await f.writeAsBytes(res.bodyBytes);
          }
        } catch (_) {}
      }
      if (mounted) setState(() => _downloadDoneCount = s);
    }
    if (mounted) setState(() => _downloadingAll = false);
  }

  List<Map<String, dynamic>> _buildJuzSummary() {
    final Map<int, Set<int>> juzSurahs = {};
    final Map<int, Set<int>> juzHizbs = {};
    final Map<int, (int, int)> juzFirstAyah = {};

    for (final s in QuranDataRepository.surahs) {
      final sNum = s['number'] as int;
      final ayahs = s['ayahs'] as List<dynamic>;
      for (final a in ayahs) {
        final juz = a['juz'] as int;
        final hizbQuarter = a['hizbQuarter'] as int? ?? 1;
        final hizb = ((hizbQuarter - 1) ~/ 4) + 1;
        juzSurahs.putIfAbsent(juz, () => {}).add(sNum);
        juzHizbs.putIfAbsent(juz, () => {}).add(hizb);
        juzFirstAyah.putIfAbsent(juz, () => (sNum, a['numberInSurah'] as int));
      }
    }

    return List.generate(30, (i) {
      final j = i + 1;
      return {
        'juz': j,
        'surahCount': juzSurahs[j]?.length ?? 0,
        'hizbCount': juzHizbs[j]?.length ?? 2,
        'firstSurah': juzFirstAyah[j]?.$1 ?? 1,
        'firstAyah': juzFirstAyah[j]?.$2 ?? 1,
      };
    });
  }

  void _openSurah(int surahNumber, {int? jumpToAyah}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahReaderScreen(
          initialSurahNumber: surahNumber,
          prefs: widget.prefs,
          isDarkMode: widget.isDarkMode,
          isEnglish: widget.isEnglish,
          appLang: widget.appLang,
          initialFontScale: widget.fontScale,
          jumpToAyah: jumpToAyah,
          onSurahCompleted: widget.onSurahCompleted,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final lastSurah = widget.prefs.getInt('lastQuranSurah');
    final lastAyah = widget.prefs.getInt('lastQuranAyah');
    final lastName = widget.prefs.getString('lastQuranSurahName') ?? '';
    final bookmarkedSurahs =
        widget.prefs.getStringList('bookmarkedSurahs') ?? [];

    final normQuery = normalizeArabicForSearch(_search);
    final normLat = normalizeLatinForSearch(_search);
    final surahs = QuranDataRepository.surahs.where((s) {
      if (_search.trim().isEmpty) return true;
      final name = normalizeArabicForSearch((s['name'] ?? '').toString());
      final en = normalizeLatinForSearch((s['englishName'] ?? '').toString());
      final enTr = normalizeLatinForSearch((s['englishNameTranslation'] ?? '').toString());
      return (normQuery.isNotEmpty && name.contains(normQuery)) ||
          (normLat.isNotEmpty && (en.contains(normLat) || enTr.contains(normLat))) ||
          s['number'].toString() == _search.trim();
    }).toList();

    final juzList = _loading ? <Map<String, dynamic>>[] : _buildJuzSummary();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('القرآن الكريم (بدون نت)', 'Noble Quran (Offline)', 'Kur’an-ı Kerim (Çevrimdışı)')),
          actions: [
          IconButton(
            tooltip: tr('الانتقال للعلامة المرجعية', 'Go to Bookmark'),
            onPressed: () {
              final bSurah = widget.prefs.getInt('lastQuranSurah');
              final bAyah = widget.prefs.getInt('lastQuranAyah');
              if (bSurah == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tr('لا توجد علامة مرجعية محفوظة بعد', 'No bookmark saved yet')),
                  ),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SurahReaderScreen(
                    prefs: widget.prefs,
                    initialSurahNumber: bSurah,
                    isEnglish: widget.isEnglish,
                    appLang: widget.appLang,
                    isDarkMode: widget.isDarkMode,
                    initialFontScale: widget.fontScale,
                    jumpToAyah: bAyah,
                    onSurahCompleted: widget.onSurahCompleted,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.bookmark_rounded, color: Colors.amber),
          ),

            IconButton(
              tooltip: tr('تحميل التلاوات بدون نت', 'Download Audio Offline'),
              onPressed: _downloadingAll
                  ? () => setState(() => _downloadingAll = false)
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: Text(tr('تحميل القرآن كاملاً', 'Download Full Quran Audio', 'Tüm Kur’an Seslerini İndir')),
                          content: Text(tr(
                            'سيتم تحميل التلاوات للاستماع بدون إنترنت.\nالحجم التقريبي للمصحف كاملاً: ~750 ميجابايت (يمكنك الإيقاف في أي وقت).',
                            'Audio files will be saved for offline listening.\nEstimated total size: ~750 MB (you can stop anytime).',
                            'Sesler çevrimdışı dinleme için indirilecek.\nTahmini toplam boyut: ~750 MB (istediğiniz zaman durdurabilirsiniz).',
                          )),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: Text(tr('إلغاء', 'Cancel', 'İptal')),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: Text(tr('بدء التحميل', 'Start Download', 'İndirmeyi Başlat')),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) _downloadAllSurahsForReciter();
                    },
              icon: Icon(
                _downloadingAll
                    ? Icons.stop_circle_rounded
                    : Icons.cloud_download_rounded,
              ),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: tr('السور (114)', 'Surahs (114)', 'Sureler (114)')),
              Tab(text: tr('الأجزاء (30)', 'Juz (30)', 'Cüzler (30)')),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_downloadingAll)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _downloadDoneCount / 114.0,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr('جاري تحميل السور للاستماع بدون نت: $_downloadDoneCount / 114',
                                'Downloading Surahs offline: $_downloadDoneCount / 114'),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  if (lastSurah != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () =>
                            _openSurah(lastSurah, jumpToAyah: lastAyah),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0D47A1), Color(0xFF0288D1)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.bookmark_rounded,
                                  color: Colors.amber),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tr(
                                    'متابعة العلامة المرجعية: $lastName (آية ${lastAyah ?? 1})',
                                    'Resume Bookmark: $lastName (Ayah ${lastAyah ?? 1})',
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  color: Colors.white70, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: TextField(
                                onChanged: (v) => setState(() => _search = v),
                                decoration: InputDecoration(
                                  hintText: tr('ابحث باسم السورة (بدون تشكيل)...', 'Search Surah...', 'Sure ara...'),
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                itemCount: surahs.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final s = surahs[i];
                                  final num = s['number'] as int;
                                  final ayahs =
                                      (s['ayahs'] as List<dynamic>).length;
                                  final revType = s['revelationType'] == 'Meccan'
                                      ? tr('مكية', 'Meccan', 'Mekki')
                                      : tr('مدنية', 'Medinan', 'Medeni');
                                  final isBookmarked = bookmarkedSurahs
                                      .contains(num.toString());
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF0D47A1)
                                          .withOpacity(0.18),
                                      child: Text('$num',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    title: Text(
                                      s['name'] ?? '',
                                      style: const TextStyle(
                                        fontFamily: 'AmiriQuran',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 19,
                                      ),
                                    ),
                                    subtitle: Text(
                                      widget.appLang != 'ar'
                                          ? '${s['englishName'] ?? ''} • $revType • $ayahs ${tr("آية", "Ayahs", "Ayet")}'
                                          : '$revType • $ayahs ${tr("آية", "Ayahs", "Ayet")}',
                                    ),
                                    trailing: Icon(
                                      isBookmarked
                                          ? Icons.bookmark_rounded
                                          : Icons.arrow_forward_ios_rounded,
                                      color: isBookmarked
                                          ? Colors.amber
                                          : Colors.grey,
                                      size: isBookmarked ? 24 : 16,
                                    ),
                                    onTap: () => _openSurah(num),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: juzList.length,
                          itemBuilder: (ctx, i) {
                            final j = juzList[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      const Color(0xFF0288D1).withOpacity(0.2),
                                  child: Text('${j['juz']}'),
                                ),
                                title: Text(
                                  tr('الجزء ${j['juz']}', 'Juz ${j['juz']}'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Text(
                                  tr(
                                    'عدد السور: ${j['surahCount']} • الأحزاب: ${j['hizbCount']}',
                                    'Surahs: ${j['surahCount']} • Hizbs: ${j['hizbCount']}',
                                  ),
                                ),
                                trailing: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16),
                                onTap: () => _openSurah(
                                  j['firstSurah'] as int,
                                  jumpToAyah: j['firstAyah'] as int,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class SurahReaderScreen extends StatefulWidget {
  final int initialSurahNumber;
  final SharedPreferences prefs;
  final bool isDarkMode;
  final bool isEnglish;
  final String appLang;
  final double initialFontScale;
  final int? jumpToAyah;
  final VoidCallback? onSurahCompleted;

  const SurahReaderScreen({
    super.key,
    required this.initialSurahNumber,
    required this.prefs,
    required this.isDarkMode,
    required this.isEnglish,
    this.appLang = 'ar',
    required this.initialFontScale,
    this.jumpToAyah,
    this.onSurahCompleted,
  });

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  late int _surahNumber;
  late double _fontScale;
  late String _fontFamily;
  late bool _tajweedColors;
  late String _reciterId;
  bool _focusDimMode = false;

  AudioPlayer get _player => QuranAudioManager.instance.player;
  bool _isPlaying = false;
  bool _showTranslitBar = false;
  int _syncOffsetMs = 0;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _translitScrollCtrl = ScrollController();
  bool _showSurahTip = false;
  int? get _playingAyahIndex => QuranAudioManager.instance.playingAyahIndex;
  set _playingAyahIndex(int? v) => QuranAudioManager.instance.playingAyahIndex = v;
  int get _playStartAyahIndex => QuranAudioManager.instance.playStartAyahIndex;
  set _playStartAyahIndex(int v) => QuranAudioManager.instance.playStartAyahIndex = v;
  double get _ayahProgress => QuranAudioManager.instance.ayahProgress;
  set _ayahProgress(double v) => QuranAudioManager.instance.ayahProgress = v;
  int? _flashAyahNum;
  bool _flashVisible = false;
  Timer? _flashTimer;
  final Map<int, GlobalKey> _ayahKeys = {};
  StreamSubscription<int?>? _idxSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;
  bool _isDownloadingAudio = false;
  bool _audioOfflineReady = false;
  bool _repeatSurah = false;
  bool _autoNextSurah = true;
  double _speed = 1.0;

  Timer? _sleepTimer;
  int _sleepSecondsRemaining = 0;
  bool _stopAfterSurah = false;

  String tr(String ar, String en, [String? trText]) {
    if (widget.appLang == 'tr') return trText ?? _kQuranEnToTr[en] ?? en;
    if (widget.appLang == 'en' || widget.isEnglish) return en;
    return ar;
  }

  @override
  void initState() {
    super.initState();
    _surahNumber = widget.initialSurahNumber;
    _fontScale = widget.initialFontScale;
    _fontFamily = widget.prefs.getString('quranFontFamily') ?? 'AmiriQuran';
    _tajweedColors = widget.prefs.getBool('quranTajweedColors') ?? true;
    _reciterId = widget.prefs.getString('quranReciterId') ?? 'ar.hudhaify';
    _syncOffsetMs = widget.prefs.getInt('quranSyncOffsetMs') ?? 0;
    _showSurahTip = !(widget.prefs.getBool('seenSurahTip') ?? false);
    _isPlaying = _player.playing;
    _ensureMediaArtUri();
    _checkAudioCache();
    if (widget.jumpToAyah != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToAyahNumber(widget.jumpToAyah!);
      });
    }

    _idxSub = _player.currentIndexStream.listen((idx) {
      if (!mounted || idx == null) return;
      if (QuranAudioManager.instance.currentSurahNumber != _surahNumber) return;
      final targetIdx = _playStartAyahIndex + idx;
      if (targetIdx >= 0 && targetIdx < _ayahs.length) {
        setState(() {
          _playingAyahIndex = targetIdx;
          _ayahProgress = 0.0;
          QuranAudioManager.instance.currentPositionMs = 0;
        });
        final numInSurah = (_ayahs[targetIdx]['numberInSurah'] as int?) ?? (targetIdx + 1);
        _scrollToAyahNumber(numInSurah, flash: false);
      }
    });

    _posSub = _player.positionStream.listen((pos) {
      if (!mounted || !_isPlaying) return;
      if (QuranAudioManager.instance.currentSurahNumber != _surahNumber) return;
      QuranAudioManager.instance.currentPositionMs = pos.inMilliseconds;
      final dur = _player.duration;
      if (dur != null && dur.inMilliseconds > 0) {
        final p = (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
        setState(() => _ayahProgress = p);
      }
    });

    _stateSub = _player.playerStateStream.listen((state) async {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
        if (state.processingState == ProcessingState.idle) {
          _playingAyahIndex = null;
          _ayahProgress = 0.0;
        }
      });
      if (state.processingState == ProcessingState.completed) {
        widget.onSurahCompleted?.call();
        if (_stopAfterSurah) {
          _cancelSleepTimer();
          return;
        }
        if (_repeatSurah) {
          await _player.seek(Duration.zero);
          await _player.play();
        } else if (_autoNextSurah && _surahNumber < 114) {
          setState(() => _surahNumber += 1);
          await _checkAudioCache();
          await _playFullSurah();
        }
      }
    });
  }

  void _triggerAyahFlash(int ayahNum) {
    _flashTimer?.cancel();
    int ticks = 0;
    setState(() {
      _flashAyahNum = ayahNum;
      _flashVisible = true;
    });
    _flashTimer = Timer.periodic(const Duration(milliseconds: 220), (t) {
      ticks++;
      if (!mounted || ticks >= 5) {
        t.cancel();
        if (mounted) {
          setState(() {
            _flashAyahNum = null;
            _flashVisible = false;
          });
        }
        return;
      }
      setState(() => _flashVisible = !_flashVisible);
    });
  }

  void _scrollToAyahNumber(int ayahNum, {bool flash = true}) {
    final idx = _ayahs.indexWhere((a) => a['numberInSurah'] == ayahNum);
    if (idx < 0) return;
    if (flash) _triggerAyahFlash(ayahNum);

    final key = _ayahKeys[ayahNum];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.5,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
      );
      return;
    }

    if (!_scrollController.hasClients) return;
    final viewport = _scrollController.position.viewportDimension;
    final targetOffset = ((idx * 140.0) - (viewport / 2) + 70.0)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
    ).then((_) {
      if (mounted && _ayahKeys[ayahNum]?.currentContext != null) {
        Scrollable.ensureVisible(
          _ayahKeys[ayahNum]!.currentContext!,
          alignment: 0.5,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Map<String, dynamic> get _currentSurah =>
      QuranDataRepository.surahs[_surahNumber - 1] as Map<String, dynamic>;

  Map<String, dynamic> get _currentTafsirSurah =>
      QuranDataRepository.tafsirSurahs[_surahNumber - 1] as Map<String, dynamic>;

  List<dynamic> get _ayahs => _currentSurah['ayahs'] as List<dynamic>;
  List<dynamic> get _tafsirAyahs =>
      _currentTafsirSurah['ayahs'] as List<dynamic>;

  Future<String> _audioFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/quran_audio/$_reciterId');
    if (!await folder.exists()) await folder.create(recursive: true);
    return '${folder.path}/surah_$_surahNumber.mp3';
  }

  Future<void> _checkAudioCache() async {
    final path = await _audioFilePath();
    final exists = await File(path).exists();
    if (mounted) setState(() => _audioOfflineReady = exists);
  }

  QuranReciter get _currentReciter => kReciters.firstWhere(
        (r) => r.id == _reciterId,
        orElse: () => kReciters.first,
      );

  String _ayahAudioUrl(int ayahNumInSurah) {
    final sStr = _surahNumber.toString().padLeft(3, '0');
    final aStr = ayahNumInSurah.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/${_currentReciter.everyAyahFolder}/$sStr$aStr.mp3';
  }

  String get _surahAudioUrl =>
      'https://cdn.islamic.network/quran/audio-surah/128/$_reciterId/$_surahNumber.mp3';

  Future<void> _ensureMediaArtUri() async {
    if (QuranAudioManager.instance.cachedArtUri != null) return;
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/azkari_media_art.png');
      if (!await f.exists()) {
        final data = await rootBundle.load('assets/images/app_icon.png');
        await f.writeAsBytes(data.buffer.asUint8List());
      }
      QuranAudioManager.instance.cachedArtUri = Uri.file(f.path);
    } catch (_) {}
  }

  MediaItem _surahMediaItem({int? ayahNum}) {
    final surahName = (_currentSurah['name'] ?? '').toString();
    final reciterName = kReciters
        .firstWhere((r) => r.id == _reciterId, orElse: () => kReciters.first)
        .nameAr;
    final titleStr = ayahNum != null ? '$surahName • الآية $ayahNum' : surahName;
    return MediaItem(
      id: 'surah_${_reciterId}_${_surahNumber}_${ayahNum ?? 0}',
      album: 'أذكاري • القرآن الكريم',
      title: titleStr,
      artist: reciterName,
      artUri: QuranAudioManager.instance.cachedArtUri,
    );
  }

  Future<void> _playFullSurah() async {
    try {
      final localPath = await _audioFilePath();
      if (await File(localPath).exists()) {
        await _player.setVolume(1.0);
        await _player.setSpeed(_speed);
        _playStartAyahIndex = 0;
        _playingAyahIndex = 0;
        await _player.setAudioSource(
            AudioSource.file(localPath, tag: _surahMediaItem()));
        await _player.play();
        return;
      }
      await _playFromAyah(0);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('تعذر تشغيل التلاوة، تأكد من الإنترنت أو حمّل السورة', 'Audio failed'))),
        );
      }
    }
  }

  Future<void> _fetchWordTimingsIfNeeded() async {
    final recId = _currentReciter.quranComId;
    if (recId <= 0) return;
    final keyPrefix = '$_surahNumber:1';
    if (QuranAudioManager.instance.wordSegments.containsKey('${recId}_$keyPrefix')) {
      return;
    }
    try {
      final url =
          'https://api.quran.com/api/v4/recitations/$recId/by_chapter/$_surahNumber?per_page=300';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final files = (data['audio_files'] as List<dynamic>?) ?? [];
        for (final f in files) {
          final vKey = (f['verse_key'] ?? '').toString();
          final segs = (f['segments'] as List<dynamic>?) ?? [];
          final parsed = <List<int>>[];
          for (final seg in segs) {
            if (seg is List && seg.length >= 3) {
              parsed.add([
                (seg[0] as num).toInt(),
                (seg[1] as num).toInt(),
                (seg[2] as num).toInt(),
              ]);
            }
          }
          final rawUrl = (f['url'] ?? '').toString();
          if (vKey.isNotEmpty && parsed.isNotEmpty) {
            QuranAudioManager.instance.wordSegments['${recId}_$vKey'] = parsed;
            if (rawUrl.isNotEmpty) {
              QuranAudioManager.instance.exactAudioUrls['${recId}_$vKey'] =
                  rawUrl.startsWith('http')
                      ? rawUrl
                      : 'https://verses.quran.com/$rawUrl';
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _playSingleAyah(int ayahIndex, {bool repeat = false}) async {
    try {
      await _fetchWordTimingsIfNeeded();
      await _player.stop();
      await _player.setVolume(1.0);
      await _player.setSpeed(_speed);
      await _player.setLoopMode(repeat ? LoopMode.one : LoopMode.off);
      QuranAudioManager.instance.currentSurahNumber = _surahNumber;
      QuranAudioManager.instance.currentReciterId = _reciterId;
      QuranAudioManager.instance.currentSurahName = (_currentSurah['name'] ?? '').toString();
      QuranAudioManager.instance.currentSurahNameEn = (_currentSurah['englishName'] ?? '').toString();
      QuranAudioManager.instance.currentReciterName = _currentReciter.nameAr;
      QuranAudioManager.instance.currentReciterNameEn = _currentReciter.nameEn;
      _playStartAyahIndex = ayahIndex;
      setState(() {
        _playingAyahIndex = ayahIndex;
        _ayahProgress = 0.0;
        QuranAudioManager.instance.currentPositionMs = 0;
      });
      final numInSurah = (_ayahs[ayahIndex]['numberInSurah'] as int?) ?? (ayahIndex + 1);
      final exactUrl = QuranAudioManager.instance.exactAudioUrls[
          '${_currentReciter.quranComId}_$_surahNumber:$numInSurah'];
      final url = exactUrl ?? _ayahAudioUrl(numInSurah);
      await _player.setAudioSource(
          AudioSource.uri(Uri.parse(url), tag: _surahMediaItem(ayahNum: numInSurah)));
      await _player.play();
    } catch (_) {}
  }

  Future<void> _playFromAyah(int startIndex) async {
    try {
      await _fetchWordTimingsIfNeeded();
      await _player.stop();
      await _player.setVolume(1.0);
      await _player.setSpeed(_speed);
      await _player.setLoopMode(LoopMode.off);
      QuranAudioManager.instance.currentSurahNumber = _surahNumber;
      QuranAudioManager.instance.currentReciterId = _reciterId;
      QuranAudioManager.instance.currentSurahName = (_currentSurah['name'] ?? '').toString();
      QuranAudioManager.instance.currentSurahNameEn = (_currentSurah['englishName'] ?? '').toString();
      QuranAudioManager.instance.currentReciterName = _currentReciter.nameAr;
      QuranAudioManager.instance.currentReciterNameEn = _currentReciter.nameEn;
      _playStartAyahIndex = startIndex;
      setState(() {
        _playingAyahIndex = startIndex;
        _ayahProgress = 0.0;
        QuranAudioManager.instance.currentPositionMs = 0;
      });
      final sources = _ayahs.sublist(startIndex).map((a) {
        final numInSurah = a['numberInSurah'] as int;
        final exactUrl = QuranAudioManager.instance.exactAudioUrls[
            '${_currentReciter.quranComId}_$_surahNumber:$numInSurah'];
        return AudioSource.uri(
          Uri.parse(exactUrl ?? _ayahAudioUrl(numInSurah)),
          tag: _surahMediaItem(ayahNum: numInSurah),
        );
      }).toList();
      await _player.setAudioSource(ConcatenatingAudioSource(children: sources));
      await _player.play();
    } catch (_) {}
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _player.pause();
    } else if (_player.audioSource != null &&
        QuranAudioManager.instance.currentSurahNumber == _surahNumber &&
        QuranAudioManager.instance.currentReciterId == _reciterId &&
        _player.processingState != ProcessingState.completed &&
        _player.processingState != ProcessingState.idle) {
      await _player.play();
    } else {
      await _player.setLoopMode(LoopMode.off);
      await _playFullSurah();
    }
  }

  Future<void> _downloadSurahAudio() async {
    if (_isDownloadingAudio) return;
    setState(() => _isDownloadingAudio = true);
    try {
      final res = await http
          .get(Uri.parse(_surahAudioUrl))
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        final path = await _audioFilePath();
        await File(path).writeAsBytes(res.bodyBytes);
        if (mounted) {
          setState(() => _audioOfflineReady = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('تم حفظ السورة للاستماع بدون نت ',
                  'Surah audio saved offline ')),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('فشل التحميل', 'Download failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingAudio = false);
    }
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _flashTimer?.cancel();
    _idxSub?.cancel();
    _posSub?.cancel();
    _stateSub?.cancel();
    _scrollController.dispose();
    _translitScrollCtrl.dispose();
    setState(() {
      _sleepSecondsRemaining = 0;
      _stopAfterSurah = false;
    });
  }

  void _startSleepTimerSeconds(int totalSeconds) {
    _cancelSleepTimer();
    setState(() => _sleepSecondsRemaining = totalSeconds);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_sleepSecondsRemaining <= 1) {
        t.cancel();
        await _player.pause();
        await _player.setVolume(1.0);
        if (mounted) setState(() => _sleepSecondsRemaining = 0);
      } else {
        setState(() => _sleepSecondsRemaining -= 1);
        if (_sleepSecondsRemaining <= 30) {
          await _player.setVolume(max(0.05, _sleepSecondsRemaining / 30.0));
        }
      }
    });
  }

  void _openTajweedGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('دليل الألوان والتجويد والتشكيل', 'Tajweed & Tashkeel Guide'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                _guideRow(const Color(0xFF38BDF8), tr('الأزرق السماوي: علامات المدّ، الألف الخنجرية، وهمزة الوصل (ٓ ٰ ٱ)', 'Sky Blue: Madd, dagger Alif & Wasl')),
                _guideRow(const Color(0xFFF59E0B), tr('الذهبي / البرتقالي: الشدّة ومواضع التشديد والغنة (ّ)', 'Amber: Shaddah & emphasis')),
                _guideRow(const Color(0xFF10B981), tr('الأخضر: علامات الوقف والوصل القرآنية (ۖ ۗ ۚ ۛ ۙ)', 'Green: Quranic pause & stop marks')),
                const Divider(height: 22),
                Text(
                  tr('معاني التشكيل وعلامات المصحف:', 'Tashkeel & Marks:'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(tr(
                  '• الفتحة (ـَ) والضمة (ـُ) والكسرة (ـِ): حركات النطق الأساسية.\n'
                  '• السكون (ـْ): خلو الحرف من الحركة.\n'
                  '• التنوين (ـً ـٌ ـٍ): نون ساكنة تُلفظ ولا تُكتب.\n'
                  '• (مـ): وقف لازم • (لا): عدم الوقف • (ج): وقف جائز • (صلى): الوصل أولى • (قلى): الوقف أولى.',
                  'Basic Arabic diacritics (Fatha, Damma, Kasra, Sukun, Tanween) and Mushaf pause marks.',
                ), style: const TextStyle(height: 1.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _guideRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _openDisplaySettings() {
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
                Text(tr('إعدادات المصحف والقراءة ', 'Quran Settings '),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: kQuranFonts.map((f) {
                    return ChoiceChip(
                      label: Text(fontLabelForLang(f.$1, widget.appLang)),
                      selected: _fontFamily == f.$1,
                      onSelected: (_) {
                        widget.prefs.setString('quranFontFamily', f.$1);
                        setState(() => _fontFamily = f.$1);
                        setSheetState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _fontScale,
                  min: 0.85,
                  max: 1.60,
                  divisions: 6,
                  label: '${(_fontScale * 100).round()}%',
                  onChanged: (v) {
                    setState(() => _fontScale = v);
                    setSheetState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('إظهار ألوان التجويد', 'Show Tajweed Colors')),
                  value: _tajweedColors,
                  onChanged: (v) {
                    widget.prefs.setBool('quranTajweedColors', v);
                    setState(() => _tajweedColors = v);
                    setSheetState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('وضع التركيز الليلي', 'Focus Dim Mode')),
                  value: _focusDimMode,
                  onChanged: (v) {
                    setState(() => _focusDimMode = v);
                    setSheetState(() {});
                  },
                ),
                Text(
                  tr(
                    'ضبط تزامن الكلمات: ${_syncOffsetMs > 0 ? "+$_syncOffsetMs" : "$_syncOffsetMs"} مللي ثانية',
                    'Word Sync Offset: ${_syncOffsetMs > 0 ? "+$_syncOffsetMs" : "$_syncOffsetMs"} ms',
                    'Kelime Senkron Ayarı: ${_syncOffsetMs > 0 ? "+$_syncOffsetMs" : "$_syncOffsetMs"} ms',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Slider(
                  value: _syncOffsetMs.toDouble(),
                  min: -500,
                  max: 500,
                  divisions: 20,
                  label: '${_syncOffsetMs}ms',
                  onChanged: (v) {
                    setState(() => _syncOffsetMs = v.round());
                    setSheetState(() {});
                    widget.prefs.setInt('quranSyncOffsetMs', _syncOffsetMs);
                  },
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _reciterId,
                  decoration: InputDecoration(
                    labelText: tr('اختر القارئ', 'Reciter'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  items: kReciters
                      .map((r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(widget.appLang == 'ar' ? r.nameAr : r.nameEn),
                          ))
                      .toList(),
                  onChanged: (v) async {
                    if (v == null || v == _reciterId) return;
                    if (_isPlaying) {
                      final newName = kReciters
                          .firstWhere((r) => r.id == v, orElse: () => kReciters.first)
                          .nameAr;
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (dCtx) => AlertDialog(
                          title: Text(tr('تغيير القارئ', 'Change Reciter')),
                          content: Text(tr(
                            'التلاوة تعمل حالياً. هل تريد التبديل إلى $newName؟',
                            'Audio is playing. Switch to $newName?',
                          )),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: Text(tr('إلغاء', 'Cancel')),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: Text(tr('تبديل', 'Switch')),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      widget.prefs.setString('quranReciterId', v);
                      setState(() => _reciterId = v);
                      setSheetState(() {});
                      await _checkAudioCache();
                      await _playFromAyah(_playingAyahIndex ?? 0);
                    } else {
                      widget.prefs.setString('quranReciterId', v);
                      setState(() => _reciterId = v);
                      setSheetState(() {});
                      await _checkAudioCache();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSleepTimerDialog() {
    final customCtrl = TextEditingController(text: '20');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('مؤقت التلاوة قبل النوم 🌙', 'Bedtime Recitation Timer 🌙'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr('عدد الدقائق (أو أي رقم)', 'Minutes'),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    final mins = int.tryParse(customCtrl.text.trim()) ?? 15;
                    Navigator.pop(ctx);
                    if (mins > 0) _startSleepTimerSeconds(mins * 60);
                  },
                  child: Text(tr('تشغيل', 'Start')),
                ),
              ],
            ),
            ListTile(
              leading: const Icon(Icons.access_time_rounded),
              title: Text(tr('تحديد ساعة التوقف بالضبط', 'Pick exact stop time')),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) {
                  final now = DateTime.now();
                  var target = DateTime(
                      now.year, now.month, now.day, picked.hour, picked.minute);
                  if (target.isBefore(now)) {
                    target = target.add(const Duration(days: 1));
                  }
                  _startSleepTimerSeconds(target.difference(now).inSeconds);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined),
              title: Text(tr('التوقف عند نهاية السورة', 'Stop at Surah end')),
              onTap: () {
                Navigator.pop(ctx);
                _cancelSleepTimer();
                setState(() => _stopAfterSurah = true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _fetchLocalizedAyahExplanation(int ayahNum, String fallbackAr) async {
    if (widget.appLang == 'ar') return fallbackAr;
    final transId = widget.appLang == 'tr' ? 77 : 20; // 77=Diyanet TR, 20=Saheeh Intl EN
    final cacheKey = '${transId}_$_surahNumber:$ayahNum';
    if (QuranAudioManager.instance.translationsCache.containsKey(cacheKey)) {
      return QuranAudioManager.instance.translationsCache[cacheKey]!;
    }
    try {
      final url =
          'https://api.quran.com/api/v4/quran/translations/$transId?verse_key=$_surahNumber:$ayahNum';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['translations'] as List<dynamic>?) ?? [];
        if (list.isNotEmpty) {
          final raw = (list.first['text'] ?? '').toString();
          final clean = raw.replaceAll(RegExp(r'<[^>]*>'), '').trim();
          if (clean.isNotEmpty) {
            QuranAudioManager.instance.translationsCache[cacheKey] = clean;
            return clean;
          }
        }
      }
    } catch (_) {}
    return fallbackAr;
  }

  void _showAyahSheet(int index) {
    int idx = index;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final ayah = _ayahs[idx] as Map<String, dynamic>;
          final numInSurah = ayah['numberInSurah'] as int;
          final globalNum = ayah['number'] as int;
          final text = (ayah['text'] ?? '').toString();
          final tafsir = (_tafsirAyahs[idx]['text'] ?? '').toString();
          final surahName = (_currentSurah['name'] ?? '').toString();

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$surahName • ${tr("آية", "Ayah")} $numInSurah',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            tooltip: tr('الآية السابقة', 'Previous'),
                            onPressed: idx > 0
                                ? () => setSheetState(() => idx -= 1)
                                : null,
                            icon: const Icon(Icons.arrow_back_ios_rounded,
                                size: 18),
                          ),
                          IconButton(
                            tooltip: tr('الآية التالية', 'Next'),
                            onPressed: idx < _ayahs.length - 1
                                ? () => setSheetState(() => idx += 1)
                                : null,
                            icon: const Icon(Icons.arrow_forward_ios_rounded,
                                size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 19,
                      height: 1.8,
                    ),
                  ),
                  if (widget.appLang != 'ar') ...[
                    const SizedBox(height: 8),
                    Text(
                      stripLeadingBasmala(_surahNumber, idx, text)
                          .split(RegExp(r'\s+'))
                          .where((w) => w.isNotEmpty)
                          .map((w) => transliterateQuranWord(w, turkish: widget.appLang == 'tr'))
                          .join(' '),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const Divider(height: 18),
                  Text(
                    tr('التفسير الميسر:', 'Explanation:', 'Açıklama:'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: SingleChildScrollView(
                      child: FutureBuilder<String>(
                        future: _fetchLocalizedAyahExplanation(numInSurah, tafsir),
                        initialData: tafsir,
                        builder: (_, snap) => Text(
                          snap.data ?? tafsir,
                          textDirection: widget.appLang == 'ar'
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          style: const TextStyle(fontSize: 15, height: 1.7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Builder(builder: (_) {
                        final isThisBookmarked =
                            widget.prefs.getInt('lastQuranSurah') == _surahNumber &&
                            widget.prefs.getInt('lastQuranAyah') == numInSurah;
                        return ActionChip(
                          avatar: Icon(
                            isThisBookmarked
                                ? Icons.bookmark_remove_rounded
                                : Icons.bookmark_add_rounded,
                            color: isThisBookmarked ? Colors.redAccent : Colors.amber,
                            size: 18,
                          ),
                          label: Text(isThisBookmarked
                              ? tr('إزالة العلامة', 'Remove Bookmark')
                              : tr('علامة مرجعية', 'Bookmark')),
                          onPressed: () async {
                            if (isThisBookmarked) {
                              await widget.prefs.remove('lastQuranSurah');
                              await widget.prefs.remove('lastQuranAyah');
                              await widget.prefs.remove('lastQuranSurahName');
                            } else {
                              await widget.prefs
                                  .setInt('lastQuranSurah', _surahNumber);
                              await widget.prefs
                                  .setInt('lastQuranAyah', numInSurah);
                              await widget.prefs
                                  .setString('lastQuranSurahName', surahName);
                            }
                            setState(() {});
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        );
                      }),
                      ActionChip(
                        avatar: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(tr('ابدأ من هنا', 'Play from here')),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _playFromAyah(idx);
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.repeat_one_rounded, size: 18),
                        label: Text(tr('تكرار الآية', 'Repeat Ayah')),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _playSingleAyah(idx, repeat: true);
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(tr('نسخ', 'Copy')),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: text));
                          Navigator.pop(ctx);
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.share_rounded, size: 18),
                        label: Text(tr('مشاركة', 'Share')),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Share.share('$text\n[$surahName: $numInSurah]\n\n$tafsir');
                        },
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

  TextSpan _buildWordSyncedSpan(
    String text,
    int numInSurah,
    Color baseColor, {
    required bool isAnyPlaying,
    required bool isActiveAyah,
    required double progress,
  }) {
    if (!isAnyPlaying) {
      return _buildTajweedSpan(text, numInSurah);
    }
    if (!isActiveAyah) {
      return TextSpan(
        text: '$text  ﴿$numInSurah﴾',
        style: TextStyle(color: baseColor.withOpacity(0.36)),
      );
    }
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) {
      return TextSpan(text: '$text  ﴿$numInSurah﴾');
    }

    final segKey = '${_currentReciter.quranComId}_$_surahNumber:$numInSurah';
    final segs = QuranAudioManager.instance.wordSegments[segKey];
    final posMs = QuranAudioManager.instance.currentPositionMs;
    final effectiveProgress = ((progress - 0.04) / 0.90).clamp(0.0, 1.0);

    final weights = words
        .map((w) => max(1, w.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '').length))
        .toList();
    final totalW = weights.fold<int>(0, (a, b) => a + b);
    int acc = 0;
    final spans = <TextSpan>[];
    final adjPosMs = (posMs + _syncOffsetMs).clamp(0, 9999999);
    final adjProgress = (effectiveProgress + (_syncOffsetMs / 4000.0)).clamp(0.0, 1.0);
    for (int i = 0; i < words.length; i++) {
      bool isSpoken;
      if (segs != null && segs.isNotEmpty) {
        final match = segs.firstWhere(
          (e) => e[0] == i + 1,
          orElse: () => i < segs.length ? segs[i] : segs.last,
        );
        isSpoken = adjPosMs >= match[1];
      } else {
        final startRatio = acc / totalW;
        acc += weights[i];
        isSpoken = adjProgress >= startRatio;
      }
      spans.add(TextSpan(
        text: i == words.length - 1 ? words[i] : '${words[i]} ',
        style: TextStyle(
          color: isSpoken ? baseColor : baseColor.withOpacity(0.30),
        ),
      ));
    }
    spans.add(TextSpan(
      text: '  ﴿$numInSurah﴾',
      style: TextStyle(
        color: progress >= 0.96
            ? const Color(0xFF38BDF8)
            : const Color(0xFF38BDF8).withOpacity(0.35),
      ),
    ));
    return TextSpan(children: spans);
  }

  TextSpan _buildTajweedSpan(String text, int numInSurah) {
    if (!_tajweedColors) {
      return TextSpan(text: '$text  ﴿$numInSurah﴾');
    }
    final spans = <TextSpan>[];
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      Color? color;
      if (ch == 'ٓ' || ch == 'ٰ' || ch == 'ٱ') {
        color = const Color(0xFF38BDF8);
      } else if (ch == 'ّ') {
        color = const Color(0xFFF59E0B);
      } else if (ch == 'ۖ' || ch == 'ۗ' || ch == 'ۚ' || ch == 'ۛ' || ch == 'ۙ') {
        color = const Color(0xFF10B981);
      }
      spans.add(TextSpan(text: ch, style: color != null ? TextStyle(color: color) : null));
    }
    spans.add(TextSpan(
      text: '  ﴿$numInSurah﴾',
      style: const TextStyle(color: Color(0xFF38BDF8)),
    ));
    return TextSpan(children: spans);
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surahName = (_currentSurah['name'] ?? '').toString();
    final savedSurah = widget.prefs.getInt('lastQuranSurah');
    final savedAyah = widget.prefs.getInt('lastQuranAyah');

    return Scaffold(
      backgroundColor: _focusDimMode ? const Color(0xFF000000) : null,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(surahName, style: const TextStyle(fontSize: 18)),
            if (widget.appLang != 'ar')
              Text(
                (_currentSurah['englishName'] ?? '').toString(),
                style: const TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr('دليل الألوان والتجويد والتشكيل', 'Tajweed & Tashkeel Guide'),
            onPressed: _openTajweedGuide,
            icon: const Icon(Icons.help_outline_rounded),
          ),
          IconButton(
            tooltip: tr('الانتقال للعلامة المرجعية', 'Jump to Bookmark'),
            onPressed: () {
              final bSurah = widget.prefs.getInt('lastQuranSurah');
              final bAyah = widget.prefs.getInt('lastQuranAyah');
              if (bSurah == null || bAyah == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('لا توجد علامة مرجعية محفوظة', 'No bookmark saved'))),
                );
                return;
              }
              if (bSurah != _surahNumber) {
                setState(() => _surahNumber = bSurah);
                _checkAudioCache();
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToAyahNumber(bAyah);
              });
            },
            icon: const Icon(Icons.bookmark_rounded, color: Colors.amber),
          ),
          IconButton(
            tooltip: tr('إعدادات الصفحة', 'Page Settings'),
            onPressed: _openDisplaySettings,
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(14),
              itemCount: _ayahs.length + ((_surahNumber != 1 && _surahNumber != 9) ? 1 : 0),
              itemBuilder: (ctx, rawIdx) {
                final hasBasmalaHeader = _surahNumber != 1 && _surahNumber != 9;
                if (hasBasmalaHeader && rawIdx == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14, top: 4),
                    child: Text(
                      'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 22 * _fontScale,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF38BDF8),
                      ),
                    ),
                  );
                }
                final i = hasBasmalaHeader ? rawIdx - 1 : rawIdx;
                final ayah = _ayahs[i] as Map<String, dynamic>;
                final numInSurah = ayah['numberInSurah'] as int;
                final ayahText = stripLeadingBasmala(
                  _surahNumber,
                  i,
                  (ayah['text'] ?? '').toString(),
                );
                final isSavedBookmark = (savedSurah == _surahNumber &&
                        savedAyah == numInSurah) ||
                    (widget.jumpToAyah == numInSurah);
                final isActiveAyah = _playingAyahIndex == i;
                final baseTextColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

                final ayahKey = _ayahKeys.putIfAbsent(numInSurah, () => GlobalKey());
                final isFlashing = _flashAyahNum == numInSurah && _flashVisible;
                return InkWell(
                  key: ayahKey,
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showAyahSheet(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isFlashing
                          ? Colors.amber.withOpacity(0.38)
                          : (isSavedBookmark
                              ? Colors.amber.withOpacity(0.10)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isFlashing
                            ? Colors.amber
                            : (isSavedBookmark
                                ? Colors.amber.withOpacity(0.55)
                                : Colors.grey.withOpacity(0.18)),
                        width: isFlashing ? 2.0 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isSavedBookmark)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Icon(Icons.bookmark_rounded,
                                color: Colors.amber, size: 18),
                          ),
                        RichText(
                          textDirection: TextDirection.rtl,
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              fontSize: 22 * _fontScale,
                              height: 2.0,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                            children: [
                              _buildWordSyncedSpan(
                                ayahText,
                                numInSurah,
                                baseTextColor,
                                isAnyPlaying: _isPlaying && _playingAyahIndex != null,
                                isActiveAyah: isActiveAyah,
                                progress: _ayahProgress,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_showSurahTip)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1).withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_rounded,
                      color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(
                        'اضغط على أي آية للتفسير والعلامة المرجعية، وعلامة (?) لدليل التجويد.',
                        'Tap any Ayah for explanation & bookmark, and (?) for Tajweed guide.',
                        'Tefsir ve yer imi için ayete dokunun, Tecvid rehberi için (?) simgesine basın.',
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      widget.prefs.setBool('seenSurahTip', true);
                      setState(() => _showSurahTip = false);
                    },
                    icon: const Icon(Icons.close_rounded, size: 16),
                  ),
                ],
              ),
            ),
          if (_isPlaying && _playingAyahIndex != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: () {
                  final idx = _playingAyahIndex!;
                  if (idx >= 0 && idx < _ayahs.length) {
                    final n = (_ayahs[idx]['numberInSurah'] as int?) ?? (idx + 1);
                    _scrollToAyahNumber(n, flash: true);
                  }
                },
                icon: const Icon(Icons.my_location_rounded, size: 16),
                label: Text(
                  tr('الانتقال للآية الحالية', 'Go to Current Ayah', 'Aktif Ayete Git'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (widget.appLang != 'ar' || _showTranslitBar)
            _buildBottomTranslitStrip(),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                IconButton.filled(
                  onPressed: _toggleAudio,
                  icon: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (() {
                          final r = kReciters.firstWhere((r) => r.id == _reciterId,
                              orElse: () => kReciters.first);
                          return widget.appLang == 'ar' ? r.nameAr : r.nameEn;
                        })(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if (_sleepSecondsRemaining > 0)
                        Text(
                          '${(_sleepSecondsRemaining ~/ 60)}:${(_sleepSecondsRemaining % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF38BDF8)),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    const speeds = [0.25, 0.5, 0.75, 1.0, 1.25];
                    final idx = speeds.indexOf(_speed);
                    final next = speeds[(idx + 1) % speeds.length];
                    setState(() => _speed = next);
                    await _player.setSpeed(_speed);
                  },
                  child: Text('${_speed}x',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: tr('تكرار السورة', 'Repeat Surah'),
                  onPressed: () => setState(() => _repeatSurah = !_repeatSurah),
                  icon: Icon(Icons.repeat_rounded,
                      color: _repeatSurah ? const Color(0xFF38BDF8) : null),
                ),
                IconButton(
                  tooltip: tr('السورة التالية تلقائياً', 'Auto Next'),
                  onPressed: () =>
                      setState(() => _autoNextSurah = !_autoNextSurah),
                  icon: Icon(Icons.skip_next_rounded,
                      color: _autoNextSurah ? const Color(0xFF38BDF8) : null),
                ),
                IconButton(
                  tooltip: tr('مؤقت قبل النوم', 'Sleep Timer'),
                  onPressed: _openSleepTimerDialog,
                  icon: const Icon(Icons.bedtime_rounded),
                ),
                IconButton(
                  tooltip: tr('تحميل أوفلاين', 'Download Offline'),
                  onPressed: _audioOfflineReady ? null : _downloadSurahAudio,
                  icon: _isDownloadingAudio
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          _audioOfflineReady
                              ? Icons.offline_pin_rounded
                              : Icons.download_rounded,
                          color: _audioOfflineReady ? Colors.green : null,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTranslitStrip() {
    if (_ayahs.isEmpty) return const SizedBox.shrink();
    final activeIdx = (_playingAyahIndex ?? 0).clamp(0, _ayahs.length - 1);
    final ayah = _ayahs[activeIdx] as Map<String, dynamic>;
    final numInSurah = (ayah['numberInSurah'] as int?) ?? (activeIdx + 1);
    final rawText = stripLeadingBasmala(
      _surahNumber,
      activeIdx,
      (ayah['text'] ?? '').toString(),
    );
    final words = rawText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const SizedBox.shrink();

    final segKey = '${_currentReciter.quranComId}_$_surahNumber:$numInSurah';
    final segs = QuranAudioManager.instance.wordSegments[segKey];
    final posMs = QuranAudioManager.instance.currentPositionMs;
    final effectiveProgress = ((_ayahProgress - 0.04) / 0.90).clamp(0.0, 1.0);

    final weights = words
        .map((w) => max(1, w.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '').length))
        .toList();
    final totalW = weights.fold<int>(0, (a, b) => a + b);
    int acc = 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : Colors.black87;
    final isTr = widget.appLang == 'tr';

    final spans = <TextSpan>[];
    for (int i = 0; i < words.length; i++) {
      bool isSpoken = !_isPlaying;
      if (_isPlaying) {
        final adjPosMs = (posMs + _syncOffsetMs).clamp(0, 9999999);
        final adjProgress = (effectiveProgress + (_syncOffsetMs / 4000.0)).clamp(0.0, 1.0);
        if (segs != null && segs.isNotEmpty) {
          final match = segs.firstWhere(
            (e) => e[0] == i + 1,
            orElse: () => i < segs.length ? segs[i] : segs.last,
          );
          isSpoken = adjPosMs >= match[1];
        } else {
          final startRatio = acc / totalW;
          acc += weights[i];
          isSpoken = adjProgress >= startRatio;
        }
      }
      final tWord = transliterateQuranWord(words[i], turkish: isTr);
      spans.add(TextSpan(
        text: i == words.length - 1 ? '$tWord ($numInSurah)' : '$tWord ',
        style: TextStyle(
          color: isSpoken ? baseColor : baseColor.withOpacity(0.30),
          fontWeight: isSpoken && _isPlaying ? FontWeight.w600 : FontWeight.normal,
        ),
      ));
    }

    if (_isPlaying && _translitScrollCtrl.hasClients) {
      final maxScroll = _translitScrollCtrl.position.maxScrollExtent;
      if (maxScroll > 0) {
        final target = (maxScroll * _ayahProgress).clamp(0.0, maxScroll);
        _translitScrollCtrl.jumpTo(target);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1220) : const Color(0xFFF1F5F9),
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.22)),
        ),
      ),
      child: SingleChildScrollView(
        controller: _translitScrollCtrl,
        scrollDirection: Axis.horizontal,
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13, height: 1.45),
            children: spans,
          ),
        ),
      ),
    );
  }
}

const Map<String, String> _kQuranEnToTr = {
  'Noble Quran (Offline)': 'Kur’an-ı Kerim (Çevrimdışı)',
  'Surahs (114)': 'Sureler (114)',
  'Juz (30)': 'Cüzler (30)',
  'Go to Bookmark': 'Yer İmine Git',
  'No bookmark saved yet': 'Henüz yer imi kaydedilmedi',
  'Download Audio Offline': 'Sesleri Çevrimdışı İndir',
  'Page Settings': 'Sayfa Ayarları',
  'Tajweed & Tashkeel Guide': 'Tecvid ve Hareke Rehberi',
  'Jump to Bookmark': 'Yer İmine Git',
  'No bookmark saved': 'Kayıtlı yer imi yok',
  'Repeat Surah': 'Sureyi Tekrarla',
  'Auto Next': 'Sonraki Sure Otomatik',
  'Sleep Timer': 'Uyku Zamanlayıcısı',
  'Download Offline': 'Çevrimdışı İndir',
  'Restart Surah': 'Baştan Başlat',
  'Change Reciter': 'Kari Değiştir',
  'Cancel': 'İptal',
  'Switch': 'Değiştir',
};