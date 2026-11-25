import 'dart:async';
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

  // Background & Pause/Resume download controller state
  static bool _isDownloading = false;
  static bool _isPaused = false;
  static bool _isCancelled = false;
  static bool _isInBackground = false;
  static double _progress = 0.0;
  static int _receivedBytes = 0;
  static int _totalBytes = 0;
  static String? _activeApkUrl;
  static http.Client? _activeClient;
  static StreamSubscription<List<int>>? _activeSub;
  static StateSetter? _dialogSetState;

  static Future<void> checkForUpdate(
    BuildContext context, {
    bool isEnglish = false,
    bool showNoUpdateMessage = false,
  }) async {
    if (_isDownloading && _isInBackground && context.mounted) {
      _showDownloadDialog(context, isEnglish);
      return;
    }

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
            final tag = (rel['tag_name'] ?? '').toString();
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _startOrResumeDownload(context, apkUrl, isEnglish,
                      reset: true);
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

  static void _refreshDialog() {
    try {
      _dialogSetState?.call(() {});
    } catch (_) {}
  }

  static void _showDownloadDialog(BuildContext context, bool isEnglish) {
    _isInBackground = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          _dialogSetState = setS;
          final mbDone = (_receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          final mbTotal = _totalBytes > 0
              ? (_totalBytes / (1024 * 1024)).toStringAsFixed(1)
              : '--';
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Text(
              _isPaused
                  ? (isEnglish ? 'Download Paused' : 'التحميل متوقف مؤقتاً')
                  : (isEnglish
                      ? 'Downloading Update...'
                      : 'جاري تحميل التحديث...'),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: _progress > 0 ? _progress : null,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${(_progress * 100).round()}%',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('$mbDone / $mbTotal MB',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  _isCancelled = true;
                  _isDownloading = false;
                  _isPaused = false;
                  await _activeSub?.cancel();
                  _activeClient?.close();
                  _dialogSetState = null;
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(isEnglish ? 'Cancel' : 'إلغاء',
                    style: const TextStyle(color: Colors.redAccent)),
              ),
              OutlinedButton(
                onPressed: () async {
                  if (_isPaused) {
                    _isPaused = false;
                    _refreshDialog();
                    if (_activeApkUrl != null) {
                      _runChunkedDownload(context, _activeApkUrl!, isEnglish);
                    }
                  } else {
                    _isPaused = true;
                    await _activeSub?.cancel();
                    _activeClient?.close();
                    _refreshDialog();
                  }
                },
                child: Text(
                  _isPaused
                      ? (isEnglish ? 'Resume' : 'استئناف')
                      : (isEnglish ? 'Pause' : 'إيقاف مؤقت'),
                ),
              ),
              FilledButton(
                onPressed: () {
                  _isInBackground = true;
                  _dialogSetState = null;
                  Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEnglish
                              ? 'Downloading update in background...'
                              : 'جاري استكمال تحميل التحديث في الخلفية...',
                        ),
                      ),
                    );
                  }
                },
                child: Text(isEnglish ? 'Background' : 'في الخلفية'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _startOrResumeDownload(
    BuildContext context,
    String apkUrl,
    bool isEnglish, {
    bool reset = false,
  }) async {
    _activeApkUrl = apkUrl;
    _isCancelled = false;
    _isPaused = false;
    _isDownloading = true;
    if (reset) {
      _receivedBytes = 0;
      _totalBytes = 0;
      _progress = 0.0;
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/azkari_update.apk');
      if (await f.exists()) await f.delete();
    }
    if (context.mounted) {
      _showDownloadDialog(context, isEnglish);
    }
    await _runChunkedDownload(context, apkUrl, isEnglish);
  }

  static Future<void> _runChunkedDownload(
    BuildContext context,
    String apkUrl,
    bool isEnglish,
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/azkari_update.apk');
      final existingLen = await file.exists() ? await file.length() : 0;
      _receivedBytes = existingLen;

      final client = http.Client();
      _activeClient = client;
      final req = http.Request('GET', Uri.parse(apkUrl));
      if (existingLen > 0) {
        req.headers['Range'] = 'bytes=$existingLen-';
      }
      final streamed = await client.send(req);

      if (streamed.statusCode != 200 && streamed.statusCode != 206) {
        client.close();
        throw Exception('HTTP ${streamed.statusCode}');
      }

      final isPartial = streamed.statusCode == 206;
      if (!isPartial && existingLen > 0) {
        await file.delete();
        _receivedBytes = 0;
      }
      final contentLen = streamed.contentLength ?? 0;
      if (contentLen > 0) {
        _totalBytes = isPartial ? existingLen + contentLen : contentLen;
      }

      final sink = file.openWrite(
          mode: isPartial ? FileMode.append : FileMode.write);
      final completer = Completer<void>();

      _activeSub = streamed.stream.listen(
        (chunk) {
          sink.add(chunk);
          _receivedBytes += chunk.length;
          if (_totalBytes > 0) {
            _progress = (_receivedBytes / _totalBytes).clamp(0.0, 1.0);
          }
          _refreshDialog();
        },
        onDone: () async {
          await sink.close();
          client.close();
          if (!completer.isCompleted) completer.complete();
        },
        onError: (e) async {
          await sink.close();
          client.close();
          if (!completer.isCompleted) completer.completeError(e);
        },
        cancelOnError: true,
      );

      await completer.future;

      if (_isPaused || _isCancelled) {
        if (_isCancelled && await file.exists()) {
          await file.delete();
        }
        return;
      }

      _isDownloading = false;

      if (await file.length() < 5 * 1024 * 1024) {
        await file.delete();
        throw Exception('Invalid APK size');
      }

      if (!_isInBackground && _dialogSetState != null && context.mounted) {
        _dialogSetState = null;
        Navigator.pop(context);
      }

      if (_isInBackground && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text(isEnglish
                ? 'Update downloaded and ready to install!'
                : 'اكتمل تحميل التحديث وجاهز للتثبيت!'),
            action: SnackBarAction(
              label: isEnglish ? 'Install' : 'تثبيت الآن',
              onPressed: () => OpenFilex.open(
                file.path,
                type: 'application/vnd.android.package-archive',
              ),
            ),
          ),
        );
      } else {
        final res = await OpenFilex.open(
          file.path,
          type: 'application/vnd.android.package-archive',
        );
        if (res.type != ResultType.done) {
          final uri = Uri.parse(apkUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      }
    } catch (_) {
      if (_isPaused || _isCancelled) return;
      _isDownloading = false;
      if (!_isInBackground && _dialogSetState != null && context.mounted) {
        _dialogSetState = null;
        Navigator.pop(context);
      }
      final uri = Uri.parse(apkUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}