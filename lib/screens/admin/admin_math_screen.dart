import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/kid.dart';
import '../../services/math_tasks_service.dart';
import '../../utils/math_task_parse.dart';

class AdminMathScreen extends StatefulWidget {
  const AdminMathScreen({super.key, this.folderId});

  /// `null` = rodniveau under `/admin/math`; ellers undermappe-id.
  final String? folderId;

  @override
  State<AdminMathScreen> createState() => _AdminMathScreenState();
}

class _AdminMathScreenState extends State<AdminMathScreen> {
  String? _profileId;
  List<MathFolderRow> _folders = [];
  List<MathTaskRow> _tasks = [];
  List<Kid> _kids = [];
  MathFolderRow? _currentFolderMeta;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profileId = await MathTasksService.currentProfileId();
    if (!mounted) return;
    if (profileId == null) {
      setState(() {
        _profileId = null;
        _loading = false;
      });
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    final kidsRes = user == null
        ? <dynamic>[]
        : await Supabase.instance.client
            .from('kids')
            .select('id,name,pin_code,avatar_url')
            .eq('parent_id', profileId)
            .order('created_at');

    final folders =
        await MathTasksService.fetchChildFolders(profileId: profileId, parentId: widget.folderId);
    List<MathTaskRow> tasks = [];
    MathFolderRow? meta;
    if (widget.folderId != null) {
      tasks = await MathTasksService.fetchTasks(widget.folderId!);
      final row = await Supabase.instance.client
          .from('math_folders')
          .select('id,parent_id,title,gold_coins_per_task,sort_order')
          .eq('id', widget.folderId!)
          .maybeSingle();
      if (row != null) {
        meta = Map<String, dynamic>.from(row);
      }
    }

    if (!mounted) return;
    setState(() {
      _profileId = profileId;
      _folders = folders;
      _tasks = tasks;
      _kids = [
        for (final e in kidsRes) Kid.fromJson(Map<String, dynamic>.from(e)),
      ];
      _currentFolderMeta = meta;
      _loading = false;
    });
  }

  String _folderTitle() {
    if (widget.folderId == null) return 'Matematik';
    return _currentFolderMeta?['title'] as String? ?? 'Mappe';
  }

  Future<void> _addFolder() async {
    final profileId = _profileId;
    if (profileId == null) return;
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ny mappe'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
            labelText: 'Navn',
            hintText: 'Fx Plusopgaver',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuller')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Opret'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await MathTasksService.createFolder(
        profileId: profileId,
        title: name,
        parentId: widget.folderId,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mappe oprettet')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fejl: $e')));
      }
    }
  }

  Future<void> _addTask() async {
    if (widget.folderId == null) return;
    final c = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ny matematikopgave'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Skriv opgaven med lighedstegn, fx:\n1+1=2 eller 12 - 3 = 9',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              decoration: const InputDecoration(
                labelText: 'Opgave',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuller')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Gem'),
          ),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty) return;
    final parsed = parseMathTaskLine(raw);
    if (parsed == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brug formen: regnestykke=svar (med =)')),
        );
      }
      return;
    }
    try {
      await MathTasksService.addTask(
        folderId: widget.folderId!,
        prompt: parsed.prompt,
        answer: parsed.answer,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opgave tilføjet')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fejl: $e')));
      }
    }
  }

  Future<void> _openFolderSettings(String folderId) async {
    final profileId = _profileId;
    if (profileId == null) return;
    final allFolders = await MathTasksService.fetchAllFolders(profileId);
    final folderById = <String, MathFolderRow>{
      for (final f in allFolders) f['id'] as String: f,
    };
    final row = folderById[folderId];
    if (row == null) return;
    final title = row['title'] as String? ?? '';

    final existingGold = (row['gold_coins_per_task'] as num?)?.toInt();
    final goldController = TextEditingController(
      text: existingGold == null ? '' : '$existingGold',
    );
    var selected = await MathTasksService.fetchFolderKidIds(folderId);
    selected = List<String>.from(selected);
    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final effective = MathTasksService.effectiveGoldPerTask(folderId, folderById);
          return AlertDialog(
            title: Text('Indstillinger: $title'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Guldmønter pr. rigtig opgave (ved Afslut på barnets skærm). '
                      'Tom felt = arve fra overmappe (eller 1 i rod uden værdi).',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: goldController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Egne guldmønter (valgfrit)',
                        hintText: 'Nuværende effekt: $effective',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Børn der må se denne mappe (og undermapper):',
                        style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ..._kids.map((k) {
                      final on = selected.contains(k.id);
                      return CheckboxListTile(
                        value: on,
                        title: Text(k.name),
                        onChanged: (v) {
                          setModal(() {
                            if (v == true) {
                              selected = [...selected, k.id];
                            } else {
                              selected = selected.where((id) => id != k.id).toList();
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuller')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Gem'),
              ),
            ],
          );
        },
      ),
    );
    if (saved != true) return;
    final gRaw = goldController.text.trim();
    final gVal = gRaw.isEmpty ? null : int.tryParse(gRaw);
    if (gRaw.isNotEmpty && gVal == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ugyldigt tal for guldmønter')),
        );
      }
      return;
    }
    try {
      await MathTasksService.updateFolderGold(folderId: folderId, goldCoinsPerTask: gVal);
      await MathTasksService.setFolderKids(folderId: folderId, kidIds: selected);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gemt')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fejl: $e')));
      }
    }
  }

  Future<void> _renameFolder(String folderId, String currentTitle) async {
    final c = TextEditingController(text: currentTitle);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Omdøb mappe'),
        content: TextField(
          controller: c,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuller')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Gem'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await MathTasksService.renameFolder(folderId: folderId, title: name);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fejl: $e')));
      }
    }
  }

  Future<void> _deleteFolder(String folderId, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Slet mappe?'),
        content: Text('Sletter "$title" og alt indhold. Det kan ikke fortrydes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuller')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Slet'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await MathTasksService.deleteFolder(folderId);
      if (mounted && widget.folderId == folderId) {
        context.pop();
        return;
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fejl: $e')));
      }
    }
  }

  Future<void> _deleteTask(String taskId, String prompt) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Slet opgave?'),
        content: Text(prompt),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuller')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Slet'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await MathTasksService.deleteTask(taskId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fejl: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_folderTitle())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_profileId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Matematik')),
        body: const Center(child: Text('Ikke logget ind')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_folderTitle()),
        backgroundColor: const Color(0xFF5A1A0D),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.folderId != null) ...[
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _addTask,
                    icon: const Icon(Icons.add),
                    label: const Text('Tilføj opgave'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openFolderSettings(widget.folderId!),
                    icon: const Icon(Icons.settings),
                    label: const Text('Indstillinger'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.tonalIcon(
              onPressed: _addFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Ny undermappe'),
            ),
            const SizedBox(height: 24),
            if (_folders.isNotEmpty) ...[
              Text('Mapper', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._folders.map((f) {
                final id = f['id'] as String;
                final t = f['title'] as String? ?? '';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(t),
                    trailing: Wrap(
                      spacing: 0,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.settings),
                          tooltip: 'Indstillinger',
                          onPressed: () => _openFolderSettings(id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.drive_file_rename_outline),
                          tooltip: 'Omdøb',
                          onPressed: () => _renameFolder(id, t),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Slet',
                          onPressed: () => _deleteFolder(id, t),
                        ),
                      ],
                    ),
                    onTap: () => context.push('/admin/math/folder/$id'),
                  ),
                );
              }),
            ],
            if (_tasks.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Opgaver', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._tasks.map((t) {
                final id = t['id'] as String;
                final prompt = t['prompt'] as String? ?? '';
                final ans = t['answer'] as String? ?? '';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.calculate),
                    title: Text(prompt),
                    subtitle: Text('Svar: $ans'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteTask(id, prompt),
                    ),
                  ),
                );
              }),
            ],
            if (_folders.isEmpty && _tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: Text('Ingen mapper eller opgaver her endnu.'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
