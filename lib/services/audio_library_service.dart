import 'package:supabase_flutter/supabase_flutter.dart';

/// Henter ord fra lydbiblioteket – word (lowercase) -> audio_url
class AudioLibraryService {
  static final _client = Supabase.instance.client;

  static Future<Map<String, String>> getWordToAudioUrl() async {
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
      return map;
    } catch (_) {
      return {};
    }
  }
}
