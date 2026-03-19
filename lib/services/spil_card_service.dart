import 'package:supabase_flutter/supabase_flutter.dart';

/// Kort til spillet – bruges af både vs computer og PvP.
class SpilGameCard {
  final String id;
  final String avatarId;
  final String name;
  final String? letter;
  final String imageUrl;
  final int stageIndex;
  final List<SpilStrength> strengths;

  SpilGameCard({
    required this.id,
    required this.avatarId,
    required this.name,
    this.letter,
    required this.imageUrl,
    required this.stageIndex,
    required this.strengths,
  });
}

class SpilStrength {
  final int strengthIndex;
  final String name;
  final int value;

  SpilStrength({
    required this.strengthIndex,
    required this.name,
    required this.value,
  });
}

int _parseStrengthValue(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v.clamp(0, 100);
  if (v is num) return v.round().clamp(0, 100);
  return int.tryParse(v.toString()) ?? 0;
}

/// Loader kort til et barn fra kid_avatar_library og kid_avatar_history.
class SpilCardService {
  SpilCardService._();

  /// Loader et enkelt kort efter avatar_id og stage_index – også for avatars barnet ikke har i bibliotek.
  static Future<SpilGameCard?> loadCardByAvatar(
    SupabaseClient client,
    String avatarId,
    int stageIndex, {
    String idPrefix = 'match',
  }) async {
    final avRes = await client
        .from('avatars')
        .select('name,letter')
        .eq('id', avatarId)
        .maybeSingle();
    if (avRes == null) return null;

    final name = avRes['name'] as String? ?? 'Alfamon';
    final letter = avRes['letter'] as String?;

    final stageRes = await client
        .from('avatar_stages')
        .select('image_url')
        .eq('avatar_id', avatarId)
        .eq('stage_index', stageIndex)
        .maybeSingle();

    final strengthRes = await client
        .from('avatar_strengths')
        .select('strength_index,name,value')
        .eq('avatar_id', avatarId)
        .eq('stage_index', stageIndex)
        .order('strength_index');

    final imageUrl = stageRes?['image_url'] as String?;
    final strengths = (strengthRes as List)
        .map((s) => SpilStrength(
              strengthIndex: s['strength_index'] as int,
              name: s['name'] as String? ?? '',
              value: _parseStrengthValue(s['value']),
            ))
        .toList();

    if (imageUrl == null || imageUrl.isEmpty || strengths.isEmpty) return null;

    return SpilGameCard(
      id: '$idPrefix-${avatarId}_$stageIndex-${DateTime.now().millisecondsSinceEpoch}',
      avatarId: avatarId,
      name: name,
      letter: letter,
      imageUrl: imageUrl,
      stageIndex: stageIndex,
      strengths: strengths,
    );
  }

  static Future<List<SpilGameCard>> loadCardsForKid(String kidId) async {
    final client = Supabase.instance.client;

    final unlockedRes = await client
        .from('kid_unlocked_alphamons')
        .select('avatar_id')
        .eq('kid_id', kidId);
    final unlockedIds = (unlockedRes as List)
        .map((e) => e['avatar_id'] as String)
        .toSet()
        .toList();

    if (unlockedIds.isEmpty) return [];

    return _loadCardsForAvatars(client, unlockedIds, kidId);
  }

  static Future<List<SpilGameCard>> _loadCardsForAvatars(
    SupabaseClient client,
    List<String> avatarIds,
    String kidId,
  ) async {
    final cards = <SpilGameCard>[];

    final libRes = await client
        .from('kid_avatar_library')
        .select('id,avatar_id,current_stage_index,avatars(name,letter)')
        .eq('kid_id', kidId)
        .inFilter('avatar_id', avatarIds);

    final libraryRows = (libRes as List)
        .where((r) => (r['current_stage_index'] as int? ?? 0) > 0)
        .toList();

    for (final row in libraryRows) {
      final avatarId = row['avatar_id'] as String;
      final stageIndex = row['current_stage_index'] as int;
      final av = row['avatars'];
      final name = (av is Map ? av['name'] : null) as String? ?? 'Alfamon';
      final letter = (av is Map ? av['letter'] : null) as String?;

      final stageRes = await client
          .from('avatar_stages')
          .select('image_url')
          .eq('avatar_id', avatarId)
          .eq('stage_index', stageIndex)
          .maybeSingle();

      final strengthRes = await client
          .from('avatar_strengths')
          .select('strength_index,name,value')
          .eq('avatar_id', avatarId)
          .eq('stage_index', stageIndex)
          .order('strength_index');

      final imageUrl = stageRes?['image_url'] as String?;
      final strengths = (strengthRes as List)
          .map((s) => SpilStrength(
                strengthIndex: s['strength_index'] as int,
                name: s['name'] as String? ?? '',
                value: _parseStrengthValue(s['value']),
              ))
          .toList();

      if (imageUrl != null && imageUrl.isNotEmpty && strengths.isNotEmpty) {
        cards.add(SpilGameCard(
          id: 'kid-${row['id']}-${cards.length}',
          avatarId: avatarId,
          name: name,
          letter: letter,
          imageUrl: imageUrl,
          stageIndex: stageIndex,
          strengths: strengths,
        ));
      }
    }

    final historyRes = await client
        .from('kid_avatar_history')
        .select('id,avatar_id,avatars(name,letter)')
        .eq('kid_id', kidId)
        .inFilter('avatar_id', avatarIds)
        .order('finished_at', ascending: false);

    for (final row in historyRes) {
      final avatarId = row['avatar_id'] as String;
      if (cards.any((c) => c.avatarId == avatarId)) continue;

      final av = row['avatars'];
      final name = (av is Map ? av['name'] : null) as String? ?? 'Alfamon';
      final letter = (av is Map ? av['letter'] : null) as String?;

      final stageRes = await client
          .from('avatar_stages')
          .select('stage_index')
          .eq('avatar_id', avatarId)
          .order('stage_index', ascending: false)
          .limit(1);

      final maxStage = (stageRes as List).isNotEmpty
          ? (stageRes.first['stage_index'] as int)
          : 0;

      if (maxStage <= 0) continue;

      final stageData = await client
          .from('avatar_stages')
          .select('image_url')
          .eq('avatar_id', avatarId)
          .eq('stage_index', maxStage)
          .maybeSingle();

      final strengthRes = await client
          .from('avatar_strengths')
          .select('strength_index,name,value')
          .eq('avatar_id', avatarId)
          .eq('stage_index', maxStage)
          .order('strength_index');

      final imageUrl = stageData?['image_url'] as String?;
      final strengths = (strengthRes as List)
          .map((s) => SpilStrength(
                strengthIndex: s['strength_index'] as int,
                name: s['name'] as String? ?? '',
                value: _parseStrengthValue(s['value']),
              ))
          .toList();

      if (imageUrl != null && imageUrl.isNotEmpty && strengths.isNotEmpty) {
        cards.add(SpilGameCard(
          id: 'kid-hist-${row['id']}-${cards.length}',
          avatarId: avatarId,
          name: name,
          letter: letter,
          imageUrl: imageUrl,
          stageIndex: maxStage,
          strengths: strengths,
        ));
      }
    }

    return cards;
  }
}
