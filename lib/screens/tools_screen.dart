import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QiblaCity {
  final String nameAr;
  final String nameEn;
  final double lat;
  final double lng;
  const QiblaCity(this.nameAr, this.nameEn, this.lat, this.lng);
}

const List<QiblaCity> kQiblaCities = [
  QiblaCity('القاهرة، مصر', 'Cairo, Egypt', 30.0444, 31.2357),
  QiblaCity('بني سويف، مصر', 'Beni Suef, Egypt', 29.0661, 31.0994),
  QiblaCity('الإسكندرية، مصر', 'Alexandria, Egypt', 31.2001, 29.9187),
  QiblaCity('المنصورة، مصر', 'Mansoura, Egypt', 31.0409, 31.3785),
  QiblaCity('أسيوط، مصر', 'Asyut, Egypt', 27.1809, 31.1837),
  QiblaCity('الرياض، السعودية', 'Riyadh, KSA', 24.7136, 46.6753),
  QiblaCity('جدة، السعودية', 'Jeddah, KSA', 21.4858, 39.1925),
  QiblaCity('دبي، الإمارات', 'Dubai, UAE', 25.2048, 55.2708),
  QiblaCity('عمّان، الأردن', 'Amman, Jordan', 31.9454, 35.9284),
  QiblaCity('الكويت', 'Kuwait City', 29.3759, 47.9774),
  QiblaCity('الدوحة، قطر', 'Doha, Qatar', 25.2854, 51.5310),
  QiblaCity('الرباط، المغرب', 'Rabat, Morocco', 34.0209, -6.8416),
];

class ToolsHubScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final bool isEnglish;
  final bool isDarkMode;
  final VoidCallback onStateChanged;

  const ToolsHubScreen({
    super.key,
    required this.prefs,
    required this.isEnglish,
    required this.isDarkMode,
    required this.onStateChanged,
  });

  @override
  State<ToolsHubScreen> createState() => _ToolsHubScreenState();
}

class _ToolsHubScreenState extends State<ToolsHubScreen> {
  int _selectedCityIdx = 0;
  List<Map<String, dynamic>> _customHabits = [];
  final _habitController = TextEditingController();

  String tr(String ar, String en) => widget.isEnglish ? en : ar;

  @override
  void initState() {
    super.initState();
    _selectedCityIdx = widget.prefs.getInt('qiblaCityIdx') ?? 0;
    if (_selectedCityIdx >= kQiblaCities.length) _selectedCityIdx = 0;
    _loadCustomHabits();
  }

  void _loadCustomHabits() {
    final raw = widget.prefs.getString('customHabits');
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        _customHabits = list.cast<Map<String, dynamic>>();
      } catch (_) {}
    }
  }

  void _saveCustomHabits() {
    widget.prefs.setString('customHabits', jsonEncode(_customHabits));
    setState(() {});
  }

  double _calculateQiblaAngle(double lat, double lng) {
    const kaabaLat = 21.4225 * pi / 180.0;
    const kaabaLng = 39.8262 * pi / 180.0;
    final phi = lat * pi / 180.0;
    final deltaL = kaabaLng - (lng * pi / 180.0);
    final y = sin(deltaL) * cos(kaabaLat);
    final x = cos(phi) * sin(kaabaLat) - sin(phi) * cos(kaabaLat) * cos(deltaL);
    final deg = (atan2(y, x) * 180.0 / pi + 360.0) % 360.0;
    return deg;
  }

  void _exportBackup() {
    final keys = widget.prefs.getKeys();
    final Map<String, dynamic> dump = {};
    for (final k in keys) {
      if (k.startsWith('surah_cache_')) continue;
      dump[k] = widget.prefs.get(k);
    }
    final jsonStr = jsonEncode(dump);
    Share.share(jsonStr, subject: 'Azkari Backup');
  }

  void _importBackupDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('استعادة نسخة احتياطية', 'Restore Backup')),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: tr('الصق نص النسخة الاحتياطية هنا...', 'Paste backup JSON...'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('إلغاء', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final Map<String, dynamic> map = jsonDecode(ctrl.text.trim());
                for (final entry in map.entries) {
                  final v = entry.value;
                  if (v is bool) await widget.prefs.setBool(entry.key, v);
                  if (v is int) await widget.prefs.setInt(entry.key, v);
                  if (v is double) await widget.prefs.setDouble(entry.key, v);
                  if (v is String) await widget.prefs.setString(entry.key, v);
                }
                _loadCustomHabits();
                widget.onStateChanged();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('تمت الاستعادة بنجاح ', 'Restored '))),
                  );
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('النص غير صالح', 'Invalid JSON'))),
                  );
                }
              }
            },
            child: Text(tr('استعادة', 'Restore')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _habitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final city = kQiblaCities[_selectedCityIdx];
    final angle = _calculateQiblaAngle(city.lat, city.lng);
    final currentSkin = widget.prefs.getInt('sabhaSkin') ?? 0;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('الأدوات والعادات ', 'Tools & Habits ')),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: tr('اتجاه القبلة', 'Qibla')),
              Tab(text: tr('عادات وأذكار مخصصة', 'Custom Habits')),
              Tab(text: tr('شكل السبحة', 'Tasbih Skin')),
              Tab(text: tr('النسخ الاحتياطي والإشعارات', 'Backup & Alerts')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1. القبلة
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                DropdownButtonFormField<int>(
                  value: _selectedCityIdx,
                  decoration: InputDecoration(
                    labelText: tr('اختر مدينتك', 'Select City'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  items: List.generate(
                    kQiblaCities.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(widget.isEnglish
                          ? kQiblaCities[i].nameEn
                          : kQiblaCities[i].nameAr),
                    ),
                  ),
                  onChanged: (v) {
                    if (v != null) {
                      widget.prefs.setInt('qiblaCityIdx', v);
                      setState(() => _selectedCityIdx = v);
                    }
                  },
                ),
                const SizedBox(height: 28),
                Center(
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D47A1), Color(0xFF0288D1)],
                      ),
                      border: Border.all(
                          color: const Color(0xFF38BDF8), width: 4),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned(
                          top: 12,
                          child: Text('N',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Transform.rotate(
                          angle: angle * pi / 180.0,
                          child: const Icon(
                            Icons.navigation_rounded,
                            size: 90,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  tr(
'زاوية القبلة من الشمال الحقيقي: ${angle.toStringAsFixed(1)}°',
'Qibla Bearing from True North: ${angle.toStringAsFixed(1)}°',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
'وجّه أعلى الهاتف نحو الشمال ثم اتبع اتجاه السهم نحو الكعبة المشرفة ',
'Face North and follow the arrow toward the Kaaba ',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            // 2. العادات المخصصة
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _habitController,
                        decoration: InputDecoration(
                          hintText: tr('أضف ذكراً أو عادة يومية خاصة...',
'Add custom habit or dhikr...'),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () {
                        final txt = _habitController.text.trim();
                        if (txt.isEmpty) return;
                        _customHabits.add({'title': txt, 'done': false});
                        _habitController.clear();
                        _saveCustomHabits();
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_customHabits.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(tr('لم تضف أي عادات مخصصة بعد',
'No custom habits yet')),
                    ),
                  )
                else
                  ..._customHabits.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final h = entry.value;
                    return Card(
                      child: CheckboxListTile(
                        title: Text(h['title'] ?? ''),
                        value: h['done'] == true,
                        onChanged: (v) {
                          _customHabits[idx]['done'] = v ?? false;
                          _saveCustomHabits();
                        },
                        secondary: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent),
                          onPressed: () {
                            _customHabits.removeAt(idx);
                            _saveCustomHabits();
                          },
                        ),
                      ),
                    );
                  }),
              ],
            ),
            // 3. أشكال السبحة
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...[
                  (0, tr('الأزرق الملكي (الافتراضي)', 'Royal Blue'),
                      const [Color(0xFF0D47A1), Color(0xFF0288D1)]),
                  (1, tr('الأخضر الزمردي', 'Emerald Green'),
                      const [Color(0xFF065F46), Color(0xFF10B981)]),
                  (2, tr('الذهبي الكلاسيكي', 'Classic Gold'),
                      const [Color(0xFF92400E), Color(0xFFD97706)]),
                  (3, tr('الكحلي الليلي العميق', 'Deep Night'),
                      const [Color(0xFF0F172A), Color(0xFF334155)]),
                ].map(
                  (skin) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: skin.$3),
                        ),
                      ),
                      title: Text(skin.$2,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: currentSkin == skin.$1
                          ? const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF38BDF8))
                          : null,
                      onTap: () {
                        widget.prefs.setInt('sabhaSkin', skin.$1);
                        widget.onStateChanged();
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ],
            ),
            // 4. النسخ الاحتياطي وحل مشكلة الإشعارات
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.upload_file_rounded,
                        color: Color(0xFF38BDF8)),
                    title: Text(tr('تصدير نسخة احتياطية', 'Export Backup')),
                    subtitle: Text(tr(
'احفظ سجل إنجازاتك وعاداتك في ملف أو شاركه لنفسك',
'Save or share your progress & habits')),
                    onTap: _exportBackup,
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.restore_rounded,
                        color: Color(0xFF0288D1)),
                    title: Text(tr('استعادة نسخة احتياطية', 'Restore Backup')),
                    onTap: _importBackupDialog,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('حل مشكلة تأخر الإشعارات ',
'Fix Delayed Notifications '),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr(
'إذا لم تصلك تنبيهات أذكار الصباح والمساء في وقتها:\n1. افتح إعدادات الهاتف > التطبيقات > أذكاري.\n2. اختر البطارية > اختر "غير مقيد" (Unrestricted).\n3. فعّل إذن التنبيهات والظهور فوق التطبيقات.',
'If reminders are delayed:\n1. Phone Settings > Apps > Azkari.\n2. Battery > Set to "Unrestricted".\n3. Enable Notifications & Alarms.',
                          ),
                          style: const TextStyle(height: 1.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}