import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _cacheKey = 'audio_cache_synced_v1';

/// Web: ingen disk-cache – brug direkte URL’er til afspilning.
class AudioCacheService {
  static final _client = Supabase.instance.client;

  static Future<String?> getCachedPath(String url) async => null;

  static Future<String> ensureCached(String url) async => url;

  static Future<void> syncAll() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await _client.from('audio_library').select('audio_url');
      final urls = (res as List)
          .map((r) => r['audio_url'] as String?)
          .where((u) => u != null && u.isNotEmpty)
          .cast<String>()
          .toList();
      if (urls.isNotEmpty) {
        await prefs.setBool(_cacheKey, true);
      }
    } catch (_) {}
  }

  static Future<Map<String, String>> getWordToLocalPath() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSynced = prefs.getBool(_cacheKey) ?? false;

    try {
      final res = await _client
          .from('audio_library')
          .select('word, audio_url');
      final map = <String, String>{};
      for (final row in res as List) {
        final word = (row['word'] as String?)?.trim();
        final url = row['audio_url'] as String?;
        if (word != null && word.isNotEmpty && url != null && url.isNotEmpty) {
          map[word.toLowerCase()] = url;
        }
      }
      if (!hasSynced) {
        await prefs.setBool(_cacheKey, true);
      }
      return map;
    } catch (_) {
      return {};
    }
  }
}
