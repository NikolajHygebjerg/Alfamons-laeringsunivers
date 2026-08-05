import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'audio_cache_service.dart';

/// Optagelser af ord for ét barn. Erstatte admin-lyd for samme ord når mappet bruges sammen.
class KidWordRecordingService {
  static final _client = Supabase.instance.client;

  static String _wordToFileStem(String word) {
    // Filnavn-sikkert unikt id; ord er allerede normaliseret
    return word
        .replaceAll(RegExp(r'[^a-z0-9æøå]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String _storageObjectPath(String kidId, String word) {
    final stem = _wordToFileStem(word);
    final use =
        stem.isNotEmpty && stem != '_' ? stem : 'w_${word.codeUnits.hashCode}';
    return 'kid-words/$kidId/$use.m4a';
  }

  /// Barnets egne ord -> lokal cache-sti. Samme mønster som [AudioCacheService.getWordToLocalPath].
  static Future<Map<String, String>> getKidWordToLocalPath(String kidId) async {
    if (kIsWeb) return {};
    try {
      final res = await _client
          .from('kid_word_recordings')
          .select('word, audio_url')
          .eq('kid_id', kidId);
      final map = <String, String>{};
      for (final row in res as List) {
        final m = Map<String, dynamic>.from(row as Map);
        final w = (m['word'] as String?)?.trim();
        final url = m['audio_url'] as String?;
        if (w != null && w.isNotEmpty && url != null && url.isNotEmpty) {
          final path = await AudioCacheService.ensureCached(url);
          map[w.toLowerCase()] = path;
        }
      }
      return map;
    } catch (e) {
      debugPrint('KidWordRecordingService.getKidWordToLocalPath: $e');
      return {};
    }
  }

  /// Lægger [word] (forventes normaliseret: trim + små bogstaver) i [kid_word_recordings] og
  /// uploader m4a til [book-audio].
  static Future<void> saveRecording({
    required String kidId,
    required String word,
    required String filePath,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Ord-optagelse er kun i appen (ikke i browseren).');
    }
    final w = word.toLowerCase().trim();
    if (w.isEmpty) {
      throw ArgumentError('Tomt ord');
    }
    final f = File(filePath);
    if (!await f.exists()) {
      throw StateError('Manglende optagefil');
    }
    final bytes = await f.readAsBytes();
    if (bytes.length < 200) {
      throw StateError('Optagelsen er for kort.');
    }
    final object = _storageObjectPath(kidId, w);
    await _client.storage.from('book-audio').uploadBinary(
          object,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'audio/mp4'),
        );
    final publicUrl = _client.storage.from('book-audio').getPublicUrl(object);
    await AudioCacheService.invalidateCachedUrl(publicUrl);
    await _client.from('kid_word_recordings').upsert(
      {
        'kid_id': kidId,
        'word': w,
        'audio_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'kid_id,word',
    );
    await AudioCacheService.ensureCached(publicUrl);
  }
}
