import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _versionUrl =
      'https://raw.githubusercontent.com/ahmfalcon00868-maker/azkari-app/main/version.json';

  static Future<void> checkForUpdate(
    BuildContext context, {
    bool isEnglish = false,
  }) async {
    try {
      final response = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return;

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final int remoteBuild = (data['build_number'] as num?)?.toInt() ?? 0;
      final String remoteVersion = (data['version'] ?? '').toString();
      final String apkUrl = (data['apk_url'] ?? '').toString();
      final String notes = (data['notes'] ?? '').toString();

      final info = await PackageInfo.fromPlatform();
      final int localBuild = int.tryParse(info.buildNumber) ?? 0;

      if (remoteBuild > localBuild && apkUrl.isNotEmpty && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            title: Text(
              isEnglish
                  ? 'New Update Available ($remoteVersion)'
                  : 'تحديث جديد متاح ($remoteVersion)',
            ),
            content: Text(
              notes.isNotEmpty
                  ? notes
                  : (isEnglish
                      ? 'A new version of Azkari is ready.'
                      : 'يتوفر إصدار جديد من تطبيق أذكاري.'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isEnglish ? 'Later' : 'لاحقاً'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(apkUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Text(isEnglish ? 'Update Now' : 'تحديث الآن'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      // يتجاهل الفحص بهدوء في حالة عدم وجود إنترنت
    }
  }
}