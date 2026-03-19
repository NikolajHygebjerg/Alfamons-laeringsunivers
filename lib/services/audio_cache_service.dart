import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _cacheKey = 'audio_cache_synced_v1';

/// Henter og cacher lydfiler fra lydbiblioteket. Synkroniseres ved første brug.
class AudioCacheService {
  static Directory? _cacheDir;
  static final _client = Supabase.instance.client;

  static Future<Directory> _getCacheDir() async {
    _cacheDir ??= Directory('${(await getApplicationDocumentsDirectory()).path}/audio_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    return _cacheDir!;
  }

  static String _urlToFilename(String url) {
    final uri = Uri.parse(url);
    final seg = uri.pathSegments;
    final last = seg.isNotEmpty ? seg.last : 'audio';
    return last.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  /// Returnerer lokal sti hvis filen er i cache, ellers null.
  static Future<String?> getCachedPath(String url) async {
    final dir = await _getCacheDir();
    final name = _urlToFilename(url);
    final file = File('${dir.path}/$name');
    return await file.exists() ? file.path : null;
  }

  /// Henter fil fra URL og gemmer i cache. Returnerer lokal sti.
  static Future<String> ensureCached(String url) async {
    final cached = await getCachedPath(url);
    if (cached != null) return cached;

    final dir = await _getCacheDir();
    final name = _urlToFilename(url);
    final file = File('${dir.path}/$name');

    final uri = Uri.parse(url);
    final request = await HttpClient().getUrl(uri);
    final response = await request.close();
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Synkroniserer alle lydfiler fra audio_library til lokal cache.
  /// Køres i baggrunden ved første brug.
  static Future<void> syncAll() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await _client
          .from('audio_library')
          .select('audio_url');
      final urls = (res as List)
          .map((r) => r['audio_url'] as String?)
          .where((u) => u != null && u.isNotEmpty)
          .cast<String>()
          .toList();

      for (final url in urls) {
        try {
          await ensureCached(url);
        } catch (_) {}
      }
      await prefs.setBool(_cacheKey, true);
    } catch (_) {}
  }

  /// Returnerer word -> lokal sti. Synkroniserer cache hvis nødvendigt.
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
          final path = await ensureCached(url);
          map[word.toLowerCase()] = path;
        }
      }
      if (!hasSynced) {
        prefs.setBool(_cacheKey, true);
      }
      return map;
    } catch (_) {
      return {};
    }
  }
}
