import 'package:flutter/material.dart';

/// Kiste + antal guldmønter (nederst til **højre** på fx «I dag» – brug `kidZoneHorizontalPadding` (20) fra `kid_layout_constants.dart`).
/// Bruger [kiste.png] (udtrukket fra SVG – flutter_svg viser ikke indlejret PNG i .svg).
class KidGoldTreasuryCorner extends StatelessWidget {
  const KidGoldTreasuryCorner({
    super.key,
    required this.goldCoins,
  });

  final int goldCoins;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final isPhone = shortest < 600;
    final chestW = (screenW * 0.2).clamp(72.0, 220.0);

    const textShadows = [
      Shadow(
        offset: Offset(1, 1),
        blurRadius: 4,
        color: Colors.black87,
      ),
    ];

    final chest = Image.asset(
      'assets/kiste.png',
      width: chestW,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: chestW,
        height: chestW * 0.85,
        child: Icon(
          Icons.inventory_2,
          size: chestW * 0.5,
          color: Colors.amber,
        ),
      ),
    );

    /// Telefon: større tal/tekst til venstre, kiste i bunden (samme baseline).
    if (isPhone) {
      final coinFont =
          (shortest * 0.072).clamp(26.0, 36.0);
      final labelFont =
          (shortest * 0.028).clamp(11.0, 14.0);
      return Material(
        color: Colors.transparent,
        clipBehavior: Clip.none,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10, bottom: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$goldCoins',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: coinFont,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.05,
                      shadows: textShadows,
                    ),
                  ),
                  Text(
                    'GULDMØNTER',
                    style: TextStyle(
                      fontSize: labelFont,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            chest,
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.none,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          chest,
          const SizedBox(height: 4),
          SizedBox(
            width: chestW,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$goldCoins',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: textShadows,
                    ),
                  ),
                ),
                Text(
                  'GULDMØNTER',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Horisontal afstand fra skærmhøjre til venstre kant af kiste-widget (til placering af fx bogskab).
  static double clearanceWidthFromScreenRight({
    required double screenWidth,
    required double shortestSide,
  }) {
    final chestW = (screenWidth * 0.2).clamp(72.0, 220.0);
    if (shortestSide >= 600) return chestW;
    return chestW + 118;
  }
}
