import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/task.dart';
import '../../providers/auth_provider.dart';
import '../../services/task_completion_service.dart';
import 'widgets/current_avatar.dart';

class KidTodayScreen extends StatefulWidget {
  final String kidId;

  const KidTodayScreen({super.key, required this.kidId});

  @override
  State<KidTodayScreen> createState() => _KidTodayScreenState();
}

class _KidTodayScreenState extends State<KidTodayScreen> {
  List<TaskInstance> _instances = [];
  bool _loading = true;
  int _refreshKey = 0;
  final Map<String, int> _countInput = {};
  String? _completingId;
  final List<_PointsPopup> _popups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _loadToday();
  }

  Future<void> _loadToday() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final client = Supabase.instance.client;

    // Materialize recurring tasks
    final recurring = await client
        .from('recurring_tasks')
        .select('task_id,due_time,allow_upfront,per_day_count')
        .eq('kid_id', widget.kidId);

    final existing = await client
        .from('task_instances')
        .select('task_id')
        .eq('kid_id', widget.kidId)
        .eq('date', today);

    final taskCounts = <String, int>{};
    for (final e in existing as List) {
      final tid = e['task_id'] as String;
      taskCounts[tid] = (taskCounts[tid] ?? 0) + 1;
    }

    final toCreate = <Map<String, dynamic>>[];
    for (final rt in recurring as List) {
      final tid = rt['task_id'] as String;
      final needed = (rt['per_day_count'] as int? ?? 1) - (taskCounts[tid] ?? 0);
      for (var i = 0; i < needed; i++) {
        toCreate.add({
          'task_id': tid,
          'kid_id': widget.kidId,
          'date': today,
          'due_time': rt['due_time'],
          'allow_upfront': rt['allow_upfront'] ?? false,
          'status': 'pending',
        });
      }
    }
    if (toCreate.isNotEmpty) {
      await client.from('task_instances').insert(toCreate);
    }

    final res = await client
        .from('task_instances')
        .select('id,task_id,kid_id,date,due_time,status,tasks(id,title,mode,points_fixed,points_per_unit)')
        .eq('date', today)
        .eq('kid_id', widget.kidId)
        .order('due_time', ascending: true, nullsFirst: false);

    setState(() {
      _instances = (res as List)
          .map((e) => TaskInstance.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _loading = false;
    });
  }

  Future<void> _complete(TaskInstance ti, GlobalKey key) async {
    if (ti.status != 'pending') return;
    setState(() => _completingId = ti.id);

    try {
      final result = await TaskCompletionService.complete(
        taskInstanceId: ti.id,
        kidId: widget.kidId,
        count: ti.task.mode == 'counter' ? _countInput[ti.id] : null,
      );

      if (result.dailyBonus != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Tillykke! Du fik ${result.dailyBonus} bonus point for at færdiggøre alle opgaver!',
            ),
          ),
        );
      }

      final id = '${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _popups.add(_PointsPopup(id: id, points: result.points));
      });
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          setState(() => _popups.removeWhere((p) => p.id == id));
        }
      });

      await _loadToday();
      if (mounted) setState(() => _refreshKey++);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fejl: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _completingId = null);
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
                // Top 3/4: Alfamon + pointtæller (3x så meget som opgaver)
                Expanded(
                  flex: 3,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return Center(
                              child: CurrentAvatar(
                                kidId: widget.kidId,
                                refreshKey: _refreshKey,
                                maxWidth: constraints.maxWidth,
                                maxHeight: constraints.maxHeight,
                              ),
                            );
                          },
                        ),
                ),
                // Bottom 1/4: Opgaver som små felter ved siden af hinanden
                Expanded(
                  flex: 1,
                  child: _loading
                      ? const SizedBox.shrink()
                      : _buildTasksSection(),
                ),
                _buildBottomNav(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<TaskInstance> get _uniquePendingTasks {
    final seen = <String>{};
    return _instances.where((ti) {
      if (ti.status != 'pending') return false;
      if (seen.contains(ti.taskId)) return false;
      seen.add(ti.taskId);
      return true;
    }).toList();
  }

  Widget _buildTasksSection() {
    final tasks = _uniquePendingTasks;
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          'Ingen opgaver i dag!',
          style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.9)),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight.clamp(140.0, 200.0)
            : 170.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: tasks.map((ti) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _TaskCard(
                  instance: ti,
                  countInput: _countInput,
                  onCountChanged: (c) => setState(() => _countInput[ti.id] = c),
                  onComplete: (_) => _complete(ti, GlobalKey()),
                  isCompleting: _completingId == ti.id,
                  compact: true,
                  cardHeight: cardHeight,
                ),
              )).toList(),
            ),
          ),
        );
      },
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
                _NavItem(icon: Icons.today, label: 'I dag', selected: true),
                _NavItem(
                  icon: Icons.calendar_view_week,
                  label: 'Ugen',
                  selected: false,
                  onTap: () => context.go('/kid/week/${widget.kidId}'),
                ),
                _NavItem(
                  icon: Icons.library_books,
                  label: 'Bibliotek',
                  selected: false,
                  onTap: () => context.go('/kid/library/${widget.kidId}'),
                ),
                _NavItem(
                  icon: Icons.sports_esports,
                  label: 'Spil',
                  selected: false,
                  onTap: () => context.go('/kid/spil/${widget.kidId}'),
                ),
                _NavItem(
                  icon: Icons.bug_report,
                  label: 'Test',
                  selected: false,
                  onTap: () => context.go('/kid/test/${widget.kidId}'),
                ),
                _NavItem(
                  icon: Icons.emoji_events,
                  label: 'Præstationer',
                  selected: false,
                  onTap: () => context.go('/kid/achievements/${widget.kidId}'),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: child,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: child,
    );
  }
}

class _PointsPopup {
  final String id;
  final int points;
  _PointsPopup({required this.id, required this.points});
}

class _TaskCard extends StatelessWidget {
  final TaskInstance instance;
  final Map<String, int> countInput;
  final void Function(int) onCountChanged;
  final void Function(GlobalKey) onComplete;
  final bool isCompleting;
  final bool compact;
  final double? cardHeight;

  const _TaskCard({
    required this.instance,
    required this.countInput,
    required this.onCountChanged,
    required this.onComplete,
    required this.isCompleting,
    this.compact = false,
    this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    final ti = instance;
    final isCounter = ti.task.mode == 'counter';
    final points = isCounter
        ? ti.task.pointsPerUnit ?? 0
        : ti.task.pointsFixed ?? 0;
    final count = countInput[ti.id] ?? 0;
    final canComplete = !isCounter || count > 0;

    if (compact) {
      const cardWidth = 150.0;
      final height = cardHeight ?? 170.0;

      return SizedBox(
        width: cardWidth,
        height: height,
        child: ClipRect(
          child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Card(
            color: Colors.white.withOpacity(0.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Titel – fast højde, overflow sikres
                    SizedBox(
                      height: 32,
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          ti.task.title,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Point
                    SizedBox(
                      height: 14,
                      child: Text(
                        '⭐ $points ${isCounter ? 'pkt' : 'point'}',
                        style: const TextStyle(fontSize: 10, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                if (isCounter) ...[
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => onCountChanged(count - 1),
                          icon: const Icon(Icons.remove, size: 14),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(2),
                            minimumSize: const Size(24, 24),
                            backgroundColor: Colors.black12,
                          ),
                        ),
                        SizedBox(
                          width: 24,
                          child: Center(
                            child: Text(
                              '$count',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => onCountChanged(count + 1),
                          icon: const Icon(Icons.add, size: 14),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(2),
                            minimumSize: const Size(24, 24),
                            backgroundColor: Colors.black12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Knap – fast højde
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    onPressed: canComplete && !isCompleting ? () => onComplete(GlobalKey()) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF9C433),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    child: isCompleting
                        ? const Text('...', style: TextStyle(fontSize: 11))
                        : Text(
                            isCounter ? 'Færdig ($count)' : 'Færdig',
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ti.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: ti.isCompleted ? Colors.green : Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ti.task.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      decoration: ti.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⭐ $points ${isCounter ? 'point/enhed' : 'point'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            if (isCounter && !ti.isCompleted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: () => onCountChanged(count - 1),
                    icon: const Icon(Icons.remove),
                    style: IconButton.styleFrom(backgroundColor: Colors.white24),
                  ),
                  SizedBox(
                    width: 60,
                    child: Center(
                      child: Text('$count', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  IconButton(
                    onPressed: () => onCountChanged(count + 1),
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(backgroundColor: Colors.white24),
                  ),
                ],
              ),
            ],
            if (!ti.isCompleted) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canComplete && !isCompleting ? () => onComplete(GlobalKey()) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF9C433),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: isCompleting
                      ? const Text('Færdiggør...')
                      : Text(isCounter ? 'Marker som færdig ($count)' : 'Marker som færdig'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
