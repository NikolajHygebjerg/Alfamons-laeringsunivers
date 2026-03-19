import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stort popup-vindue når man bliver udfordret – viser udfordrerens billede og Kæmp/Afvis.
class ChallengeNotificationDialog extends StatelessWidget {
  final String kidId;
  final String invitationId;
  final String challengerKidId;
  final String challengerName;
  final String? challengerAvatarUrl;

  const ChallengeNotificationDialog({
    super.key,
    required this.kidId,
    required this.invitationId,
    required this.challengerKidId,
    required this.challengerName,
    this.challengerAvatarUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required String kidId,
    required String invitationId,
    required String challengerKidId,
    required String challengerName,
    String? challengerAvatarUrl,
  }) {
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => ChallengeNotificationDialog(
        kidId: kidId,
        invitationId: invitationId,
        challengerKidId: challengerKidId,
        challengerName: challengerName,
        challengerAvatarUrl: challengerAvatarUrl,
      ),
    );
  }

  static Future<String?> _waitForMatchId(String invitationId) async {
    for (var i = 0; i < 25; i++) {
      final matchRes = await Supabase.instance.client
          .from('kid_matches')
          .select('id')
          .eq('invitation_id', invitationId)
          .maybeSingle();
      final matchId = matchRes?['id'] as String?;
      if (matchId != null) return matchId;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return null;
  }

  Future<void> _respond(BuildContext context, bool accept) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();

    try {
      final updated = await Supabase.instance.client
          .from('kid_match_invitations')
          .update({'status': accept ? 'accepted' : 'declined'})
          .eq('id', invitationId)
          .eq('challenged_kid_id', kidId)
          .eq('status', 'pending')
          .select('id')
          .maybeSingle();
      if (updated == null) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('Udfordringen er allerede håndteret.')),
        );
        return;
      }

      if (accept) {
        final matchId = await _waitForMatchId(invitationId);
        if (matchId != null) {
          router.go('/kid/spil/$kidId/pvp/$matchId');
        } else {
          messenger?.showSnackBar(
            const SnackBar(content: Text('Kunne ikke åbne kampen endnu. Prøv igen om et øjeblik.')),
          );
        }
      }
    } catch (e) {
      if (accept) {
        final matchId = await _waitForMatchId(invitationId);
        if (matchId != null) {
          router.go('/kid/spil/$kidId/pvp/$matchId');
        } else {
          messenger?.showSnackBar(
            SnackBar(content: Text('Kunne ikke acceptere: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final isTablet = shortestSide >= 600;
    final imageSize = isTablet ? 180.0 : 140.0;

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
              'Du er blevet udfordret!',
              style: TextStyle(
                fontSize: isTablet ? 26 : 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Billede af udfordreren
            Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF9C433), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF9C433).withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: challengerAvatarUrl != null && challengerAvatarUrl!.isNotEmpty
                  ? Image.network(
                      challengerAvatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderIcon(imageSize),
                    )
                  : _placeholderIcon(imageSize),
            ),
            const SizedBox(height: 12),
            Text(
              challengerName,
              style: TextStyle(
                fontSize: isTablet ? 22 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Kæmp
                FilledButton(
                  onPressed: () => _respond(context, true),
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
                  child: const Text('Kæmp'),
                ),
                const SizedBox(width: 20),
                // Afvis
                FilledButton(
                  onPressed: () => _respond(context, false),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    textStyle: TextStyle(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Afvis'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon(double size) {
    return Container(
      color: Colors.grey.shade700,
      child: Icon(Icons.person, size: size * 0.6, color: Colors.white54),
    );
  }
}
