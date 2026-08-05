import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/kid_storybook_service.dart';
import '../../utils/read_file_bytes_stub.dart'
    if (dart.library.io) '../../utils/read_file_bytes_io.dart' as file_reader;
import '../../widgets/admin/admin_menu_toolbar_button.dart';
import '../../widgets/asset_or_network_image.dart';

/// Admin uploader ekstra Alfamon-billeder til børne-bogbyggeren.
class AdminBookBuilderAlfamonImagesScreen extends StatefulWidget {
  const AdminBookBuilderAlfamonImagesScreen({super.key});

  @override
  State<AdminBookBuilderAlfamonImagesScreen> createState() =>
      _AdminBookBuilderAlfamonImagesScreenState();
}

class _AdminBookBuilderAlfamonImagesScreenState
    extends State<AdminBookBuilderAlfamonImagesScreen> {
  List<Map<String, dynamic>> _avatars = [];
  String? _selId;
  bool _loading = true;
  bool _uploading = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final a = await KidStorybookService.listAvatars();
      if (mounted) {
        setState(() {
          _avatars = a;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _upload() async {
    if (_selId == null) return;
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp',
      ],
      allowMultiple: false,
      withData: true,
    );
    if (pick == null || pick.files.isEmpty) return;
    final f = pick.files.single;
    var b = f.bytes ?? <int>[];
    if (b.isEmpty && f.path != null) {
      try {
        b = await file_reader.readFileBytes(f.path!);
      } catch (_) {
        b = <int>[];
      }
    }
    if (b.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kunne ikke læse filen.')),
        );
      }
      return;
    }
    setState(() => _uploading = true);
    try {
      await BookBuilderAlfamonImageService.addExtraForAvatar(
        _selId!,
        f.name,
        b,
        filePath: f.path,
      );
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Billede uploadet.')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fejl: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bogbygger – Alfamon-billeder'),
        backgroundColor: const Color(0xFF5A1A0D),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _uploading ? null : () => context.pop(),
        ),
        actions: const [AdminAppBarMenuAndLogout()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_err!, textAlign: TextAlign.center),
                  ),
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 220,
                      child: ListView(
                        children: _avatars
                            .map(
                              (a) => ListTile(
                                title: Text(a['name'] as String? ?? ''),
                                selected: _selId == a['id'],
                                onTap: () =>
                                    setState(() => _selId = a['id'] as String),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _selId == null
                          ? const Center(
                              child: Text('Vælg en Alfamon til venstre.'),
                            )
                          : _ExtrasPanel(
                              avatarId: _selId!,
                              onUpload: _uploading ? null : _upload,
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _ExtrasPanel extends StatefulWidget {
  const _ExtrasPanel({required this.avatarId, this.onUpload});

  final String avatarId;
  final VoidCallback? onUpload;

  @override
  State<_ExtrasPanel> createState() => _ExtrasPanelState();
}

class _ExtrasPanelState extends State<_ExtrasPanel> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ExtrasPanel old) {
    super.didUpdateWidget(old);
    if (old.avatarId != widget.avatarId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _rows = await BookBuilderAlfamonImageService.listExtras(widget.avatarId);
    } catch (_) {
      _rows = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: widget.onUpload,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
            icon: const Icon(Icons.upload),
            label: const Text('Upload billede til denne Alfamon'),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? const Center(
                      child: Text(
                        'Ingen ekstra endnu. Børn ser stadig udviklings-billeder fra avataren. '
                        'Tryk «Upload» for at tilføje flere i bogbyggeren.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: _rows.length,
                      itemBuilder: (ctx, i) {
                        final u = _rows[i]['image_url'] as String? ?? '';
                        final id = _rows[i]['id'] as String;
                        return Card(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: AssetOrNetworkImage(
                                    src: u,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton(
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('Slet billede?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('Annuller'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('Slet'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true && mounted) {
                                      await BookBuilderAlfamonImageService
                                          .deleteExtra(id);
                                      await _load();
                                    }
                                  },
                                  icon: const Icon(Icons.close, color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
