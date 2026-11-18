import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Global Pro & Developer Support state manager.
class AzkariProManager {
  AzkariProManager._();
  static const String _kProKey = 'is_azkari_pro';
  static const String _kSupportTotalKey = 'pro_support_total_egp';
  static const String _kLastRefKey = 'sha7nawy_last_ref';

  static bool isPro(SharedPreferences prefs) =>
      prefs.getBool(_kProKey) ?? false;

  static int totalSupportEgp(SharedPreferences prefs) =>
      prefs.getInt(_kSupportTotalKey) ?? 0;

  static Future<void> unlockPro(SharedPreferences prefs, {int amount = 0}) async {
    await prefs.setBool(_kProKey, true);
    if (amount > 0) {
      final prev = totalSupportEgp(prefs);
      await prefs.setInt(_kSupportTotalKey, prev + amount);
    }
  }

  static Future<void> recordSupportOnly(
      SharedPreferences prefs, int amount) async {
    final prev = totalSupportEgp(prefs);
    await prefs.setInt(_kSupportTotalKey, prev + amount);
  }
}

/// Sha7nawy Gate API v2 Payment & Developer Support Screen.
/// Uses ONLY Public Key on client-side (never Secret Key).
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
  static const String kBaseUrl = 'https://gate.sha7nawy.com/api/v2';

  String _selectedCountry = 'EG';
  late bool _isProUpgrade = widget.initialProMode;
  String _selectedMethod = 'vf_cash'; // vf_cash, or_cash, et_cash
  final TextEditingController _amountCtrl = TextEditingController(text: '50');
  final TextEditingController _phoneCtrl = TextEditingController();

  bool _loading = false;
  String? _pendingReference;
  String? _instructionMsg;
  String? _errorMsg;
  int _countdownSec = 0;
  Timer? _timer;

  String tr(String ar, String en, [String? trText]) {
    if (widget.appLang == 'tr') return trText ?? en;
    if (widget.appLang == 'en') return en;
    return ar;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdownSec = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdownSec <= 1) {
        t.cancel();
        setState(() => _countdownSec = 0);
      } else {
        setState(() => _countdownSec--);
      }
    });
  }

  Future<void> _createPayment() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMsg = null;
    });

    if (kSha7nawyPublicKey.contains('YOUR_SHA7NAWY_PUBLIC_KEY')) {
      setState(() {
        _errorMsg = tr(
          'يرجى استبدال YOUR_SHA7NAWY_PUBLIC_KEY بمفتاحك العام من لوحة شحناوي قبل النشر.',
          'Please replace YOUR_SHA7NAWY_PUBLIC_KEY with your Public Key from Sha7nawy dashboard.',
          'Lütfen YOUR_SHA7NAWY_PUBLIC_KEY yerine Sha7nawy Public Key girin.',
        );
      });
      return;
    }

    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount < 10 || amount > 10000) {
      setState(() {
        _errorMsg = tr(
          'المبلغ يجب أن يكون بين 10 و 10,000 جنيه مصري.',
          'Amount must be between 10 and 10,000 EGP.',
          'Tutar 10 ile 10.000 EGP arasında olmalıdır.',
        );
      });
      return;
    }

    final phone = _phoneCtrl.text.trim();
    if (!RegExp(r'^01[0125]\d{8}$').hasMatch(phone)) {
      setState(() {
        _errorMsg = tr(
          'أدخل رقم محفظة مصري صحيح مكون من 11 رقماً (يبدأ بـ 010 أو 011 أو 012 أو 015).',
          'Enter a valid 11-digit Egyptian wallet number (010, 011, 012, or 015).',
          'Geçerli 11 haneli Mısır cüzdan numarası girin (010, 011, 012, 015).',
        );
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final orderId = 'AZK-${DateTime.now().millisecondsSinceEpoch}';
      final res = await http
          .post(
            Uri.parse('$kBaseUrl/payment/create'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': kSha7nawyPublicKey,
              'X-App-Name': 'Azkari',
            },
            body: jsonEncode({
              'order_id': orderId,
              'number': phone,
              'amount': amount,
              'method': _selectedMethod,
              'description': _isProUpgrade
                  ? 'Azkari Pro Subscription ($amount EGP)'
                  : 'Support Azkari Developers ($amount EGP)',
              'metadata': {
                'type': _isProUpgrade ? 'pro_upgrade' : 'developer_support',
                'country': _selectedCountry,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>? ?? {};
        final ref = (data['reference'] ?? '').toString();
        await widget.prefs.setString('sha7nawy_last_ref', ref);
        setState(() {
          _pendingReference = ref;
          _instructionMsg = (body['message'] ?? '').toString();
        });
        _startCountdown();
      } else {
        setState(() {
          _errorMsg = (body['message'] ?? 'Payment creation failed').toString();
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = tr('تعذر الاتصال ببوابة الدفع: $e', 'Connection error: $e');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmPayment() async {
    if (_pendingReference == null || _pendingReference!.isEmpty) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final res = await http
          .post(
            Uri.parse('$kBaseUrl/payment/confirm'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': kSha7nawyPublicKey,
              'X-App-Name': 'Azkari',
            },
            body: jsonEncode({'reference': _pendingReference}),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final code = (body['code'] ?? '').toString();
      if (res.statusCode == 200 &&
          (body['success'] == true || code == 'SH-2003')) {
        _timer?.cancel();
        final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
        if (_isProUpgrade) {
          await AzkariProManager.unlockPro(widget.prefs, amount: amount);
        } else {
          await AzkariProManager.recordSupportOnly(widget.prefs, amount);
        }
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (dCtx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Text(tr('جزاك الله خيراً', 'Thank You!', 'Teşekkürler!')),
            content: Text(
              _isProUpgrade
                  ? tr(
                      'تم تأكيد الدفع بنجاح وتفعيل أذكاري برو على جهازك.',
                      'Payment confirmed! Azkari Pro is now unlocked on your device.',
                      'Ödeme onaylandı! Azkari Pro artık cihazınızda aktif.',
                    )
                  : tr(
                      'تم استلام دعمك بنجاح لتطوير تطبيق أذكاري. بارك الله فيك.',
                      'Your developer support was received! Thank you for supporting Azkari.',
                      'Desteğiniz alındı! Azkari uygulamasını desteklediğiniz için teşekkürler.',
                    ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dCtx);
                  Navigator.pop(context, true);
                },
                child: Text(tr('تم', 'Done', 'Tamam')),
              ),
            ],
          ),
        );
      } else if (res.statusCode == 202 || code == 'SH-4031') {
        setState(() {
          _errorMsg = tr(
            'العملية معلقة لموافقة المحفظة على هاتفك. قم بتأكيد السحب ثم اضغط تأكيد مرة أخرى.',
            'Pending wallet approval on your phone. Approve it then tap Confirm again.',
            'Telefonunuzda onay bekleniyor. Onaylayıp tekrar deneyin.',
          );
        });
      } else if (res.statusCode == 410 || code == 'SH-4032') {
        _timer?.cancel();
        setState(() {
          _pendingReference = null;
          _countdownSec = 0;
          _errorMsg = tr(
            'انتهت مهلة الـ 60 ثانية. يمكنك إنشاء طلب دفع جديد.',
            '60-second confirmation window expired. Please start a new request.',
            '60 saniyelik onay süresi doldu. Yeni bir istek oluşturun.',
          );
        });
      } else {
        setState(() {
          _errorMsg = (body['message'] ?? 'Confirmation failed').toString();
        });
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC);
    final card = isDark ? const Color(0xFF101010) : Colors.white;
    final border = isDark ? const Color(0xFF222222) : const Color(0xFFE2E8F0);
    final primary = const Color(0xFF0288D1);
    final isPro = AzkariProManager.isPro(widget.prefs);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(tr('دعم التطبيق وأذكاري برو', 'Support & Azkari Pro',
            'Destek ve Azkari Pro')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0A192F), Color(0xFF0D47A1), Color(0xFF0288D1)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        color: Color(0xFF38BDF8), size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isPro
                            ? tr('أذكاري برو مُفعّل', 'Azkari Pro Active',
                                'Azkari Pro Aktif')
                            : tr('ادعم التطوير أو فعّل أذكاري برو',
                                'Support Developers or Unlock Pro',
                                'Geliştiricileri Destekle veya Pro Aç'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    'التطبيق مجاني وخالٍ من الإعلانات. دعمك يساعد في تطوير المزايا الذكية مثل التسميع الصوتي وتوقيت الكلمات بالمللي ثانية ووضع الحفظ.',
                    'Azkari is ad-free. Your support funds smart features like Voice Memorization Checker, QUL word timings, and Hifz mode.',
                    'Azkari reklamsızdır. Desteğiniz sesli ezber kontrolü, kelime vurgusu ve hıfz modunu geliştirir.',
                  ),
                  style: const TextStyle(
                      color: Color(0xFFE0F2FE), fontSize: 12.5, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('نوع المساهمة', 'Contribution Type', 'Katkı Türü'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Center(
                            child: Text(tr('تفعيل أذكاري برو', 'Unlock Pro',
                                'Pro Aç'))),
                        selected: _isProUpgrade,
                        onSelected: (_) => setState(() => _isProUpgrade = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Center(
                            child: Text(tr('دعم المطورين فقط',
                                'Support Only', 'Sadece Destek'))),
                        selected: !_isProUpgrade,
                        onSelected: (_) =>
                            setState(() => _isProUpgrade = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(tr('الدولة المتاحة للدفع', 'Payment Country', 'Ülke'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedCountry,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'EG',
                      child: Text(tr('مصر (جنيه مصري EGP - متاح الآن)',
                          'Egypt (EGP - Available Now)')),
                    ),
                    DropdownMenuItem(
                      value: 'SA',
                      enabled: false,
                      child: Text(tr('السعودية (قريباً)',
                          'Saudi Arabia (Coming Soon)')),
                    ),
                    DropdownMenuItem(
                      value: 'AE',
                      enabled: false,
                      child: Text(tr('الإمارات (قريباً)', 'UAE (Coming Soon)')),
                    ),
                    DropdownMenuItem(
                      value: 'TR',
                      enabled: false,
                      child: Text(tr('تركيا (قريباً)', 'Turkey (Coming Soon)')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == 'EG') setState(() => _selectedCountry = v!);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  tr('المبلغ بالجنيه المصري (من 10 إلى 10,000 ج.م)',
                      'Amount in EGP (10 to 10,000)',
                      'Tutar EGP (10 - 10.000)'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [25, 50, 100, 250, 500].map((amt) {
                    return ActionChip(
                      label: Text('$amt EGP'),
                      onPressed: () =>
                          setState(() => _amountCtrl.text = '$amt'),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixText: 'EGP',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text(tr('المحفظة الإلكترونية', 'Mobile Wallet', 'Cüzdan'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(tr('فودافون كاش', 'Vodafone Cash')),
                      selected: _selectedMethod == 'vf_cash',
                      onSelected: (_) =>
                          setState(() => _selectedMethod = 'vf_cash'),
                    ),
                    ChoiceChip(
                      label: Text(tr('أورنج كاش', 'Orange Cash')),
                      selected: _selectedMethod == 'or_cash',
                      onSelected: (_) =>
                          setState(() => _selectedMethod = 'or_cash'),
                    ),
                    ChoiceChip(
                      label: Text(tr('اتصالات كاش', 'Etisalat Cash')),
                      selected: _selectedMethod == 'et_cash',
                      onSelected: (_) =>
                          setState(() => _selectedMethod = 'et_cash'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  decoration: InputDecoration(
                    labelText: tr('رقم المحفظة (11 رقم)',
                        'Wallet Number (11 digits)', 'Cüzdan Numarası'),
                    hintText: '010xxxxxxxx',
                    prefixIcon: const Icon(Icons.phone_android_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                ),
                if (_errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: Text(_errorMsg!,
                        style: const TextStyle(color: Colors.red, fontSize: 12.5)),
                  ),
                ],
                if (_pendingReference != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primary),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tr('المرجع:', 'Reference:')} $_pendingReference (${_countdownSec}s)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: primary),
                        ),
                        if (_instructionMsg != null &&
                            _instructionMsg!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(_instructionMsg!,
                              style: const TextStyle(fontSize: 13)),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _confirmPayment,
                            icon: const Icon(Icons.verified_rounded),
                            label: Text(tr('تأكيد الدفع الآن',
                                'Confirm Payment Now', 'Ödemeyi Onayla')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _loading ? null : _createPayment,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.lock_open_rounded),
                      label: Text(tr('متابعة الدفع عبر شحناوي',
                          'Pay with Sha7nawy', 'Sha7nawy ile Öde')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}