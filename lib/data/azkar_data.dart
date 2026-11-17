class ZikrItem {
  final int id;
  final String category;
  final String categoryLabel;
  final String text;
  final String source;
  final int target;
  int count;
  bool favorite;

  ZikrItem({
    required this.id,
    required this.category,
    required this.categoryLabel,
    required this.text,
    required this.source,
    required this.target,
    this.count = 0,
    this.favorite = false,
  });

  String get categoryLabelEn {
    switch (category) {
      case 'morning':
        return 'Morning Azkar';
      case 'evening':
        return 'Evening Azkar';
      case 'sleep':
        return 'Sleep Azkar';
      case 'wakeup':
        return 'Wakeup Azkar';
      case 'prayer':
        return 'After Prayer Azkar';
      case 'daily':
        return 'Home & Travel';
      case 'supplications':
        return 'Comprehensive Duas';
      default:
        return categoryLabel;
    }
  }

  String get categoryLabelTr {
    switch (category) {
      case 'morning':
        return 'Sabah Zikirleri';
      case 'evening':
        return 'Akşam Zikirleri';
      case 'sleep':
        return 'Uyku Zikirleri';
      case 'wakeup':
        return 'Uyanış Zikirleri';
      case 'prayer':
        return 'Namaz Sonrası Zikirler';
      case 'daily':
        return 'Ev ve Yolculuk';
      case 'supplications':
        return 'Kapsamlı Dualar';
      default:
        return categoryLabel;
    }
  }

  String categoryForLang(String lang) {
    if (lang == 'en') return categoryLabelEn;
    if (lang == 'tr') return categoryLabelTr;
    return categoryLabel;
  }

  String get englishText => kAzkarEnglishById[id] ?? text;
  String get turkishText => kAzkarTurkishById[id] ?? text;

  Map<String, dynamic> toJson() => {
        'id': id,
        'count': count,
        'favorite': favorite,
      };
}

const List<String> kRandomShortAzkar = [
  'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
  'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ وَأَتُوبُ إِلَيْهِ',
  'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
  'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
  'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
  'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ',
  'سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ',
  'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ',
];

List<ZikrItem> getInitialAzkarList() => [
      // ==========================================
      // 1. أذكار الصباح (29 ذكراً بالترتيب الدقيق)
      // ==========================================
      ZikrItem(
        id: 101,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ\n﴿اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ وَلَا يَئُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ﴾',
        source: 'آية الكرسي - البقرة 255 | من قالها حين يصبح أجير من الجن حتى يمسي',
        target: 1,
        favorite: true,
      ),
      ZikrItem(
        id: 102,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n﴿قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ﴾',
        source: 'من قالها حين يصبح وحين يمسي كفته من كل شيء (الإخلاص والمعوذتين)',
        target: 3,
      ),
      ZikrItem(
        id: 103,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n﴿قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِنْ شَرِّ مَا خَلَقَ ۝ وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ﴾',
        source: 'سورة الفلق',
        target: 3,
      ),
      ZikrItem(
        id: 104,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n﴿قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ﴾',
        source: 'سورة الناس',
        target: 3,
      ),
      ZikrItem(
        id: 105,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ.',
        source: 'رواه مسلم',
        target: 1,
      ),
      ZikrItem(
        id: 106,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ.',
        source: 'سيد الاستغفار | من قالها موقناً بها حين يصبح ومات من يومه دخل الجنة',
        target: 1,
        favorite: true,
      ),
      ZikrItem(
        id: 107,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا.',
        source: 'من قالها حين يصبح وحين يمسي كان حقاً على الله أن يرضيه يوم القيامة',
        target: 3,
      ),
      ZikrItem(
        id: 108,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'اللَّهُمَّ إِنِّي أَصْبَحْتُ أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ، وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّداً عَبْدُكَ وَرَسُولُكَ.',
        source: 'من قالها أربع مرات أعتقه الله من النار',
        target: 4,
      ),
      ZikrItem(
        id: 109,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'اللَّهُمَّ مَا أَصْبَحَ بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ، فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ.',
        source: 'من قالها حين يصبح فقد أدى شكر يومه',
        target: 1,
      ),
      ZikrItem(
        id: 110,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ.',
        source: 'من قالها سبعاً كفاه الله ما أهمه من أمر الدنيا والآخرة',
        target: 7,
      ),
      ZikrItem(
        id: 111,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ.',
        source: 'من قالها ثلاثاً لم يضره شيء',
        target: 3,
        favorite: true,
      ),
      ZikrItem(
        id: 112,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ.',
        source: 'رواه الترمذي',
        target: 1,
      ),
      ZikrItem(
        id: 113,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'أَصْبَحْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ، وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفاً مُسْلِماً وَمَا كَانَ مِنَ الْمُشْرِكِينَ.',
        source: 'رواه أحمد',
        target: 1,
      ),
      ZikrItem(
        id: 114,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ.',
        source: 'رواه مسلم',
        target: 3,
      ),
      ZikrItem(
        id: 115,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ.',
        source: 'رواه أبو داود',
        target: 3,
      ),
      ZikrItem(
        id: 116,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ، وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لَا إِلَهَ إِلَّا أَنْتَ.',
        source: 'رواه أبو داود',
        target: 3,
      ),
      ZikrItem(
        id: 117,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي، اللَّهُمَّ اسْتُرْ عَوْرَاتِي وَآمِنْ رَوْعَاتِي، اللَّهُمَّ احْفَظْنِي مِنْ بَيْنِ يَدَيَّ وَمِنْ خَلْفِي وَعَنْ يَمِينِي وَعَنْ شِمَالِي وَمِنْ فَوْقِي، وَأَعُوذُ بِعَظَمَتِكَ أَنْ أُغْتَالَ مِنْ تَحْتِي.',
        source: 'رواه أبو داود وابن ماجه',
        target: 1,
      ),
      ZikrItem(
        id: 118,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ أَصْلِحْ لِي شَأْنِي كُلَّهُ وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ.',
        source: 'رواه النسائي والحاكم',
        target: 3,
      ),
      ZikrItem(
        id: 119,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذَا الْيَوْمِ، فَتْحَهُ، وَنَصْرَهُ، وَنُورَهُ، وَبَرَكَتَهُ، وَهُدَاهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِيهِ وَشَرِّ مَا بَعْدَهُ.',
        source: 'رواه أبو داود',
        target: 1,
      ),
      ZikrItem(
        id: 120,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'اللَّهُمَّ عَالِمَ الْغَيْبِ وَالشَّهَادَةِ فَاطِرَ السَّمَاوَاتِ وَالْأَرْضِ رَبَّ كُلِّ شَيْءٍ وَمَلِيكَهُ، أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا أَنْتَ، أَعُوذُ بِكَ مِنْ شَرِّ نَفْسِي وَمِنْ شَرِّ الشَّيْطَانِ وَشِرْكِهِ، وَأَنْ أَقْتَرِفَ عَلَى نَفْسِي سُوءًا أَوْ أَجُرَّهُ إِلَى مُسْلِمٍ.',
        source: 'رواه الترمذي',
        target: 1,
      ),
      ZikrItem(
        id: 121,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text: 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ.',
        source: 'رواه مسلم',
        target: 3,
      ),
      ZikrItem(
        id: 122,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text: 'اللَّهُمَّ صَلِّ وَسَلِّمْ وَبَارِكْ عَلَى نَبِيِّنَا مُحَمَّدٍ.',
        source: 'من صلى عليّ حين يصبح وحين يمسي أدركته شفاعتي يوم القيامة',
        target: 10,
      ),
      ZikrItem(
        id: 123,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'اللَّهُمَّ إِنَّا نَعُوذُ بِكَ مِنْ أَنْ نُشْرِكَ بِكَ شَيْئًا نَعْلَمُهُ، وَنَسْتَغْفِرُكَ لِمَا لَا نَعْلَمُهُ.',
        source: 'رواه أحمد',
        target: 3,
      ),
      ZikrItem(
        id: 124,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَأَعُوذُ بِكَ مِنَ الْعَجْزِ وَالْكَسَلِ، وَأَعُوذُ بِكَ مِنَ الْجُبْنِ وَالْبُخْلِ، وَأَعُوذُ بِكَ مِنْ غَلَبَةِ الدَّيْنِ وَقَهْرِ الرِّجَالِ.',
        source: 'رواه أبو داود',
        target: 3,
      ),
      ZikrItem(
        id: 125,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ، الْحَيُّ الْقَيُّومُ، وَأَتُوبُ إِلَيْهِ.',
        source: 'رواه أبو داود والترمذي',
        target: 3,
      ),
      ZikrItem(
        id: 126,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'يَا رَبِّ، لَكَ الْحَمْدُ كَمَا يَنْبَغِي لِجَلَالِ وَجْهِكَ، وَلِعَظِيمِ سُلْطَانِكَ.',
        source: 'رواه ابن ماجه',
        target: 3,
      ),
      ZikrItem(
        id: 127,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
        source: 'كانت له عدل عشر رقاب، وكتبت له مئة حسنة، وحرزاً من الشيطان',
        target: 10,
      ),
      ZikrItem(
        id: 128,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text:
            'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، عَلَيْكَ تَوَكَّلْتُ، وَأَنْتَ رَبُّ الْعَرْشِ الْعَظِيمِ، مَا شَاءَ اللَّهُ كَانَ، وَمَا لَمْ يَشَأْ لَمْ يَكُنْ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ الْعَلِيِّ الْعَظِيمِ، أَعْلَمُ أَنَّ اللَّهَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، وَأَنَّ اللَّهَ قَدْ أَحَاطَ بِكُلِّ شَيْءٍ عِلْمًا، اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ شَرِّ نَفْسِي، وَمِنْ شَرِّ كُلِّ دَابَّةٍ أَنْتَ آخِذٌ بِنَاصِيَتِهَا، إِنَّ رَبِّي عَلَى صِرَاطٍ مُسْتَقِيمٍ.',
        source: 'حفظٌ من الآفات',
        target: 1,
      ),
      ZikrItem(
        id: 129,
        category: 'morning',
        categoryLabel: 'أذكار الصباح',
        text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.',
        source: 'من قالها مئة مرة حطت خطاياه وإن كانت مثل زبد البحر',
        target: 100,
      ),

      // ==========================================
      // 2. أذكار المساء (30 ذكراً بالترتيب الدقيق)
      // ==========================================
      ZikrItem(
        id: 201,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ\n﴿اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ وَلَا يَئُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ﴾',
        source: 'آية الكرسي - البقرة 255 | من قالها حين يمسي أجير من الجن حتى يصبح',
        target: 1,
        favorite: true,
      ),
      ZikrItem(
        id: 202,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ\n﴿آمَنَ الرَّسُولُ بِمَا أُنْزِلَ إِلَيْهِ مِنْ رَبِّهِ وَالْمُؤْمِنُونَ ۚ كُلٌّ آمَنَ بِاللَّهِ وَمَلَائِكَتِهِ وَكُتُبِهِ وَرُسُلِهِ لَا نُفَرِّقُ بَيْنَ أَحَدٍ مِنْ رُسُلِهِ ۚ وَقَالُوا سَمِعْنَا وَأَطَعْنَا ۖ غُفْرَانَكَ رَبَّنَا وَإِلَيْكَ الْمَصِيرُ ۝ لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا لَهَا مَا كَسَبَتْ وَعَلَيْهَا مَا اكْتَسَبَتْ رَبَّنَا لَا تُؤَاخِذْنَا إِنْ نَسِينَا أَوْ أَخْطَأْنَا رَبَّنَا وَلَا تَحْمِلْ عَلَيْنَا إِصْرًا كَمَا حَمَلْتَهُ عَلَى الَّذِينَ مِنْ قَبْلِنَا رَبَّنَا وَلَا تُحَمِّلْنَا مَا لَا طَاقَةَ لَنَا بِهِ وَاعْفُ عَنَّا وَاغْفِرْ لَنَا وَارْحَمْنَا أَنْتَ مَوْلَانَا فَانْصُرْنَا عَلَى الْقَوْمِ الْكَافِرِينَ﴾',
        source: 'سورة البقرة 285 - 286 | من قرأها في ليلة كفتاه',
        target: 1,
      ),
      ZikrItem(
        id: 203,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n﴿قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ﴾',
        source: 'من قالها حين يصبح وحين يمسي كفته من كل شيء',
        target: 3,
      ),
      ZikrItem(
        id: 204,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n﴿قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِنْ شَرِّ مَا خَلَقَ ۝ وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ﴾',
        source: 'سورة الفلق',
        target: 3,
      ),
      ZikrItem(
        id: 205,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n﴿قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ﴾',
        source: 'سورة الناس',
        target: 3,
      ),
      ZikrItem(
        id: 206,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ.',
        source: 'رواه مسلم',
        target: 1,
      ),
      ZikrItem(
        id: 207,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ.',
        source: 'سيد الاستغفار | من قالها موقناً بها حين يمسي ومات من ليلته دخل الجنة',
        target: 1,
        favorite: true,
      ),
      ZikrItem(
        id: 208,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا.',
        source: 'من قالها حين يصبح وحين يمسي كان حقاً على الله أن يرضيه يوم القيامة',
        target: 3,
      ),
      ZikrItem(
        id: 209,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ، وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّداً عَبْدُكَ وَرَسُولُكَ.',
        source: 'من قالها أربع مرات أعتقه الله من النار',
        target: 4,
      ),
      ZikrItem(
        id: 210,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'اللَّهُمَّ مَا أَمْسَى بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ، فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ.',
        source: 'من قالها حين يمسي فقد أدى شكر ليلته',
        target: 1,
      ),
      ZikrItem(
        id: 211,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ.',
        source: 'من قالها سبعاً كفاه الله ما أهمه من أمر الدنيا والآخرة',
        target: 7,
      ),
      ZikrItem(
        id: 212,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ.',
        source: 'من قالها ثلاثاً لم يضره شيء',
        target: 3,
        favorite: true,
      ),
      ZikrItem(
        id: 213,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ.',
        source: 'رواه الترمذي',
        target: 1,
      ),
      ZikrItem(
        id: 214,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'أَمْسَيْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ، وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفاً مُسْلِماً وَمَا كَانَ مِنَ الْمُشْرِكِينَ.',
        source: 'رواه أحمد',
        target: 1,
      ),
      ZikrItem(
        id: 215,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ.',
        source: 'رواه مسلم',
        target: 3,
      ),
      ZikrItem(
        id: 216,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ.',
        source: 'رواه أبو داود',
        target: 3,
      ),
      ZikrItem(
        id: 217,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ، وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لَا إِلَهَ إِلَّا أَنْتَ.',
        source: 'رواه أبو داود',
        target: 3,
      ),
      ZikrItem(
        id: 218,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي، اللَّهُمَّ اسْتُرْ عَوْرَاتِي وَآمِنْ رَوْعَاتِي، اللَّهُمَّ احْفَظْنِي مِنْ بَيْنِ يَدَيَّ وَمِنْ خَلْفِي وَعَنْ يَمِينِي وَعَنْ شِمَالِي وَمِنْ فَوْقِي، وَأَعُوذُ بِعَظَمَتِكَ أَنْ أُغْتَالَ مِنْ تَحْتِي.',
        source: 'رواه أبو داود وابن ماجه',
        target: 1,
      ),
      ZikrItem(
        id: 219,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ أَصْلِحْ لِي شَأْنِي كُلَّهُ وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ.',
        source: 'رواه النسائي والحاكم',
        target: 3,
      ),
      ZikrItem(
        id: 220,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذِهِ اللَّيْلَةِ، فَتْحَهَا، وَنَصْرَهَا، وَنُورَهَا، وَبَرَكَتَهَا، وَهُدَاهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِيهَا وَشَرِّ مَا بَعْدَهَا.',
        source: 'رواه أبو داود',
        target: 1,
      ),
      ZikrItem(
        id: 221,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'اللَّهُمَّ عَالِمَ الْغَيْبِ وَالشَّهَادَةِ فَاطِرَ السَّمَاوَاتِ وَالْأَرْضِ رَبَّ كُلِّ شَيْءٍ وَمَلِيكَهُ، أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا أَنْتَ، أَعُوذُ بِكَ مِنْ شَرِّ نَفْسِي وَمِنْ شَرِّ الشَّيْطَانِ وَشِرْكِهِ، وَأَنْ أَقْتَرِفَ عَلَى نَفْسِي سُوءًا أَوْ أَجُرَّهُ إِلَى مُسْلِمٍ.',
        source: 'رواه الترمذي',
        target: 1,
      ),
      ZikrItem(
        id: 222,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text: 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ.',
        source: 'رواه مسلم',
        target: 3,
      ),
      ZikrItem(
        id: 223,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text: 'اللَّهُمَّ صَلِّ وَسَلِّمْ وَبَارِكْ عَلَى نَبِيِّنَا مُحَمَّدٍ.',
        source: 'من صلى عليّ حين يصبح وحين يمسي أدركته شفاعتي يوم القيامة',
        target: 10,
      ),
      ZikrItem(
        id: 224,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'اللَّهُمَّ إِنَّا نَعُوذُ بِكَ مِنْ أَنْ نُشْرِكَ بِكَ شَيْئًا نَعْلَمُهُ، وَنَسْتَغْفِرُكَ لِمَا لَا نَعْلَمُهُ.',
        source: 'رواه أحمد',
        target: 3,
      ),
      ZikrItem(
        id: 225,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَأَعُوذُ بِكَ مِنَ الْعَجْزِ وَالْكَسَلِ، وَأَعُوذُ بِكَ مِنَ الْجُبْنِ وَالْبُخْلِ، وَأَعُوذُ بِكَ مِنْ غَلَبَةِ الدَّيْنِ وَقَهْرِ الرِّجَالِ.',
        source: 'رواه أبو داود',
        target: 3,
      ),
      ZikrItem(
        id: 226,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ، الْحَيُّ الْقَيُّومُ، وَأَتُوبُ إِلَيْهِ.',
        source: 'رواه أبو داود والترمذي',
        target: 3,
      ),
      ZikrItem(
        id: 227,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'يَا رَبِّ، لَكَ الْحَمْدُ كَمَا يَنْبَغِي لِجَلَالِ وَجْهِكَ، وَلِعَظِيمِ سُلْطَانِكَ.',
        source: 'رواه ابن ماجه',
        target: 3,
      ),
      ZikrItem(
        id: 228,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
        source: 'كانت له عدل عشر رقاب، وكتبت له مئة حسنة، وحرزاً من الشيطان',
        target: 10,
      ),
      ZikrItem(
        id: 229,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text:
            'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، عَلَيْكَ تَوَكَّلْتُ، وَأَنْتَ رَبُّ الْعَرْشِ الْعَظِيمِ، مَا شَاءَ اللَّهُ كَانَ، وَمَا لَمْ يَشَأْ لَمْ يَكُنْ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ الْعَلِيِّ الْعَظِيمِ، أَعْلَمُ أَنَّ اللَّهَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، وَأَنَّ اللَّهَ قَدْ أَحَاطَ بِكُلِّ شَيْءٍ عِلْمًا، اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ شَرِّ نَفْسِي، وَمِنْ شَرِّ كُلِّ دَابَّةٍ أَنْتَ آخِذٌ بِنَاصِيَتِهَا، إِنَّ رَبِّي عَلَى صِرَاطٍ مُسْتَقِيمٍ.',
        source: 'حفظٌ من الآفات',
        target: 1,
      ),
      ZikrItem(
        id: 230,
        category: 'evening',
        categoryLabel: 'أذكار المساء',
        text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.',
        source: 'من قالها مئة مرة حطت خطاياه وإن كانت مثل زبد البحر',
        target: 100,
      ),

      // ==========================================
      // 3. أذكار النوم (حصن المسلم)
      // ==========================================
      ZikrItem(
        id: 301,
        category: 'sleep',
        categoryLabel: 'أذكار النوم',
        text:
            'يجمع كفيه ثم ينفث فيهما فيقرأ: ﴿قُلْ هُوَ اللَّهُ أَحَدٌ﴾ و﴿قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ﴾ و﴿قُلْ أَعُوذُ بِرَبِّ النَّاسِ﴾، ثم يمسح بهما ما استطاع من جسده يبدأ بهما على رأسه ووجهه وما أقبل من جسده.',
        source: 'متفق عليه',
        target: 3,
      ),
      ZikrItem(
        id: 302,
        category: 'sleep',
        categoryLabel: 'أذكار النوم',
        text:
            '﴿اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ وَلَا يَئُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ﴾',
        source: 'آية الكرسي | لا يزال عليك من الله حافظ ولا يقربك شيطان حتى تصبح',
        target: 1,
        favorite: true,
      ),
      ZikrItem(
        id: 303,
        category: 'sleep',
        categoryLabel: 'أذكار النوم',
        text:
            'بِاسْمِكَ رَبِّي وَضَعْتُ جَنْبِي، وَبِكَ أَرْفَعُهُ، فَإِنْ أَمْسَكْتَ نَفْسِي فَارْحَمْهَا، وَإِنْ أَرْسَلْتَهَا فَاحْفَظْهَا بِمَا تَحْفَظُ بِهِ عِبَادَكَ الصَّالِحِينَ.',
        source: 'متفق عليه',
        target: 1,
      ),
      ZikrItem(
        id: 304,
        category: 'sleep',
        categoryLabel: 'أذكار النوم',
        text:
            'اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ.',
        source: 'رواه أبو داود والترمذي',
        target: 3,
      ),
      ZikrItem(
        id: 305,
        category: 'sleep',
        categoryLabel: 'أذكار النوم',
        text: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا.',
        source: 'رواه البخاري',
        target: 1,
      ),
      ZikrItem(
        id: 306,
        category: 'sleep',
        categoryLabel: 'أذكار النوم',
        text: 'سُبْحَانَ اللَّهِ (33)، وَالْحَمْدُ لِلَّهِ (33)، وَاللَّهُ أَكْبَرُ (34).',
        source: 'متفق عليه',
        target: 1,
      ),
      ZikrItem(
        id: 307,
        category: 'sleep',
        categoryLabel: 'أذكار النوم',
        text:
            'اللَّهُمَّ أَسْلَمْتُ نَفْسِي إِلَيْكَ، وَفَوَّضْتُ أَمْرِي إِلَيْكَ، وَوَجَّهْتُ وَجْهِي إِلَيْكَ، وَأَلْجَأْتُ ظَهْرِي إِلَيْكَ، رَغْبَةً وَرَهْبَةً إِلَيْكَ، لَا مَلْجَأَ وَلَا مَنْجَا مِنْكَ إِلَّا إِلَيْكَ، آمَنْتُ بِكِتَابِكَ الَّذِي أَنْزَلْتَ، وَبِنَبِيِّكَ الَّذِي أَرْسَلْتَ.',
        source: 'متفق عليه',
        target: 1,
      ),

      // ==========================================
      // 4. أذكار الاستيقاظ
      // ==========================================
      ZikrItem(
        id: 401,
        category: 'wakeup',
        categoryLabel: 'أذكار الاستيقاظ',
        text:
            'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ.',
        source: 'رواه البخاري',
        target: 1,
      ),
      ZikrItem(
        id: 402,
        category: 'wakeup',
        categoryLabel: 'أذكار الاستيقاظ',
        text:
            'الْحَمْدُ لِلَّهِ الَّذِي عَافَانِي فِي جَسَدِي، وَرَدَّ عَلَيَّ رُوحِي، وَأَذِنَ لِي بِذِكْرِهِ.',
        source: 'رواه الترمذي',
        target: 1,
      ),
      ZikrItem(
        id: 403,
        category: 'wakeup',
        categoryLabel: 'أذكار الاستيقاظ',
        text:
            'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ الْعَلِيِّ الْعَظِيمِ، رَبِّ اغْفِرْ لِي.',
        source: 'رواه البخاري',
        target: 1,
      ),

      // ==========================================
      // 5. أذكار بعد الصلاة
      // ==========================================
      ZikrItem(
        id: 501,
        category: 'prayer',
        categoryLabel: 'أذكار بعد الصلاة',
        text:
            'أَسْتَغْفِرُ اللَّهَ (ثلاثاً)، اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ.',
        source: 'رواه مسلم',
        target: 1,
      ),
      ZikrItem(
        id: 502,
        category: 'prayer',
        categoryLabel: 'أذكار بعد الصلاة',
        text:
            'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، اللَّهُمَّ لَا مَانِعَ لِمَا أَعْطَيْتَ، وَلَا مُعْطِيَ لِمَا مَنَعْتَ، وَلَا يَنْفَعُ ذَا الْجَدِّ مِنْكَ الْجَدُّ.',
        source: 'متفق عليه',
        target: 1,
      ),
      ZikrItem(
        id: 503,
        category: 'prayer',
        categoryLabel: 'أذكار بعد الصلاة',
        text: 'سُبْحَانَ اللَّهِ (33) • الْحَمْدُ لِلَّهِ (33) • اللَّهُ أَكْبَرُ (33)',
        source: 'رواه مسلم',
        target: 33,
      ),
      ZikrItem(
        id: 504,
        category: 'prayer',
        categoryLabel: 'أذكار بعد الصلاة',
        text:
            '﴿اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ...﴾ (آية الكرسي).',
        source: 'من قرأها دبر كل صلاة مكتوبة لم يمنعه من دخول الجنة إلا أن يموت',
        target: 1,
      ),
      ZikrItem(
        id: 505,
        category: 'prayer',
        categoryLabel: 'أذكار بعد الصلاة',
        text:
            'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ، وَشُكْرِكَ، وَحُسْنِ عِبَادَتِكَ.',
        source: 'رواه أبو داود والنسائي',
        target: 1,
      ),

      // ==========================================
      // 6. المنزل والسفر (اليومية)
      // ==========================================
      ZikrItem(
        id: 601,
        category: 'daily',
        categoryLabel: 'المنزل والسفر',
        text:
            'بِسْمِ اللَّهِ، تَوَكَّلْتُ عَلَى اللَّهِ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ.',
        source: 'دعاء الخروج من المنزل | رواه أبو داود والترمذي',
        target: 1,
        favorite: true,
      ),
      ZikrItem(
        id: 602,
        category: 'daily',
        categoryLabel: 'المنزل والسفر',
        text:
            'بِسْمِ اللَّهِ وَلَجْنَا، وَبِسْمِ اللَّهِ خَرَجْنَا، وَعَلَى اللَّهِ رَبِّنَا تَوَكَّلْنَا.',
        source: 'دعاء دخول المنزل | رواه أبو داود',
        target: 1,
      ),
      ZikrItem(
        id: 603,
        category: 'daily',
        categoryLabel: 'المنزل والسفر',
        text:
            'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ، وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ.',
        source: 'دعاء الركوب والسفر | رواه مسلم',
        target: 1,
      ),
      ZikrItem(
        id: 604,
        category: 'daily',
        categoryLabel: 'المنزل والسفر',
        text:
            'بِسْمِ اللَّهِ، اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْخُبُثِ وَالْخَبَائِثِ.',
        source: 'دعاء دخول الخلاء | متفق عليه',
        target: 1,
      ),
      ZikrItem(
        id: 605,
        category: 'daily',
        categoryLabel: 'المنزل والسفر',
        text: 'غُفْرَانَكَ.',
        source: 'دعاء الخروج من الخلاء | رواه أبو داود والترمذي',
        target: 1,
      ),
      ZikrItem(
        id: 606,
        category: 'daily',
        categoryLabel: 'المنزل والسفر',
        text:
            'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلَا قُوَّةٍ.',
        source: 'دعاء الفراغ من الطعام | رواه الترمذي',
        target: 1,
      ),

      // ==========================================
      // 7. الأدعية الجامعة
      // ==========================================
      ZikrItem(
        id: 701,
        category: 'supplications',
        categoryLabel: 'الأدعية الجامعة',
        text:
            'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ.',
        source: 'سورة البقرة: 201',
        target: 1,
        favorite: true,
      ),
      ZikrItem(
        id: 702,
        category: 'supplications',
        categoryLabel: 'الأدعية الجامعة',
        text:
            'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ.',
        source: 'دعاء ذي النون | رواه الترمذي',
        target: 3,
      ),
      ZikrItem(
        id: 703,
        category: 'supplications',
        categoryLabel: 'الأدعية الجامعة',
        text:
            'يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ.',
        source: 'رواه الترمذي',
        target: 3,
      ),
      ZikrItem(
        id: 704,
        category: 'supplications',
        categoryLabel: 'الأدعية الجامعة',
        text:
            'اللَّهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ الْعَفْوَ فَاعْفُ عَنِّي.',
        source: 'رواه الترمذي',
        target: 3,
      ),
      ZikrItem(
        id: 705,
        category: 'supplications',
        categoryLabel: 'الأدعية الجامعة',
        text:
            'اللَّهُمَّ اغْفِرْ لِي، وَارْحَمْنِي، وَاهْدِنِي، وَعَافِنِي، وَارْزُقْنِي.',
        source: 'رواه مسلم',
        target: 1,
      ),
    ];

const Map<int, String> kAzkarEnglishById = {
  // Morning (101-129)
  101: 'Ayat Al-Kursi: Allah — there is no deity except Him, the Ever-Living, the Sustainer of all existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what is before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His Kursi extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great.',
  102: 'Surah Al-Ikhlas: Say, He is Allah, the One. Allah, the Eternal Refuge. He neither begets nor is born, nor is there to Him any equivalent.',
  103: 'Surah Al-Falaq: Say, I seek refuge in the Lord of daybreak, from the evil of that which He created, and from the evil of darkness when it settles, and from the evil of the blowers in knots, and from the evil of an envier when he envies.',
  104: 'Surah An-Nas: Say, I seek refuge in the Lord of mankind, the Sovereign of mankind, the God of mankind, from the evil of the retreating whisperer, who whispers into the breasts of mankind, from among the jinn and mankind.',
  105: 'We have reached the morning and at this very time all sovereignty belongs to Allah, and all praise is for Allah. None has the right to be worshipped except Allah alone, without partner.',
  106: 'Sayyid Al-Istighfar: O Allah, You are my Lord, none has the right to be worshipped except You. You created me and I am Your servant, and I abide to Your covenant and promise as best I can. I seek refuge in You from the evil of what I have done. I acknowledge Your favor upon me and I acknowledge my sin, so forgive me, for verily none can forgive sins except You.',
  107: 'Raditu billahi Rabban wa bil-Islami dinan wa bi-Muhammadin (peace be upon him) nabiyya. (I am pleased with Allah as my Lord, Islam as my religion, and Muhammad as my Prophet.)',
  108: 'O Allah, verily I have reached the morning and call on You, the bearers of Your throne, Your angels, and all creation to witness that You are Allah, none has the right to be worshipped except You alone.',
  109: 'O Allah, whatever blessing I or any of Your creation have risen upon is from You alone, without partner, so for You is all praise and unto You all thanks.',
  110: 'HasbiyAllahu la ilaha illa Huwa, alayhi tawakkaltu wa Huwa Rabbul-Arshil-Azim. (Allah is sufficient for me; none has the right to be worshipped except Him; upon Him I rely.)',
  111: 'Bismillahil-ladhi la yadurru ma’asmihi shay’un fil-ardi wa la fis-sama’i wa Huwas-Sami’ul-Alim. (In the name of Allah with whose name nothing on earth or in heaven can harm.)',
  112: 'O Allah, by Your leave we have reached the morning and by Your leave we have reached the evening, by Your leave we live and die and unto You is our resurrection.',
  113: 'We have risen upon the natural religion of Islam, the word of sincere devotion, the religion of our Prophet Muhammad, and the faith of our father Ibrahim.',
  114: 'SubhanAllahi wa bihamdihi: adada khalqihi, wa rida nafsihi, wa zinata arshihi, wa midada kalimatih.',
  115: 'O Allah, grant my body health, O Allah, grant my hearing health, O Allah, grant my sight health. None has the right to be worshipped except You.',
  116: 'O Allah, I seek refuge in You from disbelief and poverty, and I seek refuge in You from the punishment of the grave. None has the right to be worshipped except You.',
  117: 'O Allah, I ask You for pardon and well-being in this life and the next. O Allah, conceal my faults and calm my fears, and protect me from before me, behind me, my right, my left, and above me.',
  118: 'Ya Hayyu Ya Qayyum, bi-rahmatika astaghith, aslih li sha’ni kullahu wa la takilni ila nafsi tarfata ayn. (O Ever-Living, O Sustainer, in Your mercy I seek relief; rectify all my affairs.)',
  119: 'We have reached the morning and all sovereignty belongs to Allah, Lord of the worlds. O Allah, I ask You for the good of this day: its victory, its light, its blessings, and its guidance.',
  120: 'O Allah, Knower of the unseen and the seen, Creator of the heavens and the earth, I seek refuge in You from the evil of my own soul and from the evil of Satan.',
  121: 'A’udhu bi-kalimatillahit-tammati min sharri ma khalaq. (I seek refuge in the perfect words of Allah from the evil of what He has created.)',
  122: 'Allahumma salli wa sallim wa barik ala Nabiyyina Muhammad. (O Allah, send peace and blessings upon our Prophet Muhammad.)',
  123: 'O Allah, we seek refuge in You from associating anything with You knowingly, and we seek Your forgiveness for what we do unknowingly.',
  124: 'O Allah, I seek refuge in You from anxiety and sorrow, weakness and laziness, miserliness and cowardice, the burden of debts and being overpowered by men.',
  125: 'Astaghfirullahal-Azimal-ladhi la ilaha illa Huwal-Hayyul-Qayyum wa atubu ilayh.',
  126: 'Ya Rabbi lakal-hamdu kama yanbaghi li-jalali wajhika wa li-azimi sultanik.',
  127: 'La ilaha illAllahu wahdahu la sharika lah, lahul-mulku wa lahul-hamdu wa Huwa ala kulli shay’in Qadir.',
  128: 'O Allah, You are my Lord, none has the right to be worshipped except You. Upon You I rely, and You are the Lord of the Mighty Throne. Whatever Allah wills happens, and whatever He does not will does not happen. There is no power nor strength except by Allah, the Most High, the Most Great. I know that Allah has power over all things and that Allah encompasses all things in knowledge. O Allah, I seek refuge in You from the evil of my soul and from the evil of every creature You hold by its forelock. Indeed, my Lord is on a straight path.',
  129: 'SubhanAllahi wa bihamdih. (Glory be to Allah and praise Him.)',

  // Evening (201-230)
  201: 'Ayat Al-Kursi: Allah — there is no deity except Him, the Ever-Living, the Sustainer of all existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what is before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His Kursi extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great.',
  202: 'Al-Baqarah (285-286): The Messenger has believed in what was revealed to him from his Lord, and so have the believers. All of them have believed in Allah and His angels and His books and His messengers, saying: We make no distinction between any of His messengers. And they say: We hear and we obey. Your forgiveness, our Lord, and to You is the final destination. Allah does not charge a soul except with that within its capacity. It will have the consequence of what good it has gained, and it will bear the consequence of what evil it has earned. Our Lord, do not impose blame upon us if we have forgotten or erred. Our Lord, and lay not upon us a burden like that which You laid upon those before us. Our Lord, and burden us not with that which we have no ability to bear. And pardon us, and forgive us, and have mercy upon us. You are our protector, so give us victory over the disbelieving people.',
  203: 'Surah Al-Ikhlas: Say, He is Allah, the One. Allah, the Eternal Refuge. He neither begets nor is born, nor is there to Him any equivalent.',
  204: 'Surah Al-Falaq: Say, I seek refuge in the Lord of daybreak, from the evil of that which He created, and from the evil of darkness when it settles, and from the evil of the blowers in knots, and from the evil of an envier when he envies.',
  205: 'Surah An-Nas: Say, I seek refuge in the Lord of mankind, the Sovereign of mankind, the God of mankind, from the evil of the retreating whisperer, who whispers into the breasts of mankind, from among the jinn and mankind.',
  206: 'We have reached the evening and at this very time all sovereignty belongs to Allah, and all praise is for Allah',
  207: 'Sayyid Al-Istighfar: O Allah, You are my Lord, none has the right to be worshipped except You... forgive me, for none forgives sins except You.',
  208: 'Raditu billahi Rabban wa bil-Islami dinan wa bi-Muhammadin (peace be upon him) nabiyya.',
  209: 'O Allah, verily I have reached the evening and call on You, the bearers of Your throne, Your angels, and all creation to witness that You are Allah',
  210: 'O Allah, whatever blessing I or any of Your creation have entered the evening upon is from You alone, without partner',
  211: 'HasbiyAllahu la ilaha illa Huwa, alayhi tawakkaltu wa Huwa Rabbul-Arshil-Azim.',
  212: 'Bismillahil-ladhi la yadurru ma’asmihi shay’un fil-ardi wa la fis-sama’i wa Huwas-Sami’ul-Alim.',
  213: 'O Allah, by Your leave we have reached the evening and by Your leave we have reached the morning, by Your leave we live and die and unto You is our return.',
  214: 'We have entered the evening upon the natural religion of Islam, the word of sincere devotion, and the religion of our Prophet Muhammad.',
  215: 'SubhanAllahi wa bihamdihi: adada khalqihi, wa rida nafsihi, wa zinata arshihi, wa midada kalimatih.',
  216: 'O Allah, grant my body health, O Allah, grant my hearing health, O Allah, grant my sight health. None has the right to be worshipped except You.',
  217: 'O Allah, I seek refuge in You from disbelief and poverty, and from the punishment of the grave.',
  218: 'O Allah, I ask You for pardon and well-being in this life and the next. Conceal my faults and calm my fears',
  219: 'Ya Hayyu Ya Qayyum, bi-rahmatika astaghith, aslih li sha’ni kullahu wa la takilni ila nafsi tarfata ayn.',
  220: 'We have reached the evening and all sovereignty belongs to Allah, Lord of the worlds. O Allah, I ask You for the good of this night',
  221: 'O Allah, Knower of the unseen and the seen, Creator of the heavens and the earth, I seek refuge in You from the evil of my own soul',
  222: 'A’udhu bi-kalimatillahit-tammati min sharri ma khalaq.',
  223: 'Allahumma salli wa sallim wa barik ala Nabiyyina Muhammad.',
  224: 'O Allah, we seek refuge in You from associating anything with You knowingly, and seek Your forgiveness for what we do unknowingly.',
  225: 'O Allah, I seek refuge in You from anxiety and sorrow, weakness and laziness, miserliness and cowardice, debt and oppression.',
  226: 'Astaghfirullahal-Azimal-ladhi la ilaha illa Huwal-Hayyul-Qayyum wa atubu ilayh.',
  227: 'Ya Rabbi lakal-hamdu kama yanbaghi li-jalali wajhika wa li-azimi sultanik.',
  228: 'La ilaha illAllahu wahdahu la sharika lah, lahul-mulku wa lahul-hamdu wa Huwa ala kulli shay’in Qadir.',
  229: 'O Allah, You are my Lord, none has the right to be worshipped except You. Upon You I rely',
  230: 'SubhanAllahi wa bihamdih.',

  // Sleep (301-307)
  301: 'Cup your palms together, blow gently into them, recite Al-Ikhlas, Al-Falaq, and An-Nas, and wipe over your head, face, and body.',
  302: 'Ayat Al-Kursi before sleep: Allah — there is no deity except Him, the Ever-Living, the Sustainer of all existence',
  303: 'Bismika Rabbi wada’tu janbi, wa bika arfa’uh. (In Your name my Lord, I lie down and in Your name I rise.)',
  304: 'Allahumma qini adhabaka yawma tab’athu ibadak. (O Allah, protect me from Your punishment on the Day You resurrect Your servants.)',
  305: 'Bismika Allahumma amutu wa ahya. (In Your name, O Allah, I die and I live.)',
  306: 'SubhanAllah (33), Alhamdulillah (33), Allahu Akbar (34).',
  307: 'O Allah, I submit my soul to You, entrust my affairs to You, and turn my face to You in hope and fear',

  // Wakeup (401-403)
  401: 'Alhamdulillahil-ladhi ahyana ba’da ma amatana wa ilayhin-nushur. (All praise is for Allah who gave us life after causing us to die, and unto Him is the resurrection.)',
  402: 'All praise is for Allah who gave strength to my body, returned my soul to me, and permitted me to remember Him.',
  403: 'La ilaha illAllahu wahdahu la sharika lah... SubhanAllah, Alhamdulillah, La ilaha illAllah, Allahu Akbar, Rabbi-ghfir li.',

  // After Prayer (501-505)
  501: 'Astaghfirullah (3x). Allahumma Antas-Salam wa minkas-salam, tabarakta ya Dhal-Jalali wal-Ikram.',
  502: 'La ilaha illAllahu wahdahu la sharika lah... O Allah, none can withhold what You give, and none can give what You withhold.',
  503: 'SubhanAllah (33) • Alhamdulillah (33) • Allahu Akbar (33).',
  504: 'Recite Ayat Al-Kursi after every obligatory prayer.',
  505: 'Allahumma a’inni ala dhikrika, wa shukrika, wa husni ibadatik. (O Allah, help me to remember You, thank You, and worship You in the best manner.)',

  // Home & Travel (601-606)
  601: 'Bismillahi, tawakkaltu alAllahi, wa la hawla wa la quwwata illa billah. (Leaving home)',
  602: 'Bismillahi walajna, wa bismillahi kharajna, wa ala Rabbina tawakkalna. (Entering home)',
  603: 'Subhanal-ladhi sakhkhara lana hadha wa ma kunna lahu muqrinin, wa inna ila Rabbina lamunqalibun. (Travel / Riding)',
  604: 'Bismillahi, Allahumma inni a’udhu bika minal-khubuthi wal-khaba’ith. (Entering restroom)',
  605: 'Ghufranaka. (I seek Your forgiveness — leaving restroom)',
  606: 'Alhamdulillahil-ladhi at’amani hadha wa razaqanihi min ghayri hawlin minni wa la quwwah. (After eating)',

  // Comprehensive Duas (701-705)
  701: 'Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina adhaban-nar.',
  702: 'La ilaha illa Anta subhanaka inni kuntu minaz-zalimin.',
  703: 'Ya Muqallibal-qulubi thabbit qalbi ala dinik. (O Turner of hearts, keep my heart firm upon Your religion.)',
  704: 'Allahumma innaka Afuwwun tuhibbul-afwa fa’fu anni. (O Allah, You are Pardoning and love to pardon, so pardon me.)',
  705: 'Allahummaghfir li, warhamni, wahdini, wa’afini, warzuqni.',
};


const Map<int, String> kAzkarTurkishById = {
  // Sabah Zikirleri (101-129)
  101: 'Ayetel Kürsi: Allah’tan başka ilah yoktur; O diridir, her şeyin varlığı O’na bağlıdır. Kendisine ne uyku gelir ne de uyuklama. Göklerde ve yerde ne varsa O’nundur. İzni olmadan O’nun katında kim şefaat edebilir? O, kullarının önlerindekini ve arkalarındakini bilir. Dilediği kadarının dışında O’nun ilminden hiçbir şey kavrayamazlar. O’nun kürsüsü gökleri ve yeri içine alır; onları koruyup gözetmek O’na ağır gelmez. O, çok yücedir, çok büyüktür.',
  102: 'İhlas Suresi: De ki: O, Allah birdir. Allah Samed’dir. Doğurmamış ve doğurulmamıştır. Hiçbir şey O’na denk değildir.',
  103: 'Felak Suresi: De ki: Yarattığı şeylerin şerrinden, karanlığı çöktüğü zaman gecenin şerrinden, düğümlere üfleyenlerin şerrinden ve haset ettiği zaman hasetçinin şerrinden sabahın Rabbine sığınırım.',
  104: 'Nas Suresi: De ki: İnsanların Rabbine, insanların Melikine, insanların İlahına; sinsi vesvesecinin şerrinden —ki o insanların göğüslerine vesvese verir— gerek cinlerden gerek insanlardan olsun, Allah’a sığınırım.',
  105: 'Sabaha eriştik, mülk de Allah’ın olarak sabahladı. Hamd Allah’a mahsustur. Allah’tan başka ilah yoktur, O tektir, ortağı yoktur.',
  106: 'Seyyidül İstiğfar: Allah’ım! Sen benim Rabbimsin, Senden başka ilah yoktur. Beni Sen yarattın ve ben Senin kulunum. Gücüm yettiğince Senin ahdin ve vaadin üzereyim. Yaptıklarımın şerrinden Sana sığınırım. Üzerimdeki nimetini itiraf ediyor, günahımı da kabul ediyorum; beni bağışla, çünkü günahları ancak Sen bağışlarsın.',
  107: 'Rab olarak Allah’tan, din olarak İslam’dan, peygamber olarak Hz. Muhammed’den (s.a.v.) razı oldum.',
  108: 'Allah’ım! Sabaha erdim; Seni, Arş’ını taşıyanları, meleklerini ve bütün yarattıklarını şahit tutarım ki Sen Allah’sın, Senden başka ilah yoktur.',
  109: 'Allah’ım! Benimle veya yarattıklarından herhangi biriyle sabahlayan her nimet yalnız Sendendir, Senin ortağın yoktur. Hamd ve şükür yalnız Sanadır.',
  110: 'Hasbiyallahu la ilahe illa Hu, aleyhi tevekkeltü ve Huve Rabbül-Arşil-Azim. (Allah bana yeter; O’ndan başka ilah yoktur, yalnız O’na güvendim.)',
  111: 'Bismillahillezi la yedurru ma’asmihi şey’ün fil-ardı ve la fis-sema’i ve Huves-Semi’ul-Alim. (İsmiyle yerde ve gökte hiçbir şeyin zarar veremeyeceği Allah’ın adıyla.)',
  112: 'Allah’ım! Senin yardımınla sabahladık, Senin yardımınla akşamladık, Seninle yaşar, Seninle ölürüz ve dönüş yalnız Sanadır.',
  113: 'İslam fıtratı, ihlas kelimesi, Peygamberimiz Muhammed’in (s.a.v.) dini ve atamız İbrahim’in hanif milleti üzere sabahladık.',
  114: 'Subhanallahi ve bihamdihi: yarattıkları sayısınca, rızasınca, Arş’ının ağırlığınca ve kelimelerinin adedince.',
  115: 'Allah’ım! Bedenime afiyet ver, kulağıma afiyet ver, gözüme afiyet ver. Senden başka ilah yoktur.',
  116: 'Allah’ım! Küfürden ve fakirlikten Sana sığınırım; kabir azabından da Sana sığınırım. Senden başka ilah yoktur.',
  117: 'Allah’ım! Dünyada ve ahirette Senden af ve afiyet dilerim. Ayıplarımı ört, korkularımı güvene çevir, beni önümden, arkamdan, sağımdan, solumdan ve üstümden koru.',
  118: 'Ya Hayyu Ya Kayyum! Rahmetinle yardım istiyorum; bütün işlerimi düzelt ve beni göz açıp kapayıncaya kadar nefsime bırakma.',
  119: 'Alemlerin Rabbi Allah’a hamdolsun, mülk O’nun olarak sabahladık. Allah’ım! Senden bugünün hayrını, fethini, yardımını, nurunu, bereketini ve hidayetini isterim.',
  120: 'Gizliyi ve açığı bilen, göklerin ve yerin yaratıcısı Allah’ım! Nefsimin şerrinden ve şeytanın şerrinden Sana sığınırım.',
  121: 'Yarattıklarının şerrinden Allah’ın eksiksiz kelimelerine sığınırım.',
  122: 'Allah’ım! Peygamberimiz Muhammed’e salat, selam ve bereket ihsan eyle.',
  123: 'Allah’ım! Bilerek Sana ortak koşmaktan Sana sığınır, bilmediklerimiz için Senden bağışlanma dileriz.',
  124: 'Allah’ım! Üzüntü ve kederden, acizlik ve tembellikten, korkaklık ve cimrilikten, borç yükünden ve insanların baskısından Sana sığınırım.',
  125: 'Kendisinden başka ilah olmayan, diri ve kayyum olan Yüce Allah’tan bağışlanma diler ve O’na tövbe ederim.',
  126: 'Rabbim! Yüzünün celaline ve saltanatının azametine yakışır şekilde Sana hamdolsun.',
  127: 'Allah’tan başka ilah yoktur, O tektir, ortağı yoktur. Mülk O’nundur, hamd O’nadır ve O her şeye kadirdir.',
  128: 'Allah’ım! Sen benim Rabbimsin, Senden başka ilah yoktur. Sana tevekkül ettim, Sen Yüce Arş’ın Rabbisin. Allah’ın dilediği olur, dilemediği olmaz. Yüce ve Büyük olan Allah’tan başka güç ve kuvvet yoktur. Bilirim ki Allah her şeye kadirdir ve Allah’ın ilmi her şeyi kuşatmıştır. Allah’ım! Nefsimin şerrinden ve perçeminden tuttuğun her canlının şerrinden Sana sığınırım. Şüphesiz Rabbim dosdoğru bir yol üzerindedir.',
  129: 'Subhanallahi ve bihamdih. (Allah’ı hamd ile tesbih ederim.)',

  // Akşam Zikirleri (201-230)
  201: 'Ayetel Kürsi: Allah’tan başka ilah yoktur; O diridir, her şeyin varlığı O’na bağlıdır. Kendisine ne uyku gelir ne de uyuklama. Göklerde ve yerde ne varsa O’nundur. İzni olmadan O’nun katında kim şefaat edebilir? O, kullarının önlerindekini ve arkalarındakini bilir. Dilediği kadarının dışında O’nun ilminden hiçbir şey kavrayamazlar. O’nun kürsüsü gökleri ve yeri içine alır; onları koruyup gözetmek O’na ağır gelmez. O, çok yücedir, çok büyüktür.',
  202: 'Amenerrasulü (Bakara 285-286): Peygamber, Rabbinden kendisine indirilene iman etti, müminler de. Her biri Allah’a, meleklerine, kitaplarına ve peygamberlerine iman etti. Peygamberlerinden hiçbiri arasında ayrım yapmayız, işittik ve itaat ettik, Rabbimiz bağışlamanı dileriz, dönüş yalnız Sanadır dediler. Allah kimseye gücünün yeteceğinden fazlasını yüklemez. Herkesin kazandığı iyilik kendi lehine, işlediği kötülük de kendi aleyhinedir. Rabbimiz! Unutur veya yanılırsak bizi sorumlu tutma. Rabbimiz! Bize bizden öncekilere yüklediğin gibi ağır yük yükleme. Rabbimiz! Güç yetiremeyeceğimiz şeyi bize taşıtma. Bizi affet, bizi bağışla, bize merhamet et. Sen bizim mevlamızsın, kafirler topluluğuna karşı bize yardım et.',
  203: 'İhlas Suresi: De ki: O, Allah birdir. Allah Samed’dir. Doğurmamış ve doğurulmamıştır. Hiçbir şey O’na denk değildir.',
  204: 'Felak Suresi: De ki: Yarattığı şeylerin şerrinden, karanlığı çöktüğü zaman gecenin şerrinden, düğümlere üfleyenlerin şerrinden ve haset ettiği zaman hasetçinin şerrinden sabahın Rabbine sığınırım.',
  205: 'Nas Suresi: De ki: İnsanların Rabbine, insanların Melikine, insanların İlahına; sinsi vesvesecinin şerrinden —ki o insanların göğüslerine vesvese verir— gerek cinlerden gerek insanlardan olsun, Allah’a sığınırım.',
  206: 'Akşama eriştik, mülk de Allah’ın olarak akşamladı. Hamd Allah’a mahsustur',
  207: 'Seyyidül İstiğfar: Allah’ım! Sen benim Rabbimsin, Senden başka ilah yoktur... Beni bağışla.',
  208: 'Rab olarak Allah’tan, din olarak İslam’dan, peygamber olarak Hz. Muhammed’den razı oldum.',
  209: 'Allah’ım! Akşama erdim; Seni, Arş’ını taşıyanları ve meleklerini şahit tutarım ki Sen Allah’sın',
  210: 'Allah’ım! Benimle veya yarattıklarından biriyle akşamlayan her nimet yalnız Sendendir',
  211: 'Hasbiyallahu la ilahe illa Hu, aleyhi tevekkeltü ve Huve Rabbül-Arşil-Azim.',
  212: 'Bismillahillezi la yedurru ma’asmihi şey’ün fil-ardı ve la fis-sema’i ve Huves-Semi’ul-Alim.',
  213: 'Allah’ım! Senin yardımınla akşamladık, Senin yardımınla sabahladık, Seninle yaşar, Seninle ölürüz ve dönüş Sanadır.',
  214: 'İslam fıtratı, ihlas kelimesi ve Peygamberimiz Muhammed’in (s.a.v.) dini üzere akşamladık.',
  215: 'Subhanallahi ve bihamdihi: yarattıkları sayısınca, rızasınca, Arş’ının ağırlığınca ve kelimelerinin adedince.',
  216: 'Allah’ım! Bedenime, kulağıma ve gözüme afiyet ver. Senden başka ilah yoktur.',
  217: 'Allah’ım! Küfürden, fakirlikten ve kabir azabından Sana sığınırım.',
  218: 'Allah’ım! Dünyada ve ahirette af ve afiyet dilerim. Ayıplarımı ört, korkularımı güvene çevir',
  219: 'Ya Hayyu Ya Kayyum! Rahmetinle yardım istiyorum; bütün işlerimi düzelt.',
  220: 'Alemlerin Rabbi Allah’a hamdolsun, mülk O’nun olarak akşamladık. Allah’ım! Bu gecenin hayrını isterim',
  221: 'Gizliyi ve açığı bilen Allah’ım! Nefsimin ve şeytanın şerrinden Sana sığınırım.',
  222: 'Yarattıklarının şerrinden Allah’ın eksiksiz kelimelerine sığınırım.',
  223: 'Allah’ım! Peygamberimiz Muhammed’e salat, selam ve bereket ihsan eyle.',
  224: 'Allah’ım! Bilerek ortak koşmaktan Sana sığınır, bilmediklerimiz için bağışlanma dileriz.',
  225: 'Allah’ım! Üzüntüden, kederden, acizlikten, tembellikten, borç yükünden ve insanların baskısından Sana sığınırım.',
  226: 'Kendisinden başka ilah olmayan Yüce Allah’tan bağışlanma diler ve O’na tövbe ederim.',
  227: 'Rabbim! Yüzünün celaline ve saltanatının azametine yakışır şekilde Sana hamdolsun.',
  228: 'Allah’tan başka ilah yoktur, O tektir, ortağı yoktur. Mülk O’nundur ve O her şeye kadirdir.',
  229: 'Allah’ım! Sen benim Rabbimsin, sana tevekkül ettim, Sen Yüce Arş’ın Rabbisin',
  230: 'Subhanallahi ve bihamdih.',

  // Uyku Zikirleri (301-307)
  301: 'İki avucunu birleştirip üfleyerek İhlas, Felak ve Nas surelerini oku ve başından başlayarak vücuduna meshet.',
  302: 'Uyku öncesi Ayetel Kürsi: Allah’tan başka ilah yoktur; O diridir, kayyumdur',
  303: 'Rabbim! Senin adınla yanımı yere koydum ve Senin adınla kalkarım.',
  304: 'Allah’ım! Kullarını dirilteceğin gün beni azabından koru.',
  305: 'Allah’ım! Senin adınla ölür ve Senin adınla dirilirim.',
  306: 'Subhanallah (33), Elhamdülillah (33), Allahu Ekber (34).',
  307: 'Allah’ım! Kendimi Sana teslim ettim, işimi Sana havale ettim, ümit ve korkuyla yüzümü Sana çevirdim',

  // Uyanış Zikirleri (401-403)
  401: 'Bizi öldürdükten sonra dirilten Allah’a hamdolsun. Dönüş de O’nadır.',
  402: 'Bedenime afiyet veren, ruhumu bana geri döndüren ve kendisini zikretmeme izin veren Allah’a hamdolsun.',
  403: 'Allah’tan başka ilah yoktur... Subhanallah, Elhamdülillah, La ilahe illallah, Allahu Ekber, Rabbim beni bağışla.',

  // Namaz Sonrası (501-505)
  501: 'Estağfirullah (3 kez). Allah’ım! Selam Sensin, selamet Sendendir. Ey celal ve ikram sahibi, Sen yücesin.',
  502: 'Allah’tan başka ilah yoktur... Allah’ım! Senin verdiğine engel olacak, vermediğini de verecek kimse yoktur.',
  503: 'Subhanallah (33) • Elhamdülillah (33) • Allahu Ekber (33).',
  504: 'Her farz namazın ardından Ayetel Kürsi okumak.',
  505: 'Allah’ım! Seni zikretmek, Sana şükretmek ve Sana güzelce kulluk etmek için bana yardım et.',

  // Ev ve Yolculuk (601-606)
  601: 'Evden çıkarken: Allah’ın adıyla, Allah’a tevekkül ettim; güç ve kuvvet yalnız Allah’tandır.',
  602: 'Eve girerken: Allah’ın adıyla girdik, Allah’ın adıyla çıktık ve Rabbimize tevekkül ettik.',
  603: 'Yolculuk / Binek duası: Bunu hizmetimize veren Allah noksanlardan münezzehtir, biz buna güç yetiremezdik.',
  604: 'Tuvalete girerken: Allah’ın adıyla; Allah’ım pisliklerden ve kötü varlıklardan Sana sığınırım.',
  605: 'Tuvaletten çıkarken: Gufraneke (Allah’ım bağışlamanı dilerim).',
  606: 'Yemekten sonra: Güç ve kuvvetim olmadan bunu bana yediren ve rızık olarak veren Allah’a hamdolsun.',

  // Kapsamlı Dualar (701-705)
  701: 'Rabbimiz! Bize dünyada da iyilik ver, ahirette de iyilik ver ve bizi ateş azabından koru.',
  702: 'Senden başka ilah yoktur, Seni tenzih ederim; gerçekten ben zalimlerden oldum.',
  703: 'Ey kalpleri evirip çeviren! Kalbimi dinin üzere sabit kıl.',
  704: 'Allah’ım! Sen affedicisin, affetmeyi seversin; beni de affet.',
  705: 'Allah’ım! Beni bağışla, bana merhamet et, bana hidayet ver, bana afiyet ver ve beni rızıklandır.',
};