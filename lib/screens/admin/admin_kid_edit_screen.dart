import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/kid.dart';
import '../../models/task.dart';

/// Admin: Rediger barn – avatar, PIN, opgavetildeling.
class AdminKidEditScreen extends StatefulWidget {
  final Kid kid;

  const AdminKidEditScreen({super.key, required this.kid});

  @override
  State<AdminKidEditScreen> createState() => _AdminKidEditScreenState();
}

class _AdminKidEditScreenState extends State<AdminKidEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _pinController;
  List<Task> _tasks = [];
  Set<String> _assignedTaskIds = {};
  List<Map<String, dynamic>> _avatars = [];
  String? _selectedAvatarId;
  String? _selectedAvatarImageUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.kid.name);
    _pinController = TextEditingController(text: widget.kid.pinCode ?? '');
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;

    final user = client.auth.currentUser;
    if (user == null) return;

    final profile = await client
        .from('profiles')
        .select('id')
        .eq('auth_user_id', user.id)
        .maybeSingle();
    final parentId = profile?['id'];
    if (parentId == null) return;

    final tasksRes = await client
        .from('tasks')
        .select('id,title,description,mode,points_fixed,points_per_unit')
        .eq('parent_id', parentId)
        .order('created_at');

    final recurringRes = await client
        .from('recurring_tasks')
        .select('task_id')
        .eq('kid_id', widget.kid.id);

    final activeAvatarRes = await client
        .from('kid_active_avatar')
        .select('avatar_id')
        .eq('kid_id', widget.kid.id)
        .maybeSingle();

    final avatarsRes = await client
        .from('avatars')
        .select('id,name,letter')
        .order('name');

    final stageRes = await client
        .from('avatar_stages')
        .select('avatar_id,stage_index,image_url');

    final stageMap = <String, String>{};
    final stagesList = (stageRes as List)
        .cast<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) {
        final aidCmp = (a['avatar_id'] as String).compareTo(b['avatar_id'] as String);
        if (aidCmp != 0) return aidCmp;
        return (b['stage_index'] as int).compareTo(a['stage_index'] as int);
      });
    for (final s in stagesList) {
      final aid = s['avatar_id'] as String;
      if (!stageMap.containsKey(aid)) {
        stageMap[aid] = s['image_url'] as String? ?? '';
      }
    }

    final avatars = <Map<String, dynamic>>[];
    for (final a in avatarsRes as List) {
      final avatarId = a['id'] as String;
      avatars.add({
        'id': avatarId,
        'name': a['name'] ?? 'Alfamon',
        'letter': a['letter'],
        'image_url': stageMap[avatarId],
      });
    }

    if (!mounted) return;
    setState(() {
      _tasks = (tasksRes as List).map((e) => Task.fromJson(e)).toList();
      _assignedTaskIds = (recurringRes as List)
          .map((e) => e['task_id'] as String)
          .toSet();
      _avatars = avatars;
      _selectedAvatarId = activeAvatarRes?['avatar_id'] as String?;
      _selectedAvatarImageUrl = _selectedAvatarId != null
          ? stageMap[_selectedAvatarId]
          : widget.kid.avatarUrl;
      _loading = false;
    });
  }

  Future<void> _saveNameAndPin() async {
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();

    await Supabase.instance.client.from('kids').update({
      'name': name,
      'pin_code': pin.isEmpty ? null : pin,
    }).eq('id', widget.kid.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navn og PIN gemt')),
      );
    }
  }

  Future<void> _selectAvatar(Map<String, dynamic> avatar) async {
    final client = Supabase.instance.client;
    final avatarId = avatar['id'] as String;
    final imageUrl = avatar['image_url'] as String?;

    await client.from('kids').update({
      'avatar_url': imageUrl,
    }).eq('id', widget.kid.id);

    final existingUnlock = await client
        .from('kid_unlocked_alphamons')
        .select('id')
        .eq('kid_id', widget.kid.id)
        .eq('avatar_id', avatarId)
        .maybeSingle();

    var points = 0;
    if (existingUnlock == null) {
      await client.from('kid_unlocked_alphamons').insert({
        'kid_id': widget.kid.id,
        'avatar_id': avatarId,
      });

      final stagesRes = await client
          .from('avatar_stages')
          .select('stage_index')
          .eq('avatar_id', avatarId)
          .order('stage_index')
          .limit(1);
      final initialStage = (stagesRes as List).isNotEmpty
          ? (stagesRes.first['stage_index'] as int)
          : 0;

      await client.from('kid_avatar_library').insert({
        'kid_id': widget.kid.id,
        'avatar_id': avatarId,
        'current_stage_index': initialStage,
        'points_current': 0,
      });
    } else {
      final libRes = await client
          .from('kid_avatar_library')
          .select('points_current')
          .eq('kid_id', widget.kid.id)
          .eq('avatar_id', avatarId)
          .maybeSingle();
      points = libRes?['points_current'] as int? ?? 0;
    }

    await client.from('kid_active_avatar').upsert({
      'kid_id': widget.kid.id,
      'avatar_id': avatarId,
      'points_current': points,
    }, onConflict: 'kid_id');

    if (mounted) {
      setState(() {
        _selectedAvatarId = avatarId;
        _selectedAvatarImageUrl = imageUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar opdateret')),
      );
    }
  }

  Future<void> _toggleTask(Task task, bool assign) async {
    final client = Supabase.instance.client;

    if (assign) {
      await client.from('recurring_tasks').insert({
        'kid_id': widget.kid.id,
        'task_id': task.id,
        'due_time': '18:00',
        'allow_upfront': true,
        'per_day_count': 1,
      });
      setState(() => _assignedTaskIds.add(task.id));
    } else {
      await client
          .from('recurring_tasks')
          .delete()
          .eq('kid_id', widget.kid.id)
          .eq('task_id', task.id);
      setState(() => _assignedTaskIds.remove(task.id));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(assign ? 'Opgave tildelt' : 'Opgave fjernet')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rediger ${widget.kid.name}'),
        backgroundColor: const Color(0xFF5A1A0D),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNameAndPin,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Navn og PIN',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Navn',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinController,
                    decoration: const InputDecoration(
                      labelText: 'PIN (4 cifre, valgfrit)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Avatar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _avatars.length,
                      itemBuilder: (_, i) {
                        final a = _avatars[i];
                        final isSelected = _selectedAvatarId == a['id'];
                        final url = a['image_url'] as String?;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: InkWell(
                            onTap: () => _selectAvatar(a),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 90,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.amber
                                      : Colors.grey,
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: url != null && url.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(11)),
                                            child: Image.network(
                                              url,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(Icons.person, size: 40),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Text(
                                      a['name'] as String? ?? '',
                                      style: const TextStyle(fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Opgaver',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Ingen opgaver oprettet. Opret opgaver under "Opgaver" først.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._tasks.map((t) {
                      final assigned = _assignedTaskIds.contains(t.id);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          title: Text(t.title),
                          subtitle: Text(
                            '${t.mode == "fixed" ? "Fast" : "Tæller"} • ${t.mode == "fixed" ? (t.pointsFixed ?? 0) : (t.pointsPerUnit ?? 0)} point',
                          ),
                          value: assigned,
                          onChanged: (v) => _toggleTask(t, v ?? false),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
