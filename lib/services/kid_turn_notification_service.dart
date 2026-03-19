import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';
import '../widgets/turn_notification_dialog.dart';

/// Lytter på PvP-kampe og viser notifikation når det er barnets tur, hvis de ikke er inde i spillet.
class KidTurnNotificationService {
  KidTurnNotificationService._();

  static GlobalKey<NavigatorState>? _navigatorKey;
  static String? _currentKidId;
  static String? _currentRoute;
  static final Map<String, RealtimeChannel> _channels = {};
  static RealtimeChannel? _matchesChannel;
  static final Set<String> _subscribingMatchIds = {};
  static bool _refreshInProgress = false;
  static bool _refreshQueued = false;
  static final List<String> _shownForMatch = [];
  static final Set<String> _shownForfeitMatchIds = {};

  static void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  static void updateCurrentRoute(String? route) {
    _currentRoute = route;
  }

  static void start(String kidId) {
    if (_currentKidId == kidId) return;
    stop();
    _currentKidId = kidId;
    _subscribeToMatches();

    _matchesChannel = Supabase.instance.client
        .channel('kid_turn_matches_$kidId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'kid_matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'kid1_id',
            value: kidId,
          ),
          callback: (payload) {
            _subscribeToMatches();
            _handleMatchTableChange(payload);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'kid_matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'kid2_id',
            value: kidId,
          ),
          callback: (payload) {
            _subscribeToMatches();
            _handleMatchTableChange(payload);
          },
        )
        .subscribe();
  }

  static void stop() {
    _matchesChannel?.unsubscribe();
    _matchesChannel = null;
    for (final ch in _channels.values) {
      ch.unsubscribe();
    }
    _channels.clear();
    _subscribingMatchIds.clear();
    _refreshInProgress = false;
    _refreshQueued = false;
    _currentKidId = null;
    _currentRoute = null;
    _shownForfeitMatchIds.clear();
  }

  static Future<void> _subscribeToMatches() async {
    if (_currentKidId == null) return;
    if (_refreshInProgress) {
      _refreshQueued = true;
      return;
    }
    _refreshInProgress = true;
    final kidId = _currentKidId!;

    try {
      final matchesRes = await Supabase.instance.client
          .from('kid_matches')
          .select('id,kid1_id,kid2_id')
          .or('kid1_id.eq.$kidId,kid2_id.eq.$kidId')
          .eq('status', 'in_progress');
      if (_currentKidId != kidId) return;

      final activeMatchIds = <String>{};
      for (final m in matchesRes as List) {
        activeMatchIds.add(m['id'] as String);
      }

      final stale = _channels.keys.where((id) => !activeMatchIds.contains(id)).toList();
      for (final matchId in stale) {
        _channels.remove(matchId)?.unsubscribe();
      }

      for (final m in matchesRes) {
        final matchId = m['id'] as String;
        if (_channels.containsKey(matchId) || _subscribingMatchIds.contains(matchId)) {
          continue;
        }
        _subscribingMatchIds.add(matchId);
        final kid1Id = m['kid1_id'] as String;
        final kid2Id = m['kid2_id'] as String;

        final channel = Supabase.instance.client
            .channel('kid_turn_$matchId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'kid_match_rounds',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'match_id',
                value: matchId,
              ),
              callback: (_) => _onRoundChanged(matchId, kid1Id, kid2Id),
            )
            .subscribe();

        _channels[matchId] = channel;
        _subscribingMatchIds.remove(matchId);
      }
    } finally {
      _refreshInProgress = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        _subscribeToMatches();
      }
    }
  }

  static Future<void> _onRoundChanged(String matchId, String kid1Id, String kid2Id) async {
    if (_currentKidId == null) return;
    if (_currentKidId != kid1Id && _currentKidId != kid2Id) return;

    final amKid1 = _currentKidId == kid1Id;
    final ctx = _navigatorKey?.currentContext;
    String route = _currentRoute ?? '';
    if (route.isEmpty && ctx != null) {
      try {
        route = GoRouterState.of(ctx).matchedLocation;
      } catch (_) {}
    }
    final inThisMatch = RegExp(
      '^/kid/spil/${RegExp.escape(_currentKidId!)}/pvp/${RegExp.escape(matchId)}\$',
    ).hasMatch(route);
    if (inThisMatch) return;

    final inForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (!inForeground) return;

    final matchRes = await Supabase.instance.client
        .from('kid_matches')
        .select('round_number')
        .eq('id', matchId)
        .maybeSingle();
    final roundNumber = matchRes?['round_number'] as int? ?? 1;

    final roundRes = await Supabase.instance.client
        .from('kid_match_rounds')
        .select('phase,kid1_avatar_id,kid2_avatar_id,kid1_strength_index,kid2_strength_index,ability_picker')
        .eq('match_id', matchId)
        .eq('round_number', roundNumber)
        .maybeSingle();

    if (roundRes == null) return;

    final phase = roundRes['phase'] as String? ?? 'pick_card';
    final k1Avatar = roundRes['kid1_avatar_id'];
    final k2Avatar = roundRes['kid2_avatar_id'];
    final k1Str = roundRes['kid1_strength_index'];
    final k2Str = roundRes['kid2_strength_index'];
    final abilityPicker = roundRes['ability_picker'] as String?;

    bool isMyTurn = false;
    if (phase == 'pick_card') {
      if (amKid1 && k1Avatar == null) isMyTurn = true;
      if (!amKid1 && k2Avatar == null) isMyTurn = true;
    } else if (phase == 'pick_strength') {
      final iAmPicker = (abilityPicker == 'kid1' && amKid1) || (abilityPicker == 'kid2' && !amKid1);
      if (iAmPicker) {
        if (amKid1 && k1Str == null) isMyTurn = true;
        if (!amKid1 && k2Str == null) isMyTurn = true;
      }
    }

    if (!isMyTurn) return;

    final key = '$matchId-$roundNumber-$phase';
    if (_shownForMatch.contains(key)) return;
    _shownForMatch.add(key);
    if (_shownForMatch.length > 20) {
      _shownForMatch.removeAt(0);
    }

    final opponentId = amKid1 ? kid2Id : kid1Id;
    final opponentRes = await Supabase.instance.client
        .from('kids')
        .select('name')
        .eq('id', opponentId)
        .maybeSingle();
    final opponentName = opponentRes?['name'] as String? ?? 'Modstander';

    if (ctx != null && ctx.mounted) {
      TurnNotificationDialog.show(
        ctx,
        kidId: _currentKidId!,
        matchId: matchId,
        opponentName: opponentName,
      );
    }
  }

  static Future<void> _handleMatchTableChange(dynamic payload) async {
    if (_currentKidId == null) return;
    final row = payload.newRecord as Map<String, dynamic>?;
    final old = payload.oldRecord as Map<String, dynamic>?;
    if (row == null || row.isEmpty) return;

    final status = row['status'] as String?;
    final oldStatus = old?['status'] as String?;
    if (status != 'completed' || oldStatus == 'completed') return;

    final winner = row['winner'] as String?;
    if (winner == null) return;

    final matchId = row['id'] as String?;
    final kid1Id = row['kid1_id'] as String?;
    final kid2Id = row['kid2_id'] as String?;
    if (matchId == null || kid1Id == null || kid2Id == null) return;
    if (_shownForfeitMatchIds.contains(matchId)) return;

    final amKid1 = _currentKidId == kid1Id;
    final iWon = (winner == 'kid1' && amKid1) || (winner == 'kid2' && !amKid1);
    if (!iWon) return;

    _shownForfeitMatchIds.add(matchId);
    final opponentId = amKid1 ? kid2Id : kid1Id;
    final opponentRes = await Supabase.instance.client
        .from('kids')
        .select('name')
        .eq('id', opponentId)
        .maybeSingle();
    final opponentName = opponentRes?['name'] as String? ?? 'Modstanderen';
    final message = '$opponentName opgav - du vandt!';

    final inForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final ctx = _navigatorKey?.currentContext;
    String route = _currentRoute ?? '';
    if (route.isEmpty && ctx != null) {
      try {
        route = GoRouterState.of(ctx).matchedLocation;
      } catch (_) {}
    }
    final inThisMatch = RegExp(
      '^/kid/spil/${RegExp.escape(_currentKidId!)}/pvp/${RegExp.escape(matchId)}\$',
    ).hasMatch(route);

    if (inForeground && ctx != null && ctx.mounted && !inThisMatch) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } else if (!inForeground) {
      await NotificationService.showSimpleNotification(
        title: 'Kamp afsluttet',
        body: message,
      );
    }
  }
}
