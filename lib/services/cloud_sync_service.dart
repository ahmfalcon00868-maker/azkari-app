import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Free Cloud Sync & Local JSON Backup Service for Azkari.
/// Replace [kSupabaseUrl] and [kSupabaseAnonKey] with your Supabase project
/// credentials to enable automatic cloud sync across devices.
class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  // TODO: Replace with your own Supabase URL & Anon Key (optional; local JSON backup works offline without keys)
  static const String kSupabaseUrl = 'YOUR_SUPABASE_URL';
  static const String kSupabaseAnonKey = 'sb_publishable_COpqQQHx_d5P4TxnCTbO-w_dB2O-5gZ';

  static bool get isCloudConfigured =>
      kSupabaseUrl.startsWith('https://') &&
      !kSupabaseUrl.contains('YOUR_SUPABASE_URL') &&
      kSupabaseAnonKey.isNotEmpty &&
      !kSupabaseAnonKey.contains('YOUR_SUPABASE_ANON_KEY');

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
            Uri.parse('$kSupabaseUrl/rest/v1/azkari_sync?on_conflict=user_id'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': kSupabaseAnonKey,
              'Authorization': 'Bearer $kSupabaseAnonKey',
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await prefs.setString(
            'last_cloud_sync_at', DateTime.now().toIso8601String());
        return (true, 'Synced successfully');
      }
      return (false, 'HTTP ${res.statusCode}');
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
        Uri.parse(
            '$kSupabaseUrl/rest/v1/azkari_sync?user_id=eq.${Uri.encodeComponent(accountId)}&select=payload'),
        headers: {
          'apikey': kSupabaseAnonKey,
          'Authorization': 'Bearer $kSupabaseAnonKey',
        },
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
      return (false, 'HTTP ${res.statusCode}');
    } catch (e) {
      return (false, e.toString());
    }
  }
}