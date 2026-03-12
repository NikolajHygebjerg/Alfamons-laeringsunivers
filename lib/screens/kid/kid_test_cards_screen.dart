import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../utils/card_assets.dart';
import 'widgets/alfamon_card.dart';

/// Midlertidig test-side: viser kun billederne (uden kortdesign) for alle avatars stage 1.
class KidTestCardsScreen extends StatefulWidget {
  final String kidId;

  const KidTestCardsScreen({super.key, required this.kidId});

  @override
  State<KidTestCardsScreen> createState() => _KidTestCardsScreenState();
}

class _TestCard {
  final String avatarId;
  final String name;
  final String? letter;
  final String imageUrl;
  final int stageIndex;
  final List<AlfamonStrength> strengths;

  _TestCard({
    required this.avatarId,
    required this.name,
    this.letter,
    required this.imageUrl,
    required this.stageIndex,
    required this.strengths,
  });

  String? get assetPath => CardAssets.getCardAssetPath(name, stageIndex, letter: letter);

  /// PNG/JPG først (viser korrekt); SVG har flutter_svg-problemer med base64-billeder.
  List<String> get imagePathsToTry {
    final p = assetPath;
    if (p == null) return [];
    final base = p.replaceAll('.svg', '');
    return ['$base.png', '$base.jpg', p];
  }
}

/// Viser kun billedet (SVG eller netværk) uden kortdesign.
class _TestImageTile extends StatelessWidget {
  final _TestCard card;
  final double size;

  const _TestImageTile({required this.card, this.size = 120});

  @override
  Widget build(BuildContext context) {
    final pathsToTry = card.imagePathsToTry;
    final imageUrl = card.imageUrl;

    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black26),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildImage(pathsToTry, imageUrl),
          ),
          const SizedBox(height: 4),
          Text(
            card.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.95),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildImage(List<String> pathsToTry, String imageUrl) {
    if (pathsToTry.isEmpty) {
      if (imageUrl.isNotEmpty) {
        return Image.network(
          imageUrl,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
        );
      }
      return const Icon(Icons.image_not_supported, size: 48);
    }
    return FutureBuilder<String?>(
      future: _resolveFirstPath(pathsToTry),
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path != null) {
          if (path.endsWith('.png') || path.endsWith('.jpg') || path.endsWith('.jpeg')) {
            return Image.asset(
              path,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            );
          }
          return SvgPicture.asset(
            path,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          );
        }
        if (snapshot.connectionState == ConnectionState.done && imageUrl.isNotEmpty) {
          return Image.network(
            imageUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
          );
        }
        if (imageUrl.isNotEmpty) {
          return Image.network(
            imageUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
          );
        }
        return const Icon(Icons.image_not_supported, size: 48);
      },
    );
  }

  Future<String?> _resolveFirstPath(List<String> paths) async {
    for (final p in paths) {
      try {
        await rootBundle.load(p);
        return p;
      } catch (_) {}
    }
    return null;
  }
}

class _KidTestCardsScreenState extends State<KidTestCardsScreen> {
  List<_TestCard> _cards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final client = Supabase.instance.client;

    // Hent alle avatars
    final avatarsRes = await client
        .from('avatars')
        .select('id,name,letter')
        .order('letter');

    if (avatarsRes == null || (avatarsRes as List).isEmpty) {
      setState(() {
        _cards = [];
        _loading = false;
      });
      return;
    }

    final avatars = avatarsRes as List;
    final avatarIds = avatars.map((a) => a['id'] as String).toList();

    // Hent stage 1 (eller 0 hvis DB bruger 0-baseret) for alle avatars
    final stagesRes = await client
        .from('avatar_stages')
        .select('avatar_id,stage_index,image_url')
        .inFilter('avatar_id', avatarIds)
        .inFilter('stage_index', [0, 1]);

    final stageMap = <String, Map<String, dynamic>>{};
    for (final s in stagesRes as List) {
      final idx = s['stage_index'] as int;
      // Foretræk stage 1, ellers brug stage 0
      final aid = s['avatar_id'] as String;
      if (!stageMap.containsKey(aid) || idx == 1) {
        stageMap[aid] = Map<String, dynamic>.from(s);
      }
    }

    // Hent strengths for samme stage (0 eller 1)
    final strengthsRes = await client
        .from('avatar_strengths')
        .select('avatar_id,stage_index,strength_index,name,value')
        .inFilter('avatar_id', avatarIds)
        .inFilter('stage_index', [0, 1])
        .order('strength_index');

    final strengthsMap = <String, List<AlfamonStrength>>{};
    for (final s in strengthsRes as List) {
      final aid = s['avatar_id'] as String;
      final stageIdx = s['stage_index'] as int;
      final stageData = stageMap[aid];
      if (stageData == null) continue;
      // Kun brug strengths der matcher avatar's stage
      if (stageIdx != (stageData['stage_index'] as int)) continue;

      strengthsMap.putIfAbsent(aid, () => []);
      strengthsMap[aid]!.add(AlfamonStrength(
        strengthIndex: s['strength_index'] as int,
        name: s['name'] as String? ?? '',
        value: s['value'] as int? ?? 0,
      ));
    }

    final cards = <_TestCard>[];
    for (final av in avatars) {
      final avatarId = av['id'] as String;
      final stageData = stageMap[avatarId];
      if (stageData == null) continue;

      final strengths = strengthsMap[avatarId] ?? [];
      if (strengths.isEmpty) continue;

      final stageIndex = stageData['stage_index'] as int;
      final imageUrl = stageData['image_url'] as String? ?? '';
      cards.add(_TestCard(
        avatarId: avatarId,
        name: av['name'] as String? ?? 'Alfamon',
        letter: av['letter'] as String?,
        imageUrl: imageUrl,
        stageIndex: stageIndex >= 1 ? stageIndex : 1,
        strengths: strengths,
      ));
    }

    setState(() {
      _cards = cards;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final isTablet = shortestSide >= 600;
    final bgAsset = isTablet
        ? 'assets/baggrund_roedipad.svg'
        : 'assets/baggrund_roediphone.svg';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: SvgPicture.asset(bgAsset, fit: BoxFit.cover),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go('/kid/today/${widget.kidId}'),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          'Test – kun billeder stage 1',
                          style: TextStyle(
                            fontSize: isTablet ? 28 : 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _cards.isEmpty
                          ? Center(
                              child: Text(
                                'Ingen avatars med stage 1 fundet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 16,
                                alignment: WrapAlignment.center,
                                children: _cards
                                    .map((c) => _TestImageTile(card: c, size: 120))
                                    .toList(),
                              ),
                            ),
                ),
                _buildBottomNav(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      color: Colors.black26,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.today,
                  label: 'I dag',
                  onTap: () => context.go('/kid/today/${widget.kidId}'),
                ),
                _NavItem(
                  icon: Icons.calendar_view_week,
                  label: 'Ugen',
                  onTap: () => context.go('/kid/week/${widget.kidId}'),
                ),
                _NavItem(
                  icon: Icons.library_books,
                  label: 'Bibliotek',
                  onTap: () => context.go('/kid/library/${widget.kidId}'),
                ),
                _NavItem(
                  icon: Icons.sports_esports,
                  label: 'Spil',
                  onTap: () => context.go('/kid/spil/${widget.kidId}'),
                ),
                _NavItem(
                  icon: Icons.bug_report,
                  label: 'Test',
                  selected: true,
                ),
                _NavItem(
                  icon: Icons.emoji_events,
                  label: 'Præstationer',
                  onTap: () => context.go('/kid/achievements/${widget.kidId}'),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
              if (context.mounted) context.go('/auth');
            },
            child: const Text(
              'Log ud',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: selected ? Colors.amber : Colors.white70,
          size: 28,
        ),
        Text(
          label,
          style: TextStyle(
            color: selected ? Colors.amber : Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: child,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: child,
    );
  }
}
