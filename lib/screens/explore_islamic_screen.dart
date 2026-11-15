import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ExploreIslamicScreen extends StatefulWidget {
  final bool isEnglish;
  final bool isDarkMode;
  final int initialTab;

  const ExploreIslamicScreen({
    super.key,
    required this.isEnglish,
    required this.isDarkMode,
    this.initialTab = 0,
  });

  @override
  State<ExploreIslamicScreen> createState() => _ExploreIslamicScreenState();
}

class _ExploreIslamicScreenState extends State<ExploreIslamicScreen> {
  String _selectedMood = 'قلق وهم';
  int _istighfarCount = 0;

  String tr(String ar, String en) => widget.isEnglish ? en : ar;

  static const Map<String, List<String>> _moodDuas = {
    'قلق وهم': [
      'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ.',
      'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ.',
      'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ أَصْلِحْ لِي شَأْنِي كُلَّهُ وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ.',
    ],
    'طلب الرزق': [
      'اللَّهُمَّ اكْفِنِي بِحَلَالِكَ عَنْ حَرَامِكَ، وَأَغْنِنِي بِفَضْلِكَ عَمَّنْ سِوَاكَ.',
      'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا.',
    ],
    'شكر وسعادة': [
      'رَبِّ أَوْزِعْنِي أَنْ أَشْكُرَ نِعْمَتَكَ الَّتِي أَنْعَمْتَ عَلَيَّ وَعَلَى وَالِدَيَّ وَأَنْ أَعْمَلَ صَالِحًا تَرْضَاهُ.',
      'الْحَمْدُ لِلَّهِ الَّذِي بِنِعْمَتِهِ تَتِمُّ الصَّالِحَاتُ.',
    ],
    'شفاء وعافية': [
      'أَذْهِبِ الْبَاسَ رَبَّ النَّاسِ، اشْفِ وَأَنْتَ الشَّافِي، لَا شِفَاءَ إِلَّا شِفَاؤُكَ، شِفَاءً لَا يُغَادِرُ سَقَمًا.',
      'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي.',
    ],
    'استخارة': [
      'اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ، وَأَسْتَقْدِرُكَ بِقُدْرَتِكَ، وَأَسْأَلُكَ مِنْ فَضْلِكَ الْعَظِيمِ، فَإِنَّكَ تَقْدِرُ وَلَا أَقْدِرُ، وَتَعْلَمُ وَلَا أَعْلَمُ، وَأَنْتَ عَلَّامُ الْغُيُوبِ.',
    ],
  };

  static const List<(String, String)> _asmaAllah = [
    ('الرَّحْمَنُ', 'واسع الرحمة لجميع خلقه'),
    ('الرَّحِيمُ', 'المتفضل على عباده المؤمنين بالرحمة الخاصة'),
    ('الْمَلِكُ', 'المتصرف في ملكه كيف يشاء'),
    ('الْقُدُّوسُ', 'المنزه عن كل نقص وعيب'),
    ('السَّلَامُ', 'الذي سلم من كل نقص ومانح الأمان'),
    ('الْمُؤْمِنُ', 'المصدق لرسله والمؤمّن لعباده'),
    ('الْمُهَيْمِنُ', 'الرقيب الحافظ لكل شيء'),
    ('الْعَزِيزُ', 'الغالب الذي لا يُقهر'),
    ('الْجَبَّارُ', 'جابر قلوب المنكسرين والقاهر فوق عباده'),
    ('الْغَفَّارُ', 'كثير المغفرة لذنوب عباده'),
    ('الْوَهَّابُ', 'كثير العطاء بدون مقابل'),
    ('الرَّزَّاقُ', 'المتكفل بأرزاق جميع المخلوقات'),
    ('الْفَتَّاحُ', 'الذي يفتح أبواب الرزق والفرج'),
    ('الْعَلِيمُ', 'المحيط علمه بكل شيء'),
    ('اللَّطِيفُ', 'الرفيق بعباده المحسن إليهم من حيث لا يحتسبون'),
    ('الْحَكِيمُ', 'الذي يضع كل شيء في موضعه الصحيح'),
    ('الْوَدُودُ', 'المحب لعباده الصالحين المحبوب في قلوبهم'),
    ('الْمُجِيبُ', 'الذي يجيب دعاء الداعين إذا دعوه'),
  ];

  static const List<(String, String, String)> _nawawi = [
    (
      'الحديث الأول: الأعمال بالنيات',
      '«إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى»',
      'رواه البخاري ومسلم — النية هي أساس قبول كل عمل صالح.',
    ),
    (
      'الحديث السابع: الدين النصيحة',
      '«الدِّينُ النَّصِيحَةُ» قلنا: لمن يا رسول الله؟ قال: «لِلَّهِ وَلِكِتَابِهِ وَلِرَسُولِهِ وَلِأَئِمَّةِ الْمُسْلِمِينَ وَعَامَّتِهِمْ».',
      'رواه مسلم — الإخلاص وحب الخير للناس قوام الدين.',
    ),
    (
      'الحديث الثالث عشر: محبة الخير للناس',
      '«لَا يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ».',
      'رواه البخاري ومسلم — من كمال الإيمان سلامة الصدر.',
    ),
    (
      'الحديث الثامن عشر: التقوى وحسن الخلق',
      '«اتَّقِ اللَّهَ حَيْثُمَا كُنْتَ، وَأَتْبِعِ السَّيِّئَةَ الْحَسَنَةَ تَمْحُهَا، وَخَالِقِ النَّاسَ بِخُلُقٍ حَسَنٍ».',
      'رواه الترمذي — منهج متكامل مع الله ومع النفس ومع الناس.',
    ),
  ];

  static const List<String> _fridaySunan = [
    'قراءة سورة الكهف (نور ما بين الجمعتين)',
    'الإكثار من الصلاة على النبي ﷺ',
    'الغسل والتطيب ولبس أحسن الثياب',
    'التبكير إلى صلاة الجمعة',
    'تحرّي ساعة الاستجابة (خاصة آخر ساعة بعد العصر)',
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('واحة الذكر والعبادات 🌿', 'Islamic Oasis 🌿')),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: tr('دعاء حسب شعورك', 'Mood Dua')),
              Tab(text: tr('سنن الجمعة', 'Friday Sunan')),
              Tab(text: tr('الاستغفار', 'Istighfar')),
              Tab(text: tr('أسماء الله الحسنى', 'Asma Allah')),
              Tab(text: tr('الأربعون النووية', '40 Nawawi')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMoodTab(),
            _buildFridayTab(),
            _buildIstighfarTab(),
            _buildAsmaTab(),
            _buildNawawiTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodTab() {
    final duas = _moodDuas[_selectedMood] ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr('بماذا تشعر الآن؟', 'How do you feel right now?'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _moodDuas.keys.map((mood) {
            final selected = mood == _selectedMood;
            return ChoiceChip(
              label: Text(mood),
              selected: selected,
              onSelected: (_) => setState(() => _selectedMood = mood),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        ...duas.map(
          (d) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    d,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 18, height: 1.9),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.share_rounded),
                      onPressed: () => Share.share(d),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFridayTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF0288D1)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'اللَّهُمَّ صَلِّ وَسَلِّمْ وَبَارِكْ عَلَى نَبِيِّنَا مُحَمَّدٍ ﷺ',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 14),
        ..._fridaySunan.map(
          (item) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.mosque_rounded, color: Color(0xFF38BDF8)),
              title: Text(item, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIstighfarTab() {
    const phrases = [
      'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ وَأَتُوبُ إِلَيْهِ',
      'سَيِّدُ الِاسْتِغْفَارِ: اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ...',
      'رَبِّ اغْفِرْ لِي وَتُبْ عَلَيَّ إِنَّكَ أَنْتَ التَّوَّابُ الرَّحِيمُ',
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF0288D1)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Text(tr('عداد الاستغفار', 'Istighfar Counter'),
                    style: const TextStyle(color: Colors.white70)),
                Text('$_istighfarCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _istighfarCount += 1);
                  },
                  child: Text(tr('أستغفر الله', 'Tap')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: phrases
                  .map((p) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(p,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(fontSize: 16, height: 1.8)),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAsmaTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _asmaAllah.length,
      itemBuilder: (ctx, i) {
        final (name, meaning) = _asmaAllah[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text(meaning),
          ),
        );
      },
    );
  }

  Widget _buildNawawiTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _nawawi
          .map(
            (h) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.$1,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF38BDF8))),
                    const SizedBox(height: 8),
                    Text(h.$2,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontSize: 17, height: 1.8)),
                    const SizedBox(height: 8),
                    Text(h.$3,
                        style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}