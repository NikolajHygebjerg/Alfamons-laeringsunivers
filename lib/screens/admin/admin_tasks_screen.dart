import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/task.dart';

class AdminTasksScreen extends StatefulWidget {
  const AdminTasksScreen({super.key});

  @override
  State<AdminTasksScreen> createState() => _AdminTasksScreenState();
}

class _AdminTasksScreenState extends State<AdminTasksScreen> {
  List<Task> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('id')
        .eq('auth_user_id', user.id)
        .maybeSingle();

    final parentId = profile?['id'];
    if (parentId == null) return;

    final res = await Supabase.instance.client
        .from('tasks')
        .select('id,title,description,mode,points_fixed,points_per_unit')
        .eq('parent_id', parentId)
        .order('created_at');

    setState(() {
      _tasks = (res as List).map((e) => Task.fromJson(e)).toList();
      _loading = false;
    });
  }

  Future<void> _addTask() async {
    final titleController = TextEditingController();
    final pointsController = TextEditingController(text: '10');
    var mode = 'fixed';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Opret opgave'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Titel'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Fast'),
                    selected: mode == 'fixed',
                    onSelected: (_) => setModalState(() => mode = 'fixed'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Tæller'),
                    selected: mode == 'counter',
                    onSelected: (_) => setModalState(() => mode = 'counter'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pointsController,
                decoration: InputDecoration(
                  labelText: mode == 'fixed' ? 'Point' : 'Point per enhed',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuller'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Opret'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('id')
        .eq('auth_user_id', user.id)
        .maybeSingle();

    final parentId = profile?['id'];
    if (parentId == null) return;

    final points = int.tryParse(pointsController.text) ?? 10;

    await Supabase.instance.client.from('tasks').insert({
      'parent_id': parentId,
      'title': titleController.text.trim(),
      'mode': mode,
      'points_fixed': mode == 'fixed' ? points : null,
      'points_per_unit': mode == 'counter' ? points : null,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opgave oprettet')),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Opgaver'),
        backgroundColor: const Color(0xFF5A1A0D),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tasks.length,
              itemBuilder: (_, i) {
                final t = _tasks[i];
                final points = t.mode == 'fixed'
                    ? t.pointsFixed ?? 0
                    : t.pointsPerUnit ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(t.title),
                    subtitle: Text(
                      '${t.mode == "fixed" ? "Fast" : "Tæller"} • $points point',
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        backgroundColor: const Color(0xFFF9C433),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
