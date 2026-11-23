import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/cloud_sync_service.dart';

/// Global Azkari Pro, Daily Free Taste, Streak Reward & Contribution Manager.
class AzkariProManager {
  AzkariProManager._();
  static const String _kProKey = 'is_azkari_pro';
  static const String _kProExpiresKey = 'pro_expires_at_iso';
  static const String _kProPlanLabelKey = 'pro_plan_label';
  static const String _kSupportTotalKey = 'pro_support_total_egp';
  static const String _kFreeTasteDateKey = 'pro_free_taste_date';
  static const String _kFreeTasteCountKey = 'pro_free_taste_count';
  static const String _kStreakRewardedKey = 'pro_streak_7_rewarded';

  static const String kBybitUid = '105501004';

  static bool isPro(SharedPreferences prefs) {
    final active = prefs.getBool(_kProKey) ?? false;
    if (!active) return false;
    final expIso = prefs.getString(_kProExpiresKey);
    if (expIso == null || expIso.isEmpty) return true; // Lifetime / legacy
    final exp = DateTime.tryParse(expIso);
    if (exp == null) return true;
    return DateTime.now().isBefore(exp);
  }

  static String? planLabel(SharedPreferences prefs) =>
      prefs.getString(_kProPlanLabelKey);

  static DateTime? expiresAt(SharedPreferences prefs) {
    final s = prefs.getString(_kProExpiresKey);
    return s != null ? DateTime.tryParse(s) : null;
  }

  static int totalSupportEgp(SharedPreferences prefs) =>
      prefs.getInt(_kSupportTotalKey) ?? 0;

  static Future<void> unlockPro(
    SharedPreferences prefs, {
    int days = 30,
    String planLabel = 'أذكاري PRO',
    int amountEgp = 0,
  }) async {
    final now = DateTime.now();
    final existingExp = expiresAt(prefs);
    final base = (existingExp != null && existingExp.isAfter(now))
        ? existingExp
        : now;
    final newExp = base.add(Duration(days: days));
    await prefs.setBool(_kProKey, true);
    await prefs.setString(_kProExpiresKey, newExp.toIso8601String());
    await prefs.setString(_kProPlanLabelKey, planLabel);
    if (amountEgp > 0) {
      await prefs.setInt(_kSupportTotalKey, totalSupportEgp(prefs) + amountEgp);
    }
  }

  static Future<void> recordSupportOnly(
      SharedPreferences prefs, int amountEgp) async {
    await prefs.setInt(_kSupportTotalKey, totalSupportEgp(prefs) + amountEgp);
  }

  /// Allows free users to experience Pro features on Surah Al-Fatihah or 3 Ayahs/day.
  static bool canUseFreeTaste(SharedPreferences prefs, {int? surahNumber}) {
    if (isPro(prefs)) return true;
    if (surahNumber == 1) return true; // Surah Al-Fatihah always free to try
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString(_kFreeTasteDateKey) ?? '';
    final count = savedDate == today ? (prefs.getInt(_kFreeTasteCountKey) ?? 0) : 0;
    return count < 3;
  }

  static Future<void> consumeFreeTaste(SharedPreferences prefs) async {
    if (isPro(prefs)) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString(_kFreeTasteDateKey) ?? '';
    final count = savedDate == today ? (prefs.getInt(_kFreeTasteCountKey) ?? 0) : 0;
    await prefs.setString(_kFreeTasteDateKey, today);
    await prefs.setInt(_kFreeTasteCountKey, count + 1);
  }

  static String formatExpiryDate(DateTime dt, String lang) {
    const monthsAr = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    const monthsEn = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const monthsTr = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    final mList = lang == 'tr' ? monthsTr : (lang == 'en' ? monthsEn : monthsAr);
    return '${dt.day} ${mList[dt.month - 1]} ${dt.year}';
  }

  static int remainingDays(SharedPreferences prefs) {
    if (!isPro(prefs)) return 0;
    final exp = expiresAt(prefs);
    if (exp == null) return 999;
    final diff = exp.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff + 1;
  }

  static String lastReference(SharedPreferences prefs) =>
      prefs.getString('azkari_last_payment_ref') ?? '';

  static Future<void> saveLastReference(
      SharedPreferences prefs, String ref) async {
    if (ref.trim().isNotEmpty) {
      await prefs.setString('azkari_last_payment_ref', ref.trim());
    }
  }

  static int linkedDevicesCount(SharedPreferences prefs) =>
      prefs.getInt('pro_linked_devices_count') ?? 1;

  static bool hasContributorBadge(SharedPreferences prefs) =>
      prefs.getBool('pro_contributor_badge') ?? false;

  static Future<void> grantContributorBadge(SharedPreferences prefs) async {
    await prefs.setBool('pro_contributor_badge', true);
  }

  static bool isExpiringSoon(SharedPreferences prefs) {
    if (!isPro(prefs)) return false;
    final exp = expiresAt(prefs);
    if (exp == null) return false;
    final diff = exp.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 3;
  }

  static bool hasUsedFatihaTrial(SharedPreferences prefs) =>
      prefs.getBool('pro_fatiha_trial_used') ?? false;

  static Future<void> markFatihaTrialUsed(SharedPreferences prefs) async {
    await prefs.setBool('pro_fatiha_trial_used', true);
  }

  static String getOrCreateDeviceId(SharedPreferences prefs) {
    var id = prefs.getString('azkari_device_uid');
    if (id == null || id.isEmpty) {
      id = 'dev_${DateTime.now().millisecondsSinceEpoch}_${prefs.hashCode}';
      prefs.setString('azkari_device_uid', id);
    }
    return id;
  }

  /// Syncs authoritative Pro subscription status from Supabase user_subscriptions (Anti-Crack)
  static Future<void> syncServerSubscription(SharedPreferences prefs) async {
    final fbId = prefs.getString('fbUserId') ?? '';
    if (fbId.isEmpty || !CloudSyncService.isCloudConfigured) return;
    try {
      final res = await http.get(
        Uri.parse(
            '${CloudSyncService.kSupabaseUrl}/rest/v1/user_subscriptions?fb_user_id=eq.${Uri.encodeComponent(fbId)}&select=*'),
        headers: {
          'apikey': CloudSyncService.kSupabaseAnonKey,
          'Authorization': 'Bearer ${CloudSyncService.kSupabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List && list.isNotEmpty) {
          final row = list.first as Map<String, dynamic>;
          final expIso = (row['expires_at'] ?? '').toString();
          final exp = DateTime.tryParse(expIso);
          if (exp != null && exp.isAfter(DateTime.now())) {
            await prefs.setBool(_kProKey, true);
            await prefs.setString(_kProExpiresKey, expIso);
            await prefs.setString(
                _kProPlanLabelKey, (row['plan_label'] ?? 'أذكاري PRO').toString());
          }
          if (row['contributor_badge'] == true) {
            await prefs.setBool('pro_contributor_badge', true);
          }
          if (row['trial_used'] == true) {
            await prefs.setBool('pro_fatiha_trial_used', true);
          }
          if (row['device_ids'] is List) {
            final cnt = (row['device_ids'] as List).length.clamp(1, 2);
            await prefs.setInt('pro_linked_devices_count', cnt);
          }
        }
      }
    } catch (_) {}
  }

  /// Secret Loyalty Tracker: counts a day ONLY if user actively uses app >= 5 minutes.
  /// On 30 consecutive qualifying days, quietly rewards 3 free days of Azkari PRO!
  static Future<bool> recordActiveMinuteAndCheckSecretReward(
      SharedPreferences prefs) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDay = prefs.getString('loyalty_today_date') ?? '';
    int minsToday = savedDay == today ? (prefs.getInt('loyalty_today_mins') ?? 0) : 0;
    minsToday += 1;
    await prefs.setString('loyalty_today_date', today);
    await prefs.setInt('loyalty_today_mins', minsToday);

    if (minsToday < 5) return false;
    final lastQualDay = prefs.getString('loyalty_last_qualified_date') ?? '';
    if (lastQualDay == today) return false; // Already counted today

    int consec = prefs.getInt('loyalty_consecutive_days') ?? 0;
    if (lastQualDay.isNotEmpty) {
      final prev = DateTime.tryParse(lastQualDay);
      final nowD = DateTime.tryParse(today);
      if (prev != null && nowD != null && nowD.difference(prev).inDays == 1) {
        consec += 1;
      } else {
        consec = 1;
      }
    } else {
      consec = 1;
    }
    await prefs.setString('loyalty_last_qualified_date', today);
    await prefs.setInt('loyalty_consecutive_days', consec);

    if (consec >= 30 && !(prefs.getBool('loyalty_30_rewarded') ?? false)) {
      await prefs.setBool('loyalty_30_rewarded', true);
      await unlockPro(
        prefs,
        days: 3,
        planLabel: 'هدية تقديرية (3 أيام PRO)',
      );
      return true;
    }
    return false;
  }

  static Future<void> logContributionMessage({
    required String country,
    required String method,
    required num amount,
    required String currency,
    String? reference,
    String? message,
  }) async {
    if (!CloudSyncService.isCloudConfigured) return;
    try {
      await http
          .post(
            Uri.parse('${CloudSyncService.kSupabaseUrl}/rest/v1/developer_contributions'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': CloudSyncService.kSupabaseAnonKey,
              'Authorization': 'Bearer ${CloudSyncService.kSupabaseAnonKey}',
            },
            body: jsonEncode({
              'country': country,
              'method': method,
              'amount': amount,
              'currency': currency,
              'reference': reference ?? '',
              'message': (message ?? '').trim(),
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }
}

class _CountryOption {
  final String code;
  final String nameAr;
  final String nameEn;
  final String currency;
  final String flag;
  final bool available;
  final String subtitleAr;
  final String subtitleEn;
  const _CountryOption(
    this.code,
    this.nameAr,
    this.nameEn,
    this.currency,
    this.flag,
    this.available,
    this.subtitleAr,
    this.subtitleEn,
  );
}

const List<_CountryOption> _kCountries = [
  _CountryOption('EG', 'مصر', 'Egypt', 'EGP', '🇪🇬', true,
      'فودافون • أورنج • اتصالات ماني', 'Vodafone • Orange • Etisalat Money'),
  _CountryOption('GLOBAL', 'عالمياً (جميع الدول)', 'Global (Worldwide)', 'USDT',
      '🌍', true, 'دفع فوري تلقائي عبر Bybit', 'Instant Auto-Verify via Bybit'),
  _CountryOption('SA', 'السعودية', 'Saudi Arabia', 'SAR', '🇸🇦', false,
      'قريباً • استخدم عالمياً (Bybit)', 'Coming soon • Use Global (Bybit)'),
  _CountryOption('AE', 'الإمارات', 'UAE', 'AED', '🇦🇪', false,
      'قريباً • استخدم عالمياً (Bybit)', 'Coming soon • Use Global (Bybit)'),
  _CountryOption('KW', 'الكويت', 'Kuwait', 'KWD', '🇰🇼', false,
      'قريباً • استخدم عالمياً (Bybit)', 'Coming soon • Use Global (Bybit)'),
  _CountryOption('QA', 'قطر', 'Qatar', 'QAR', '🇶🇦', false,
      'قريباً • استخدم عالمياً (Bybit)', 'Coming soon • Use Global (Bybit)'),
  _CountryOption('JO', 'الأردن', 'Jordan', 'JOD', '🇯🇴', false,
      'قريباً • استخدم عالمياً (Bybit)', 'Coming soon • Use Global (Bybit)'),
  _CountryOption('MA', 'المغرب', 'Morocco', 'MAD', '🇲🇦', false,
      'قريباً • استخدم عالمياً (Bybit)', 'Coming soon • Use Global (Bybit)'),
  _CountryOption('TR', 'تركيا', 'Turkey', 'TRY', '🇹🇷', false,
      'قريباً • استخدم عالمياً (Bybit)', 'Coming soon • Use Global (Bybit)'),
  _CountryOption('US', 'الولايات المتحدة', 'United States', 'USD', '🇺🇸', false,
      'قريباً • استخدم عالمياً (Bybit)', 'Coming soon • Use Global (Bybit)'),
];

class _WalletOption {
  final String id;
  final String nameAr;
  final String nameEn;
  final String prefix;
  final String assetPath;
  final String instructionAr;
  final String instructionEn;
  const _WalletOption(
    this.id,
    this.nameAr,
    this.nameEn,
    this.prefix,
    this.assetPath,
    this.instructionAr,
    this.instructionEn,
  );
}

const List<_WalletOption> _kEgyptWallets = [
  _WalletOption(
    'vf_cash',
    'فودافون كاش',
    'Vodafone Cash',
    '010',
    'assets/images/wallet_vodafone.jpg',
    'اطلب كود *9*1# من هاتفك وأدخل الرقم السري للمحفظة خلال 60 ثانية لتأكيد السحب.',
    'Dial *9*1# on your phone and enter your wallet PIN within 60 seconds.',
  ),
  _WalletOption(
    'or_cash',
    'أورنج كاش',
    'Orange Cash',
    '012',
    'assets/images/wallet_orange.jpg',
    'افتح تطبيق Orange Cash على هاتفك ووافق على طلب السحب المعلّق خلال 60 ثانية.',
    'Open the Orange Cash app on your phone and approve the pending request.',
  ),
  _WalletOption(
    'et_cash',
    'اتصالات ماني',
    'Etisalat Money',
    '011',
    'assets/images/wallet_etisalat.png',
    'اطلب كود *777*11# أو افتح تطبيق e& Money لتأكيد السحب خلال 60 ثانية.',
    'Dial *777*11# or open e& Money app to approve within 60 seconds.',
  ),
];

/// Redesigned, calm Azkari Pro & Developer Contribution Screen.
/// Supports Sha7nawy Gate API v2 (Egypt), Bybit Transfer ID Auto-Verify (Global),
/// and Supabase Promo Codes (percentage discount or free activation days).
class Sha7nawyPaymentScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final String appLang;
  final bool isDarkMode;
  final bool initialProMode;

  const Sha7nawyPaymentScreen({
    super.key,
    required this.prefs,
    this.appLang = 'ar',
    this.isDarkMode = false,
    this.initialProMode = true,
  });

  @override
  State<Sha7nawyPaymentScreen> createState() => _Sha7nawyPaymentScreenState();
}

class _Sha7nawyPaymentScreenState extends State<Sha7nawyPaymentScreen> {
  // TODO: Replace with your Sha7nawy Public Key from gate.sha7nawy.com -> API Keys
  // NEVER put your Secret Key inside the Flutter app!
  static const String kSha7nawyPublicKey = '6YDIiraLNYm38Je0CO308JjJtMxY7OBBJ8vxqQ00oaGV38VRRneLCuz8EhahhmVPGLlQEgiyf7EImcxBvomv7YCZvwPec27Y11Jh';
  static const String kSha7nawyBaseUrl = 'https://gate.sha7nawy.com/api/v2';

  static const Color kGoldLight = Color(0xFFFDE047);
  static const Color kGoldMid = Color(0xFFF59E0B);
  static const Color kGoldDark = Color(0xFFD97706);
  static const Color kSkyBlue = Color(0xFF0288D1);

  late bool _isProTab = widget.initialProMode;
  String _selectedCountry = 'EG'; // 'EG' | 'GLOBAL'
  String _selectedPlan = 'yearly'; // 'monthly' | 'yearly'
  String _selectedWallet = 'vf_cash'; // 'vf_cash' | 'or_cash' | 'et_cash'
  int _visualDemoIdx = 0; // 0: Recite, 1: QUL, 2: Hifz
  int _demoWordIdx = 0;
  Timer? _autoShowcaseTimer;

  @override
  void initState() {
    super.initState();
    _autoShowcaseTimer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      if (!mounted) return;
      setState(() {
        _demoWordIdx = (_demoWordIdx + 1) % 8;
        if (_demoWordIdx == 0) {
          _visualDemoIdx = (_visualDemoIdx + 1) % 3;
        }
      });
    });
  }

  String? _appliedPromoCode;
  int _appliedDiscountPercent = 0;

  final TextEditingController _amountCtrl = TextEditingController(text: '50');
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _bybitTxCtrl = TextEditingController();
  final TextEditingController _messageCtrl = TextEditingController();

  bool _loading = false;
  String? _errorMsg;

  String tr(String ar, String en, [String? trText]) {
    if (widget.appLang == 'tr') return trText ?? en;
    if (widget.appLang == 'en') return en;
    return ar;
  }

  @override
  void dispose() {
    _autoShowcaseTimer?.cancel();
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _bybitTxCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  _CountryOption get _countryObj => _kCountries.firstWhere(
        (c) => c.code == _selectedCountry,
        orElse: () => _kCountries.first,
      );

  _WalletOption get _walletObj => _kEgyptWallets.firstWhere(
        (w) => w.id == _selectedWallet,
        orElse: () => _kEgyptWallets.first,
      );

  double get _baseProPrice {
    if (_selectedCountry == 'EG') {
      return _selectedPlan == 'yearly' ? 999.0 : 99.0;
    }
    return _selectedPlan == 'yearly' ? 19.90 : 1.99;
  }

  double get _finalProPrice {
    if (_appliedDiscountPercent <= 0) return _baseProPrice;
    final net = _baseProPrice * (1 - _appliedDiscountPercent / 100.0);
    return net < 0 ? 0 : net;
  }

  String _formatPrice(double val) {
    if (_selectedCountry == 'EG') {
      return '${val.round()} ${tr('ج.م', 'EGP')}';
    }
    return '\$${val.toStringAsFixed(2)}';
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF0D47A1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(msg, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Future<void> _openCountryPicker() async {
    String query = '';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final q = query.trim().toLowerCase();
          final filtered = _kCountries.where((c) {
            if (q.isEmpty) return true;
            return c.nameAr.contains(q) ||
                c.nameEn.toLowerCase().contains(q) ||
                c.currency.toLowerCase().contains(q);
          }).toList();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  18, 14, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.68,
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tr('اختر الدولة', 'Select Country'),
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(tr('إغلاق', 'Close')),
                        ),
                      ],
                    ),
                    TextField(
                      onChanged: (v) => setS(() => query = v),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: tr('ابحث باسم الدولة (مصر، عالمياً، السعودية...)',
                            'Search country...'),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final c = filtered[i];
                          final isSelected = c.code == _selectedCountry;
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: !c.available
                                ? null
                                : () {
                                    setState(() {
                                      _selectedCountry = c.code;
                                      _amountCtrl.text =
                                          c.code == 'EG' ? '50' : '5';
                                      _errorMsg = null;
                                    });
                                    Navigator.pop(ctx);
                                  },
                            child: Opacity(
                              opacity: c.available ? 1.0 : 0.5,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? kSkyBlue
                                        : Colors.grey.withOpacity(0.25),
                                    width: isSelected ? 1.6 : 1.0,
                                  ),
                                  color: isSelected
                                      ? kSkyBlue.withOpacity(0.08)
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Text(c.flag,
                                        style: const TextStyle(fontSize: 24)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${tr(c.nameAr, c.nameEn)} (${c.currency})',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5),
                                          ),
                                          Text(
                                            tr(c.subtitleAr, c.subtitleEn),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(99),
                                        color: c.available
                                            ? Colors.green.withOpacity(0.14)
                                            : Colors.grey.withOpacity(0.18),
                                      ),
                                      child: Text(
                                        c.available
                                            ? (isSelected
                                                ? tr('مختار', 'Selected')
                                                : tr('متاح', 'Available'))
                                            : tr('قريباً', 'Soon'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: c.available
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPromoCodeSheet() async {
    final codeCtrl = TextEditingController();
    bool busy = false;
    String? localErr;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(tr('هل لديك برومو كود؟', 'Have a Promo Code?'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  tr(
                    'أدخل البرومو كود للحصول على خصم فوري على الباقة أو تفعيل مجاني مباشر لأذكاري PRO.',
                    'Enter a promo code for an instant discount or direct Pro activation.',
                  ),
                  style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: codeCtrl,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'AZK20',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                if (localErr != null) ...[
                  const SizedBox(height: 8),
                  Text(localErr!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 12.5)),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kGoldMid,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: busy
                        ? null
                        : () async {
                            final code = codeCtrl.text.trim().toUpperCase();
                            if (code.isEmpty) {
                              setS(() => localErr = tr(
                                  'يرجى إدخال البرومو كود أولاً',
                                  'Enter a promo code first'));
                              return;
                            }
                            if (!CloudSyncService.isCloudConfigured) {
                              setS(() => localErr = tr(
                                  'يرجى تفعيل بيانات Supabase أولاً لتفعيل الأكواد.',
                                  'Supabase is not configured yet.'));
                              return;
                            }
                            setS(() {
                              busy = true;
                              localErr = null;
                            });
                            try {
                              final res = await http.get(
                                Uri.parse(
                                    '${CloudSyncService.kSupabaseUrl}/rest/v1/pro_promo_codes?code=eq.${Uri.encodeComponent(code)}&active=eq.true&select=*'),
                                headers: {
                                  'apikey': CloudSyncService.kSupabaseAnonKey,
                                  'Authorization':
                                      'Bearer ${CloudSyncService.kSupabaseAnonKey}',
                                },
                              ).timeout(const Duration(seconds: 10));
                              final list = jsonDecode(res.body);
                              if (res.statusCode == 200 &&
                                  list is List &&
                                  list.isNotEmpty) {
                                final row = list.first as Map<String, dynamic>;
                                final maxUses = (row['max_uses'] as num?)?.toInt() ?? 1;
                                final used = (row['used_count'] as num?)?.toInt() ?? 0;
                                if (used >= maxUses) {
                                  setS(() {
                                    busy = false;
                                    localErr = tr(
                                        'تم استخدام هذا الكود بالكامل.',
                                        'This code has already been redeemed.');
                                  });
                                  return;
                                }
                                // Increment usage count
                                await http.patch(
                                  Uri.parse(
                                      '${CloudSyncService.kSupabaseUrl}/rest/v1/pro_promo_codes?code=eq.${Uri.encodeComponent(code)}'),
                                  headers: {
                                    'Content-Type': 'application/json',
                                    'apikey': CloudSyncService.kSupabaseAnonKey,
                                    'Authorization':
                                        'Bearer ${CloudSyncService.kSupabaseAnonKey}',
                                  },
                                  body: jsonEncode({'used_count': used + 1}),
                                );

                                final freeDays = (row['free_days'] as num?)?.toInt() ?? 0;
                                final discPct = (row['discount_percent'] as num?)?.toInt() ?? 0;

                                if (freeDays > 0) {
                                  await AzkariProManager.unlockPro(
                                    widget.prefs,
                                    days: freeDays,
                                    planLabel: freeDays >= 300
                                        ? tr('الباقة السنوية (برومو كود)', 'Yearly (Promo)')
                                        : tr('الباقة الشهرية (برومو كود)', 'Monthly (Promo)'),
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await _showSuccessDialog(unlockedPro: true);
                                } else if (discPct > 0) {
                                  setState(() {
                                    _appliedPromoCode = code;
                                    _appliedDiscountPercent = discPct;
                                  });
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _showSnack(tr(
                                      'تم تطبيق خصم $discPct% بنجاح!',
                                      '$discPct% discount applied!'));
                                }
                              } else {
                                setS(() {
                                  busy = false;
                                  localErr = tr(
                                      'البرومو كود غير صحيح أو منتهي الصلاحية.',
                                      'Invalid or expired promo code.');
                                });
                              }
                            } catch (e) {
                              setS(() {
                                busy = false;
                                localErr = tr('تعذر التحقق من الكود: $e',
                                    'Could not verify code: $e');
                              });
                            }
                          },
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : Text(tr('تطبيق البرومو كود', 'Apply Promo Code'),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleProceedPayment() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMsg = null);

    final fbId = widget.prefs.getString('fbUserId') ?? '';
    if (_isProTab && fbId.isEmpty) {
      setState(() {
        _errorMsg = tr(
          'يرجى تسجيل الدخول بحساب فيسبوك أولاً من الصفحة الرئيسية لربط اشتراكك وحمايته على كل أجهزتك.',
          'Please sign in with Facebook first from the Home screen to protect and bind your PRO subscription.',
        );
      });
      return;
    }

    if (_selectedCountry == 'GLOBAL') {
      await _verifyBybitTransfer();
      return;
    }

    // Egypt Sha7nawy flow
    if (kSha7nawyPublicKey.trim().isEmpty || kSha7nawyPublicKey.startsWith('YOUR_')) {
      setState(() {
        _errorMsg = tr(
          'يرجى استبدال YOUR_SHA7NAWY_PUBLIC_KEY بمفتاحك العام في إعدادات الدفع.',
          'Please replace YOUR_SHA7NAWY_PUBLIC_KEY with your Public Key.',
        );
      });
      return;
    }

    final int amountEgp = _isProTab
        ? _finalProPrice.round()
        : (int.tryParse(_amountCtrl.text.trim()) ?? 0);

    if (amountEgp < 10 || amountEgp > 10000) {
      setState(() {
        _errorMsg = tr(
          'المبلغ يجب أن يكون بين 10 و 10,000 جنيه مصري.',
          'Amount must be between 10 and 10,000 EGP.',
        );
      });
      return;
    }

    final phone = _phoneCtrl.text.trim();
    if (!RegExp(r'^01[0125]\d{8}$').hasMatch(phone)) {
      setState(() {
        _errorMsg = tr(
          'أدخل رقم محفظة مصري صحيح من 11 رقماً (010 / 011 / 012 / 015).',
          'Enter a valid 11-digit Egyptian wallet number.',
        );
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final orderId = 'AZK-${DateTime.now().millisecondsSinceEpoch}';
      final res = await http
          .post(
            Uri.parse('$kSha7nawyBaseUrl/payment/create'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': kSha7nawyPublicKey,
              'X-App-Name': 'Azkari',
            },
            body: jsonEncode({
              'order_id': orderId,
              'number': phone,
              'amount': (amountEgp / 1.02).round().clamp(5, 10000),
              'method': _selectedWallet,
              'description': _isProTab
                  ? 'Azkari Pro ($_selectedPlan - $amountEgp EGP)'
                  : 'Azkari Developer Contribution ($amountEgp EGP)',
              'metadata': {
                'type': _isProTab ? 'pro_upgrade' : 'developer_contribution',
                'plan': _selectedPlan,
                'promo': _appliedPromoCode ?? '',
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>? ?? {};
        final ref = (data['reference'] ?? '').toString();
        final msg = (body['message'] ?? '').toString();
        setState(() => _loading = false);
        await _openSha7nawyConfirmSheet(
          reference: ref,
          amountEgp: amountEgp,
          serverMsg: msg,
        );
      } else {
        setState(() {
          _loading = false;
          _errorMsg = (body['message'] ?? 'Payment creation failed').toString();
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = tr('تعذر الاتصال بخدمة الدفع: $e', 'Connection error: $e');
      });
    }
  }

  Future<void> _openSha7nawyConfirmSheet({
    required String reference,
    required int amountEgp,
    required String serverMsg,
  }) async {
    int secondsLeft = 60;
    bool confirming = false;
    String? sheetErr;
    Timer? timer;

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (!ctx.mounted) {
              t.cancel();
              return;
            }
            if (secondsLeft <= 1) {
              t.cancel();
              setS(() => secondsLeft = 0);
            } else {
              setS(() => secondsLeft--);
            }
          });

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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('تأكيد عملية الدفع', 'Confirm Payment'),
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                          Text(
                            '${tr(_walletObj.nameAr, _walletObj.nameEn)} • $amountEgp ${tr('ج.م', 'EGP')}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              value: secondsLeft / 60.0,
                              strokeWidth: 4,
                              color: kSkyBlue,
                              backgroundColor: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          Text('${secondsLeft}s',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: kSkyBlue)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('الرقم المرجعي', 'Reference'),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            Text(reference,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: kSkyBlue)),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: reference));
                            _showSnack(tr('تم نسخ المرجع', 'Reference copied'));
                          },
                          child: Text(tr('نسخ', 'Copy')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kGoldMid.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kGoldMid.withOpacity(0.35)),
                    ),
                    child: Text(
                      serverMsg.isNotEmpty
                          ? serverMsg
                          : tr(_walletObj.instructionAr, _walletObj.instructionEn),
                      style: const TextStyle(fontSize: 12.5, height: 1.5),
                    ),
                  ),
                  if (sheetErr != null) ...[
                    const SizedBox(height: 8),
                    Text(sheetErr!,
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: confirming
                              ? null
                              : () {
                                  timer?.cancel();
                                  Navigator.pop(ctx);
                                },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(tr('إلغاء', 'Cancel')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: kGoldMid,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: confirming
                              ? null
                              : () async {
                                  setS(() {
                                    confirming = true;
                                    sheetErr = null;
                                  });
                                  try {
                                    final res = await http
                                        .post(
                                          Uri.parse(
                                              '$kSha7nawyBaseUrl/payment/confirm'),
                                          headers: {
                                            'Content-Type': 'application/json',
                                            'Accept': 'application/json',
                                            'Authorization': kSha7nawyPublicKey,
                                            'X-App-Name': 'Azkari',
                                          },
                                          body: jsonEncode(
                                              {'reference': reference}),
                                        )
                                        .timeout(const Duration(seconds: 15));
                                    final body = jsonDecode(res.body)
                                        as Map<String, dynamic>;
                                    final code = (body['code'] ?? '').toString();
                                    if (res.statusCode == 200 &&
                                        (body['success'] == true ||
                                            code == 'SH-2003')) {
                                      timer?.cancel();
                                      if (_isProTab) {
                                        await AzkariProManager.unlockPro(
                                          widget.prefs,
                                          days: _selectedPlan == 'yearly'
                                              ? 365
                                              : 30,
                                          planLabel: _selectedPlan == 'yearly'
                                              ? tr('الباقة السنوية PRO',
                                                  'Yearly PRO')
                                              : tr('الباقة الشهرية PRO',
                                                  'Monthly PRO'),
                                          amountEgp: amountEgp,
                                        );
                                      } else {
                                        await AzkariProManager.recordSupportOnly(widget.prefs, amountEgp);
                                        await AzkariProManager.grantContributorBadge(widget.prefs);
                                      }
                                      await AzkariProManager.saveLastReference(widget.prefs, reference);
                                      await AzkariProManager
                                          .logContributionMessage(
                                        country: 'EG',
                                        method: _selectedWallet,
                                        amount: amountEgp,
                                        currency: 'EGP',
                                        reference: reference,
                                        message: _messageCtrl.text,
                                      );
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      await _showSuccessDialog(
                                          unlockedPro: _isProTab);
                                    } else if (res.statusCode == 202 ||
                                        code == 'SH-4031') {
                                      setS(() {
                                        confirming = false;
                                        sheetErr = tr(
                                          'العملية معلقة لموافقة المحفظة على هاتفك. وافق عليها ثم اضغط تأكيد مرة أخرى.',
                                          'Waiting for wallet approval. Approve then tap Confirm again.',
                                        );
                                      });
                                    } else {
                                      setS(() {
                                        confirming = false;
                                        sheetErr = (body['message'] ??
                                                'Confirmation failed')
                                            .toString();
                                      });
                                    }
                                  } catch (e) {
                                    setS(() {
                                      confirming = false;
                                      sheetErr = e.toString();
                                    });
                                  }
                                },
                          child: confirming
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.black))
                              : Text(tr('تأكيد إتمام الدفع', 'Confirm Payment'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
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
    timer?.cancel();
  }

  Future<void> _verifyBybitTransfer() async {
    final txId = _bybitTxCtrl.text.trim();
    final double amountUsd = _isProTab
        ? _finalProPrice
        : (double.tryParse(_amountCtrl.text.trim()) ?? 0.0);

    if (!_isProTab && (amountUsd < 1.0 || amountUsd > 10000.0)) {
      setState(() {
        _errorMsg = tr('المبلغ يجب أن يكون بين 1 و 10,000 دولار (USDT).',
            'Amount must be between \$1 and \$10,000 USDT.');
      });
      return;
    }

    if (txId.length < 6) {
      setState(() {
        _errorMsg = tr(
          'أدخل رقم عملية التحويل (Transfer ID) من سجل Bybit للتحقق الفوري.',
          'Please paste your Bybit Transfer ID for instant verification.',
        );
      });
      return;
    }

    if (!CloudSyncService.isCloudConfigured) {
      setState(() {
        _errorMsg = tr(
          'يرجى تفعيل بيانات Supabase لنشر دالة التحقق التلقائي من Bybit.',
          'Configure Supabase first to verify Bybit transfers automatically.',
        );
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await http
          .post(
            Uri.parse(
                '${CloudSyncService.kSupabaseUrl}/functions/v1/verify-bybit'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': CloudSyncService.kSupabaseAnonKey,
              'Authorization': 'Bearer ${CloudSyncService.kSupabaseAnonKey}',
            },
            body: jsonEncode({
              'tx_id': txId,
              'plan': _isProTab ? _selectedPlan : 'contribution',
              'expected_amount': amountUsd,
              'user_id': widget.prefs.getString('fbUserId') ?? 'azkari_user',
            }),
          )
          .timeout(const Duration(seconds: 18));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        if (_isProTab) {
          final days = (body['days'] as num?)?.toInt() ??
              (_selectedPlan == 'yearly' ? 365 : 30);
          await AzkariProManager.unlockPro(
            widget.prefs,
            days: days,
            planLabel: days >= 300
                ? tr('الباقة السنوية PRO (Bybit)', 'Yearly PRO (Bybit)')
                : tr('الباقة الشهرية PRO (Bybit)', 'Monthly PRO (Bybit)'),
          );
        }
        await AzkariProManager.saveLastReference(widget.prefs, txId);
        await AzkariProManager.logContributionMessage(
          country: 'GLOBAL',
          method: 'bybit_internal',
          amount: amountUsd,
          currency: 'USDT',
          reference: txId,
          message: _messageCtrl.text,
        );
        setState(() => _loading = false);
        await _showSuccessDialog(unlockedPro: _isProTab);
      } else {
        setState(() {
          _loading = false;
          _errorMsg = (body['message'] ?? 'Verification failed').toString();
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = tr('تعذر التحقق التلقائي من Bybit: $e',
            'Bybit auto-verify error: $e');
      });
    }
  }

  Future<void> _showSuccessDialog({required bool unlockedPro}) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [kGoldLight, kGoldMid, kGoldDark]),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.black, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              unlockedPro
                  ? tr('مبارك! تم تفعيل أذكاري PRO', 'Azkari PRO Unlocked!')
                  : tr('جزاك الله خيراً!', 'Thank You!'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          unlockedPro
              ? tr(
                  'تم تفعيل الشارة الذهبية وفتح التسميع الذكي ووضع الحفظ وتوقيت الكلمات بالمللي ثانية على جهازك.',
                  'Golden PRO badge active! Smart Recitation, Hifz Mode & QUL Word Timings are now unlocked.',
                )
              : tr(
                  'تم استلام مساهمتك ورسالتك بنجاح. بارك الله فيك ونفع بك.',
                  'Your contribution and message were received. Thank you!',
                ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kGoldMid,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(dCtx);
              Navigator.pop(context, true);
            },
            child: Text(tr('العودة للتطبيق', 'Back to App'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualProShowcase(Color cardColor, Color borderColor) {
    final words = ['وَبَشِّرِ', 'الَّذِينَ', 'آمَنُوا', 'وَعَمِلُوا', 'الصَّالِحَاتِ', 'أَنَّ', 'لَهُمْ', 'جَنَّاتٍ'];
    final tabs = [
      tr('توقيت الكلمات', 'Word Sync'),
      tr('وضع الحفظ', 'Hifz Mode'),
      tr('التسميع الذكي', 'Smart Recite'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: List.generate(3, (i) {
              final sel = _visualDemoIdx == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _visualDemoIdx = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? kGoldMid.withOpacity(0.16) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tabs[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: sel ? kGoldMid : Colors.grey,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          if (_visualDemoIdx == 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tr('تظليل QUL بالمللي ثانية', 'QUL Millisecond Sync'),
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: kGoldMid)),
                Text(tr('● معاينة مباشرة', '● Live Preview'),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
              ],
            ),
            const SizedBox(height: 6),
            RichText(
              textDirection: TextDirection.rtl,
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: 19,
                  height: 1.9,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                ),
                children: List.generate(words.length, (i) {
                  if (i < _demoWordIdx) {
                    return TextSpan(
                        text: '${words[i]} ',
                        style: const TextStyle(color: kSkyBlue));
                  }
                  if (i == _demoWordIdx) {
                    return TextSpan(
                      text: '${words[i]} ',
                      style: TextStyle(
                        color: kGoldMid,
                        fontWeight: FontWeight.bold,
                        backgroundColor: kGoldMid.withOpacity(0.20),
                      ),
                    );
                  }
                  return TextSpan(
                    text: '${words[i]} ',
                    style: TextStyle(
                        color: (widget.isDarkMode ? Colors.white : Colors.black)
                            .withOpacity(0.32)),
                  );
                }),
              ),
            ),
          ] else if (_visualDemoIdx == 1) ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kSkyBlue.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('1. تلاوة القارئ', '1. Reciter'),
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: kSkyBlue)),
                        Text(tr('5.4 ثانية', '5.4 sec'),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kGoldMid.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('2. صمت للترديد', '2. Auto Silence'),
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: kGoldMid)),
                        Text(tr('5.4 ثانية تلقائياً', '5.4 sec auto'),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              tr(
                'إخفاء الكلمات مع ذكاء المدّ بالخشوع وإعادة الآية بدون خطأ، وتنبيه لطيف للمتشابهات مع توهج زر (+ كلمة).',
                'Hidden words reveal with Madd/Repeat forgiveness, Mutashabihat alert & glowing word-hint.',
              ),
              style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC);
    final card = isDark ? const Color(0xFF0F1115) : Colors.white;
    final border = isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0);
    final isPro = AzkariProManager.isPro(widget.prefs);
    final isEgypt = _selectedCountry == 'EG';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isProTab
              ? tr('أذكاري PRO', 'Azkari PRO')
              : tr('المساهمة في التطوير', 'Support Development'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (isPro)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kGoldLight, kGoldMid]),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Row(
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      size: 14, color: Colors.black),
                  SizedBox(width: 4),
                  Text('PRO',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
        children: [
          // Clean Segmented Switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isProTab = true;
                      _errorMsg = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: _isProTab
                            ? const LinearGradient(
                                colors: [kGoldLight, kGoldMid])
                            : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.workspace_premium_rounded,
                              size: 16,
                              color: _isProTab ? Colors.black : Colors.grey),
                          const SizedBox(width: 5),
                          Text(
                            tr('أذكاري PRO', 'Azkari PRO'),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: _isProTab ? Colors.black : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isProTab = false;
                      _errorMsg = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isProTab ? kSkyBlue : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        tr('المساهمة في التطوير', 'Support Development'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: !_isProTab ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_isProTab)
            _buildVisualProShowcase(card, border)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                tr(
                  'أذكاري تطبيق مجاني وخالٍ تماماً من الإعلانات. مساهمتك الاختيارية تساعدنا في استمرار التطوير وإضافة مزايا قرآنية جديدة.',
                  'Azkari is ad-free. Your voluntary contribution funds ongoing development and new Quranic features.',
                ),
                style: const TextStyle(
                    fontSize: 12.5, color: Colors.grey, height: 1.5),
              ),
            ),

          const SizedBox(height: 14),

          // Unified Calm Checkout Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Searchable Country Selector Row
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _openCountryPicker,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Text(_countryObj.flag,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr(_countryObj.nameAr, _countryObj.nameEn),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5)),
                              Text(
                                  tr(_countryObj.subtitleAr,
                                      _countryObj.subtitleEn),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text(tr('تغيير الدولة', 'Change'),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: kSkyBlue)),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: kSkyBlue),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: border),
                const SizedBox(height: 14),

                // Plans (Pro Tab) OR Free-Form Amount (Contribution Tab)
                if (_isProTab) ...[
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedPlan = 'monthly'),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _selectedPlan == 'monthly'
                                    ? kGoldMid
                                    : border,
                                width: _selectedPlan == 'monthly' ? 1.8 : 1,
                              ),
                              color: _selectedPlan == 'monthly'
                                  ? kGoldMid.withOpacity(0.10)
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tr('الباقة الشهرية', 'Monthly'),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  isEgypt ? '99 ج.م' : '\$1.99',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: _selectedPlan == 'monthly'
                                        ? kGoldMid
                                        : null,
                                  ),
                                ),
                                Text(isEgypt ? '110 ج.م' : '\$2.50', style: const TextStyle(fontSize: 10.5, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                                Text(tr('شهرياً', 'per month'),
                                    style: const TextStyle(
                                        fontSize: 10.5, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedPlan = 'yearly'),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _selectedPlan == 'yearly'
                                        ? kGoldMid
                                        : border,
                                    width: _selectedPlan == 'yearly' ? 1.8 : 1,
                                  ),
                                  color: _selectedPlan == 'yearly'
                                      ? kGoldMid.withOpacity(0.10)
                                      : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tr('الباقة السنوية', 'Yearly'),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      isEgypt ? '999 ج.م' : '\$19.90',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: _selectedPlan == 'yearly'
                                            ? kGoldMid
                                            : null,
                                      ),
                                    ),
                                    Text(
                                      isEgypt ? '1,188 ج.م' : '\$23.88',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.grey,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: -10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                        colors: [kGoldLight, kGoldMid]),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(tr('وفر 189 ج.م', 'Best Value'),
                                      style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_appliedPromoCode != null &&
                      _appliedDiscountPercent > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.green.withOpacity(0.35)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_appliedPromoCode (-$_appliedDiscountPercent%)',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                          Row(
                            children: [
                              Text(_formatPrice(_finalProPrice),
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.5)),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close,
                                    size: 16, color: Colors.red),
                                onPressed: () => setState(() {
                                  _appliedPromoCode = null;
                                  _appliedDiscountPercent = 0;
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  Text(
                    isEgypt
                        ? tr('مبلغ المساهمة (10 – 10,000 ج.م)',
                            'Contribution Amount (10 - 10,000 EGP)')
                        : tr('مبلغ المساهمة (1 – 10,000 USDT)',
                            'Contribution Amount (1 - 10,000 USDT)'),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900),
                    decoration: InputDecoration(
                      suffixText: isEgypt ? tr('ج.م', 'EGP') : 'USDT',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: (isEgypt
                            ? ['25', '50', '100', '250']
                            : ['3', '5', '10', '25'])
                        .map((p) => ActionChip(
                              label: Text('$p ${isEgypt ? 'ج' : '\$'}'),
                              onPressed: () =>
                                  setState(() => _amountCtrl.text = p),
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 16),

                // Payment Method Section
                if (isEgypt) ...[
                  Text(tr('وسيلة الدفع', 'Payment Wallet'),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: _kEgyptWallets.map((w) {
                      final active = _selectedWallet == w.id;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedWallet = w.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: active ? kSkyBlue : border,
                                  width: active ? 1.8 : 1,
                                ),
                                color: active
                                    ? kSkyBlue.withOpacity(0.10)
                                    : null,
                              ),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.asset(
                                      w.assetPath,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.account_balance_wallet_rounded,
                                        size: 36,
                                        color: kSkyBlue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    tr(w.nameAr, w.nameEn),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 11,
                    textDirection: TextDirection.ltr,
                    onChanged: (v) {
                      if (v.startsWith('010') && _selectedWallet != 'vf_cash') {
                        setState(() => _selectedWallet = 'vf_cash');
                      } else if (v.startsWith('012') &&
                          _selectedWallet != 'or_cash') {
                        setState(() => _selectedWallet = 'or_cash');
                      } else if (v.startsWith('011') &&
                          _selectedWallet != 'et_cash') {
                        setState(() => _selectedWallet = 'et_cash');
                      }
                    },
                    decoration: InputDecoration(
                      labelText: tr('رقم ${_walletObj.nameAr} (11 رقم)',
                          '${_walletObj.nameEn} Number'),
                      hintText: '${_walletObj.prefix}xxxxxxxx',
                      prefixIcon: const Icon(Icons.phone_android_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      isDense: true,
                    ),
                  ),
                ] else ...[
                  // Global Bybit Internal Transfer Auto-Verify
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: kGoldMid.withOpacity(0.08),
                      border: Border.all(color: kGoldMid.withOpacity(0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tr('تحويل داخلي عبر Bybit (0 رسوم)',
                                    'Bybit Internal Transfer (0 Fee)'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                const Text('UID: ${AzkariProManager.kBybitUid}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: kGoldMid,
                                        fontSize: 13.5)),
                              ],
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: kGoldMid,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              onPressed: () {
                                Clipboard.setData(const ClipboardData(
                                    text: AzkariProManager.kBybitUid));
                                _showSnack(tr('تم نسخ Bybit UID',
                                    'Bybit UID copied'));
                              },
                              child: Text(tr('نسخ UID', 'Copy UID'),
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr(
                            '1. افتح Bybit ← Assets ← Transfer / Internal Transfer\n2. حوّل المبلغ بعملة USDT إلى UID: 105501004\n3. من Funding Account > History انسخ Transfer ID وألصقه بالأسفل للتفعيل الفوري.',
                            '1. Open Bybit -> Assets -> Internal Transfer\n2. Send USDT to UID: 105501004\n3. Copy Transfer ID from Funding History and paste below for instant verification.',
                          ),
                          style: const TextStyle(
                              fontSize: 11.5, color: Colors.grey, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bybitTxCtrl,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: tr('رقم العملية (Bybit Transfer ID)',
                          'Bybit Transfer ID'),
                      hintText: 'Paste Transfer ID here...',
                      prefixIcon: const Icon(Icons.receipt_long_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      isDense: true,
                    ),
                  ),
                ],

                // Optional Message / Dua for Developer on Contribution Tab
                if (!_isProTab) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _messageCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: tr('رسالة أو دعوة للمطور (اختياري)',
                          'Message or Dua for Developer (Optional)'),
                      hintText: tr('اكتب رسالتك أو دعوتك هنا...',
                          'Write your message here...'),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      isDense: true,
                    ),
                  ),
                ],

                if (_errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Text(_errorMsg!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 12.5)),
                ],

                if (isEgypt) ...[
                  const SizedBox(height: 8),
                  Builder(builder: (_) {
                    final double baseEgp = _isProTab
                        ? _finalProPrice
                        : (double.tryParse(_amountCtrl.text.trim()) ?? 0.0);
                    final int netToGateway = (baseEgp / 1.02).round();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.30)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              baseEgp > 0
                                  ? tr(
                                      'الرسوم علينا! ستصلك رسالة تأكيد دفع بمبلغ $netToGateway ج.م، وبإضافة 2% رسوم الخدمة سيُخصم منك ${baseEgp.round()} ج.م فقط.',
                                      'Zero extra fee! You will receive a $netToGateway EGP confirmation message so your exact total is ${baseEgp.round()} EGP.',
                                    )
                                  : tr(
                                      'نحن نتحمل 2% رسوم الدفع بالكامل عنك.',
                                      'We cover the 2% payment fee for you.',
                                    ),
                              style: const TextStyle(fontSize: 11.5, color: Colors.green, height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 14),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _isProTab ? kGoldMid : kSkyBlue,
                      foregroundColor:
                          _isProTab ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _loading ? null : _handleProceedPayment,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            _isProTab
                                ? (isEgypt
                                    ? '${tr('اشترك الآن', 'Subscribe Now')} • ${_formatPrice(_finalProPrice)}'
                                    : '${tr('تحقق وتفعيل فوري', 'Verify & Unlock')} • ${_formatPrice(_finalProPrice)}')
                                : (isEgypt
                                    ? tr('متابعة المساهمة', 'Continue')
                                    : tr('تحقق وإرسال المساهمة',
                                        'Verify & Send')),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 14.5),
                          ),
                  ),
                ),
              ],
            ),
          ),

          if (_isProTab) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 13, color: Colors.grey),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    tr(
                      'دفع لمرة واحدة بدون خصم تلقائي — أنت من يقرر التجديد',
                      'One-time payment, no auto-renewal — you stay in full control',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],

          if (_isProTab) ...[
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _openPromoCodeSheet,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kGoldMid.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_offer_rounded,
                          color: kGoldMid, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('هل لديك برومو كود؟', 'Have a Promo Code?'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            tr('خصم على الباقة أو تفعيل مجاني مباشر',
                                'Plan discount or instant free activation'),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Text(tr('إدخال', 'Redeem'),
                        style: const TextStyle(
                            color: kGoldMid,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5)),
                    const Icon(Icons.chevron_right_rounded,
                        color: kGoldMid, size: 18),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: border),
                  ),
                  onPressed: () async {
                    final fbId = widget.prefs.getString('fbUserId') ?? '';
                    if (fbId.isEmpty) {
                      _showSnack(
                        tr('سجّل الدخول بحساب فيسبوك أولاً لاستعادة اشتراكك',
                            'Sign in with Facebook first to restore your subscription'),
                        isError: true,
                      );
                      return;
                    }
                    await AzkariProManager.syncServerSubscription(widget.prefs);
                    if (mounted) setState(() {});
                    final active = AzkariProManager.isPro(widget.prefs);
                    _showSnack(
                      active
                          ? tr('تمت استعادة اشتراك أذكاري PRO بنجاح!',
                              'Azkari PRO restored successfully!')
                          : tr('لم يتم العثور على اشتراك نشط لهذا الحساب.',
                              'No active subscription found for this account.'),
                      isError: !active,
                    );
                  },
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: Text(tr('استعادة اشتراكي', 'Restore PRO'),
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: border),
                  ),
                  onPressed: () async {
                    final fbId = widget.prefs.getString('fbUserId') ?? 'Guest';
                    final lastRef = AzkariProManager.lastReference(widget.prefs);
                    final uri = Uri(
                      scheme: 'mailto',
                      path: 'ahmfalcon00868@gmail.com',
                      queryParameters: {
                        'subject': 'مساعدة في الدفع - أذكاري PRO',
                        'body': 'معرّف الحساب: $fbId\nآخر رقم مرجعي: ${lastRef.isEmpty ? "لا يوجد" : lastRef}\n\nوصف المشكلة:',
                      },
                    );
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {
                      _showSnack(tr('تواصل معنا عبر: ahmfalcon00868@gmail.com',
                          'Contact us: ahmfalcon00868@gmail.com'));
                    }
                  },
                  icon: const Icon(Icons.support_agent_rounded, size: 16),
                  label: Text(tr('مشكلة في الدفع؟', 'Payment Help?'),
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}