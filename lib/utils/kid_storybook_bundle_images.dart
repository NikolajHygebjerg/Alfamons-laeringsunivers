import 'card_assets.dart';
import 'flutter_asset_key_cache.dart';

/// Lister lokale [assets/alfamons_bundles/trace/] (og [books/]) for bogbyggeren —
/// Supabase [avatar_stages] viser ofte ~5 udviklinger; bundtet indeholder flere
/// raster-billeder pr. Alfamon.
class KidStorybookBundleImages {
  KidStorybookBundleImages._();

  static Set<String>? _manifestKeys;

  static Future<Set<String>> _keys() async {
    final c = _manifestKeys;
    if (c != null) return c;
    _manifestKeys = await FlutterAssetKeyCache.allKeys();
    return _manifestKeys!;
  }

  static bool _matchesPrefix(String key, String subdir, String? prefix) {
    if (!key.startsWith('assets/alfamons_bundles/$subdir/')) return false;
    if (key.endsWith('/')) return false;
    final last = key.split('/').last;
    if (last.startsWith('.')) return false;
    if (prefix == null || prefix.isEmpty) return true;
    final p = prefix.toLowerCase();
    final base = last.replaceAll(
      RegExp(r'\.(png|jpg|jpeg|webp|gif|svg)$', caseSensitive: false),
      '',
    );
    return base.toLowerCase().startsWith(p);
  }

  /// Alle asset-stier i trace/ + books/ der hører til [prefix] (fx "Atiach", "Xbug").
  static Future<List<String>> pathsForTracePrefix(String? prefix) async {
    if (prefix == null || prefix.trim().isEmpty) return [];
    final p0 = prefix.trim();
    final keys = await _keys();
    final out = <String>[];
    for (final k in keys) {
      if (_matchesPrefix(k, 'trace', p0) || _matchesPrefix(k, 'books', p0)) {
        out.add(k);
      }
    }
    out.sort();
    return out;
  }

  /// [name] kan være tom, hvis [letter] er sat (bogstav A→B→C … til trace-prefix).
  static Future<List<String>> pathsForAvatar({
    String? name,
    String? letter,
  }) async {
    final n = (name ?? '').trim();
    final prefix = CardAssets.traceFilePrefixFor(n, letter: letter);
    return pathsForTracePrefix(prefix);
  }
}
