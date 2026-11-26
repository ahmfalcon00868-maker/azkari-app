import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Free Cloud Sync & Local JSON Backup Service for Azkari.
///
/// [kSupabaseProjectUrl] must be the **project base URL only**
/// (e.g. `https://project-ref.supabase.co`) — never a full function/REST URL,
/// because every endpoint below is built by appending its own path. A URL with
/// a path makes every request hit the wrong place (404), which is why
/// [isCloudConfigured] rejects it.
class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  static const String kSupabaseProjectUrl =
      'https://knwtqvzwojywtascbeil.supabase.co';

  /// Base project URL (kept for existing call sites).
  static const String kSupabaseUrl = kSupabaseProjectUrl;

  /// Publishable client key. Safe to ship in the app; RLS protects the data.
  static const String kSupabaseAnonKey =
      'sb_publishable_COpqQQHx_d5P4TxnCTbO-w_dB2O-5gZ';

  /// `apikey`-only headers.
  ///
  /// Supabase's publishable keys (`sb_publishable_…`) are NOT JWTs, so they must
  /// never be sent as `Authorization: Bearer …` — the gateway then tries to
  /// verify them as a JWT and answers 401 "Invalid JWT". Only legacy `eyJ…`
  /// keys may be used in the Authorization header, and those are handled below.
  static Map<String, String> get authHeaders {
    final key = kSupabaseAnonKey.trim();
    final headers = <String, String>{'apikey': key};
    if (key.startsWith('eyJ')) {
      headers['Authorization'] = 'Bearer $key';
    }
    return headers;
  }

  static Map<String, String> get jsonAuthHeaders =>
      {...authHeaders, 'Content-Type': 'application/json'};

  static String get _base {
    var url = kSupabaseProjectUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// PostgREST base: `<project>/rest/v1`
  static String get restUrl => '$_base/rest/v1';

  /// Edge Functions base: `<project>/functions/v1`
  static String get functionsUrl => '$_base/functions/v1';

  /// Builds a PostgREST URL, e.g. [rest] `azkari_sync?select=payload`.
  static String rest(String pathAndQuery) => '$restUrl/$pathAndQuery';

  /// Builds an Edge Function URL, e.g. [function] `verify-bybit`.
  static String function(String name) => '$functionsUrl/$name';

  static bool get isCloudConfigured {
    final url = kSupabaseProjectUrl.trim();
    if (!url.startsWith('https://') || !url.contains('.supabase.co')) {
      return false;
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }
    return kSupabaseAnonKey.trim().length > 20;
  }

  /// Human readable hint for the HTTP failures that are actually actionable.
  static String describeHttpFailure(int statusCode) {
    switch (statusCode) {
      case 401:
        return 'انتهت أو رُفضت صلاحية الاتصال بالسحابة (401). تأكد من صحة مفتاح Supabase وأنه في ترويسة apikey فقط.';
      case 403:
        return 'السحابة رفضت العملية (403). راجع سياسات RLS للجداول في Supabase.';
      case 404:
        return 'المسار أو الجدول غير موجود على السحابة (404). تأكد من إنشاء الجداول في Supabase.';
      default:
        return 'فشل الاتصال بالسحابة (HTTP $statusCode).';
    }
  }

  static const List<String> _syncKeys = [
    'totalTasbihCount',
    'streakCount',
    'streakFreezeCount',
    'activityDays',
    'firstInstallDate',
    'favoriteAzkarIds',
    'customAzkar',
    'bookmarkedSurahs',
    'lastQuranSurah',
    'lastQuranAyah',
    'is_azkari_pro',
    'pro_support_total_egp',
  ];

  Map<String, dynamic> exportSnapshot(SharedPreferences prefs) {
    final map = <String, dynamic>{
      'schema': 'azkari_sync_v1',
      'exported_at': DateTime.now().toIso8601String(),
      'data': <String, dynamic>{},
    };
    final data = map['data'] as Map<String, dynamic>;
    for (final k in _syncKeys) {
      if (prefs.containsKey(k)) {
        data[k] = prefs.get(k);
      }
    }
    return map;
  }

  String exportSnapshotJson(SharedPreferences prefs) {
    return const JsonEncoder.withIndent('  ').convert(exportSnapshot(prefs));
  }

  Future<bool> importSnapshotJson(
      SharedPreferences prefs, String rawJson) async {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) return false;
      final data = (decoded['data'] is Map<String, dynamic>)
          ? decoded['data'] as Map<String, dynamic>
          : decoded;
      for (final entry in data.entries) {
        if (!_syncKeys.contains(entry.key)) continue;
        final val = entry.value;
        if (val is int) {
          await prefs.setInt(entry.key, val);
        } else if (val is bool) {
          await prefs.setBool(entry.key, val);
        } else if (val is double) {
          await prefs.setDouble(entry.key, val);
        } else if (val is String) {
          await prefs.setString(entry.key, val);
        } else if (val is List) {
          await prefs.setStringList(
              entry.key, val.map((e) => e.toString()).toList());
        }
      }
      await prefs.setString(
          'last_cloud_sync_at', DateTime.now().toIso8601String());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<(bool, String)> pushToCloud(
      SharedPreferences prefs, String accountId) async {
    if (!isCloudConfigured) {
      await prefs.setString(
          'last_cloud_sync_at', DateTime.now().toIso8601String());
      return (
        false,
        'Cloud endpoint not configured yet (YOUR_SUPABASE_URL). Use JSON backup or add your Supabase keys.'
      );
    }
    try {
      final payload = {
        'user_id': accountId,
        'payload': exportSnapshot(prefs),
        'updated_at': DateTime.now().toIso8601String(),
      };
      final res = await http
          .post(
            Uri.parse(rest('azkari_sync?on_conflict=user_id')),
            headers: {
              ...jsonAuthHeaders,
              'Prefer': 'resolution=merge-duplicates,return=minimal',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await prefs.setString(
            'last_cloud_sync_at', DateTime.now().toIso8601String());
        return (true, 'Synced successfully');
      }
      return (false, describeHttpFailure(res.statusCode));
    } catch (e) {
      return (false, e.toString());
    }
  }

  Future<(bool, String)> pullFromCloud(
      SharedPreferences prefs, String accountId) async {
    if (!isCloudConfigured) {
      return (
        false,
        'Cloud endpoint not configured yet (YOUR_SUPABASE_URL).'
      );
    }
    try {
      final res = await http.get(
        Uri.parse(rest(
            'azkari_sync?user_id=eq.${Uri.encodeComponent(accountId)}&select=payload')),
        headers: authHeaders,
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List && list.isNotEmpty && list.first['payload'] != null) {
          final ok = await importSnapshotJson(
              prefs, jsonEncode(list.first['payload']));
          return (ok, ok ? 'Restored from cloud' : 'Invalid cloud payload');
        }
        return (false, 'No cloud backup found for this account');
      }
      return (false, describeHttpFailure(res.statusCode));
    } catch (e) {
      return (false, e.toString());
    }
  }
}