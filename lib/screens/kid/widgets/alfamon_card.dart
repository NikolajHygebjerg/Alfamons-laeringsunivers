import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Styrke-farver matchende kortdesignet (POWER, SPEED, MIND, MAGIC, ARMOR, CHARM)
const strengthColors = [
  Color(0xFFBA2A13), // POWER - rød
  Color(0xFF22556B), // SPEED - blå/teal
  Color(0xFF67314F), // MIND - lilla
  Color(0xFF54651D), // MAGIC - grøn
  Color(0xFFB85518), // ARMOR - orange
  Color(0xFFC53C3E), // CHARM - pink
];

/// Ikoner for hver styrke (Power, Speed, Mind, Magic, Armor, Charm)
const strengthIcons = [
  Icons.bolt,              // Power
  Icons.speed,            // Speed
  Icons.psychology,       // Mind
  Icons.auto_awesome,     // Magic
  Icons.shield,           // Armor
  Icons.favorite,         // Charm
];

/// Alfamon-navn → type (Fleximon, Powermon, Crazymon, Cutimon)
const _alfamonTypes = {
  'apego': 'Fleximon',
  'bazzle': 'Fleximon',
  'cekimon': 'Powermon',
  'deedoo': 'Crazymon',
  'elisboo': 'Cutimon',
  'flizard': 'Fleximon',
  'gemitsui': 'Powermon',
  'harkal': 'Fleximon',
  'iitle': 'Cutimon',
  'jadrik': 'Crazymon',
  'klyax': 'Powermon',
  'l-mii': 'Cutimon',
  'master': 'Powermon',
  'nimbroo': 'Powermon',
  'oglah': 'Crazymon',
  'peppapop': 'Fleximon',
  'quibbty': 'Fleximon',
  'r-minax': 'Crazymon',
  's-males': 'Cutimon',
  'tegorm': 'Powermon',
  'ummiroo': 'Fleximon',
  'vindleak': 'Fleximon',
  'windioo': 'Powermon',
  'x-bug': 'Powermon',
  'yalfax': 'Cutimon',
  'zebra': 'Powermon',
  'aelgor': 'Fleximon',
  'armok': 'Powermon',
  // Variant-stavninger fra appen
  'quibbly': 'Fleximon',
  'iffle': 'Cutimon',
  'atiach': 'Powermon',
  'wigloo': 'Fleximon',
  'bezzle': 'Fleximon',
  'kavax': 'Powermon',
  'kåvax': 'Powermon',
  's-nake': 'Cutimon',
};

class AlfamonCardData {
  final String name;
  final String? letter;
  final String imageUrl;
  final String? assetPath;
  final List<AlfamonStrength> strengths;

  AlfamonCardData({
    required this.name,
    this.letter,
    required this.imageUrl,
    this.assetPath,
    required this.strengths,
  });
}

class AlfamonStrength {
  final int strengthIndex;
  final String name;
  final int value;

  AlfamonStrength({
    required this.strengthIndex,
    required this.name,
    required this.value,
  });
}

/// Billede til kort: lokalt SVG-asset eller netværksbillede. BoxFit.contain viser hele figuren.
class _CardImage extends StatefulWidget {
  final String? assetPath;
  final String imageUrl;

  const _CardImage({this.assetPath, required this.imageUrl});

  @override
  State<_CardImage> createState() => _CardImageState();
}

class _CardImageState extends State<_CardImage> {
  static final _assetCache = <String, bool>{};

  Future<bool> _assetExists(String path) async {
    if (_assetCache.containsKey(path)) return _assetCache[path]!;
    try {
      await rootBundle.load(path);
      _assetCache[path] = true;
      return true;
    } catch (_) {
      _assetCache[path] = false;
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = widget.assetPath;
    final imageUrl = widget.imageUrl;
    const fit = BoxFit.contain; // Vis hele figuren uden at beskære

    if (assetPath == null || assetPath.isEmpty) {
      return Image.network(
        imageUrl,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const SizedBox.expand(),
      );
    }
    return FutureBuilder<bool>(
      key: ValueKey(assetPath),
      future: _assetExists(assetPath),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return SvgPicture.asset(
            assetPath,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
          );
        }
        if (snapshot.data == false && imageUrl.isNotEmpty) {
          return Image.network(
            imageUrl,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const SizedBox.expand(),
          );
        }
        // Mens vi tjekker asset: prøv netværk
        if (imageUrl.isNotEmpty) {
          return Image.network(
            imageUrl,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const SizedBox.expand(),
          );
        }
        return const SizedBox.expand();
      },
    );
  }
}

/// Kortbagsdesign – samme størrelse som AlfamonCard, bruges til modstanderens bunke.
class AlfamonCardBack extends StatelessWidget {
  final double width;

  const AlfamonCardBack({super.key, this.width = 103.5}); // Samme som AlfamonCard

  @override
  Widget build(BuildContext context) {
    final height = AlfamonCard.heightForWidth(width);
    final borderColor = const Color(0xFF4A3728);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF5C4033),
                Color(0xFF4A3728),
                Color(0xFF3D2E20),
              ],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: width * 0.4, color: const Color(0xFFE8DCC8).withValues(alpha: 0.9)),
                  const SizedBox(height: 4),
                  Text(
                    'ALFAMON',
                    style: TextStyle(
                      fontSize: width >= 100 ? 12 : 8,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFE8DCC8).withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Alfamon-kort i trading card-stil: brun ramme, rød gradient, header med bogstav,
/// illustration, 6 styrkebokse, og "ALFAMON" type.
/// Kortformat 1.1:1.6 (bredde:højde) – altid samme proportioner
const double cardAspectRatio = 1.6 / 1.1;

class AlfamonCard extends StatelessWidget {
  /// Returnerer kortets højde for en given bredde – format 1.1×1.6
  static double heightForWidth(double width) => width * cardAspectRatio;

  final AlfamonCardData card;
  final int? selectedStrengthIndex;
  final bool isWinner;
  final double width;

  const AlfamonCard({
    super.key,
    required this.card,
    this.selectedStrengthIndex,
    this.isWinner = false,
    this.width = 103.5,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * cardAspectRatio;
    final borderColor = const Color(0xFF4A3728);
    final textColor = const Color(0xFFE8DCC8);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: isWinner ? 12 : 6,
            offset: const Offset(0, 4),
          ),
          if (isWinner)
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Solid baggrund – undgår at se igennem transparente SVG'er
            Container(
              color: const Color(0xFF4A3728),
              width: double.infinity,
              height: double.infinity,
            ),
            // Billede: prøv lokalt asset først, ellers netværksbillede
            _CardImage(assetPath: card.assetPath, imageUrl: card.imageUrl),
            // Brun overskrift ovenpå billedets top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: width >= 120 ? 8 : 4,
                  vertical: width >= 120 ? 4 : 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF5C4033).withValues(alpha: 0.95),
                ),
                child: Row(
                  children: [
                    Text(
                      (card.letter ?? (card.name.isNotEmpty ? card.name[0] : '?'))
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: width >= 120 ? 22 : 16,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    SizedBox(width: width >= 120 ? 6 : 4),
                    Expanded(
                      child: Text(
                        card.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: width >= 120 ? 12 : 9,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Evnefelter og bundmenu ovenpå billedets bund
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(width >= 120 ? 6 : 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFFB33A00).withValues(alpha: 0.95),
                      const Color(0xFF5C4033).withValues(alpha: 0.98),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildStatBox(card, 0, textColor, width)),
                        const SizedBox(width: 2),
                        Expanded(child: _buildStatBox(card, 1, textColor, width)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(child: _buildStatBox(card, 2, textColor, width)),
                        const SizedBox(width: 2),
                        Expanded(child: _buildStatBox(card, 3, textColor, width)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(child: _buildStatBox(card, 4, textColor, width)),
                        const SizedBox(width: 2),
                        Expanded(child: _buildStatBox(card, 5, textColor, width)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _alfamonTypes[card.name.toLowerCase().trim()] ?? 'ALFAMON',
                      style: TextStyle(
                        fontSize: width >= 120 ? 10 : 7,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(AlfamonCardData card, int index, Color textColor, double cardWidth) {
    final strength = card.strengths
        .where((s) => s.strengthIndex == index)
        .firstOrNull;
    final value = strength?.value ?? 0;
    final color = index < strengthColors.length
        ? strengthColors[index]
        : Colors.grey;
    final icon = index < strengthIcons.length ? strengthIcons[index] : Icons.help_outline;

    final isSelected = selectedStrengthIndex == index;
    final iconSize = cardWidth >= 120 ? 12.0 : 8.0;
    final fontSize = cardWidth >= 120 ? 9.0 : 6.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: cardWidth >= 120 ? 4 : 1,
        vertical: cardWidth >= 120 ? 2 : 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected ? Colors.white : Colors.black26,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: Colors.white),
          SizedBox(width: cardWidth >= 120 ? 5 : 3),
          Text(
            '$value',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

}

/// Evneknapper til valg af styrke – altid samme layout og farver.
/// Kolonne 1: Power, Mind, Armor. Kolonne 2: Speed, Magic, Charm.
class StrengthChoiceGrid extends StatelessWidget {
  final List<AlfamonStrength> strengths;
  final void Function(int index) onSelect;

  const StrengthChoiceGrid({
    super.key,
    required this.strengths,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const col1 = [0, 2, 4];
    const col2 = [1, 3, 5];

    AlfamonStrength? getStrength(int index) {
      final list = strengths.where((x) => x.strengthIndex == index).toList();
      return list.isEmpty ? null : list.first;
    }

    Widget buildChip(int index) {
      final s = getStrength(index);
      if (s == null) return const SizedBox.shrink();
      final color = index < strengthColors.length
          ? strengthColors[index]
          : Colors.grey;
      final icon = index < strengthIcons.length ? strengthIcons[index] : Icons.help_outline;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Material(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => onSelect(index),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 140,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${s.name}: ${s.value}',
                    style: const TextStyle(
                      color: Color(0xFFE8DCC8),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: col1.map((i) => buildChip(i)).toList(),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: col2.map((i) => buildChip(i)).toList(),
        ),
      ],
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
