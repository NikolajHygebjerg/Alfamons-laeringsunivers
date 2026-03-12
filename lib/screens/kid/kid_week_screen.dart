import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/task.dart';
import '../../providers/auth_provider.dart';

class KidWeekScreen extends StatefulWidget {
  final String kidId;

  const KidWeekScreen({super.key, required this.kidId});

  @override
  State<KidWeekScreen> createState() => _KidWeekScreenState();
}

class _KidWeekScreenState extends State<KidWeekScreen> {
  Map<String, List<TaskInstance>> _weekTasks = {};
  bool _loading = true;

  static const _dayNames = ['Man', 'Tir', 'Ons', 'Tor', 'Fre', 'Lør', 'Søn'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;

    // Uge: mandag til søndag
    final now = DateTime.now();
    final weekday = now.weekday; // 1=mandag, 7=søndag
    final monday = now.subtract(Duration(days: weekday - 1));

    final toCreate = <Map<String, dynamic>>[];
    final recurring = await client
        .from('recurring_tasks')
        .select('task_id,due_time,allow_upfront,per_day_count')
        .eq('kid_id', widget.kidId);

    for (var d = 0; d < 7; d++) {
      final date = monday.add(Duration(days: d));
      final dateStr = date.toIso8601String().substring(0, 10);

      final existing = await client
          .from('task_instances')
          .select('task_id')
          .eq('kid_id', widget.kidId)
          .eq('date', dateStr);

      final taskCounts = <String, int>{};
      for (final e in existing as List) {
        final tid = e['task_id'] as String;
        taskCounts[tid] = (taskCounts[tid] ?? 0) + 1;
      }

      for (final rt in recurring as List) {
        final tid = rt['task_id'] as String;
        final needed = (rt['per_day_count'] as int? ?? 1) - (taskCounts[tid] ?? 0);
        for (var i = 0; i < needed; i++) {
          toCreate.add({
            'task_id': tid,
            'kid_id': widget.kidId,
            'date': dateStr,
            'due_time': rt['due_time'],
            'allow_upfront': rt['allow_upfront'] ?? false,
            'status': 'pending',
          });
        }
      }
    }

    if (toCreate.isNotEmpty) {
      await client.from('task_instances').insert(toCreate);
    }

    final weekTasks = <String, List<TaskInstance>>{};
    for (var d = 0; d < 7; d++) {
      final date = monday.add(Duration(days: d));
      final dateStr = date.toIso8601String().substring(0, 10);

      final res = await client
          .from('task_instances')
          .select('id,task_id,kid_id,date,due_time,status,tasks(id,title,mode,points_fixed,points_per_unit)')
          .eq('kid_id', widget.kidId)
          .eq('date', dateStr)
          .order('due_time', ascending: true, nullsFirst: false);

      weekTasks[dateStr] = (res as List)
          .map((e) => TaskInstance.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    setState(() {
      _weekTasks = weekTasks;
      _loading = false;
    });
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
                    'Ugen',
                    style: TextStyle(
                      fontSize: isTablet ? 28 : 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : _buildWeekContent(),
                ),
                _buildBottomNav(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekContent() {
    final now = DateTime.now();
    final weekday = now.weekday;
    final monday = now.subtract(Duration(days: weekday - 1));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(7, (i) {
          final date = monday.add(Duration(days: i));
          final dateStr = date.toIso8601String().substring(0, 10);
          final tasks = _weekTasks[dateStr] ?? [];
          final dayName = _dayNames[i];
          final isToday = dateStr == DateTime.now().toIso8601String().substring(0, 10);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: isToday
                  ? Border.all(color: const Color(0xFFF9C433), width: 2)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$dayName ${date.day}/${date.month}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (isToday)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9C433),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'I dag',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (tasks.isEmpty)
                  const Text(
                    'Ingen opgaver',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  )
                else
                  ...tasks.map((ti) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          ti.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 20,
                          color: ti.isCompleted ? Colors.green : Colors.black54,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ti.task.title,
                            style: TextStyle(
                              fontSize: 14,
                              color: ti.isCompleted ? Colors.black54 : Colors.black87,
                              decoration: ti.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ti.isCompleted
                              ? '0'
                              : (ti.task.mode == 'counter'
                                  ? '${ti.task.pointsPerUnit ?? 0} pkt'
                                  : '${ti.task.pointsFixed ?? 0} point'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  )),
              ],
            ),
          );
        }),
      ),
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
                _NavItem(
                  icon: Icons.today,
                  label: 'I dag',
                  selected: false,
                  onTap: () => context.go('/kid/today/${widget.kidId}'),
                ),
                _NavItem(
                  icon: Icons.calendar_view_week,
                  label: 'Ugen',
                  selected: true,
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
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: child),
      );
    }
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: child);
  }
}
