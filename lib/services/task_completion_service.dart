import 'package:supabase_flutter/supabase_flutter.dart';

/// Replicates the /api/complete logic from Next.js - runs entirely client-side with Supabase.
class TaskCompletionService {
  static final _client = Supabase.instance.client;

  static Future<CompleteResult> complete({
    required String taskInstanceId,
    required String kidId,
    int? count,
  }) async {
    // Fetch instance + task
    final instanceRes = await _client
        .from('task_instances')
        .select('id,status,task_id')
        .eq('id', taskInstanceId)
        .single();

    if (instanceRes['status'] != 'pending') {
      throw Exception('Already completed');
    }

    final taskRes = await _client
        .from('tasks')
        .select('mode,points_fixed,points_per_unit,require_approval')
        .eq('id', instanceRes['task_id'])
        .single();

    final mode = taskRes['mode'] as String;
    final pointsFixed = taskRes['points_fixed'] as int?;
    final pointsPerUnit = taskRes['points_per_unit'] as int?;
    final requireApproval = taskRes['require_approval'] as bool? ?? false;

    final points = mode == 'fixed'
        ? (pointsFixed ?? 0)
        : (pointsPerUnit ?? 0) * (count ?? 0);

    // Insert completion
    final completionRes = await _client.from('task_completions').insert({
      'task_instance_id': taskInstanceId,
      'kid_id': kidId,
      'count_entered': mode == 'counter' ? count : null,
      'points_awarded': points,
    }).select('id').single();

    final status = requireApproval ? 'needs_approval' : 'completed';
    await _client
        .from('task_instances')
        .update({'status': status})
        .eq('id', taskInstanceId);

    int? dailyBonus;
    if (!requireApproval) {
      final activeRes = await _client
          .from('kid_active_avatar')
          .select('avatar_id,points_current')
          .eq('kid_id', kidId)
          .maybeSingle();

      if (activeRes != null && activeRes['avatar_id'] != null) {
        final avatarId = activeRes['avatar_id'] as String;
        final currentPoints = activeRes['points_current'] as int? ?? 0;
        final newBalance = currentPoints + points;

        // Check alphamon unlocked
        final unlocked = await _client
            .from('kid_unlocked_alphamons')
            .select('id')
            .eq('kid_id', kidId)
            .eq('avatar_id', avatarId)
            .maybeSingle();

        if (unlocked != null) {
          int workingBalance = newBalance;

          await _client
              .from('kid_active_avatar')
              .update({'points_current': workingBalance})
              .eq('kid_id', kidId);

          await _client.from('points_ledger').insert({
            'kid_id': kidId,
            'source': 'task',
            'task_completion_id': completionRes['id'],
            'delta_points': points,
            'balance_after': workingBalance,
          });

          // Daily bonus check (before library/evolution logic)
          final today = DateTime.now().toIso8601String().substring(0, 10);
          final todayInstances = await _client
              .from('task_instances')
              .select('id,status')
              .eq('kid_id', kidId)
              .eq('date', today);

          final allCompleted = (todayInstances as List).every((ti) =>
              ti['status'] == 'completed' || ti['status'] == 'approved');
          final hasPending =
              (todayInstances).any((ti) => ti['status'] == 'pending');
          final hasTasks = todayInstances.isNotEmpty;

          if (allCompleted && !hasPending && hasTasks) {
            final existingBonus = await _client
                .from('points_ledger')
                .select('id')
                .eq('kid_id', kidId)
                .eq('source', 'daily_bonus')
                .gte('created_at', '${today}T00:00:00')
                .lt('created_at', '${today}T23:59:59')
                .maybeSingle();

            if (existingBonus == null) {
              const bonusPoints = 5;
              workingBalance += bonusPoints;
              dailyBonus = bonusPoints;

              await _client
                  .from('kid_active_avatar')
                  .update({'points_current': workingBalance})
                  .eq('kid_id', kidId);

              await _client.from('points_ledger').insert({
                'kid_id': kidId,
                'source': 'daily_bonus',
                'task_completion_id': null,
                'delta_points': bonusPoints,
                'balance_after': workingBalance,
              });
            }
          }

          // Update kid_avatar_library
          final libRes = await _client
              .from('kid_avatar_library')
              .select('id,current_stage_index')
              .eq('kid_id', kidId)
              .eq('avatar_id', avatarId)
              .maybeSingle();

          final avatarRes = await _client
              .from('avatars')
              .select('points_per_stage')
              .eq('id', avatarId)
              .single();

          final stagesRes = await _client
              .from('avatar_stages')
              .select('stage_index')
              .eq('avatar_id', avatarId)
              .order('stage_index');

          final pointsPerStage =
              (avatarRes['points_per_stage'] as Map<String, dynamic>?) ?? {};
          final stages = stagesRes as List;

          if (stages.isNotEmpty) {
            final maxStage = (stages.last as Map)['stage_index'] as int;
            int pointsAccumulated = 0;
            int currentStage = (stages.first as Map)['stage_index'] as int;

            for (var i = 0; i < stages.length - 1; i++) {
              final stageIdx = (stages[i] as Map)['stage_index'] as int;
              final pointsNeeded =
                  (pointsPerStage[stageIdx.toString()] as num?)?.toInt() ?? 10;
              if (workingBalance >= pointsAccumulated + pointsNeeded) {
                pointsAccumulated += pointsNeeded;
                currentStage = (stages[i + 1] as Map)['stage_index'] as int;
              } else {
                break;
              }
            }

            if (libRes != null) {
              await _client.from('kid_avatar_library').update({
                'current_stage_index': currentStage,
                'points_current': workingBalance,
              }).eq('id', libRes['id']);
            } else {
              await _client.from('kid_avatar_library').insert({
                'kid_id': kidId,
                'avatar_id': avatarId,
                'current_stage_index': currentStage,
                'points_current': workingBalance,
              });
            }

            if (currentStage >= maxStage) {
              await _client.from('kid_avatar_history').insert({
                'kid_id': kidId,
                'avatar_id': avatarId,
                'total_points': workingBalance,
              });
              await _client
                  .from('kid_active_avatar')
                  .update({'avatar_id': null, 'points_current': 0})
                  .eq('kid_id', kidId);
            }
          }
        }
      }
    }

    return CompleteResult(points: points, dailyBonus: dailyBonus);
  }
}

class CompleteResult {
  final int points;
  final int? dailyBonus;

  CompleteResult({required this.points, this.dailyBonus});
}
