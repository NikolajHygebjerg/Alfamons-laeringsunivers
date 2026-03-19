import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CurrentAvatar extends StatefulWidget {
  final String kidId;
  final int refreshKey;
  final double? maxWidth;
  final double? maxHeight;

  const CurrentAvatar({
    super.key,
    required this.kidId,
    required this.refreshKey,
    this.maxWidth,
    this.maxHeight,
  });

  @override
  State<CurrentAvatar> createState() => _CurrentAvatarState();
}

class _CurrentAvatarState extends State<CurrentAvatar> {
  String? _imageUrl;
  String _avatarName = 'Alfamon';
  String? _avatarLetter;
  int _currentStage = 0;
  int _progress = 0;
  int _maxProgress = 30;
  bool _hasAvatar = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CurrentAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey || oldWidget.kidId != widget.kidId) {
      _load();
    }
  }

  Future<void> _load() async {
    final active = await Supabase.instance.client
        .from('kid_active_avatar')
        .select('avatar_id,points_current')
        .eq('kid_id', widget.kidId)
        .maybeSingle();

    if (active == null || active['avatar_id'] == null) {
      setState(() {
        _hasAvatar = false;
        _imageUrl = null;
      });
      return;
    }

    setState(() => _hasAvatar = true);

    final avatarId = active['avatar_id'] as String;

    // kid_avatar_library er kilde til stage og point (opdateres af task completion)
    final libRes = await Supabase.instance.client
        .from('kid_avatar_library')
        .select('current_stage_index,points_current')
        .eq('kid_id', widget.kidId)
        .eq('avatar_id', avatarId)
        .maybeSingle();

    int currentStage;
    int points;
    if (libRes != null) {
      currentStage = libRes['current_stage_index'] as int? ?? 0;
      points = libRes['points_current'] as int? ?? 0;
    } else {
      // Fallback: brug kid_active_avatar (f.eks. lige efter valg)
      points = active['points_current'] as int? ?? 0;
      currentStage = await _calculateStageFromPoints(avatarId, points);
    }

    final avatarRes = await Supabase.instance.client
        .from('avatars')
        .select('name,letter,points_per_stage')
        .eq('id', avatarId)
        .single();

    final stagesRes = await Supabase.instance.client
        .from('avatar_stages')
        .select('stage_index')
        .eq('avatar_id', avatarId)
        .order('stage_index');

    final pointsPerStage =
        (avatarRes['points_per_stage'] as Map<String, dynamic>?) ?? {};
    final stages = stagesRes as List;

    int maxProgressVal = 0;
    if (stages.isNotEmpty) {
      for (var i = 0; i < stages.length - 1; i++) {
        final stageIdx = (stages[i] as Map)['stage_index'] as int;
        final pointsNeeded =
            (pointsPerStage[stageIdx.toString()] as num?)?.toInt() ?? 10;
        maxProgressVal += pointsNeeded;
      }
    }

    final stageData = await Supabase.instance.client
        .from('avatar_stages')
        .select('image_url')
        .eq('avatar_id', avatarId)
        .eq('stage_index', currentStage)
        .maybeSingle();

    setState(() {
      _avatarName = avatarRes['name'] as String? ?? 'Alfamon';
      _avatarLetter = avatarRes['letter'] as String?;
      _currentStage = currentStage;
      _progress = points.clamp(0, maxProgressVal);
      _maxProgress = maxProgressVal;
      _imageUrl = stageData?['image_url'] as String?;
    });
  }

  Future<int> _calculateStageFromPoints(String avatarId, int points) async {
    final avatarRes = await Supabase.instance.client
        .from('avatars')
        .select('points_per_stage')
        .eq('id', avatarId)
        .single();
    final stagesRes = await Supabase.instance.client
        .from('avatar_stages')
        .select('stage_index')
        .eq('avatar_id', avatarId)
        .order('stage_index');

    final pointsPerStage =
        (avatarRes['points_per_stage'] as Map<String, dynamic>?) ?? {};
    final stages = stagesRes as List;
    if (stages.isEmpty) return 0;

    int pointsAccumulated = 0;
    int currentStage = (stages.first as Map)['stage_index'] as int;

    for (var i = 0; i < stages.length - 1; i++) {
      final stageIdx = (stages[i] as Map)['stage_index'] as int;
      final raw = pointsPerStage[stageIdx.toString()] ?? pointsPerStage[stageIdx];
      var pointsNeeded = (raw as num?)?.toInt() ?? 10;
      if (pointsNeeded < 1) pointsNeeded = 10;
      if (points >= pointsAccumulated + pointsNeeded) {
        pointsAccumulated += pointsNeeded;
        currentStage = (stages[i + 1] as Map)['stage_index'] as int;
      } else {
        break;
      }
    }
    return currentStage;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAvatar) {
      return GestureDetector(
        onTap: () => context.go('/kid/alfamons/${widget.kidId}'),
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black54, width: 2),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.library_books, size: 64),
              SizedBox(height: 12),
              Text(
                'Vælg en Alfamon fra biblioteket',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Billedet så stort som muligt i højden. Boksens sider 10 px bredere end billedet.
    // textAreaHeight: plads til navn, progressbar, point-tekst, padding og margin (~130 px)
    const sidePadding = 10.0;
    const textAreaHeight = 140.0;
    final maxH = (widget.maxHeight != null && widget.maxHeight!.isFinite)
        ? widget.maxHeight!
        : 400.0;
    final maxW = (widget.maxWidth != null && widget.maxWidth!.isFinite)
        ? widget.maxWidth!
        : 400.0;
    // Prioriter højde – billedet så stort som muligt i højden
    final availHeight = maxH - textAreaHeight;
    final availWidth = maxW - sidePadding * 2;
    final imageSize = (availHeight < availWidth ? availHeight : availWidth)
        .clamp(80.0, 400.0);

    return GestureDetector(
      onTap: () => context.go('/kid/alfamons/${widget.kidId}'),
      child: SizedBox(
        width: imageSize + sidePadding * 2,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: sidePadding, vertical: 10),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black54, width: 2),
          ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasAvatar)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _imageUrl != null && _imageUrl!.isNotEmpty
                    ? Image.network(
                        _imageUrl!,
                        width: imageSize,
                        height: imageSize,
                        fit: BoxFit.cover,
                      )
                    : Icon(Icons.person, size: imageSize),
              )
            else
              Icon(Icons.person, size: imageSize),
            const SizedBox(height: 12),
            Text(
              _avatarName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _maxProgress > 0 ? _progress / _maxProgress : 0,
                minHeight: 12,
                backgroundColor: Colors.grey.shade700,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$_progress / $_maxProgress point',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
