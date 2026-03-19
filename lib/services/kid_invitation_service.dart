import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';
import '../widgets/challenge_notification_dialog.dart';

/// Global service der lytter på udfordrings-invitationer via Supabase Realtime.
/// Kaldes fra kid-skærme når barnet er logget ind.
class KidInvitationService {
  KidInvitationService._();

  static GlobalKey<NavigatorState>? _navigatorKey;
  static RealtimeChannel? _channelAccepted;
  static RealtimeChannel? _channelChallenged;
  static String? _currentKidId;
  static final List<String> _shownInvitationEventKeys = [];

  static void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  static void start(String kidId) {
    if (_currentKidId == kidId) return;
    stop();
    _currentKidId = kidId;

    // Lyt på: vores udfordring er accepteret
    _channelAccepted = Supabase.instance.client
        .channel('kid_inv_accepted_$kidId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'kid_match_invitations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'challenger_kid_id',
            value: kidId,
          ),
          callback: (payload) async {
            final newRow = payload.newRecord;
            final status = newRow['status'] as String?;
            if (status == 'accepted') {
              final invId = newRow['id'] as String?;
              if (invId != null) {
                final matchRes = await Supabase.instance.client
                    .from('kid_matches')
                    .select('id')
                    .eq('invitation_id', invId)
                    .maybeSingle();
                final matchId = matchRes?['id'] as String?;
                if (matchId != null) {
                  _showAndNavigate(kidId, matchId);
                }
              }
            }
          },
        )
        .subscribe();

    // Lyt på: vi er blevet udfordret (ny invitation)
    _channelChallenged = Supabase.instance.client
        .channel('kid_inv_challenged_$kidId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'kid_match_invitations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'challenged_kid_id',
            value: kidId,
          ),
          callback: (payload) async {
            final row = payload.newRecord;
            final status = row['status'] as String?;
            if (status != 'pending') return;
            final invitationId = row['id'] as String?;
            final challengerKidId = row['challenger_kid_id'] as String?;
            final pendingVersion =
                (row['updated_at'] ?? row['created_at'] ?? '').toString();
            if (invitationId != null && challengerKidId != null) {
              await _handleChallenged(
                kidId,
                invitationId,
                challengerKidId,
                pendingVersion: pendingVersion,
              );
            }
          },
        )
        .subscribe();

    _syncPendingChallenges(kidId);
  }

  static Future<void> refreshPendingForCurrentKid() async {
    final kidId = _currentKidId;
    if (kidId == null) return;
    await _syncPendingChallenges(kidId);
  }

  static void stop() {
    _channelAccepted?.unsubscribe();
    _channelChallenged?.unsubscribe();
    _channelAccepted = null;
    _channelChallenged = null;
    _currentKidId = null;
    _shownInvitationEventKeys.clear();
  }

  static void _showAndNavigate(String kidId, String matchId) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Din udfordring er accepteret! Klik for at spille.'),
        action: SnackBarAction(
          label: 'Spil',
          onPressed: () {
            context.go('/kid/spil/$kidId/pvp/$matchId');
          },
        ),
      ),
    );
  }

  static Future<void> _handleChallenged(
    String kidId,
    String invitationId,
    String challengerKidId,
    {String? pendingVersion}
  ) async {
    final eventKey = '$invitationId:${pendingVersion ?? ''}';
    if (_shownInvitationEventKeys.contains(eventKey)) return;
    _shownInvitationEventKeys.add(eventKey);
    if (_shownInvitationEventKeys.length > 60) {
      _shownInvitationEventKeys.removeAt(0);
    }

    final kidRes = await Supabase.instance.client
        .from('kids')
        .select('name,avatar_url')
        .eq('id', challengerKidId)
        .maybeSingle();

    final name = kidRes?['name'] as String? ?? 'Nogen';
    final avatarUrl = kidRes?['avatar_url'] as String?;

    final inForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    if (inForeground) {
      for (var attempt = 0; attempt < 3; attempt++) {
        final context = _navigatorKey?.currentContext;
        if (context != null && context.mounted) {
          ChallengeNotificationDialog.show(
            context,
            kidId: kidId,
            invitationId: invitationId,
            challengerKidId: challengerKidId,
            challengerName: name,
            challengerAvatarUrl: avatarUrl,
          );
          return;
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }
      await NotificationService.showChallengeNotification(
        kidId: kidId,
        invitationId: invitationId,
        challengerKidId: challengerKidId,
        challengerName: name,
      );
    } else {
      await NotificationService.showChallengeNotification(
        kidId: kidId,
        invitationId: invitationId,
        challengerKidId: challengerKidId,
        challengerName: name,
      );
    }
  }

  static Future<void> _syncPendingChallenges(String kidId) async {
    final res = await Supabase.instance.client
        .from('kid_match_invitations')
        .select('id,challenger_kid_id,status,updated_at,created_at')
        .eq('challenged_kid_id', kidId)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(1);
    if ((res as List).isEmpty) return;
    final row = res.first;
    final invitationId = row['id'] as String?;
    final challengerKidId = row['challenger_kid_id'] as String?;
    final pendingVersion = (row['updated_at'] ?? row['created_at'] ?? '').toString();
    if (invitationId == null || challengerKidId == null) return;
    await _handleChallenged(
      kidId,
      invitationId,
      challengerKidId,
      pendingVersion: pendingVersion,
    );
  }
}
