import 'package:flutter/material.dart';

import '../../data/task_emoji_library.dart';

/// Viser emoji-bibliotek. Returnerer:
/// - `null` hvis brugeren lukker uden valg
/// - `''` for at fjerne emoji
/// - ellers det valgte tegn
Future<String?> showTaskEmojiPickerSheet(
  BuildContext context, {
  String? currentEmoji,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return _TaskEmojiPickerBody(currentEmoji: currentEmoji);
    },
  );
}

class _TaskEmojiPickerBody extends StatefulWidget {
  const _TaskEmojiPickerBody({this.currentEmoji});

  final String? currentEmoji;

  @override
  State<_TaskEmojiPickerBody> createState() => _TaskEmojiPickerBodyState();
}

class _TaskEmojiPickerBodyState extends State<_TaskEmojiPickerBody> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<TaskEmojiCategory> get _filteredCategories {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return kTaskEmojiCategories;
    return kTaskEmojiCategories
        .where((c) => c.title.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height * 0.88;

    return SizedBox(
      height: h + bottom,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Vælg emoji til opgaven',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (widget.currentEmoji != null &&
                widget.currentEmoji!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Nuværende: '),
                    Text(
                      widget.currentEmoji!.trim(),
                      style: const TextStyle(fontSize: 28),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Søg efter kategori (fx mad, skole, dyr)…',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, ''),
                icon: const Icon(Icons.clear),
                label: const Text('Ingen emoji (standard på barnets skærm)'),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _filteredCategories.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Ingen kategorier matcher «$_query».\nPrøv et andet søgeord eller ryd søgning.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _filteredCategories.length,
                      itemBuilder: (context, i) {
                        final cat = _filteredCategories[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: cat.emojis.map((emoji) {
                                  return Material(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                      onTap: () =>
                                          Navigator.pop(context, emoji),
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: Center(
                                          child: Text(
                                            emoji,
                                            style: const TextStyle(
                                              fontSize: 28,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
