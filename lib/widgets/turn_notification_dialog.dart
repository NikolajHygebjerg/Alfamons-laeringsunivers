import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Dialog når det er din tur i en PvP-kamp, men du ikke er inde i spillet.
class TurnNotificationDialog extends StatelessWidget {
  final String kidId;
  final String matchId;
  final String opponentName;

  const TurnNotificationDialog({
    super.key,
    required this.kidId,
    required this.matchId,
    required this.opponentName,
  });

  static Future<void> show(
    BuildContext context, {
    required String kidId,
    required String matchId,
    required String opponentName,
  }) {
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => TurnNotificationDialog(
        kidId: kidId,
        matchId: matchId,
        opponentName: opponentName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final isTablet = shortestSide >= 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: BoxConstraints(maxWidth: isTablet ? 420 : 340),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Det er din tur!',
              style: TextStyle(
                fontSize: isTablet ? 26 : 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Du skal spille mod $opponentName',
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/kid/spil/$kidId/pvp/$matchId');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    textStyle: TextStyle(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Spil'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF9C433),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    textStyle: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Vent med at spille'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
