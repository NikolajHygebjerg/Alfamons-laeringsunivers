import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/flutter_asset_key_cache.dart';

/// Tilknytning af bundtede [asset_path]-billeder til en Alfamon (bogbygger).
class BookBuilderGalleryService {
  BookBuilderGalleryService._();

  static const String kAdminEmail = 'nikolaj@begejstring.dk';

  static final _client = Supabase.instance.client;

  static final _imageKey = RegExp(
    r'\.(png|jpg|jpeg|gif|webp)$',
    caseSensitive: false,
  );

  /// Alle billed-assets ifølge appens asset-manifest (alt der shipper med i bundten).
  static Future<List<String>> listBundledImageAssetKeys() async {
    final keys = await FlutterAssetKeyCache.allKeys();
    final out = <String>[];
    for (final s in keys) {
      if (!s.startsWith('assets/')) continue;
      if (!_imageKey.hasMatch(s)) continue;
      if (s.contains('FontManifest') || s.contains('/fonts/')) continue;
      out.add(s);
    }
    out.sort();
    return out;
  }

  static Future<bool> isCurrentUserGalleryAdmin() async {
    final e = _client.auth.currentUser?.email?.trim();
    return e == kAdminEmail;
  }

  static Future<List<Map<String, dynamic>>> fetchAllAssignments() async {
    final r = await _client
        .from('book_builder_gallery')
        .select('id, asset_path, avatar_id, sort_order')
        .order('sort_order');
    return (r as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Upsert: én sti pr. række; [avatarId] `null` = fjern tilknytning.
  static Future<void> setAssignmentForAssetPath({
    required String assetPath,
    required String? avatarId,
    int sortOrder = 0,
  }) async {
    final t = assetPath.trim();
    if (t.isEmpty) return;
    if (avatarId == null || avatarId.trim().isEmpty) {
      await _client.from('book_builder_gallery').delete().eq('asset_path', t);
      return;
    }
    await _client.from('book_builder_gallery').upsert(
      {
        'asset_path': t,
        'avatar_id': avatarId,
        'sort_order': sortOrder,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'asset_path',
    );
  }

  /// Tilknyttede stier for én Alfamon — bruges fra [KidStorybookService.imageUrlsForAvatar].
  static Future<List<String>> assetPathsForAvatar(String avatarId) async {
    if (avatarId.trim().isEmpty) return <String>[];
    try {
      final r = await _client
          .from('book_builder_gallery')
          .select('asset_path, sort_order')
          .eq('avatar_id', avatarId)
          .order('sort_order');
      final out = <String>[];
      for (final row in r as List) {
        final p = (row as Map)['asset_path'] as String?;
        final t = (p ?? '').trim();
        if (t.isNotEmpty) out.add(t);
      }
      return out;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116' || e.message.contains('does not exist')) {
        return <String>[];
      }
      debugPrint('book_builder_gallery: $e');
      rethrow;
    }
  }
}
