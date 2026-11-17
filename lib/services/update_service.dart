import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _versionUrl =
      'https://raw.githubusercontent.com/ahmfalcon00868-maker/azkari-app/main/version.json';
  static const String _releasesApiUrl =
      'https://api.github.com/repos/ahmfalcon00868-maker/azkari-app/releases/latest';

  static Future<void> checkForUpdate(
    BuildContext context, {
    bool isEnglish = false,
    bool showNoUpdateMessage = false,
  }) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final int localBuild = int.tryParse(info.buildNumber) ?? 0;

      int remoteBuild = 0;
      String remoteVersion = '';
      String apkUrl = '';
      String notes = '';

      // 1. Try version.json first (cache-busted)
      try {
        final response = await http.get(
          Uri.parse('$_versionUrl?t=${DateTime.now().millisecondsSinceEpoch}'),
          headers: {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          remoteBuild = (data['build_number'] as num?)?.toInt() ?? 0;
          remoteVersion = (data['version'] ?? '').toString();
          apkUrl = (data['apk_url'] ?? '').toString();
          notes = (data['notes'] ?? '').toString();
        }
      } catch (_) {}

      // 2. Fallback to GitHub Releases API if version.json missing or not newer
      if (remoteBuild <= localBuild || apkUrl.isEmpty) {
        try {
          final relRes = await http
              .get(Uri.parse(_releasesApiUrl))
              .timeout(const Duration(seconds: 6));
          if (relRes.statusCode == 200) {
            final rel = jsonDecode(utf8.decode(relRes.bodyBytes))
                as Map<String, dynamic>;
            final tag = (rel['tag_name'] ?? '').toString(); // e.g. v2.2.0 or v2.2.0+4
            final assets = (rel['assets'] as List<dynamic>?) ?? [];
            String? releaseApk;
            for (final a in assets) {
              final url = (a['browser_download_url'] ?? '').toString();
              if (url.endsWith('.apk')) {
                releaseApk = url;
                break;
              }
            }
            if (releaseApk != null && tag.isNotEmpty) {
              final cleanTag = tag.replaceFirst(RegExp(r'^v'), '');
              if (cleanTag != info.version && remoteBuild <= localBuild) {
                remoteVersion = cleanTag;
                apkUrl = releaseApk;
                notes = (rel['body'] ?? '').toString();
                remoteBuild = localBuild + 1;
              }
            }
          }
        } catch (_) {}
      }

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
                onPressed: () {
                  Navigator.pop(ctx);
                  _downloadAndInstallApk(context, apkUrl, isEnglish);
                },
                child: Text(isEnglish ? 'Update Now' : 'تحديث الآن'),
              ),
            ],
          ),
        );
      } else if (showNoUpdateMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEnglish
                ? 'Latest version (${info.version}+${info.buildNumber} | GitHub: $remoteBuild)'
                : 'أنت على أحدث إصدار (${info.version}+${info.buildNumber} | GitHub: $remoteBuild)'),
          ),
        );
      }
    } catch (_) {
      if (showNoUpdateMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEnglish
                ? 'Could not check for updates'
                : 'تعذر التحقق من التحديثات، تأكد من الإنترنت'),
          ),
        );
      }
    }
  }

  static Future<void> _downloadAndInstallApk(
    BuildContext context,
    String apkUrl,
    bool isEnglish,
  ) async {
    double progress = 0;
    StateSetter? setDialogState;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) {
            setDialogState = setS;
            return AlertDialog(
              title: Text(
                  isEnglish ? 'Downloading Update...' : 'جاري تحميل التحديث...'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress > 0 ? progress : null),
                  const SizedBox(height: 10),
                  Text('${(progress * 100).round()}%'),
                ],
              ),
            );
          },
        ),
      );
    }

    try {
      final client = http.Client();
      final req = http.Request('GET', Uri.parse(apkUrl));
      final streamed = await client.send(req);
      final total = streamed.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/azkari_update.apk');
      final sink = file.openWrite();
      int received = 0;

      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && setDialogState != null) {
          setDialogState!(() => progress = received / total);
        }
      }
      await sink.close();
      client.close();

      if (context.mounted) Navigator.pop(context);
      final res = await OpenFilex.open(file.path);
      if (res.type != ResultType.done) {
        final uri = Uri.parse(apkUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      if (context.mounted) Navigator.pop(context);
      final uri = Uri.parse(apkUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}