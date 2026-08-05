import 'package:flutter/services.dart';

/// Alle asset-nøgler i appen. Bruger [AssetManifest.loadFromAssetBundle] så det virker
/// på Flutter 3.19+ (hvor [AssetManifest.json] ikke længere genereres; i stedet
/// [AssetManifest.bin] / samme API som frameworket).
class FlutterAssetKeyCache {
  FlutterAssetKeyCache._();

  static Set<String>? _all;

  static Future<Set<String>> allKeys() async {
    if (_all != null) return _all!;
    final m = await AssetManifest.loadFromAssetBundle(rootBundle);
    _all = m.listAssets().toSet();
    return _all!;
  }

  /// Sæt for tests / hvis I genindlæser assets.
  static void clearForTest() {
    _all = null;
  }
}
