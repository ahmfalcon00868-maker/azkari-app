import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuranSurahMeta {
  final int number;
  final String name;
  final String englishName;
  final int ayahsCount;
  const QuranSurahMeta(this.number, this.name, this.englishName, this.ayahsCount);
}

const List<QuranSurahMeta> kCommonSurahs = [
  QuranSurahMeta(1, 'الفاتحة', 'Al-Fatihah', 7),
  QuranSurahMeta(2, 'البقرة', 'Al-Baqarah', 286),
  QuranSurahMeta(18, 'الكهف', 'Al-Kahf', 110),
  QuranSurahMeta(36, 'يس', 'Ya-Sin', 83),
  QuranSurahMeta(55, 'الرحمن', 'Ar-Rahman', 78),
  QuranSurahMeta(56, 'الواقعة', 'Al-Waqiah', 96),
  QuranSurahMeta(67, 'الملك', 'Al-Mulk', 30),
  QuranSurahMeta(78, 'النبأ', 'An-Naba', 40),
  QuranSurahMeta(87, 'الأعلى', 'Al-Ala', 19),
  QuranSurahMeta(93, 'الضحى', 'Ad-Duha', 11),
  QuranSurahMeta(94, 'الشرح', 'Ash-Sharh', 8),
  QuranSurahMeta(97, 'القدر', 'Al-Qadr', 5),
  QuranSurahMeta(103, 'العصر', 'Al-Asr', 3),
  QuranSurahMeta(108, 'الكوثر', 'Al-Kawthar', 3),
  QuranSurahMeta(109, 'الكافرون', 'Al-Kafirun', 6),
  QuranSurahMeta(112, 'الإخلاص', 'Al-Ikhlas', 4),
  QuranSurahMeta(113, 'الفلق', 'Al-Falaq', 5),
  QuranSurahMeta(114, 'الناس', 'An-Nas', 6),
];

class QuranHomeScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final bool isDarkMode;
  final bool isEnglish;
  final double fontScale;

  const QuranHomeScreen({
    super.key,
    required this.prefs,
    required this.isDarkMode,
    required this.isEnglish,
    required this.fontScale,
  });

  @override
  State<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

class _QuranHomeScreenState extends State<QuranHomeScreen> {
  List<QuranSurahMeta> _surahs = kCommonSurahs;
  String _search = '';
  bool _loadingList = false;

  String tr(String ar, String en) => widget.isEnglish ? en : ar;

  @override
  void initState() {
    super.initState();
    _loadFullSurahList();
  }

  Future<void> _loadFullSurahList() async {
    final cached = widget.prefs.getString('quran_surah_list');
    if (cached != null) {
      try {
        final List<dynamic> list = jsonDecode(cached);
        setState(() {
          _surahs = list
              .map((e) => QuranSurahMeta(
                    e['number'] as int,
                    e['name'] as String,
                    e['englishName'] as String,
                    e['numberOfAyahs'] as int,
                  ))
              .toList();
        });
        return;
      } catch (_) {}
    }

    setState(() => _loadingList = true);
    try {
      final res = await http
          .get(Uri.parse('https://api.alquran.cloud/v1/surah'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        final List<dynamic> data = body['data'];
        await widget.prefs.setString('quran_surah_list', jsonEncode(data));
        if (mounted) {
          setState(() {
            _surahs = data
                .map((e) => QuranSurahMeta(
                      e['number'] as int,
                      e['name'] as String,
                      e['englishName'] as String,
                      e['numberOfAyahs'] as int,
                    ))
                .toList();
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingList = false);
  }

  @override
  Widget build(BuildContext context) {
    final lastSurah = widget.prefs.getInt('lastQuranSurah');
    final lastAyah = widget.prefs.getInt('lastQuranAyah');
    final lastName = widget.prefs.getString('lastQuranSurahName') ?? '';

    final filtered = _surahs.where((s) {
      if (_search.trim().isEmpty) return true;
      return s.name.contains(_search) ||
          s.englishName.toLowerCase().contains(_search.toLowerCase()) ||
          s.number.toString() == _search.trim();
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('القرآن الكريم والتفسير 📖', 'Noble Quran & Tafsir 📖')),
      ),
      body: Column(
        children: [
          if (lastSurah != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  final meta = _surahs.firstWhere(
                    (s) => s.number == lastSurah,
                    orElse: () => QuranSurahMeta(lastSurah, lastName, '', 0),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SurahReaderScreen(
                        surah: meta,
                        prefs: widget.prefs,
                        isDarkMode: widget.isDarkMode,
                        isEnglish: widget.isEnglish,
                        initialFontScale: widget.fontScale,
                        jumpToAyah: lastAyah,
                      ),
                    ),
                  ).then((_) => setState(() {}));
                },
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
                      const Icon(Icons.bookmark_rounded, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr(
                            'متابعة الختمة: $lastName (آية ${lastAyah ?? 1})',
                            'Resume Khatmah: $lastName (Ayah ${lastAyah ?? 1})',
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: tr('ابحث باسم السورة أو رقمها...', 'Search Surah...'),
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (_loadingList)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final surah = filtered[i];
                final isCached = widget.prefs
                    .containsKey('surah_cache_${surah.number}');
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0D47A1).withOpacity(0.15),
                    child: Text(
                      '${surah.number}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    surah.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  subtitle: Text(
                    '${surah.englishName} • ${surah.ayahsCount} ${tr("آية", "Ayahs")}',
                  ),
                  trailing: Icon(
                    isCached
                        ? Icons.offline_pin_rounded
                        : Icons.cloud_download_outlined,
                    color: isCached ? Colors.green : Colors.grey,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SurahReaderScreen(
                          surah: surah,
                          prefs: widget.prefs,
                          isDarkMode: widget.isDarkMode,
                          isEnglish: widget.isEnglish,
                          initialFontScale: widget.fontScale,
                        ),
                      ),
                    ).then((_) => setState(() {}));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SurahReaderScreen extends StatefulWidget {
  final QuranSurahMeta surah;
  final SharedPreferences prefs;
  final bool isDarkMode;
  final bool isEnglish;
  final double initialFontScale;
  final int? jumpToAyah;

  const SurahReaderScreen({
    super.key,
    required this.surah,
    required this.prefs,
    required this.isDarkMode,
    required this.isEnglish,
    required this.initialFontScale,
    this.jumpToAyah,
  });

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  List<Map<String, dynamic>> _ayahs = [];
  bool _loading = true;
  String? _error;
  late double _fontScale;
  bool _focusDimMode = false;

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isDownloadingAudio = false;
  bool _audioOfflineReady = false;
  double _speed = 1.0;

  // مؤقت التلاوة قبل النوم
  Timer? _sleepTimer;
  Timer? _fadeTimer;
  int _sleepSecondsRemaining = 0;
  bool _stopAfterSurah = false;

  String tr(String ar, String en) => widget.isEnglish ? en : ar;

  @override
  void initState() {
    super.initState();
    _fontScale = widget.initialFontScale;
    _loadSurahData();
    _checkAudioCache();
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
      if (state.processingState == ProcessingState.completed) {
        if (_stopAfterSurah) {
          _cancelSleepTimer();
        }
      }
    });
  }

  Future<void> _loadSurahData() async {
    final key = 'surah_cache_${widget.surah.number}';
    final cached = widget.prefs.getString(key);
    if (cached != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cached);
        setState(() {
          _ayahs = decoded.cast<Map<String, dynamic>>();
          _loading = false;
        });
        return;
      } catch (_) {}
    }

    try {
      final url =
          'https://api.alquran.cloud/v1/surah/${widget.surah.number}/editions/quran-uthmani,ar.muyassar';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        final List<dynamic> editions = body['data'];
        final List<dynamic> textAyahs = editions[0]['ayahs'];
        final List<dynamic> tafsirAyahs = editions[1]['ayahs'];

        final merged = List.generate(textAyahs.length, (i) {
          return {
            'numberInSurah': textAyahs[i]['numberInSurah'],
            'text': textAyahs[i]['text'],
            'tafsir': i < tafsirAyahs.length ? tafsirAyahs[i]['text'] : '',
          };
        });

        await widget.prefs.setString(key, jsonEncode(merged));
        if (mounted) {
          setState(() {
            _ayahs = merged;
            _loading = false;
          });
        }
      } else {
        setState(() {
          _error = tr('تعذر تحميل السورة الآن', 'Failed to load Surah');
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = tr('تأكد من الاتصال بالإنترنت للتحميل لأول مرة',
              'Internet required for first-time download');
          _loading = false;
        });
      }
    }
  }

  Future<String> _audioFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/quran_audio');
    if (!await folder.exists()) await folder.create(recursive: true);
    return '${folder.path}/surah_${widget.surah.number}.mp3';
  }

  Future<void> _checkAudioCache() async {
    final path = await _audioFilePath();
    final exists = await File(path).exists();
    if (mounted) setState(() => _audioOfflineReady = exists);
  }

  String get _audioUrl =>
      'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/${widget.surah.number}.mp3';

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    try {
      await _player.setVolume(1.0);
      await _player.setSpeed(_speed);
      final localPath = await _audioFilePath();
      if (await File(localPath).exists()) {
        await _player.setFilePath(localPath);
      } else {
        await _player.setUrl(_audioUrl);
      }
      await _player.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('تعذر تشغيل التلاوة، تحقق من الإنترنت',
                'Could not play audio')),
          ),
        );
      }
    }
  }

  Future<void> _downloadSurahAudio() async {
    if (_isDownloadingAudio) return;
    setState(() => _isDownloadingAudio = true);
    try {
      final res = await http
          .get(Uri.parse(_audioUrl))
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        final path = await _audioFilePath();
        await File(path).writeAsBytes(res.bodyBytes);
        if (mounted) {
          setState(() => _audioOfflineReady = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('تم حفظ السورة للاستماع بدون إنترنت ✓',
                  'Surah audio saved for offline playback ✓')),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('فشل تحميل الصوت', 'Download failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingAudio = false);
    }
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _fadeTimer?.cancel();
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
        // خفض الصوت تدريجياً في آخر 30 ثانية
        if (_sleepSecondsRemaining <= 30) {
          final vol = max(0.05, _sleepSecondsRemaining / 30.0);
          await _player.setVolume(vol);
        }
      }
    });
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
            const SizedBox(height: 8),
            Text(
              tr('اختر المدة بحرية وسيتم خفض الصوت تدريجياً قبل التوقف:',
                  'Choose any stop time; volume fades out gently:'),
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr('عدد الدقائق (أو أي رقم)', 'Minutes'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                  child: Text(tr('تشغيل المؤقت', 'Start')),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
              title: Text(
                  tr('التوقف عند نهاية هذه السورة', 'Stop after this Surah')),
              onTap: () {
                Navigator.pop(ctx);
                _cancelSleepTimer();
                setState(() => _stopAfterSurah = true);
              },
            ),
            if (_sleepSecondsRemaining > 0 || _stopAfterSurah)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _cancelSleepTimer();
                },
                icon: const Icon(Icons.close_rounded, color: Colors.red),
                label: Text(tr('إلغاء المؤقت', 'Cancel Timer'),
                    style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  void _showAyahActions(Map<String, dynamic> ayah) {
    final numInSurah = ayah['numberInSurah'] as int;
    final text = ayah['text'] as String;
    final tafsir = (ayah['tafsir'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.surah.name} • ${tr("آية", "Ayah")} $numInSurah',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (tafsir.isNotEmpty) ...[
                Text(
                  tr('التفسير الميسر:', 'Tafsir Al-Muyassar:'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(
                      tafsir,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 15, height: 1.7),
                    ),
                  ),
                ),
                const Divider(height: 20),
              ],
              ListTile(
                leading: const Icon(Icons.bookmark_add_rounded,
                    color: Color(0xFF0288D1)),
                title: Text(tr('حفظ كعلامة ختمة (آخر موضع)', 'Bookmark Khatmah')),
                onTap: () async {
                  await widget.prefs
                      .setInt('lastQuranSurah', widget.surah.number);
                  await widget.prefs.setInt('lastQuranAyah', numInSurah);
                  await widget.prefs
                      .setString('lastQuranSurahName', widget.surah.name);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(tr('تم حفظ موضع القراءة ✓',
                              'Bookmark saved ✓'))),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: Text(tr('مشاركة الآية والتفسير', 'Share Ayah')),
                onTap: () {
                  Navigator.pop(ctx);
                  Share.share(
                    '$text\n[${widget.surah.name}: $numInSurah]\n\n$tafsir',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _fadeTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgOverride = _focusDimMode ? const Color(0xFF060A12) : null;
    return Scaffold(
      backgroundColor: bgOverride,
      appBar: AppBar(
        title: Text(widget.surah.name),
        actions: [
          IconButton(
            tooltip: tr('وضع التركيز الليلي', 'Focus Dim Mode'),
            onPressed: () => setState(() => _focusDimMode = !_focusDimMode),
            icon: Icon(_focusDimMode
                ? Icons.brightness_low_rounded
                : Icons.brightness_6_rounded),
          ),
          IconButton(
            tooltip: tr('تصغير الخط', 'Decrease Font'),
            onPressed: () =>
                setState(() => _fontScale = (_fontScale - 0.1).clamp(0.85, 1.6)),
            icon: const Icon(Icons.text_decrease_rounded),
          ),
          IconButton(
            tooltip: tr('تكبير الخط', 'Increase Font'),
            onPressed: () =>
                setState(() => _fontScale = (_fontScale + 0.1).clamp(0.85, 1.6)),
            icon: const Icon(Icons.text_increase_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _loadSurahData();
                        },
                        child: Text(tr('إعادة المحاولة', 'Retry')),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // شريط مشغل العفاسي + مؤقت النوم
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D47A1).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          IconButton.filled(
                            onPressed: _toggleAudio,
                            icon: Icon(_isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('مشاري العفاسي', 'Mishary Alafasy'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                if (_sleepSecondsRemaining > 0)
                                  Text(
                                    '🌙 ${(_sleepSecondsRemaining ~/ 60)}:${(_sleepSecondsRemaining % 60).toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xFF38BDF8)),
                                  )
                                else if (_stopAfterSurah)
                                  Text(
                                    tr('🌙 يقف بنهاية السورة', '🌙 Stops at end'),
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xFF38BDF8)),
                                  ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              const speeds = [0.75, 1.0, 1.25, 1.5];
                              final next = speeds[
                                  (speeds.indexOf(_speed) + 1) % speeds.length];
                              setState(() => _speed = next);
                              await _player.setSpeed(_speed);
                            },
                            child: Text('${_speed}x',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            tooltip: tr('مؤقت قبل النوم', 'Sleep Timer'),
                            onPressed: _openSleepTimerDialog,
                            icon: const Icon(Icons.bedtime_rounded),
                          ),
                          IconButton(
                            tooltip: tr('تحميل أوفلاين', 'Download Offline'),
                            onPressed:
                                _audioOfflineReady ? null : _downloadSurahAudio,
                            icon: _isDownloadingAudio
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Icon(
                                    _audioOfflineReady
                                        ? Icons.offline_pin_rounded
                                        : Icons.download_rounded,
                                    color: _audioOfflineReady
                                        ? Colors.green
                                        : null,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _ayahs.length,
                        itemBuilder: (ctx, i) {
                          final ayah = _ayahs[i];
                          final numInSurah = ayah['numberInSurah'] as int;
                          final isBookmarked =
                              widget.jumpToAyah == numInSurah;
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _showAyahActions(ayah),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isBookmarked
                                    ? const Color(0xFF0288D1).withOpacity(0.18)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.18),
                                ),
                              ),
                              child: Text(
                                '${ayah['text']}  ﴿$numInSurah﴾',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontSize: 21 * _fontScale,
                                  height: 2.0,
                                ),
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