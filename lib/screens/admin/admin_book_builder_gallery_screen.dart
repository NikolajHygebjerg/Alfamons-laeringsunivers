import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/book_builder_gallery_service.dart';
import '../../services/kid_storybook_service.dart';
import '../../widgets/admin/admin_menu_toolbar_button.dart';
import '../../widgets/asset_or_network_image.dart';

/// Intern billedbank: bundt-assets + tildeling til Alfamon. Kun [BookBuilderGalleryService.kAdminEmail].
class AdminBookBuilderGalleryScreen extends StatefulWidget {
  const AdminBookBuilderGalleryScreen({super.key});

  @override
  State<AdminBookBuilderGalleryScreen> createState() =>
      _AdminBookBuilderGalleryScreenState();
}

class _AdminBookBuilderGalleryScreenState
    extends State<AdminBookBuilderGalleryScreen> {
  List<String> _allPaths = [];
  final Map<String, String?> _pathToAvatarId = {};
  List<Map<String, dynamic>> _avatars = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;
  String _q = '';
  /// Flere tildelinger: markér stier, derefter én fælles tildeling.
  bool _selectMode = false;
  final Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email?.trim() ?? '';
    final canEdit = email == BookBuilderGalleryService.kAdminEmail;

    if (!canEdit) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Billedbibliotek'),
          backgroundColor: const Color(0xFF5A1A0D),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          actions: const [AdminAppBarMenuAndLogout()],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Kun for den konto, der er sat op til dette værktøj.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billedbibliotek → Alfamon'),
        backgroundColor: const Color(0xFF5A1A0D),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_selectMode ? Icons.close : Icons.checklist),
            tooltip: _selectMode ? 'Luk vælgetilstand' : 'Vælg flere',
            onPressed: _saving
                ? null
                : () {
                    setState(() {
                      if (_selectMode) {
                        _selectMode = false;
                        _selectedPaths.clear();
                      } else {
                        _selectMode = true;
                      }
                    });
                  },
          ),
          const AdminAppBarMenuAndLogout(),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Søg i sti / filnavn',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          if (_selectMode)
            Material(
              elevation: 8,
              color: const Color(0xFFEDE8E2),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        '${_selectedPaths.length} valgt',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () {
                                final vis = _visiblePaths.toSet();
                                setState(() {
                                  for (final p in vis) {
                                    _selectedPaths.add(p);
                                  }
                                });
                              },
                        child: const Text('Vælg synlige'),
                      ),
                      FilledButton(
                        onPressed: _saving || _selectedPaths.isEmpty
                            ? null
                            : () => unawaited(_onAssignSelected()),
                        child: const Text('Tildel til Alfamon'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final a = await KidStorybookService.listAvatars();
      final paths = await BookBuilderGalleryService.listBundledImageAssetKeys();
      final rows = await BookBuilderGalleryService.fetchAllAssignments();
      final map = <String, String?>{};
      for (final r in rows) {
        final p = (r['asset_path'] as String? ?? '').trim();
        if (p.isEmpty) continue;
        final id = (r['avatar_id'] as String?)?.trim();
        map[p] = (id == null || id.isEmpty) ? null : id;
      }
      if (mounted) {
        setState(() {
          _avatars = a;
          _allPaths = paths;
          _pathToAvatarId
            ..clear()
            ..addAll(map);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  List<String> get _visiblePaths {
    if (_q.isEmpty) return _allPaths;
    return _allPaths.where((p) => p.toLowerCase().contains(_q)).toList();
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Fejl: $_error', textAlign: TextAlign.center),
        ),
      );
    }
    if (_allPaths.isEmpty) {
      return const Center(
        child: Text('Ingen bundtede billeder i AssetManifest (tjek pubspec).'),
      );
    }
    final v = _visiblePaths;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: v.length,
      itemBuilder: (context, i) {
        final p = v[i];
        return _cell(p);
      },
    );
  }

  Widget _cell(String p) {
    final assigned = _pathToAvatarId[p];
    var titleText = '— ikke tildelt —';
    if (assigned != null) {
      var found = false;
      for (final a in _avatars) {
        if (a['id'] == assigned) {
          titleText = a['name'] as String? ?? assigned;
          found = true;
          break;
        }
      }
      if (!found) {
        titleText = assigned;
      }
    }
    final isSel = _selectedPaths.contains(p);
    return Material(
      color: const Color(0xFFF2F0ED),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: _selectMode && isSel
            ? const BorderSide(color: Color(0xFF4A148C), width: 2.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _saving
            ? null
            : () {
                if (_selectMode) {
                  setState(() {
                    if (isSel) {
                      _selectedPaths.remove(p);
                    } else {
                      _selectedPaths.add(p);
                    }
                  });
                } else {
                  unawaited(_onPickPath(p));
                }
              },
        onLongPress: _saving
            ? null
            : _selectMode
                ? null
                : () {
                    setState(() {
                      _selectMode = true;
                      _selectedPaths.add(p);
                    });
                  },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Center(
                        child: AssetOrNetworkImage(
                          src: p,
                          width: 180,
                          height: 150,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  if (_selectMode)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSel
                              ? const Color(0xFF4A148C)
                              : Colors.white70,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 2,
                              color: Color(0x33000000),
                            ),
                          ],
                        ),
                        child: isSel
                            ? const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              )
                            : const Icon(
                                Icons.circle_outlined,
                                size: 18,
                                color: Colors.black45,
                              ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _pathToAvatarId[p] != null
                          ? const Color(0xFF4A148C)
                          : Colors.black54,
                    ),
                  ),
                  Text(
                    p,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onPickPath(String path) async {
    if (!mounted) return;
    var sel = _pathToAvatarId[path];
    final firstId = _avatars.isEmpty
        ? null
        : (_avatars.first['id'] as String?);
    if (sel == null && firstId != null) {
      sel = firstId;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              title: const Text('Tildel til Alfamon'),
              content: SizedBox(
                width: 400,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Alfamon',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButton<String?>(
                    value: sel,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('(ingen / fjern)'),
                      ),
                      ..._avatars.map(
                        (a) => DropdownMenuItem<String?>(
                          value: a['id'] as String?,
                          child: Text(a['name'] as String? ?? '?'),
                        ),
                      ),
                    ],
                    onChanged: (v) => setSt(() => sel = v),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuller'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Gem'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await BookBuilderGalleryService.setAssignmentForAssetPath(
        assetPath: path,
        avatarId: sel,
      );
      if (sel == null) {
        _pathToAvatarId.remove(path);
      } else {
        _pathToAvatarId[path] = sel;
      }
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tilknytning gemt.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kunne ikke gemme: $e')),
        );
      }
    }
  }

  Future<void> _onAssignSelected() async {
    if (!mounted || _selectedPaths.isEmpty) return;
    final paths = _selectedPaths.toList();
    var sel = _pathToAvatarId[paths.first];
    final firstId =
        _avatars.isEmpty ? null : (_avatars.first['id'] as String?);
    if (sel == null && firstId != null) {
      sel = firstId;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              title: Text(
                'Tildel ${paths.length} ${paths.length == 1 ? 'billede' : 'billeder'} til Alfamon',
              ),
              content: SizedBox(
                width: 400,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Alfamon',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButton<String?>(
                    value: sel,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('(ingen / fjern)'),
                      ),
                      ..._avatars.map(
                        (a) => DropdownMenuItem<String?>(
                          value: a['id'] as String?,
                          child: Text(a['name'] as String? ?? '?'),
                        ),
                      ),
                    ],
                    onChanged: (v) => setSt(() => sel = v),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuller'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Gem til alle'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    var nOk = 0;
    Object? firstErr;
    for (final path in paths) {
      try {
        await BookBuilderGalleryService.setAssignmentForAssetPath(
          assetPath: path,
          avatarId: sel,
        );
        if (sel == null) {
          _pathToAvatarId.remove(path);
        } else {
          _pathToAvatarId[path] = sel;
        }
        nOk++;
      } catch (e) {
        firstErr = e;
        break;
      }
    }
    if (mounted) {
      setState(() {
        _saving = false;
        if (firstErr == null) {
          _selectMode = false;
          _selectedPaths.clear();
        }
      });
      if (firstErr == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nOk == 1
                  ? 'Tilknytning gemt.'
                  : 'Tilknytning gemt for $nOk billeder.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunne ikke gemme efter $nOk: $firstErr'),
          ),
        );
      }
    }
  }
}
