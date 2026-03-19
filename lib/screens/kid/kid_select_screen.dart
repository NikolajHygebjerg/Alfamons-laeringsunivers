import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/kid.dart';

class KidSelectScreen extends StatefulWidget {
  const KidSelectScreen({super.key});

  @override
  State<KidSelectScreen> createState() => _KidSelectScreenState();
}

class _KidSelectScreenState extends State<KidSelectScreen> {
  List<Kid> _kids = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadKids();
  }

  Future<void> _loadKids() async {
    final res = await Supabase.instance.client
        .from('kids')
        .select('id,name,pin_code,avatar_url')
        .order('created_at');
    setState(() {
      _kids = (res as List).map((e) => Kid.fromJson(e)).toList();
      _loading = false;
    });
  }

  Future<void> _selectKid(Kid kid) async {
    bool stayLoggedIn = true;
    if (kid.pinCode != null && kid.pinCode!.isNotEmpty) {
      final controller = TextEditingController();
      bool stayLoggedInValue = true;
      final result = await showDialog<({bool ok, bool stayLoggedIn})>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Indtast PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: '4-cifret PIN',
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: stayLoggedInValue,
                  onChanged: (v) => setState(() => stayLoggedInValue = v ?? true),
                  title: const Text('Forbliv logget ind'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, (ok: false, stayLoggedIn: false)),
                child: const Text('Annuller'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, (ok: true, stayLoggedIn: stayLoggedInValue)),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      );
      if (result == null || !result.ok) return;
      final pin = controller.text;
      if (pin.length != 4 || pin != kid.pinCode) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Forkert PIN')),
          );
        }
        return;
      }
      stayLoggedIn = result.stayLoggedIn;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kidId', kid.id);
    await prefs.setBool('kidStayLoggedIn', stayLoggedIn);

    if (mounted) {
      context.go('/kid/today/${kid.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final isTablet = shortestSide >= 600;
    final bgAsset =
        isTablet ? 'assets/baggrund_roedipad.svg' : 'assets/baggrund_roediphone.svg';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: SvgPicture.asset(bgAsset, fit: BoxFit.cover),
          ),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _kids.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Ingen børn tilføjet. Gå til Admin for at tilføje.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'Vælg barn',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              child: GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 6,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 0.85,
                                ),
                                itemCount: _kids.length,
                                itemBuilder: (_, i) {
                                  final kid = _kids[i];
                                  return _KidCard(
                                    kid: kid,
                                    onLogin: () => _selectKid(kid),
                                    onAvatarUpdated: _loadKids,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _KidCard extends StatelessWidget {
  final Kid kid;
  final VoidCallback onLogin;
  final VoidCallback onAvatarUpdated;

  const _KidCard({
    required this.kid,
    required this.onLogin,
    required this.onAvatarUpdated,
  });

  Future<void> _showAvatarPicker(BuildContext context) async {
    final client = Supabase.instance.client;

    final unlockedRes = await client
        .from('kid_unlocked_alphamons')
        .select('avatar_id,avatars(id,name,letter)')
        .eq('kid_id', kid.id);

    if (unlockedRes == null || (unlockedRes as List).isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingen Alfamons låst op endnu. Færdiggør opgaver for at låse op.')),
        );
      }
      return;
    }

    final avatarIds = (unlockedRes as List).map((e) => e['avatar_id'] as String).toSet().toList();

    final libRes = await client
        .from('kid_avatar_library')
        .select('avatar_id,current_stage_index')
        .eq('kid_id', kid.id)
        .inFilter('avatar_id', avatarIds);

    final stagesRes = await client
        .from('avatar_stages')
        .select('avatar_id,stage_index,image_url')
        .inFilter('avatar_id', avatarIds);

    final libMap = <String, int>{};
    for (final r in libRes as List) {
      libMap[r['avatar_id'] as String] = r['current_stage_index'] as int? ?? 0;
    }

    final stageMap = <String, Map<int, String>>{};
    for (final s in stagesRes as List) {
      final aid = s['avatar_id'] as String;
      stageMap.putIfAbsent(aid, () => {});
      stageMap[aid]![s['stage_index'] as int] = s['image_url'] as String? ?? '';
    }

    final options = <Map<String, dynamic>>[];
    for (final u in unlockedRes as List) {
      final av = u['avatars'];
      if (av == null) continue;
      final avMap = Map<String, dynamic>.from(av as Map);
      final avatarId = avMap['id'] as String;
      final stageIdx = libMap[avatarId] ?? 0;
      var imageUrl = stageMap[avatarId]?[stageIdx];
      if ((imageUrl == null || imageUrl.isEmpty) && (stageMap[avatarId]?.isNotEmpty ?? false)) {
        final urls = stageMap[avatarId]!.values.where((u) => u.isNotEmpty).toList();
        if (urls.isNotEmpty) imageUrl = urls.first;
      }
      if (imageUrl != null && imageUrl.isNotEmpty) {
        options.add({
          'avatar_id': avatarId,
          'name': avMap['name'] ?? 'Alfamon',
          'image_url': imageUrl,
          'stage_index': stageIdx,
        });
      }
    }

    if (options.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingen Alfamons med billeder endnu.')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF5C4033),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Vælg avatar for ${kid.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final o = options[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, o),
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              o['image_url'] as String,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 100,
                            child: Text(
                              o['name'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      final url = selected['image_url'];
      await client.from('kids').update({
        'avatar_url': url,
      }).eq('id', kid.id);
      onAvatarUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Avatar fylder hele feltet – lokale SVG eller netværksbillede
              kid.avatarUrl != null && kid.avatarUrl!.isNotEmpty
                  ? (kid.avatarUrl!.startsWith('assets/')
                      ? SvgPicture.asset(
                          kid.avatarUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Image.network(
                          kid.avatarUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ))
                  : Container(
                      color: const Color(0xFFF9C433).withValues(alpha: 0.9),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person, size: 48, color: Colors.black38),
                            const SizedBox(height: 4),
                            Text(
                              kid.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
              // Navn øverst (let overlay)
              Positioned(
                top: 4,
                left: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    kid.name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Bundmenu med to knapper
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _showAvatarPicker(context),
                          icon: const Icon(Icons.person, size: 14),
                          label: const Text('Avatar', style: TextStyle(fontSize: 10)),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF5C4033),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onLogin,
                          icon: const Icon(Icons.login, size: 14),
                          label: const Text('Login', style: TextStyle(fontSize: 10)),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF9C433),
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
