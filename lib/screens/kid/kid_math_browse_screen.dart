import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/math_tasks_service.dart';
import 'widgets/kid_session_nav_button.dart';

/// Mapper til matematik – rod eller undermappe.
class KidMathBrowseScreen extends StatefulWidget {
  const KidMathBrowseScreen({
    super.key,
    required this.kidId,
    this.folderId,
  });

  final String kidId;
  final String? folderId;

  @override
  State<KidMathBrowseScreen> createState() => _KidMathBrowseScreenState();
}

class _KidMathBrowseScreenState extends State<KidMathBrowseScreen> {
  Map<String, MathFolderRow> _folderById = {};
  List<MathFolderRow> _folders = [];
  Map<String, int> _taskCounts = {};
  String? _title;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ctx = await MathTasksService.loadKidVisibilityContext(widget.kidId);
    final folderById = ctx.folderById;
    final assigned = ctx.assigned;
    List<MathFolderRow> folders;
    if (widget.folderId == null) {
      folders = MathTasksService.visibleRootFolders(folderById, assigned);
      _title = 'Matematik';
    } else {
      folders = MathTasksService.visibleChildFolders(
        parentId: widget.folderId!,
        folderById: folderById,
        assigned: assigned,
      );
      final row = folderById[widget.folderId!];
      _title = row?['title'] as String? ?? 'Matematik';
    }
    final ids = folders.map((f) => f['id'] as String).toList();
    final counts = await _fetchTaskCounts(ids);
    if (!mounted) return;
    setState(() {
      _folderById = folderById;
      _folders = folders;
      _taskCounts = counts;
      _loading = false;
    });
  }

  Future<Map<String, int>> _fetchTaskCounts(List<String> folderIds) async {
    if (folderIds.isEmpty) return {};
    final client = Supabase.instance.client;
    final res = await client.from('math_tasks').select('folder_id').inFilter('folder_id', folderIds);
    final map = <String, int>{};
    for (final id in folderIds) {
      map[id] = 0;
    }
    for (final e in res as List) {
      final fid = (e as Map)['folder_id'] as String?;
      if (fid != null) map[fid] = (map[fid] ?? 0) + 1;
    }
    return map;
  }

  Future<int> _taskCountInFolder(String folderId) async {
    final res = await Supabase.instance.client
        .from('math_tasks')
        .select('id')
        .eq('folder_id', folderId);
    return (res as List).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? 'Matematik' : (_title ?? 'Matematik')),
        backgroundColor: const Color(0xFF1B4D3E),
        foregroundColor: Colors.white,
        leading: KidSessionNavButton(
          kidId: widget.kidId,
          isHome: false,
          fallbackLocation: widget.folderId == null
              ? '/kid/today/${widget.kidId}'
              : '/kid/math/${widget.kidId}',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.folderId != null) ...[
                  // Opgaver i **denne** mappe
                  FutureBuilder<int>(
                    future: _taskCountInFolder(widget.folderId!),
                    builder: (ctx, snap) {
                      final n = snap.data ?? 0;
                      if (n == 0) return const SizedBox.shrink();
                      final rate = MathTasksService.effectiveGoldPerTask(
                        widget.folderId!,
                        _folderById,
                      );
                      return Card(
                        color: const Color(0xFFF9C433),
                        child: ListTile(
                          leading: const Icon(Icons.play_circle_fill, size: 40),
                          title: const Text(
                            'Start opgaver',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('$n opgaver · $rate guldmønter pr. rigtig (ved Afslut)'),
                          onTap: () => context.push('/kid/math/${widget.kidId}/play/${widget.folderId}'),
                        ),
                      );
                    },
                  ),
                  if (_folders.isNotEmpty) const SizedBox(height: 16),
                ],
                  if (_folders.isEmpty && widget.folderId != null)
                    FutureBuilder<int>(
                      future: _taskCountInFolder(widget.folderId!),
                      builder: (ctx, snap) {
                        final n = snap.data ?? 0;
                        if (n > 0) return const SizedBox.shrink();
                        return const Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: Center(child: Text('Ingen opgaver her.')),
                        );
                      },
                    ),
                  ..._folders.map((f) {
                    final id = f['id'] as String;
                    final t = f['title'] as String? ?? '';
                    final tc = _taskCounts[id] ?? 0;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.folder_open),
                        title: Text(t),
                        subtitle: tc > 0 ? Text('$tc opgaver i mappen') : const Text('Mappe'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/kid/math/${widget.kidId}/folder/$id'),
                      ),
                    );
                  }),
                  if (_folders.isEmpty && widget.folderId == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(
                        child: Text(
                          'Din voksen skal oprette matematikmapper under Admin → Matematik.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
