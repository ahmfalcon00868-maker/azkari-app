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
  const QuranReciter(this.id, this.nameAr, this.nameEn);
}

const List<QuranReciter> kReciters = [
  QuranReciter('ar.alafasy', 'مشاري راشد العفاسي', 'Mishary Alafasy'),
  QuranReciter('ar.husary', 'محمود خليل الحصري', 'Mahmoud Al-Husary'),
  QuranReciter('ar.abdulbasitmurattal', 'عبد الباسط عبد الصمد', 'Abdul Basit'),
  QuranReciter('ar.minshawi', 'محمد صديق المنشاوي', 'Al-Minshawi'),
  QuranReciter('ar.mahermuaiqly', 'ماهر المعيقلي', 'Maher Al-Muaiqly'),
];

const List<(String, String)> kQuranFonts = [
  ('AmiriQuran', 'عثماني (أميري)'),
  ('Lateef', 'خط لطيف'),
  ('Scheherazade', 'خط شهرزاد'),
  ('NotoKufi', 'نوتو كوفي'),
];

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

class QuranHomeScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final bool isDarkMode;
  final bool isEnglish;
  final double fontScale;
  final VoidCallback? onSurahCompleted;

  const QuranHomeScreen({
    super.key,
    required this.prefs,
    required this.isDarkMode,
    required this.isEnglish,
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

  String tr(String ar, String en) => widget.isEnglish ? en : ar;

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
    final reciterId = widget.prefs.getString('quranReciterId') ?? 'ar.alafasy';
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
    final surahs = QuranDataRepository.surahs.where((s) {
      if (normQuery.isEmpty) return true;
      final name = normalizeArabicForSearch((s['name'] ?? '').toString());
      final en = (s['englishName'] ?? '').toString().toLowerCase();
      return name.contains(normQuery) ||
          en.contains(normQuery) ||
          s['number'].toString() == normQuery;
    }).toList();

    final juzList = _loading ? <Map<String, dynamic>>[] : _buildJuzSummary();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('القرآن الكريم (بدون نت) 📖', 'Noble Quran (Offline) 📖')),
          actions: [
            IconButton(
              tooltip: tr('تحميل التلاوات بدون نت', 'Download Audio Offline'),
              onPressed: _downloadingAll
                  ? () => setState(() => _downloadingAll = false)
                  : _downloadAllSurahsForReciter,
              icon: Icon(
                _downloadingAll
                    ? Icons.stop_circle_rounded
                    : Icons.cloud_download_rounded,
              ),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: tr('السور (114)', 'Surahs (114)')),
              Tab(text: tr('الأجزاء (30)', 'Juz (30)')),
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
                                  hintText: tr('ابحث باسم السورة (بدون تشكيل)...',
                                      'Search Surah...'),
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
                                      ? tr('مكية', 'Meccan')
                                      : tr('مدنية', 'Medinan');
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
                                      '$revType • $ayahs ${tr("آية", "Ayahs")}',
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
  final double initialFontScale;
  final int? jumpToAyah;
  final VoidCallback? onSurahCompleted;

  const SurahReaderScreen({
    super.key,
    required this.initialSurahNumber,
    required this.prefs,
    required this.isDarkMode,
    required this.isEnglish,
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

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isDownloadingAudio = false;
  bool _audioOfflineReady = false;
  bool _repeatSurah = false;
  bool _autoNextSurah = true;
  double _speed = 1.0;

  Timer? _sleepTimer;
  int _sleepSecondsRemaining = 0;
  bool _stopAfterSurah = false;

  String tr(String ar, String en) => widget.isEnglish ? en : ar;

  @override
  void initState() {
    super.initState();
    _surahNumber = widget.initialSurahNumber;
    _fontScale = widget.initialFontScale;
    _fontFamily = widget.prefs.getString('quranFontFamily') ?? 'AmiriQuran';
    _tajweedColors = widget.prefs.getBool('quranTajweedColors') ?? true;
    _reciterId = widget.prefs.getString('quranReciterId') ?? 'ar.alafasy';
    _checkAudioCache();

    _player.playerStateStream.listen((state) async {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
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

  String get _surahAudioUrl =>
      'https://cdn.islamic.network/quran/audio-surah/128/$_reciterId/$_surahNumber.mp3';

  MediaItem _surahMediaItem() {
    final surahName = (_currentSurah['name'] ?? '').toString();
    final reciterName = kReciters
        .firstWhere((r) => r.id == _reciterId, orElse: () => kReciters.first)
        .nameAr;
    return MediaItem(
      id: 'surah_${_reciterId}_$_surahNumber',
      album: 'القرآن الكريم • أذكاري',
      title: surahName,
      artist: reciterName,
    );
  }

  Future<void> _playFullSurah() async {
    try {
      await _player.setVolume(1.0);
      await _player.setSpeed(_speed);
      final localPath = await _audioFilePath();
      final source = await File(localPath).exists()
          ? AudioSource.file(localPath, tag: _surahMediaItem())
          : AudioSource.uri(Uri.parse(_surahAudioUrl), tag: _surahMediaItem());
      await _player.setAudioSource(source);
      await _player.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('تعذر تشغيل التلاوة، تأكد من الإنترنت أو حمّل السورة', 'Audio failed'))),
        );
      }
    }
  }

  Future<void> _playSingleAyah(int globalAyahNum, {bool repeat = false}) async {
    try {
      await _player.setVolume(1.0);
      await _player.setSpeed(_speed);
      await _player.setLoopMode(repeat ? LoopMode.one : LoopMode.off);
      final url =
          'https://cdn.islamic.network/quran/audio/128/$_reciterId/$globalAyahNum.mp3';
      await _player.setAudioSource(
          AudioSource.uri(Uri.parse(url), tag: _surahMediaItem()));
      await _player.play();
    } catch (_) {}
  }

  Future<void> _playFromAyah(int startIndex) async {
    try {
      await _player.setVolume(1.0);
      await _player.setSpeed(_speed);
      await _player.setLoopMode(LoopMode.off);
      final sources = _ayahs
          .sublist(startIndex)
          .map((a) => AudioSource.uri(
                Uri.parse(
                    'https://cdn.islamic.network/quran/audio/128/$_reciterId/${a['number']}.mp3'),
                tag: _surahMediaItem(),
              ))
          .toList();
      await _player.setAudioSource(ConcatenatingAudioSource(children: sources));
      await _player.play();
    } catch (_) {}
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _player.pause();
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
              content: Text(tr('تم حفظ السورة للاستماع بدون نت ✓',
                  'Surah audio saved offline ✓')),
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
                Text(tr('إعدادات المصحف والقراءة ⚙️', 'Quran Settings ⚙️'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: kQuranFonts.map((f) {
                    return ChoiceChip(
                      label: Text(f.$2),
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
                            child: Text(widget.isEnglish ? r.nameEn : r.nameAr),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      widget.prefs.setString('quranReciterId', v);
                      setState(() => _reciterId = v);
                      setSheetState(() {});
                      _checkAudioCache();
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
                  const Divider(height: 18),
                  Text(tr('التفسير الميسر:', 'Tafsir:'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF38BDF8))),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: SingleChildScrollView(
                      child: Text(tafsir,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(fontSize: 15, height: 1.7)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.bookmark_rounded,
                            color: Colors.amber, size: 18),
                        label: Text(tr('علامة مرجعية', 'Bookmark')),
                        onPressed: () async {
                          await widget.prefs
                              .setInt('lastQuranSurah', _surahNumber);
                          await widget.prefs.setInt('lastQuranAyah', numInSurah);
                          await widget.prefs
                              .setString('lastQuranSurahName', surahName);
                          final list = widget.prefs
                                  .getStringList('bookmarkedSurahs') ??
                              [];
                          if (!list.contains(_surahNumber.toString())) {
                            list.add(_surahNumber.toString());
                            await widget.prefs
                                .setStringList('bookmarkedSurahs', list);
                          }
                          setState(() {});
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
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
                          _playSingleAyah(globalNum, repeat: true);
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
    _player.dispose();
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
        title: Text(surahName),
        actions: [
          IconButton(
            tooltip: tr('إعدادات الصفحة', 'Page Settings'),
            onPressed: _openDisplaySettings,
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
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
                        kReciters
                            .firstWhere((r) => r.id == _reciterId,
                                orElse: () => kReciters.first)
                            .nameAr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if (_sleepSecondsRemaining > 0)
                        Text(
                          '🌙 ${(_sleepSecondsRemaining ~/ 60)}:${(_sleepSecondsRemaining % 60).toString().padLeft(2, '0')}',
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
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _ayahs.length,
              itemBuilder: (ctx, i) {
                final ayah = _ayahs[i] as Map<String, dynamic>;
                final numInSurah = ayah['numberInSurah'] as int;
                final isSavedBookmark = (savedSurah == _surahNumber &&
                        savedAyah == numInSurah) ||
                    (widget.jumpToAyah == numInSurah);

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showAyahSheet(i),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSavedBookmark
                          ? Colors.amber.withOpacity(0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSavedBookmark
                            ? Colors.amber.withOpacity(0.45)
                            : Colors.grey.withOpacity(0.18),
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
                              _buildTajweedSpan(
                                  (ayah['text'] ?? '').toString(), numInSurah),
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
        ],
      ),
    );
  }
}