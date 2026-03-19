import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _danishAlphabet = 'abcdefghijklmnopqrstuvwxyzæøå';

class KidAlfamonsScreen extends StatefulWidget {
  final String kidId;

  const KidAlfamonsScreen({super.key, required this.kidId});

  @override
  State<KidAlfamonsScreen> createState() => _KidAlfamonsScreenState();
}

class _UnlockedAlphamon {
  final String avatarId;
  final String letter;
  final String name;
  final String? imageUrl;
  final int currentStage;
  final int maxStage;

  _UnlockedAlphamon({
    required this.avatarId,
    required this.letter,
    required this.name,
    this.imageUrl,
    required this.currentStage,
    required this.maxStage,
  });
}

class _KidAlfamonsScreenState extends State<KidAlfamonsScreen> {
  Set<String> _unlockedLetters = {};
  Map<String, _UnlockedAlphamon> _unlockedAlphamons = {};
  String? _activeAvatarId;
  String? _unlockCode;
  bool _loading = true;
  String? _selectedLetter;
  bool _showCodeModal = false;
  final _codeController = TextEditingController();
  bool _unlocking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final activeRes = await client
        .from('kid_active_avatar')
        .select('avatar_id')
        .eq('kid_id', widget.kidId)
        .maybeSingle();
    final activeId = activeRes?['avatar_id'] as String?;

    final settingsRes = await client
        .from('settings')
        .select('value')
        .eq('key', 'alphamon_unlock_code')
        .maybeSingle();
    final code = settingsRes?['value'] as String? ?? '0881';

    final unlockedRes = await client
        .from('kid_unlocked_alphamons')
        .select('avatar_id,avatars(id,name,letter,points_per_stage)')
        .eq('kid_id', widget.kidId);

    if (unlockedRes == null || (unlockedRes as List).isEmpty) {
      setState(() {
        _activeAvatarId = activeId;
        _unlockCode = code;
        _unlockedLetters = {};
        _unlockedAlphamons = {};
        _loading = false;
      });
      return;
    }

    final unlocked = unlockedRes as List;
    final avatarIds = unlocked.map((e) => e['avatar_id'] as String).toSet().toList();
    final libRes = await client
        .from('kid_avatar_library')
        .select('avatar_id,current_stage_index,points_current')
        .eq('kid_id', widget.kidId)
        .inFilter('avatar_id', avatarIds);
    final stagesRes = await client
        .from('avatar_stages')
        .select('avatar_id,stage_index,image_url')
        .inFilter('avatar_id', avatarIds);

    final libMap = <String, Map<String, dynamic>>{};
    for (final r in libRes as List) {
      libMap[r['avatar_id'] as String] = Map<String, dynamic>.from(r);
    }
    final stageMap = <String, Map<int, String>>{};
    final maxStageMap = <String, int>{};
    for (final s in stagesRes as List) {
      final aid = s['avatar_id'] as String;
      final idx = s['stage_index'] as int;
      stageMap.putIfAbsent(aid, () => {});
      stageMap[aid]![idx] = s['image_url'] as String? ?? '';
      if ((maxStageMap[aid] ?? -1) < idx) maxStageMap[aid] = idx;
    }

    final letters = <String>{};
    final alphamons = <String, _UnlockedAlphamon>{};
    for (final u in unlocked) {
      final av = u['avatars'];
      if (av == null) continue;
      final avMap = Map<String, dynamic>.from(av as Map);
      final letter = (avMap['letter'] as String? ?? '').toLowerCase();
      if (letter.isEmpty) continue;
      letters.add(letter);
      final avatarId = avMap['id'] as String;
      final lib = libMap[avatarId];
      final points = lib?['points_current'] as int? ?? 0;
      final pointsPerStage = (avMap['points_per_stage'] as Map<String, dynamic>?) ?? {};
      final stageIdx = _calculateStageFromPoints(points, pointsPerStage, stagesRes as List, avatarId);
      final storedStage = lib?['current_stage_index'] as int? ?? 0;
      if (lib != null && storedStage != stageIdx) {
        await client.from('kid_avatar_library').update({'current_stage_index': stageIdx}).eq('kid_id', widget.kidId).eq('avatar_id', avatarId);
      }
      final maxStage = maxStageMap[avatarId] ?? 0;
      final imageUrl = stageMap[avatarId]?[stageIdx];
      alphamons[letter] = _UnlockedAlphamon(
        avatarId: avatarId,
        letter: letter,
        name: avMap['name'] as String? ?? 'Alfamon',
        imageUrl: imageUrl?.isNotEmpty == true ? imageUrl : null,
        currentStage: stageIdx,
        maxStage: maxStage,
      );
    }
    setState(() {
      _activeAvatarId = activeId;
      _unlockCode = code;
      _unlockedLetters = letters;
      _unlockedAlphamons = alphamons;
      _loading = false;
    });
  }

  int _calculateStageFromPoints(int points, Map<String, dynamic> pointsPerStage, List<dynamic> allStages, String avatarId) {
    final stages = allStages.where((s) => s['avatar_id'] == avatarId).toList()
      ..sort((a, b) => (a['stage_index'] as int).compareTo(b['stage_index'] as int));
    if (stages.isEmpty) return 0;
    int pointsAccumulated = 0;
    int currentStage = stages.first['stage_index'] as int;
    for (var i = 0; i < stages.length - 1; i++) {
      final stageIdx = stages[i]['stage_index'] as int;
      final raw = pointsPerStage[stageIdx.toString()] ?? pointsPerStage[stageIdx];
      var pointsNeeded = (raw as num?)?.toInt() ?? 10;
      if (pointsNeeded < 1) pointsNeeded = 10;
      if (points >= pointsAccumulated + pointsNeeded) {
        pointsAccumulated += pointsNeeded;
        currentStage = stages[i + 1]['stage_index'] as int;
      } else {
        break;
      }
    }
    return currentStage;
  }

  void _onLetterTap(String letter) {
    if (_unlockedLetters.contains(letter)) {
      _selectAvatar(_unlockedAlphamons[letter]!.avatarId);
      return;
    }
    setState(() {
      _selectedLetter = letter;
      _showCodeModal = true;
      _codeController.clear();
      _error = null;
    });
  }

  Future<void> _selectAvatar(String avatarId) async {
    final client = Supabase.instance.client;
    final libRes = await client.from('kid_avatar_library').select('points_current').eq('kid_id', widget.kidId).eq('avatar_id', avatarId).maybeSingle();
    final points = libRes?['points_current'] as int? ?? 0;
    await client.from('kid_active_avatar').upsert({'kid_id': widget.kidId, 'avatar_id': avatarId, 'points_current': points}, onConflict: 'kid_id');
    setState(() => _activeAvatarId = avatarId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alfamon valgt!')));
      context.go('/kid/today/${widget.kidId}');
    }
  }

  Future<void> _unlock() async {
    final letter = _selectedLetter;
    if (letter == null || _unlockCode == null) return;
    if (_codeController.text.trim() != _unlockCode) {
      setState(() => _error = 'Forkert kode! Prøv igen.');
      return;
    }
    setState(() { _unlocking = true; _error = null; });
    final client = Supabase.instance.client;
    final avRes = await client.from('avatars').select('id,name').eq('letter', letter).maybeSingle();
    if (avRes == null) {
      setState(() { _error = 'Ingen alphamon fundet.'; _unlocking = false; });
      return;
    }
    final avatarId = avRes['id'] as String;
    final existing = await client.from('kid_unlocked_alphamons').select('id').eq('kid_id', widget.kidId).eq('avatar_id', avatarId).maybeSingle();
    if (existing != null) {
      setState(() { _error = 'Allerede låst op!'; _unlocking = false; });
      return;
    }
    await client.from('kid_unlocked_alphamons').insert({'kid_id': widget.kidId, 'avatar_id': avatarId});
    final stagesRes = await client.from('avatar_stages').select('stage_index').eq('avatar_id', avatarId).order('stage_index').limit(1);
    final initialStage = (stagesRes as List).isNotEmpty ? (stagesRes.first['stage_index'] as int) : 0;
    await client.from('kid_avatar_library').insert({'kid_id': widget.kidId, 'avatar_id': avatarId, 'current_stage_index': initialStage, 'points_current': 0});
    await _load();
    if (mounted) {
      setState(() { _unlocking = false; _showCodeModal = false; _selectedLetter = null; _codeController.clear(); });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alfamon låst op!')));
    }
  }

  void _closeModal() {
    setState(() { _showCodeModal = false; _selectedLetter = null; _error = null; _codeController.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final isTablet = shortestSide >= 600;
    final bgAsset = isTablet ? 'assets/baggrund_roedipad.svg' : 'assets/baggrund_roediphone.svg';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: SvgPicture.asset(bgAsset, fit: BoxFit.cover)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Alfamons', style: TextStyle(fontSize: isTablet ? 28 : 24, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth - 32;
                            final crossCount = isTablet ? 7 : 6;
                            final size = (width / crossCount) - 8;
                            return SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: _danishAlphabet.split('').map((letter) {
                                  final isUnlocked = _unlockedLetters.contains(letter);
                                  final alphamon = _unlockedAlphamons[letter];
                                  final isActive = alphamon != null && _activeAvatarId == alphamon.avatarId;
                                  return SizedBox(
                                    width: size,
                                    height: size,
                                    child: GestureDetector(
                                      onTap: () => _onLetterTap(letter),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isUnlocked ? Colors.green.shade400 : const Color(0xFFF9C433),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: isActive ? Colors.amber : (isUnlocked ? Colors.green.shade600 : Colors.grey.shade300), width: isActive ? 3 : 2),
                                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2))],
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            if (isUnlocked && alphamon?.imageUrl != null && alphamon!.imageUrl!.isNotEmpty)
                                              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(alphamon.imageUrl!, fit: BoxFit.cover))
                                            else if (!isUnlocked)
                                              Center(child: Text(letter.toUpperCase(), style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.w900, color: Colors.black87)))
                                            else
                                              Center(child: Text(letter.toUpperCase(), style: TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.bold, color: Colors.white))),
                                            if (isUnlocked)
                                              Positioned(top: 4, left: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)), child: Text(letter.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
                                            if (isUnlocked)
                                              Positioned(top: 4, right: 4, child: Container(width: 20, height: 20, decoration: BoxDecoration(color: isActive ? Colors.amber : Colors.green, shape: BoxShape.circle), child: Icon(isActive ? Icons.star : Icons.check, size: 14, color: Colors.white))),
                                            if (isUnlocked && alphamon != null && alphamon.maxStage > 0)
                                              Positioned(bottom: 4, left: 4, right: 4, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)), child: Text('${alphamon.currentStage}/${alphamon.maxStage}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))))),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                ),
                _buildBottomNav(context),
              ],
            ),
          ),
          if (_showCodeModal && _selectedLetter != null) _buildCodeModal(),
        ],
      ),
    );
  }

  Widget _buildCodeModal() {
    return GestureDetector(
      onTap: _closeModal,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 20, offset: const Offset(0, 10))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedLetter!.toUpperCase(), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Lås alphamon op!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Spørg en voksen om koden.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                  const SizedBox(height: 20),
                  TextField(controller: _codeController, keyboardType: TextInputType.number, maxLength: 4, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8), decoration: InputDecoration(hintText: '4-cifret kode', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true), onChanged: (_) => setState(() => _error = null)),
                  if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600))],
                  const SizedBox(height: 16),
                  Row(children: [Expanded(child: TextButton(onPressed: _closeModal, child: const Text('Annuller'))), const SizedBox(width: 12), Expanded(child: FilledButton(onPressed: _unlocking || _codeController.text.length != 4 ? null : _unlock, child: Text(_unlocking ? 'Låser op...' : 'Lås op')))]),
                ],
              ),
            ),
          ),
        ),
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
                _NavItem(icon: Icons.today, label: 'I dag', onTap: () => context.go('/kid/today/${widget.kidId}')),
                _NavItem(icon: Icons.calendar_view_week, label: 'Ugen', onTap: () => context.go('/kid/week/${widget.kidId}')),
                _NavItem(icon: Icons.library_books, label: 'Bibliotek', onTap: () => context.go('/kid/library/${widget.kidId}')),
                _NavItem(icon: Icons.pets, label: 'Alfamons', selected: true),
                _NavItem(icon: Icons.sports_esports, label: 'Spil', onTap: () => context.go('/kid/spil/${widget.kidId}')),
                _NavItem(icon: Icons.emoji_events, label: 'Præstationer', onTap: () => context.go('/kid/achievements/${widget.kidId}')),
              ],
            ),
          ),
          TextButton(onPressed: () async { final prefs = await SharedPreferences.getInstance(); await prefs.remove('kidId'); await prefs.remove('kidStayLoggedIn'); if (context.mounted) context.go('/kid/select'); }, child: const Text('Log ud', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
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

  const _NavItem({required this.icon, required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: selected ? Colors.amber : Colors.white70, size: 26), Text(label, style: TextStyle(color: selected ? Colors.amber : Colors.white70, fontSize: 11))]);
    if (onTap != null) return GestureDetector(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: child));
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: child);
  }
}
