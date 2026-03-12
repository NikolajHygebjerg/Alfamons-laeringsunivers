import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../utils/angreb_assets.dart';
import '../../utils/card_assets.dart';
import 'widgets/alfamon_card.dart';

/// Angreb-billeder: true = de kigger til højre i originalen. false = de kigger til venstre.
/// Skift denne hvis figurerne vender forkert – eller tilret alle billeder til at kigge højre.
const bool _angrebImagesFaceRight = false;

class _GameCard {
  final String id;
  final String avatarId;
  final String name;
  final String? letter;
  final String imageUrl;
  final int stageIndex;
  final List<_Strength> strengths;

  _GameCard({
    required this.id,
    required this.avatarId,
    required this.name,
    this.letter,
    required this.imageUrl,
    required this.stageIndex,
    required this.strengths,
  });

  AlfamonCardData toAlfamonCardData() => AlfamonCardData(
        name: name,
        letter: letter,
        imageUrl: imageUrl,
        assetPath: CardAssets.getCardAssetPath(name, stageIndex, letter: letter),
        strengths: strengths
            .map((s) => AlfamonStrength(
                  strengthIndex: s.strengthIndex,
                  name: s.name,
                  value: s.value,
                ))
            .toList(),
      );
}

class _Strength {
  final int strengthIndex;
  final String name;
  final int value;

  _Strength({
    required this.strengthIndex,
    required this.name,
    required this.value,
  });
}

class KidSpilScreen extends StatefulWidget {
  final String kidId;

  const KidSpilScreen({super.key, required this.kidId});

  @override
  State<KidSpilScreen> createState() => _KidSpilScreenState();
}

class _KidSpilScreenState extends State<KidSpilScreen> {
  List<_GameCard> _kidCards = [];
  List<_GameCard> _computerCards = [];
  bool _loading = true;
  String _gameState = 'idle'; // idle, choosing_strength, round_result, game_over
  _GameCard? _kidCard;
  _GameCard? _computerCard;
  int? _selectedStrengthIndex;
  int _kidScore = 0;
  int _computerScore = 0;
  String? _roundWinner; // 'kid', 'computer', 'tie'
  String? _previousRoundWinner; // Hvem vandt forrige runde – bestemmer hvem der vælger evne
  int _roundNumber = 0;
  bool _gameWinRecorded = false;
  _GameCard? _gameOverStrongestCard; // Stærkeste alfamon til game over-skærm
  bool _gameOverKidWon = false;

  final _random = Random();

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() => _loading = true);

    final client = Supabase.instance.client;

    final unlockedRes = await client
        .from('kid_unlocked_alphamons')
        .select('avatar_id')
        .eq('kid_id', widget.kidId);
    final unlockedIds = (unlockedRes as List)
        .map((e) => e['avatar_id'] as String)
        .toSet()
        .toList();

    if (unlockedIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _kidCards = [];
        _loading = false;
      });
      return;
    }

    final cards = await _loadCardsForAvatars(client, unlockedIds, widget.kidId);

    final shuffled = List<_GameCard>.from(cards)..shuffle(_random);

    if (!mounted) return;
    setState(() {
      _kidCards = shuffled;
      _computerCards = List<_GameCard>.from(shuffled)
        ..shuffle(_random);
      _loading = false;
    });
  }

  Future<List<_GameCard>> _loadCardsForAvatars(
    SupabaseClient client,
    List<String> avatarIds,
    String kidId,
  ) async {
    final cards = <_GameCard>[];

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
          .map((s) => _Strength(
                strengthIndex: s['strength_index'] as int,
                name: s['name'] as String? ?? '',
                value: s['value'] as int? ?? 0,
              ))
          .toList();

      if (imageUrl != null && imageUrl.isNotEmpty && strengths.isNotEmpty) {
        cards.add(_GameCard(
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

    final historyAvatarIds = (historyRes as List)
        .map((r) => r['avatar_id'] as String)
        .toSet();

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
          .map((s) => _Strength(
                strengthIndex: s['strength_index'] as int,
                name: s['name'] as String? ?? '',
                value: s['value'] as int? ?? 0,
              ))
          .toList();

      if (imageUrl != null && imageUrl.isNotEmpty && strengths.isNotEmpty) {
        cards.add(_GameCard(
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

  void _startGame() {
    if (_kidCards.isEmpty || _computerCards.isEmpty) return;

    setState(() {
      _gameOverStrongestCard = null;
      _gameOverKidWon = false;
      _gameState = 'idle';
      _roundNumber = 1;
      _kidScore = 0;
      _computerScore = 0;
      _kidCard = null;
      _computerCard = null;
      _selectedStrengthIndex = null;
      _roundWinner = null;
      _previousRoundWinner = null;
      _gameWinRecorded = false;
    });
  }

  Future<void> _resetAndStartNewGame() async {
    setState(() => _loading = true);
    await _loadCards();
    if (!mounted) return;
    if (_kidCards.isEmpty || _computerCards.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    _startGame();
    setState(() => _loading = false);
  }

  _GameCard? _getStrongestCard(List<_GameCard> cards) {
    if (cards.isEmpty) return null;
    return cards.reduce((a, b) {
      if (a.stageIndex != b.stageIndex) return a.stageIndex > b.stageIndex ? a : b;
      final maxA = a.strengths.isEmpty ? 0 : a.strengths.map((s) => s.value).reduce((x, y) => x > y ? x : y);
      final maxB = b.strengths.isEmpty ? 0 : b.strengths.map((s) => s.value).reduce((x, y) => x > y ? x : y);
      return maxA >= maxB ? a : b;
    });
  }

  void _kidPlayCard() {
    if (_gameState != 'idle' || _kidCards.isEmpty) return;
    if (_computerCards.isEmpty) {
      _endGame();
      return;
    }

    final card = _kidCards.first;
    final compCard = _computerCards.first;

    final kidChooses = _previousRoundWinner == null || _previousRoundWinner == 'kid' || _previousRoundWinner == 'tie';

    if (kidChooses) {
      setState(() {
        _kidCards.removeAt(0);
        _computerCards.removeAt(0);
        _kidCard = card;
        _computerCard = compCard;
        _gameState = 'choosing_strength';
      });
    } else {
      // Modstanderen vandt forrige runde – de bestemmer evnen. Vælger altid stærkeste evne.
      final compStrengths = compCard.strengths;
      final strongest = compStrengths.isNotEmpty
          ? compStrengths.reduce((a, b) => a.value >= b.value ? a : b)
          : null;
      final compStrengthIndex = strongest?.strengthIndex ?? 0;

      setState(() {
        _kidCards.removeAt(0);
        _computerCards.removeAt(0);
        _kidCard = card;
        _computerCard = compCard;
        _selectedStrengthIndex = compStrengthIndex;
        _gameState = 'round_result';
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _resolveRound(compCard, compStrengthIndex);
      });
    }
  }

  void _selectStrength(int index) {
    if (_gameState != 'choosing_strength' || _kidCard == null || _computerCard == null) return;

    setState(() {
      _selectedStrengthIndex = index;
      _gameState = 'round_result';
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _resolveRound(_computerCard!, index);
    });
  }

  void _resolveRound(_GameCard compCard, int strengthIndex) {
    final kidCard = _kidCard!;
    final kidStrength = kidCard.strengths
        .where((s) => s.strengthIndex == strengthIndex)
        .firstOrNull;
    final compStrength = compCard.strengths
        .where((s) => s.strengthIndex == strengthIndex)
        .firstOrNull;

    final kidVal = kidStrength?.value ?? 0;
    final compVal = compStrength?.value ?? 0;

    String winner;
    if (kidVal > compVal) {
      winner = 'kid';
    } else if (compVal > kidVal) {
      winner = 'computer';
    } else {
      winner = 'tie';
    }

    setState(() => _roundWinner = winner);
  }

  void _applyRoundResult(String winner, _GameCard compCard) {
    final kidCard = _kidCard!;

    if (winner == 'kid') {
      // Vundet: mit vinderkort + modstanderens taberkort nederst i min bunke
      setState(() {
        _kidScore++;
        _kidCards.add(kidCard);
        _kidCards.add(_GameCard(
          id: 'kid-${DateTime.now().millisecondsSinceEpoch}-${compCard.avatarId}',
          avatarId: compCard.avatarId,
          name: compCard.name,
          letter: compCard.letter,
          imageUrl: compCard.imageUrl,
          stageIndex: compCard.stageIndex,
          strengths: compCard.strengths,
        ));
      });
    } else if (winner == 'computer') {
      // Tabt: mister mit kort til modstanderen. Modstanderens kort går tilbage i deres bunke.
      setState(() {
        _computerScore++;
        _computerCards.add(_GameCard(
          id: 'comp-${DateTime.now().millisecondsSinceEpoch}-${kidCard.avatarId}',
          avatarId: kidCard.avatarId,
          name: kidCard.name,
          letter: kidCard.letter,
          imageUrl: kidCard.imageUrl,
          stageIndex: kidCard.stageIndex,
          strengths: kidCard.strengths,
        ));
        _computerCards.add(compCard);
      });
    } else {
      // Uafgjort: begge kort går tilbage i deres egne bunker
      setState(() {
        _kidCards.add(kidCard);
        _computerCards.add(compCard);
      });
    }

    if (_kidCards.isEmpty || _computerCards.isEmpty) {
      _endGame();
      return;
    }

    setState(() {
      _roundNumber++;
      _previousRoundWinner = winner == 'tie' ? 'kid' : winner;
      _kidCard = null;
      _computerCard = null;
      _selectedStrengthIndex = null;
      _roundWinner = null;
      _gameState = 'idle';
    });
  }

  void _endGame() {
    final kidWon = _kidCards.isNotEmpty;
    final strongest = kidWon
        ? _getStrongestCard(_kidCards)
        : _getStrongestCard(_computerCards);

    setState(() {
      _gameState = 'game_over';
      _gameOverStrongestCard = strongest;
      _gameOverKidWon = kidWon;
    });

    if (kidWon && !_gameWinRecorded) {
      _gameWinRecorded = true;
      Supabase.instance.client.from('game_wins').insert({
        'kid_id': widget.kidId,
        'metadata': {
          'kid_score': _kidScore,
          'computer_score': _computerScore,
          'rounds': _roundNumber,
        },
      });
    }
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
                  child: Text(
                    'Spil',
                    style: TextStyle(
                      fontSize: isTablet ? 28 : 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _kidCards.isEmpty
                          ? _buildNoCards()
                          : _gameState == 'game_over'
                              ? _buildGameOver()
                              : _buildGame(),
                ),
                _buildBottomNav(context, widget.kidId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCards() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎴', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Ingen kort endnu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Færdiggør opgaver for at opgradere din avatar og låse kort op til spillet!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOver() {
    final kidWon = _gameOverKidWon;
    final strongest = _gameOverStrongestCard;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (strongest != null) ...[
            _GameOverAlfamon(
              card: strongest,
              message: kidWon ? 'Du vandt!' : 'Du tabte',
              kidWon: kidWon,
            ),
            const SizedBox(height: 24),
          ] else ...[
            Text(
              kidWon ? 'Du vandt!' : 'Du tabte',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            '$_kidScore - $_computerScore',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _resetAndStartNewGame,
            icon: const Icon(Icons.refresh),
            label: const Text('Ny kamp'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF9C433),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGame() {
    if (_gameState == 'idle' && _kidCard == null) {
      return _buildIdleLayout();
    }
    if (_gameState == 'choosing_strength') {
      return _buildChoosingLayout();
    }
    return _buildDuelLayout();
  }

  /// Når man spiller kort: vis kortet og evnerne man kan vælge.
  Widget _buildChoosingLayout() {
    final kidCard = _kidCard!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ScoreCard(label: 'Dig', score: _kidScore),
              Text(
                'Runde $_roundNumber',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              _ScoreCard(label: 'Computer', score: _computerScore),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: AlfamonCard(
              card: kidCard.toAlfamonCardData(),
              width: _gameCardWidth,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Vælg styrke',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          StrengthChoiceGrid(
            strengths: kidCard.strengths
                .map((s) => AlfamonStrength(
                      strengthIndex: s.strengthIndex,
                      name: s.name,
                      value: s.value,
                    ))
                .toList(),
            onSelect: _selectStrength,
          ),
        ],
      ),
    );
  }

  /// Efter valg af evne: kort i venstre hjørne, angreb-figurer peger mod hinanden.
  Widget _buildDuelLayout() {
    final kidCard = _kidCard!;
    final computerCard = _computerCard!;
    final selectedStrength = _selectedStrengthIndex != null
        ? kidCard.strengths
            .where((s) => s.strengthIndex == _selectedStrengthIndex)
            .firstOrNull
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ScoreCard(label: 'Dig', score: _kidScore),
                  Text(
                    'Runde $_roundNumber',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  _ScoreCard(label: 'Computer', score: _computerScore),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _DuelAngrebTile(
                        card: kidCard,
                        faceRight: _angrebImagesFaceRight,
                        strengthName: selectedStrength?.name,
                      ),
                    ),
                    Expanded(
                      child: _DuelAngrebTile(
                        card: computerCard,
                        faceRight: !_angrebImagesFaceRight,
                        strengthName: selectedStrength?.name,
                      ),
                    ),
                  ],
                ),
              ),
              if (_roundWinner != null) ...[
                const SizedBox(height: 12),
                Text(
                  _roundWinner == 'kid'
                      ? '✓ Du vandt runden!'
                      : _roundWinner == 'computer'
                          ? '✗ Computeren vandt'
                          : 'Uafgjort',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _roundWinner == 'kid'
                        ? Colors.green
                        : _roundWinner == 'computer'
                            ? Colors.red
                            : Colors.amber,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _applyRoundResult(_roundWinner!, _computerCard!),
                  icon: const Icon(Icons.sports_martial_arts),
                  label: const Text('Næste kamp'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF9C433),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        Positioned(
          bottom: 16,
          left: 8,
          child: AlfamonCard(
            card: kidCard.toAlfamonCardData(),
            selectedStrengthIndex: _selectedStrengthIndex,
            isWinner: _roundWinner == 'kid',
            width: _gameCardWidth,
          ),
        ),
        if (_roundWinner == 'kid')
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width / 2,
            child: Center(child: _buildWinnerSplash()),
          ),
        if (_roundWinner == 'computer')
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width / 2,
            child: Center(child: _buildWinnerSplash()),
          ),
      ],
    );
  }

  Widget _buildWinnerSplash() {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9C433).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          'VINDER',
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 4,
            shadows: [
              Shadow(color: Colors.black54, offset: const Offset(2, 2), blurRadius: 4),
              Shadow(color: Colors.black38, offset: const Offset(-1, -1), blurRadius: 2),
            ],
          ),
        ),
      ),
    );
  }

  static const double _gameCardWidth = 103.5; // Samme format i bunke og i spil
  static const String _danishAlphabet = 'abcdefghijklmnopqrstuvwxyzæøå';

  /// Sorterer kort efter bogstav (a-å)
  List<_GameCard> _cardsSortedByLetter(List<_GameCard> cards) {
    final sorted = List<_GameCard>.from(cards);
    sorted.sort((a, b) {
      final letterA = (a.letter ?? '').toLowerCase();
      final letterB = (b.letter ?? '').toLowerCase();
      final idxA = letterA.isEmpty ? 999 : _danishAlphabet.indexOf(letterA);
      final idxB = letterB.isEmpty ? 999 : _danishAlphabet.indexOf(letterB);
      return idxA.compareTo(idxB);
    });
    return sorted;
  }

  /// Før start: vis alle kort i rækkefølge a-å (undtagen æg)
  Widget _buildCardPreview() {
    final sorted = _cardsSortedByLetter(_kidCards);
    if (sorted.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Dine kort i spil',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: sorted.map((c) => AlfamonCard(
                card: c.toAlfamonCardData(),
                width: _gameCardWidth,
              )).toList(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start spil'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF9C433),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_kidCards.length} kort lægges i bunken',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdleLayout() {
    const stackOffset = 4.0;

    // Før start: vis alle kort i rækkefølge a-å
    if (_roundNumber == 0) {
      return _buildCardPreview();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ScoreCard(label: 'Dig', score: _kidScore),
                Text(
                  'Runde $_roundNumber',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                _ScoreCard(label: 'Computer', score: _computerScore),
              ],
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: _gameCardWidth + 20,
                child: _buildOpponentPile(_gameCardWidth, stackOffset),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            child: _buildPlayerPile(_gameCardWidth, stackOffset),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: _kidPlayCard,
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('Spil kort'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF9C433),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_kidCards.length} kort i bunken',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerPile(double cardWidth, double stackOffset) {
    if (_kidCards.isEmpty) return const SizedBox.shrink();
    final topCard = _kidCards.first;
    final stackCount = _kidCards.length.clamp(0, 8);

    return SizedBox(
      width: cardWidth + (stackCount - 1) * stackOffset + 8,
      height: AlfamonCard.heightForWidth(cardWidth) + (stackCount - 1) * stackOffset + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = stackCount - 1; i >= 1; i--)
            Positioned(
              left: i * stackOffset,
              top: i * stackOffset,
              child: AlfamonCardBack(width: cardWidth),
            ),
          Positioned(
            left: 0,
            top: 0,
            child: AlfamonCard(
              card: topCard.toAlfamonCardData(),
              width: cardWidth,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpponentPile(double cardWidth, double stackOffset) {
    final stackCount = _computerCards.length.clamp(0, 8);
    if (stackCount == 0) return const SizedBox.shrink();

    return SizedBox(
      width: cardWidth + (stackCount - 1) * stackOffset + 8,
      height: AlfamonCard.heightForWidth(cardWidth) + (stackCount - 1) * stackOffset + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < stackCount; i++)
            Positioned(
              left: i * stackOffset,
              top: i * stackOffset,
              child: AlfamonCardBack(width: cardWidth),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, String kidId) {
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
                  selected: false,
                  onTap: () => context.go('/kid/today/$kidId'),
                ),
                _NavItem(
                  icon: Icons.calendar_view_week,
                  label: 'Ugen',
                  selected: false,
                  onTap: () => context.go('/kid/week/$kidId'),
                ),
                _NavItem(
                  icon: Icons.library_books,
                  label: 'Bibliotek',
                  selected: false,
                  onTap: () => context.go('/kid/library/$kidId'),
                ),
                _NavItem(
                  icon: Icons.sports_esports,
                  label: 'Spil',
                  selected: true,
                ),
                _NavItem(
                  icon: Icons.emoji_events,
                  label: 'Præstationer',
                  selected: false,
                  onTap: () => context.go('/kid/achievements/$kidId'),
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

/// Viser angreb-figur. faceRight: true = vis uden flip, false = flip horisontalt.
class _DuelAngrebTile extends StatelessWidget {
  final _GameCard? card;
  final bool faceRight;
  final String? strengthName;

  const _DuelAngrebTile({
    required this.card,
    required this.faceRight,
    this.strengthName,
  });

  @override
  Widget build(BuildContext context) {
    if (card == null) {
      return const SizedBox.shrink();
    }

    final path = AngrebAssets.getAngrebAssetPath(
      card!.name,
      card!.stageIndex,
      letter: card!.letter,
    );

    Widget imageWidget;
    if (path != null) {
      imageWidget = Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(card!.name),
      );
    } else {
      imageWidget = _placeholder(card!.name);
    }

    // Atiachangreb2 vender modsat af de andre – brug override
    final flipOverride = path != null && path.contains('Atiachangreb2');
    final shouldFlip = flipOverride ? faceRight : !faceRight;
    if (shouldFlip) {
      imageWidget = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(-1.0, 1.0),
        child: imageWidget,
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: imageWidget,
          ),
        ),
        if (strengthName != null && strengthName!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            strengthName!,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(color: Colors.black54, offset: Offset(1, 1)),
                Shadow(color: Colors.black38, blurRadius: 4),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _placeholder(String name) {
    return Container(
      color: Colors.white12,
      child: Center(
        child: Text(
          name,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
    );
  }
}

/// Viser stærkeste alfamon med taleboble (Du vandt / Du tabte).
class _GameOverAlfamon extends StatelessWidget {
  final _GameCard card;
  final String message;
  final bool kidWon;

  const _GameOverAlfamon({
    required this.card,
    required this.message,
    required this.kidWon,
  });

  @override
  Widget build(BuildContext context) {
    final path = AngrebAssets.getAngrebAssetPath(
      card.name,
      card.stageIndex,
      letter: card.letter,
    );
    final bubbleColor = kidWon
        ? const Color(0xFF2E7D32).withValues(alpha: 0.95)
        : const Color(0xFFC62828).withValues(alpha: 0.95);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -10,
              child: Center(
                child: CustomPaint(
                  size: const Size(24, 14),
                  painter: _BubbleTailPainter(color: bubbleColor),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 180,
          height: 180,
          child: path != null
              ? Image.asset(path, fit: BoxFit.contain)
              : Container(
                  color: Colors.white12,
                  child: Center(
                    child: Text(
                      card.name,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;

  _BubbleTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(size.width / 2, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScoreCard extends StatelessWidget {
  final String label;
  final int score;

  const _ScoreCard({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9C433).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
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
        Icon(icon, color: selected ? Colors.amber : Colors.white70, size: 28),
        Text(label, style: TextStyle(color: selected ? Colors.amber : Colors.white70, fontSize: 12)),
      ],
    );
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: child),
      );
    }
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: child);
  }
}
