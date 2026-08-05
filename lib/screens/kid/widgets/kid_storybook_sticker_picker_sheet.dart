import 'package:flutter/material.dart';

import '../../../models/kid_storybook_page_decoration.dart';
import '../../../widgets/kid_storybook_decoration.dart';

/// Bundark med faner: **Ikoner** / **Figurer** (Book Creator-lignende).
class KidStorybookStickerPickerSheet extends StatefulWidget {
  const KidStorybookStickerPickerSheet({super.key});

  @override
  State<KidStorybookStickerPickerSheet> createState() =>
      _KidStorybookStickerPickerSheetState();
}

class _KidStorybookStickerPickerSheetState
    extends State<KidStorybookStickerPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabC;
  String _search = '';
  final _searchC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabC = TabController(length: 2, vsync: this);
    _searchC.addListener(() {
      setState(() => _search = _searchC.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabC.dispose();
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabC,
              labelColor: const Color(0xFF1565C0),
              tabs: const [
                Tab(
                  child: Text(
                    'IKONER',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                Tab(
                  child: Text(
                    'FIGURER',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.5,
              child: TabBarView(
                controller: _tabC,
                children: [
                  _IconsTab(
                    search: _search,
                    searchController: _searchC,
                  ),
                  const _FiguresTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconsTab extends StatelessWidget {
  const _IconsTab({
    required this.search,
    required this.searchController,
  });

  final String search;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final list = search.isEmpty
        ? kidStorybookIconCatalog
        : kidStorybookIconCatalog
            .where(
              (e) =>
                  e.label.contains(search) ||
                  e.id.toLowerCase().contains(search),
            )
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: 'Søg efter ikoner…',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final e = list[i];
              return Material(
                color: const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(
                      context,
                      KidStorybookPageDecoration(
                        kind: KidStorybookPageDecoration.kKindIcon,
                        id: e.id,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(e.icon, size: 32, color: Colors.black87),
                      const SizedBox(height: 4),
                      Text(
                        e.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FiguresTab extends StatelessWidget {
  const _FiguresTab();

  @override
  Widget build(BuildContext context) {
    final list = kidStorybookShapeCatalog;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final e = list[i];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          elevation: 1,
          child: InkWell(
            onTap: () {
              Navigator.pop(
                context,
                KidStorybookPageDecoration(
                  kind: KidStorybookPageDecoration.kKindShape,
                  id: e.id,
                  colorValue: e.color.toARGB32(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 40,
                  child: Center(
                    child: kidStorybookDecorationContent(
                      KidStorybookPageDecoration(
                        kind: KidStorybookPageDecoration.kKindShape,
                        id: e.id,
                        colorValue: e.color.toARGB32(),
                      ),
                      baseSize: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  e.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
