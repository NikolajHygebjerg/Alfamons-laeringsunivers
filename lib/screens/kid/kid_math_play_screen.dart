import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/math_tasks_service.dart';
import '../../utils/math_task_parse.dart';
import 'widgets/gold_coins_earned_overlay.dart';
import 'widgets/kid_session_nav_button.dart';

class KidMathPlayScreen extends StatefulWidget {
  const KidMathPlayScreen({
    super.key,
    required this.kidId,
    required this.folderId,
  });

  final String kidId;
  final String folderId;

  @override
  State<KidMathPlayScreen> createState() => _KidMathPlayScreenState();
}

class _KidMathPlayScreenState extends State<KidMathPlayScreen> {
  List<MathTaskRow> _tasks = [];
  int _index = 0;
  int _pending = 0;
  bool _loading = true;
  final _answer = TextEditingController();
  int _rate = 1;
  String? _folderTitle;
  int? _overlayGold;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ctx = await MathTasksService.loadKidVisibilityContext(widget.kidId);
    final folderById = ctx.folderById;
    if (!MathTasksService.kidHasAccessToFolder(
      folderId: widget.folderId,
      assignedFolderIds: ctx.assigned,
      folderById: folderById,
    )) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Denne mappe er ikke til dig.')),
        );
        context.pop();
      }
      return;
    }
    final tasks = await MathTasksService.fetchTasks(widget.folderId);
    final prog = await MathTasksService.fetchProgress(
      kidId: widget.kidId,
      folderId: widget.folderId,
    );
    final rate = MathTasksService.effectiveGoldPerTask(widget.folderId, folderById);
    final title = folderById[widget.folderId]?['title'] as String? ?? 'Opgaver';
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _index = prog.nextIndex.clamp(0, tasks.isEmpty ? 0 : tasks.length);
      _pending = prog.pendingGold;
      _rate = rate;
      _folderTitle = title;
      _loading = false;
      _answer.clear();
    });
  }

  Future<void> _submitAnswer() async {
    if (_tasks.isEmpty || _index >= _tasks.length) return;
    final task = _tasks[_index];
    final expected = task['answer'] as String? ?? '';
    if (!mathAnswersMatch(expected, _answer.text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ikke helt rigtig – prøv igen!')),
        );
      }
      return;
    }
    final nextIdx = _index + 1;
    final nextPending = _pending + 1;
    await MathTasksService.saveProgress(
      kidId: widget.kidId,
      folderId: widget.folderId,
      nextTaskIndex: nextIdx,
      pendingGoldTasks: nextPending,
    );
    if (!mounted) return;
    setState(() {
      _index = nextIdx;
      _pending = nextPending;
      _answer.clear();
    });
  }

  Future<void> _settle() async {
    if (_pending <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Du har ingen nye rigtige svar at hente guld for. Tryk på opgaver først.')),
        );
      }
      return;
    }
    final amount = await MathTasksService.settlePendingGold(
      kidId: widget.kidId,
      folderId: widget.folderId,
      pendingCount: _pending,
      coinsPerTask: _rate,
    );
    if (!mounted) return;
    setState(() {
      _pending = 0;
      _overlayGold = amount;
    });
  }

  Future<void> _restart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Starte forfra?'),
        content: const Text(
          'Fremskridt og ulønnet guldmønter for rigtige svar i denne mappe nulstilles.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuller')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Forfra'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await MathTasksService.resetProgress(
      kidId: widget.kidId,
      folderId: widget.folderId,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Matematik')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final done = _tasks.isNotEmpty && _index >= _tasks.length;
    final task = (!done && _tasks.isNotEmpty) ? _tasks[_index] : null;
    final prompt = task?['prompt'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(_folderTitle ?? 'Matematik'),
        backgroundColor: const Color(0xFF1B4D3E),
        foregroundColor: Colors.white,
        leading: KidSessionNavButton(
          kidId: widget.kidId,
          isHome: false,
          fallbackLocation: '/kid/math/${widget.kidId}/folder/${widget.folderId}',
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$_rate guldmønter pr. rigtig svar når du trykker Afslut',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                if (_pending > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Ulønnet: $_pending rigtige ($_pending × $_rate = ${_pending * _rate} guld ved Afslut)',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF8B4513)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 16),
                if (_tasks.isEmpty)
                  const Expanded(
                    child: Center(child: Text('Ingen opgaver i denne mappe.')),
                  )
                else if (done)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.celebration, size: 64, color: Color(0xFFF9C433)),
                          const SizedBox(height: 12),
                          const Text(
                            'Du har løst alle opgaver i mappen!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _pending > 0
                                ? 'Husk Afslut for at få $_pending × $_rate guldmønter.'
                                : 'Tryk Afslut hvis du er færdig.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Opgave ${_index + 1} af ${_tasks.length}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Text(
                              '$prompt = ?',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _answer,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: 'Dit svar',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _submitAnswer(),
                            textInputAction: TextInputAction.done,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _submitAnswer,
                            icon: const Icon(Icons.check),
                            label: const Text('Tjek svar'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _restart,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          side: const BorderSide(color: Color(0xFF5A1A0D), width: 2),
                        ),
                        child: const Text(
                          'FORFRA',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _settle,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          backgroundColor: const Color(0xFFF9C433),
                          foregroundColor: Colors.black87,
                        ),
                        child: const Text(
                          'Afslut og hent guld',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_overlayGold != null && _overlayGold! > 0)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() => _overlayGold = null);
                  context.go('/kid/math/${widget.kidId}/folder/${widget.folderId}');
                },
                child: GoldCoinsEarnedOverlay(amount: _overlayGold!),
              ),
            ),
        ],
      ),
    );
  }
}
