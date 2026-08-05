import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../models/kid_storybook_page_decoration.dart';
import '../../models/kid_storybook_page_format.dart';
import '../../models/kid_storybook_page_item.dart';
import '../../models/kid_storybook_page_layout.dart';
import '../../services/kid_storybook_service.dart';
import '../../utils/alfamon_display_name.dart';
import '../../widgets/kid_storybook_decoration.dart';
import '../../widgets/asset_or_network_image.dart';
import '../../utils/read_file_bytes_stub.dart'
    if (dart.library.io) '../../utils/read_file_bytes_io.dart'
    as file_reader;
import '../../widgets/kid_parent_admin_corner.dart';
import 'kid_layout_constants.dart';
import 'widgets/alfamon_storybook_letter_picker.dart';
import 'widgets/kid_library_cabinet_shelf.dart';
import 'widgets/kid_session_nav_button.dart';
import 'widgets/kid_storybook_sticker_picker_sheet.dart';
import 'widgets/library_cabinet_background.dart';

/// iPadOS: uden fokus + næste frame for pop kan [TextField] i en dialog
/// ramme `dependents.isEmpty: is not true` når ruten stables ned for tidligt.
void _closeInputDialog<T>(BuildContext dialogContext, [T? result]) {
  FocusManager.instance.primaryFocus?.unfocus();
  final nav = Navigator.of(dialogContext, rootNavigator: true);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!nav.mounted) return;
    nav.pop<T>(result);
  });
}

/// Lille sletning af billede, tekst eller figur.
class _StorybookItemCloseButton extends StatelessWidget {
  const _StorybookItemCloseButton({
    required this.onPressed,
    required this.semanticLabel,
  });

  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(Icons.close, size: 18, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}

/// Fuldskærms-baggrund i bogbyggeren — læg filen i `assets/`.
const String kBogbyggerBackgroundAsset = 'assets/bogbygger_baggrund.png';

/// Reference-billede til valg af format (ny bog) — læg filen i `assets/`.
const String kBogbyggerFormatReferenceAsset = 'assets/bogbygger_format.png';

/// Indre reference-størrelse til [kBogbyggerFormatReferenceAsset] (usynlige knapper skalerer med [FittedBox]).
const double _kBogbyggerFormatRefW = 900;
const double _kBogbyggerFormatRefH = 520;

const Color _kBogbyggerEditorWorkspace = Color(0xFFBAC8D2);

// Bogbygger-lyd (læg MP3'er i assets/)
const String _kBogbyggerSfxOpen = 'assets/Bogbyggeren.mp3';
const String _kBogbyggerSfxFormat = 'assets/Bogbyggeren_format.mp3';
const String _kBogbyggerSfxForside = 'assets/Bogbyggeren_forside.mp3';

/// `kind`: `open` | `format` | `forside` — hver højst én afspilning per barn.
String _bogbyggerSfxOncePrefsKey(String kidId, String kind) =>
    'kid_${kidId}_storybook_bogbygger_sfx_$kind';

String _parseFontKey(String? raw) {
  final s = (raw ?? 'sans').toLowerCase().trim();
  if (s == 'serif' || s == 'mono' || s == 'system') return s;
  return 'sans';
}

/// Tre lige søjler over billedet = de tre bøger (virker når asset ikke fylder 900×520).
Widget _bogbyggerFormatBigImageWithInvisibleButtons({
  required bool enabled,
  required void Function(KidStorybookPageFormat) onPicked,
}) {
  void pick(KidStorybookPageFormat f) {
    if (!enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => onPicked(f));
  }

  return Center(
    child: FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: _kBogbyggerFormatRefW,
        height: _kBogbyggerFormatRefH,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                kBogbyggerFormatReferenceAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: Colors.brown.shade200,
                  child: const Center(
                    child: Text(
                      'Mangler assets/bogbygger_format.png',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF3E2723)),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _FormatTapColumn(
                    label: KidStorybookPageFormat.portrait.displayLabelDanish,
                    onPick: () => pick(KidStorybookPageFormat.portrait),
                    enabled: enabled,
                  ),
                ),
                Expanded(
                  child: _FormatTapColumn(
                    label: KidStorybookPageFormat.landscape.displayLabelDanish,
                    onPick: () => pick(KidStorybookPageFormat.landscape),
                    enabled: enabled,
                  ),
                ),
                Expanded(
                  child: _FormatTapColumn(
                    label: KidStorybookPageFormat.square.displayLabelDanish,
                    onPick: () => pick(KidStorybookPageFormat.square),
                    enabled: enabled,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _FormatTapColumn extends StatelessWidget {
  const _FormatTapColumn({
    required this.label,
    required this.onPick,
    required this.enabled,
  });

  final String label;
  final VoidCallback onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? onPick : null,
          splashColor: const Color(0x33FFFFFF),
          highlightColor: const Color(0x18FFFFFF),
          // Opaque hit — vigtigt når man trykker «mellem» bog og kant
          child: const ColoredBox(color: Color(0x00000000)),
        ),
      ),
    );
  }
}

/// Barn bygger egen bog (Book Creator-stil: sider, hvidt lærred, pile).
class KidStorybookBuilderScreen extends StatefulWidget {
  const KidStorybookBuilderScreen({
    super.key,
    required this.kidId,
    this.existingBookId,
  });

  final String kidId;
  final String? existingBookId;

  @override
  State<KidStorybookBuilderScreen> createState() =>
      _KidStorybookBuilderScreenState();
}

class _KidStorybookBuilderScreenState extends State<KidStorybookBuilderScreen> {
  final _titleController = TextEditingController(text: 'Min bog');

  /// Forsinket autogem (layout + tekst) uden at forlade redigeringsvisningen.
  Timer? _autoSaveDebounce;
  stt.SpeechToText? _speech;
  bool _sttInit = false;
  bool _sttAvailable = false;
  int _currentPageIndex = 0;

  String? _bookId;
  List<_SpreadDraft> _spreads = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  /// `true` = startskærm med hylder; `false` = redigering.
  bool _libraryPhase = true;
  List<Map<String, dynamic>> _builderShelfItems = [];
  bool _builderLibraryLoading = true;

  /// Efter + : kun format-billedet, derefter sprednings-dialog.
  bool _newBookFormatPhase = false;

  KidStorybookPageFormat? _pageFormat;

  /// Synlig i hovedbiblioteket — ellers kun her i bogbyggeren.
  bool _publishedToLibrary = false;

  late final AudioPlayer _bogbyggerSfx;
  bool _bogbyggerSfxInited = false;

  @override
  void initState() {
    super.initState();
    _bogbyggerSfx = AudioPlayer();
    unawaited(_bootstrapBogbyggerScreen());
    // Tale-til-tekst: plugin initialiserer native STT, som kan crashe på
    // macOS/skrivebord (uafhængigt af try/catch). Brug kun på mobil.
    if (_platformSupportsStorybookSpeech) {
      unawaited(_initSpeech());
    }
  }

  /// SFX-initialisering færdig før indlæsning af bøger, så [play] fungerer pålideligt.
  Future<void> _bootstrapBogbyggerScreen() async {
    if (widget.existingBookId != null) {
      _libraryPhase = false;
    } else {
      _libraryPhase = true;
      _loading = false;
    }
    await _initBogbyggerSfx();
    if (!mounted) return;
    if (widget.existingBookId != null) {
      await _loadExisting(widget.existingBookId!);
    } else {
      await _loadBuilderLibrary();
    }
  }

  static bool get _platformSupportsStorybookSpeech {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    unawaited(_bogbyggerSfx.dispose());
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _initBogbyggerSfx() async {
    if (_bogbyggerSfxInited) return;
    _bogbyggerSfxInited = true;
    try {
      _bogbyggerSfx.audioCache.prefix = '';
      // mediaPlayer: større buffer end lowLatency – hele taledelen i MP3 (ikke SFX-klip).
      await _bogbyggerSfx.setPlayerMode(PlayerMode.mediaPlayer);
      await _bogbyggerSfx.setReleaseMode(ReleaseMode.stop);
      await _bogbyggerSfx.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Bogbygger SFX init: $e');
      }
    }
  }

  /// Altid [stop] + [play(AssetSource)] med mediaPlayer; seek/resume efter
  /// forvarmet setSource giver ofte forsnævret start/klippet slut på længere MP3'er.
  Future<void> _playBogbyggerSfx(String asset) async {
    try {
      await _initBogbyggerSfx();
      await _bogbyggerSfx.setVolume(1);
      await _bogbyggerSfx.stop();
      await _bogbyggerSfx.play(AssetSource(asset));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Bogbygger SFX: $e ($asset)');
      }
    }
  }

  /// Afspil bogbygger-SFX højst én gang per [widget.kidId] (persistent).
  Future<void> _playBogbyggerSfxOncePerKid(String asset, String kind) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _bogbyggerSfxOncePrefsKey(widget.kidId, kind);
      if (prefs.getBool(key) == true) return;
      await _playBogbyggerSfx(asset);
      await prefs.setBool(key, true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Bogbygger SFX once: $e');
      }
    }
  }

  void _playBogbyggerForsideIfEditor() {
    if (!mounted) return;
    if (_libraryPhase || _loading) return;
    if (_spreads.isEmpty) return;
    if (_currentPageIndex != 0) return;
    unawaited(_playBogbyggerSfxOncePerKid(_kBogbyggerSfxForside, 'forside'));
  }

  void _onDraftContentChanged() {
    if (!mounted || _bookId == null) return;
    if (_spreads.isEmpty) return;
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(_autoSaveBookQuietly());
    });
  }

  Future<void> _autoSaveBookQuietly() async {
    if (!mounted || _bookId == null) return;
    if (_spreads.isEmpty) return;
    if (_saving) return;
    try {
      await KidStorybookService.saveFullBook(
        bookId: _bookId!,
        title: _effectiveBookTitle(),
        pages: _pagesPayload(),
      );
    } catch (e) {
      debugPrint('KidStorybook auto-save: $e');
    }
  }

  TextStyle _textStyleForItem(KidStorybookPageItem it) {
    final size = (it.textFontSize ?? 24).clamp(8.0, 300.0);
    return TextStyle(
      fontSize: size,
      height: 1.35,
      color: Colors.black87,
      fontFamily: switch ((it.textFontKey ?? 'sans').toLowerCase().trim()) {
        'serif' => 'serif',
        'mono' => 'monospace',
        'system' => null,
        _ => null,
      },
    );
  }

  Future<void> _initSpeech() async {
    final s = stt.SpeechToText();
    try {
      _sttInit = await s.initialize();
    } catch (e, st) {
      debugPrint('KidStorybookBuilder: speech init fejlede: $e\n$st');
      if (!mounted) return;
      setState(() {
        _speech = null;
        _sttInit = false;
        _sttAvailable = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _speech = s;
      _sttAvailable = _sttInit;
    });
  }

  Future<void> _loadExisting(String id) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await KidStorybookService.loadKidBookWithPages(id);
      if (data == null) {
        if (mounted) {
          setState(() {
            _error = 'Bogen findes ikke';
            _loading = false;
          });
        }
        return;
      }
      final book = data['book']! as Map<String, dynamic>;
      final pages = List<Map<String, dynamic>>.from(
        data['pages']! as List<dynamic>,
      );
      int spreadIxFromRow(Map<String, dynamic> p) {
        final v = p['spread_index'];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          return int.tryParse(v.trim()) ?? 0;
        }
        return 0;
      }

      pages.sort((a, b) {
        return spreadIxFromRow(a).compareTo(spreadIxFromRow(b));
      });
      _bookId = book['id'] as String;
      _publishedToLibrary = book['published_to_library'] == true;
      _titleController.text = (book['title'] as String?)?.trim() ?? 'Min bog';
      _pageFormat = KidStorybookPageFormatX.fromDb(
        book['page_format'] as String?,
      );
      _spreads = pages
          .map(
            (p) => _SpreadDraft(
              dbId: p['id'] as String?,
              items: KidStorybookPageItem.fromStoredPage(
                pageLayoutRaw: p['page_layout'],
                leftText: p['left_text'] as String? ?? '',
                rightImageUrl: p['right_image_url'] as String?,
                textFontSize: (p['text_font_size'] as num?)?.toDouble(),
                textFontKey: _parseFontKey(p['text_font_key'] as String?),
              ),
            ),
          )
          .toList();
      _currentPageIndex = 0;
      if (mounted) {
        setState(() => _loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _playBogbyggerForsideIfEditor();
          }
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

  Future<void> _loadBuilderLibrary() async {
    if (!mounted) return;
    if (widget.existingBookId == null) {
      unawaited(_playBogbyggerSfxOncePerKid(_kBogbyggerSfxOpen, 'open'));
    }
    if (!mounted) return;
    setState(() {
      _builderLibraryLoading = true;
    });
    try {
      final list = await KidStorybookService.listKidBooksForCabinet(
        widget.kidId,
      );
      if (mounted) {
        setState(() {
          _builderShelfItems = list;
          _builderLibraryLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _builderShelfItems = [];
          _builderLibraryLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kunne ikke hente bøger: $e')));
      }
    }
  }

  void _goToBuilderLibrary() {
    if (!mounted) return;
    setState(() {
      _libraryPhase = true;
      _newBookFormatPhase = false;
      _bookId = null;
      _spreads = [];
      _error = null;
      _loading = false;
      _titleController.text = 'Min bog';
      _pageFormat = null;
      _currentPageIndex = 0;
    });
    unawaited(_loadBuilderLibrary());
  }

  void _openEditorForBookId(String id) {
    if (!mounted) return;
    setState(() {
      _newBookFormatPhase = false;
      _libraryPhase = false;
      _loading = true;
      _error = null;
    });
    unawaited(_loadExisting(id));
  }

  void _onTapNewBook() {
    if (!mounted) return;
    setState(() => _newBookFormatPhase = true);
    unawaited(_playBogbyggerSfxOncePerKid(_kBogbyggerSfxFormat, 'format'));
  }

  Future<void> _onNewBookFormatPicked(KidStorybookPageFormat format) async {
    if (!mounted) return;
    setState(() => _newBookFormatPhase = false);
    await _createNewBookWithDefaultOnePage(format);
  }

  Future<void> _createNewBookWithDefaultOnePage(
    KidStorybookPageFormat format,
  ) async {
    if (!mounted) return;
    setState(() {
      _libraryPhase = false;
      _loading = true;
      _error = null;
      _pageFormat = format;
      _currentPageIndex = 0;
    });
    final parent = await KidStorybookService.parentProfileId();
    if (parent == null) {
      if (mounted) {
        setState(() {
          _error = 'Kunne ikke finde forældre-profil. Log ind igen.';
          _loading = false;
        });
      }
      return;
    }
    final title = _titleController.text.trim();
    final t = title.isEmpty ? 'Min bog' : title;
    try {
      _bookId = await KidStorybookService.createEmptyBook(
        kidId: widget.kidId,
        parentId: parent,
        title: t,
        spreadCount: 1,
        pageFormat: format,
      );
      _titleController.text = t;
      await _loadExisting(_bookId!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  String _effectiveBookTitle() {
    final t = _titleController.text.trim();
    return t.isEmpty ? 'Min bog' : t;
  }

  List<Map<String, dynamic>> _pagesPayload() {
    return _spreads
        .map(
          (s) => {
            'left_text': KidStorybookPageItem.joinedText(s.items),
            'right_image_url': KidStorybookPageItem.firstImageUrl(s.items),
            'text_font_size': KidStorybookPageItem.firstTextFontSize(s.items),
            'text_font_key': KidStorybookPageItem.firstTextFontKey(s.items),
            'page_layout': KidStorybookPageItem.pageLayoutV2Json(s.items),
          },
        )
        .toList();
  }

  /// Udgiv i barnets hovedbibliotek (guldmønter ved gennemlæsning som andre bøger).
  /// Første gang markér som udgivet; hvis bogen allerede er udgivet, gemmer vi og opdaterer bibliotekskopien.
  Future<void> _publishToLibrary() async {
    if (_bookId == null) return;
    if (_spreads.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tilføj mindst en side.')));
      return;
    }
    final wasAlreadyPublished = _publishedToLibrary;
    setState(() => _saving = true);
    try {
      await KidStorybookService.saveFullBook(
        bookId: _bookId!,
        title: _effectiveBookTitle(),
        pages: _pagesPayload(),
      );
      await publishKidBookToLibrary(bookId: _bookId!, kidId: widget.kidId);
      if (mounted) {
        setState(() {
          _saving = false;
          _publishedToLibrary = true;
        });
        final msg = wasAlreadyPublished
            ? 'Bogen i dit bibliotek er opdateret.'
            : 'Bogen er udgivet! Den ligger i dit bibliotek — du kan få guldmønter når du læser den færdig.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kunne ikke udgive: $e')));
      }
    }
  }

  /// Gem og gå til bibliotek (fx efter «Gem min bog»).
  Future<void> _saveToLibrary() async {
    if (_bookId == null) return;
    if (_spreads.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tilføj mindst en side.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await KidStorybookService.saveFullBook(
        bookId: _bookId!,
        title: _effectiveBookTitle(),
        pages: _pagesPayload(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bogen er gemt. Den ligger i bogbyggerens bibliotek.',
            ),
          ),
        );
        setState(() => _saving = false);
        _goToBuilderLibrary();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kunne ikke gemme: $e')));
      }
    }
  }

  /// Automatisk gem når barnet går tilbage til biblioteket (tilbage-knap / system-back).
  Future<void> _leaveEditorSavingFirst() async {
    if (!mounted) return;
    if (_saving) return;
    if (_bookId == null) {
      _goToBuilderLibrary();
      return;
    }
    if (_spreads.isEmpty) {
      _goToBuilderLibrary();
      return;
    }
    setState(() => _saving = true);
    try {
      await KidStorybookService.saveFullBook(
        bookId: _bookId!,
        title: _effectiveBookTitle(),
        pages: _pagesPayload(),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kunne ikke gemme: $e')));
      }
      return;
    }
    if (mounted) {
      setState(() => _saving = false);
      _goToBuilderLibrary();
    }
  }

  Future<void> _confirmDeleteBuilderBook(Map<String, dynamic> book) async {
    final id = book['id'] as String;
    final title = (book['title'] as String? ?? 'Bog').trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Slet bog?'),
        content: Text(
          'Vil du slette «${title.isEmpty ? 'uden titel' : title}»? Det kan ikke fortrydes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Slet'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _builderLibraryLoading = true);
    try {
      await KidStorybookService.deleteKidBook(bookId: id, kidId: widget.kidId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('«$title» er slettet.')));
        await _loadBuilderLibrary();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kunne ikke slette: $e')));
        setState(() => _builderLibraryLoading = false);
      }
    }
  }

  Future<void> _printBook() async {
    if (_spreads.isEmpty) return;
    setState(() => _saving = true);
    try {
      final pdf = await KidStorybookService.buildPrintablePdf(
        title: _effectiveBookTitle(),
        pages: _pagesPayload(),
      );
      if (mounted) {
        setState(() => _saving = false);
        await KidStorybookService.showPrintDialogForPdf(pdf);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Print: $e')));
      }
    }
  }

  Future<void> _pickUserImage(int spreadIndex) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp'],
        allowMultiple: false,
        withData: true,
        dialogTitle: 'Vælg billede',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Billedvalg: $e')));
      }
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    var bytes = f.bytes ?? <int>[];
    if (bytes.isEmpty && f.path != null) {
      try {
        bytes = await file_reader.readFileBytes(f.path!);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kunne ikke læse billedet (prøv et andet format).'),
            ),
          );
        }
        return;
      }
    }
    if (bytes.isEmpty) return;
    setState(() => _saving = true);
    try {
      final url = await KidStorybookService.uploadUserImage(
        widget.kidId,
        f.name,
        bytes,
        filePath: f.path,
      );
      if (mounted) {
        setState(() {
          _spreads[spreadIndex].items.add(
            KidStorybookPageItem(
              id: KidStorybookPageItem.newId(),
              kind: KidStorybookPageItem.kImage,
              cx: 0.5,
              cy: 0.38,
              scale: 1.0,
              imageUrl: url,
            ),
          );
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload: $e')));
      }
    }
  }

  void _onAlfamonImagePicked(int spreadIndex, String url) {
    setState(() {
      _spreads[spreadIndex].items.add(
        KidStorybookPageItem(
          id: KidStorybookPageItem.newId(),
          kind: KidStorybookPageItem.kImage,
          cx: 0.5,
          cy: 0.38,
          scale: 1.0,
          imageUrl: url,
        ),
      );
    });
  }

  void _editorPrev() {
    if (_currentPageIndex <= 0) return;
    setState(() => _currentPageIndex--);
    if (_currentPageIndex == 0) {
      _playBogbyggerForsideIfEditor();
    }
  }

  void _editorNext() {
    if (_currentPageIndex < _spreads.length - 1) {
      setState(() => _currentPageIndex++);
    } else {
      setState(() {
        _spreads.add(_SpreadDraft());
        _currentPageIndex = _spreads.length - 1;
      });
    }
  }

  bool _pageIsEmpty(_SpreadDraft d) {
    return d.items.isEmpty;
  }

  Future<void> _showTitleEditDialog() async {
    final c = TextEditingController(text: _titleController.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bogens titel'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Skriv titel',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => _closeInputDialog(ctx, false),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () => _closeInputDialog(ctx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() => _titleController.text = c.text);
    }
    c.dispose();
  }

  Future<void> _showImageSourceSheet() async {
    if (_spreads.isEmpty) return;
    final i = _currentPageIndex;
    if (i < 0 || i >= _spreads.length) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.pets,
                color: Color(0xFF6A1B9A),
                size: 32,
              ),
              title: const Text(
                'Alfamon-billeder',
                style: TextStyle(fontSize: 18),
              ),
              onTap: () => Navigator.pop(ctx, 'alfamon'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file, size: 32),
              title: const Text(
                'Upload billede',
                style: TextStyle(fontSize: 18),
              ),
              onTap: () => Navigator.pop(ctx, 'upload'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'alfamon') {
      unawaited(_openAlfamonPicker(i));
    } else if (choice == 'upload') {
      unawaited(_pickUserImage(i));
    }
  }

  Future<void> _showStickerPicker() async {
    if (_spreads.isEmpty) return;
    final i = _currentPageIndex;
    if (i < 0 || i >= _spreads.length) return;
    if (_saving) return;
    final picked = await showModalBottomSheet<KidStorybookPageDecoration>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => const KidStorybookStickerPickerSheet(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _spreads[i].items.add(
        KidStorybookPageItem(
          id: KidStorybookPageItem.newId(),
          kind: KidStorybookPageItem.kFigure,
          cx: 0.52,
          cy: 0.48,
          scale: 1.0,
          decoration: picked,
        ),
      );
    });
  }

  Future<void> _showInsertTextDialog({String? editItemId}) async {
    if (_spreads.isEmpty) return;
    final i = _currentPageIndex;
    if (i < 0 || i >= _spreads.length) return;
    final d = _spreads[i];
    KidStorybookPageItem? existing;
    if (editItemId != null) {
      for (final e in d.items) {
        if (e.id == editItemId && e.isText) {
          existing = e;
          break;
        }
      }
    }
    final textC = TextEditingController(text: existing?.text ?? '');
    double size = (existing?.textFontSize ?? 24.0).toDouble();
    if (size < 8) {
      size = 8;
    } else if (size > 300) {
      size = 300;
    }
    var key = existing?.textFontKey ?? 'sans';
    if (!const {'sans', 'system', 'serif', 'mono'}.contains(key)) {
      key = 'sans';
    }
    if (!mounted) return;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Indsæt tekst'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: textC,
                    minLines: 2,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Din tekst',
                      alignLabelWithHint: true,
                      hintText: 'Flere linjer: tryk Enter for linjeskift',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Skriftstørrelse: ${size.round()}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: size,
                    min: 8,
                    max: 300,
                    divisions: 292,
                    label: '${size.round()}',
                    onChanged: (v) => setSt(() => size = v),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Skrifttype',
                      style: Theme.of(ctx).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: key,
                    items: const [
                      DropdownMenuItem(
                        value: 'sans',
                        child: Text('Almindelig (sans)'),
                      ),
                      DropdownMenuItem(
                        value: 'system',
                        child: Text('System (maskinens)'),
                      ),
                      DropdownMenuItem(
                        value: 'serif',
                        child: Text('Med fødder (serif)'),
                      ),
                      DropdownMenuItem(
                        value: 'mono',
                        child: Text('Skrivemaskine'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setSt(() => key = v);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => _closeInputDialog(ctx, false),
                child: const Text('Annuller'),
              ),
              FilledButton(
                onPressed: () => _closeInputDialog(ctx, true),
                child: const Text('Sæt på siden'),
              ),
            ],
          );
        },
      ),
    );
    if (save == true && mounted) {
      setState(() {
        if (existing != null) {
          final ix = d.items.indexWhere((e) => e.id == existing!.id);
          if (ix >= 0) {
            d.items[ix] = d.items[ix].copyWith(
              text: textC.text,
              textFontSize: size,
              textFontKey: key,
            );
          }
        } else {
          final nTxt = d.items.where((e) => e.isText).length;
          d.items.add(
            KidStorybookPageItem(
              id: KidStorybookPageItem.newId(),
              kind: KidStorybookPageItem.kText,
              cx: 0.5,
              cy: (0.1 + 0.05 * nTxt).clamp(0.04, 0.28),
              scale: 1.0,
              text: textC.text,
              textFontSize: size,
              textFontKey: key,
            ),
          );
        }
      });
    }
    textC.dispose();
  }

  Future<void> _showSpeechToTextPanel() async {
    if (_spreads.isEmpty) return;
    final i = _currentPageIndex;
    if (i < 0 || i >= _spreads.length) return;
    if (kIsWeb || _speech == null || !_sttAvailable) {
      if (mounted) {
        final msg = kIsWeb
            ? 'Tale til tekst virker i appen på iPad/telefon – ikke i browser.'
            : 'Tale til tekst er kun i appen på iPad/telefon.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }
    final d = _spreads[i];
    final initial = KidStorybookPageItem.joinedText(d.items);
    final resultText = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _SpeechToTextDialog(speech: _speech!, initialText: initial),
    );
    if (resultText != null && mounted) {
      setState(() {
        d.items.add(
          KidStorybookPageItem(
            id: KidStorybookPageItem.newId(),
            kind: KidStorybookPageItem.kText,
            cx: 0.5,
            cy: (0.1 + 0.05 * d.items.where((e) => e.isText).length).clamp(
              0.04,
              0.28,
            ),
            scale: 1.0,
            text: resultText,
            textFontSize: 24.0,
            textFontKey: 'sans',
          ),
        );
      });
    }
  }

  /// Bog Creator-lærred: pile + hvid side.
  Widget _buildPageEditorLayout() {
    if (_spreads.isEmpty) {
      return const Center(
        child: Text(
          'Ingen sider i bogen endnu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black87),
        ),
      );
    }
    final i = _currentPageIndex.clamp(0, _spreads.length - 1);
    final d = _spreads[i];
    final ar =
        _pageFormat?.imageAspectWidthOverHeight ??
        KidStorybookPageFormat.landscape.imageAspectWidthOverHeight;
    final empty = _pageIsEmpty(d);

    return LayoutBuilder(
      builder: (context, cons) {
        final maxW = (cons.maxWidth * 0.82).clamp(0.0, 800.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: IconButton(
                icon: const Icon(Icons.chevron_left, size: 44),
                color: Colors.black87,
                tooltip: 'Forrige side',
                onPressed: i > 0 ? _editorPrev : null,
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxW,
                    maxHeight: cons.maxHeight * 0.92,
                  ),
                  child: AspectRatio(
                    aspectRatio: ar,
                    child: Material(
                      color: Colors.white,
                      elevation: 8,
                      shadowColor: Colors.black38,
                      borderRadius: BorderRadius.circular(2),
                      clipBehavior: Clip.none,
                      child: empty
                          ? _buildEmptyPageCenterActions()
                          : _buildFilledPageBody(d),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: IconButton(
                icon: const Icon(Icons.chevron_right, size: 44),
                color: Colors.black87,
                tooltip: 'Næste side (ny hvis nødvendigt)',
                onPressed: _saving ? null : _editorNext,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyPageCenterActions() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PageCenterAction(
                icon: Icons.add_photo_alternate,
                label: 'Billede',
                onPressed: _saving ? null : _showImageSourceSheet,
              ),
              const SizedBox(width: 12),
              _PageCenterAction(
                icon: Icons.text_fields,
                label: 'Tekst',
                onPressed: _saving ? null : _showInsertTextDialog,
              ),
              const SizedBox(width: 12),
              _PageCenterAction(
                icon: Icons.mic,
                label: 'Tale',
                onPressed: _saving ? null : _showSpeechToTextPanel,
              ),
              const SizedBox(width: 12),
              _PageCenterAction(
                icon: Icons.interests,
                label: 'Figur',
                onPressed: _saving ? null : _showStickerPicker,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilledPageBody(_SpreadDraft d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _StorybookPageLayoutEditor(
            key: ObjectKey(d),
            draft: d,
            textStyleForItem: _textStyleForItem,
            onEditText: (id) => _showInsertTextDialog(editItemId: id),
            onContentChanged: _onDraftContentChanged,
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: _saving ? null : _showImageSourceSheet,
                  icon: const Icon(Icons.add_photo_alternate, size: 28),
                  tooltip: 'Billede',
                ),
                IconButton.filledTonal(
                  onPressed: _saving ? null : _showInsertTextDialog,
                  icon: const Icon(Icons.text_fields, size: 28),
                  tooltip: 'Tekst',
                ),
                IconButton.filledTonal(
                  onPressed: _saving ? null : _showSpeechToTextPanel,
                  icon: const Icon(Icons.mic, size: 28),
                  tooltip: 'Tale til tekst',
                ),
                IconButton.filledTonal(
                  onPressed: _saving ? null : _showStickerPicker,
                  icon: const Icon(Icons.interests, size: 28),
                  tooltip: 'Figurer og ikoner',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bogbyggerBackgroundLayer() {
    return Positioned.fill(
      child: Image.asset(
        kBogbyggerBackgroundAsset,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF5A1A0D), Color(0xFFE85A4A)],
            ),
          ),
        ),
      ),
    );
  }

  static const double _newBookRingSize = 120;

  Widget _buildNewBookPlusButton() {
    return Semantics(
      button: true,
      label: 'Ny bog',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saving ? null : _onTapNewBook,
          customBorder: const CircleBorder(),
          child: Ink(
            width: _newBookRingSize,
            height: _newBookRingSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x33F9C433),
              border: Border.all(color: const Color(0xFFF9C433), width: 6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 16,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.add, size: 72, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryView() {
    final topPad = MediaQuery.paddingOf(context).top;
    final screenSize = MediaQuery.sizeOf(context);
    final shortest = screenSize.shortestSide;
    final isTablet = shortest >= 600;
    final hasBooks = _builderShelfItems.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF2D1B0F),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          _bogbyggerBackgroundLayer(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPad + 72,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    kidZoneHorizontalPadding + 52,
                    8,
                    kidZoneHorizontalPadding,
                    4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bogbygger',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 26 : 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mine egne bøger',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.95),
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _builderLibraryLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFF9C433),
                          ),
                        )
                      : hasBooks
                      ? Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            _buildNewBookPlusButton(),
                            const SizedBox(height: 8),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, cons) {
                                  return Center(
                                    child: SizedBox(
                                      width: screenSize.width,
                                      height: cons.maxHeight,
                                      child: Transform.scale(
                                        scale: 0.8,
                                        alignment: Alignment.center,
                                        filterQuality: FilterQuality.medium,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          clipBehavior: Clip.none,
                                          children: [
                                            const LibraryCabinetBackground(
                                              showWallBackdrop: false,
                                            ),
                                            BogskabShelfOverlay(
                                              maxWidth: screenSize.width,
                                              maxHeight: cons.maxHeight,
                                              kidId: widget.kidId,
                                              booksPerShelf:
                                                  distributeBooksOnCabinetShelves(
                                                    _builderShelfItems,
                                                  ),
                                              isTablet: isTablet,
                                              onBookTapOverride: (m) {
                                                _openEditorForBookId(
                                                  m['id'] as String,
                                                );
                                              },
                                              onDeleteKidStoryBook:
                                                  _confirmDeleteBuilderBook,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      : Center(child: _buildNewBookPlusButton()),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: kidZoneHorizontalPadding,
            child: KidSessionNavButton(kidId: widget.kidId),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: kidZoneHorizontalPadding,
            child: const KidParentAdminCornerButton(),
          ),
        ],
      ),
    );
  }

  /// Ny bog: tre trykbare forhåndsvisninger (ét format per «bog»), derefter én tom side.
  Widget _buildNewBookFormatScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF2D1B0F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _bogbyggerBackgroundLayer(),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() => _newBookFormatPhase = false);
                          },
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 32,
                          ),
                          tooltip: 'Tilbage',
                        ),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Vælg format',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tryk på bogen i billedet (lodret, vandret eller kvadratisk).',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            shadows: const [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 5,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: _bogbyggerFormatBigImageWithInvisibleButtons(
                        enabled: !_saving,
                        onPicked: (f) => unawaited(_onNewBookFormatPicked(f)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_newBookFormatPhase) {
      return _buildNewBookFormatScreen();
    }
    if (_libraryPhase) {
      return _buildLibraryView();
    }
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF2D1B0F),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _bogbyggerBackgroundLayer(),
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFF9C433)),
            ),
          ],
        ),
      );
    }
    if (_error != null && _bookId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF2D1B0F),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _bogbyggerBackgroundLayer(),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _leaveEditorSavingFirst();
      },
      child: Scaffold(
        backgroundColor: _kBogbyggerEditorWorkspace,
        appBar: AppBar(
          backgroundColor: const Color(0xFFE8EEF2),
          foregroundColor: Colors.black87,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Tilbage til mine bøger (gemmer)',
            onPressed: _saving ? null : _leaveEditorSavingFirst,
          ),
          title: ListenableBuilder(
            listenable: _titleController,
            builder: (context, _) {
              return InkWell(
                onTap: _saving ? null : _showTitleEditDialog,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _titleController.text.trim().isEmpty
                            ? 'Ny bog'
                            : _titleController.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit, size: 20, color: Colors.black54),
                  ],
                ),
              );
            },
          ),
          actions: [
            IconButton(
              tooltip: _publishedToLibrary
                  ? 'Opdater bogen i dit bibliotek'
                  : 'Udgiv bogen i dit bibliotek',
              onPressed: _saving ? null : _publishToLibrary,
              icon: Image.asset(
                'assets/release.png',
                height: 28,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'Gem min bog',
              onPressed: _saving ? null : _saveToLibrary,
            ),
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Print',
              onPressed: _saving ? null : _printBook,
            ),
            const KidParentAdminCornerButton(),
          ],
        ),
        body: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_spreads.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      _currentPageIndex == 0
                          ? 'Forside'
                          : 'Side ${_currentPageIndex + 1} af ${_spreads.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                Expanded(child: _buildPageEditorLayout()),
              ],
            ),
            if (_saving)
              const ColoredBox(
                color: Color(0x33000000),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('Arbejder…'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAlfamonPicker(int spreadIndex) async {
    setState(() => _saving = true);
    try {
      final list = await KidStorybookService.listAvatars();
      if (!mounted) return;
      setState(() => _saving = false);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) {
          return _AlfamonPickerBody(
            avatars: list,
            onPick: (url) {
              _onAlfamonImagePicked(spreadIndex, url);
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kunne ikke hente Alfamons: $e')),
        );
      }
    }
  }
}

/// Billede med ramme + hjørnehåndtag. Skalering/flytning kun når [selected].
/// Stateful, så [GestureDetector] får **stabile** onScale-callbacks — ellers under grupperes
/// `setState` en ny closure hvert frame, og næste pinch (især macOS) virker ikke.
class _StorybookImageWithHandles extends StatefulWidget {
  const _StorybookImageWithHandles({
    super.key,
    required this.baseW,
    required this.baseH,
    required this.imageUrl,
    required this.imageFullBleed,
    required this.layout,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.onFillPage,
    this.onCornerPanDelta,
    this.onCornerPanEnd,
  });

  final double baseW;
  final double baseH;
  final String imageUrl;
  final bool imageFullBleed;
  final KidStorybookPageLayout layout;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;
  final VoidCallback? onFillPage;
  final void Function(Offset delta, int sx, int sy)? onCornerPanDelta;
  final VoidCallback? onCornerPanEnd;

  @override
  State<_StorybookImageWithHandles> createState() =>
      _StorybookImageWithHandlesState();
}

class _StorybookImageWithHandlesState
    extends State<_StorybookImageWithHandles> {
  static const double _pad = 14;

  /// Lokal visning under pinch — overrides parents widget.layout.imageScale så
  /// skalering ikke hopper hvis forælderens setState er én frame bagud.
  double? _pinchVisScale;
  double _pinchBase = 1.0;

  /// Lokal visning under hjørne-pan; model opdateres i forælderen uden [setState] pr. frame.
  double? _cornerVisScale;

  double get _displayScale {
    if (_pinchVisScale != null) return _pinchVisScale!;
    if (_cornerVisScale != null) return _cornerVisScale!;
    return widget.layout.imageScale;
  }

  @override
  void didUpdateWidget(_StorybookImageWithHandles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected && !widget.selected) {
      _pinchVisScale = null;
      _cornerVisScale = null;
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    _pinchBase = widget.layout.imageScale;
    _pinchVisScale = _pinchBase;
    widget.onScaleStart?.call(d);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _pinchVisScale = (_pinchBase * d.scale).clamp(
        KidStorybookPageLayout.kEditMinImageScale,
        KidStorybookPageLayout.kEditMaxImageScale,
      );
    });
    widget.onScaleUpdate?.call(d);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    setState(() => _pinchVisScale = null);
    widget.onScaleEnd?.call(d);
  }

  void _onCornerStart() {
    _cornerVisScale = widget.layout.imageScale;
  }

  void _onCornerUpdate(DragUpdateDetails d, int sx, int sy) {
    if (_cornerVisScale == null) return;
    final diagonalLenSq =
        widget.baseW * widget.baseW + widget.baseH * widget.baseH;
    final scaleDelta = diagonalLenSq <= 0
        ? 0.0
        : (sx * d.delta.dx * widget.baseW + sy * d.delta.dy * widget.baseH) /
              diagonalLenSq;
    setState(() {
      _cornerVisScale = (_cornerVisScale! + scaleDelta).clamp(
        KidStorybookPageLayout.kEditMinImageScale,
        KidStorybookPageLayout.kEditMaxImageScale,
      );
    });
    widget.onCornerPanDelta?.call(d.delta, sx, sy);
  }

  void _onCornerEnd() {
    setState(() => _cornerVisScale = null);
    widget.onCornerPanEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final showChrome = widget.selected;
    final canScale = widget.onScaleStart != null;
    final displayScale = _displayScale;
    final hitW = widget.baseW * displayScale;
    final hitH = widget.baseH * displayScale;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => widget.onSelect(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: canScale ? _onScaleStart : null,
            onScaleUpdate: canScale ? _onScaleUpdate : null,
            onScaleEnd: canScale ? _onScaleEnd : null,
            child: SizedBox(
              width: hitW,
              height: hitH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: AssetOrNetworkImage(
                      src: widget.imageUrl,
                      fit: widget.imageFullBleed
                          ? BoxFit.cover
                          : BoxFit.contain,
                    ),
                  ),
                  if (showChrome)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF1976D2),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (showChrome && widget.onFillPage != null)
                    Positioned(
                      left: 4,
                      top: 4,
                      child: _StorybookImageChromeButton(
                        icon: Icons.fullscreen,
                        semanticLabel: 'Fyld hele siden',
                        onPressed: widget.onFillPage!,
                      ),
                    ),
                  if (showChrome && widget.onCornerPanDelta != null) ...[
                    _imageCorner(
                      left: -_pad,
                      top: -_pad,
                      align: Alignment.bottomRight,
                      onStart: _onCornerStart,
                      onPan: (u) => _onCornerUpdate(u, -1, -1),
                      onEnd: _onCornerEnd,
                    ),
                    _imageCorner(
                      right: -_pad,
                      top: -_pad,
                      align: Alignment.bottomLeft,
                      onStart: _onCornerStart,
                      onPan: (u) => _onCornerUpdate(u, 1, -1),
                      onEnd: _onCornerEnd,
                      innerTopLeftChild: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (_) => widget.onSelect(),
                        child: _StorybookItemCloseButton(
                          onPressed: widget.onDelete,
                          semanticLabel: 'Fjern billede',
                        ),
                      ),
                    ),
                    _imageCorner(
                      left: -_pad,
                      bottom: -_pad,
                      align: Alignment.topRight,
                      onStart: _onCornerStart,
                      onPan: (u) => _onCornerUpdate(u, -1, 1),
                      onEnd: _onCornerEnd,
                    ),
                    _imageCorner(
                      right: -_pad,
                      bottom: -_pad,
                      align: Alignment.topLeft,
                      onStart: _onCornerStart,
                      onPan: (u) => _onCornerUpdate(u, 1, 1),
                      onEnd: _onCornerEnd,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _imageCorner({
    double? left,
    double? top,
    double? right,
    double? bottom,
    required Alignment align,
    required VoidCallback onStart,
    required void Function(DragUpdateDetails) onPan,
    required VoidCallback onEnd,
    Widget? innerTopLeftChild,
  }) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => onStart(),
              onPanUpdate: onPan,
              onPanEnd: (_) => onEnd(),
              child: Align(
                alignment: align,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1976D2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            if (innerTopLeftChild != null)
              Positioned(
                left: 0,
                top: 0,
                child: innerTopLeftChild,
              ),
          ],
        ),
      ),
    );
  }
}

class _StorybookImageChromeButton extends StatelessWidget {
  const _StorybookImageChromeButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFF1976D2),
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );
  }
}

class _StorybookDecalWithHandles extends StatefulWidget {
  const _StorybookDecalWithHandles({
    super.key,
    required this.baseSize,
    required this.decoration,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.onCornerPanDelta,
    this.onCornerPanEnd,
  });

  final double baseSize;
  final KidStorybookPageDecoration decoration;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;
  final void Function(Offset delta, int sx, int sy)? onCornerPanDelta;
  final VoidCallback? onCornerPanEnd;

  @override
  State<_StorybookDecalWithHandles> createState() =>
      _StorybookDecalWithHandlesState();
}

class _StorybookDecalWithHandlesState
    extends State<_StorybookDecalWithHandles> {
  static const double _pad = 14;

  double? _pinchVisScale;
  double _pinchBase = 1.0;
  double? _cornerVisScale;

  double get _displayScale {
    if (_pinchVisScale != null) return _pinchVisScale!;
    if (_cornerVisScale != null) return _cornerVisScale!;
    return widget.decoration.scale;
  }

  @override
  void didUpdateWidget(_StorybookDecalWithHandles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected && !widget.selected) {
      _pinchVisScale = null;
      _cornerVisScale = null;
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    _pinchBase = widget.decoration.scale;
    _pinchVisScale = _pinchBase;
    widget.onScaleStart?.call(d);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _pinchVisScale = (_pinchBase * d.scale).clamp(
        KidStorybookPageDecoration.kEditMinScale,
        KidStorybookPageDecoration.kEditMaxScale,
      );
    });
    widget.onScaleUpdate?.call(d);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    setState(() => _pinchVisScale = null);
    widget.onScaleEnd?.call(d);
  }

  void _onCornerStart() {
    _cornerVisScale = widget.decoration.scale;
  }

  void _onCornerUpdate(DragUpdateDetails d, int sx, int sy) {
    if (_cornerVisScale == null) return;
    final diagonalLenSq = widget.baseSize * widget.baseSize * 2;
    final scaleDelta = diagonalLenSq <= 0
        ? 0.0
        : (sx * d.delta.dx * widget.baseSize +
                  sy * d.delta.dy * widget.baseSize) /
              diagonalLenSq;
    setState(() {
      _cornerVisScale = (_cornerVisScale! + scaleDelta).clamp(
        KidStorybookPageDecoration.kEditMinScale,
        KidStorybookPageDecoration.kEditMaxScale,
      );
    });
    widget.onCornerPanDelta?.call(d.delta, sx, sy);
  }

  void _onCornerEnd() {
    setState(() => _cornerVisScale = null);
    widget.onCornerPanEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final showChrome = widget.selected;
    final canScale = widget.onScaleStart != null;
    final displayScale = _displayScale;
    final hitSize = widget.baseSize * displayScale;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: widget.onSelect,
          onScaleStart: canScale ? _onScaleStart : null,
          onScaleUpdate: canScale ? _onScaleUpdate : null,
          onScaleEnd: canScale ? _onScaleEnd : null,
          child: SizedBox(
            width: hitSize,
            height: hitSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Center(
                    child: kidStorybookDecorationContent(
                      widget.decoration,
                      baseSize: hitSize * 0.9,
                    ),
                  ),
                ),
                if (showChrome)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF1976D2),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showChrome && widget.onCornerPanDelta != null) ...[
                  _decalDot(
                    left: -_pad,
                    top: -_pad,
                    align: Alignment.bottomRight,
                    onStart: _onCornerStart,
                    onPan: (u) => _onCornerUpdate(u, -1, -1),
                    onEnd: _onCornerEnd,
                  ),
                  _decalDot(
                    right: -_pad,
                    top: -_pad,
                    align: Alignment.bottomLeft,
                    onStart: _onCornerStart,
                    onPan: (u) => _onCornerUpdate(u, 1, -1),
                    onEnd: _onCornerEnd,
                    innerTopLeftChild: _StorybookItemCloseButton(
                      onPressed: widget.onDelete,
                      semanticLabel: 'Fjern figur',
                    ),
                  ),
                  _decalDot(
                    left: -_pad,
                    bottom: -_pad,
                    align: Alignment.topRight,
                    onStart: _onCornerStart,
                    onPan: (u) => _onCornerUpdate(u, -1, 1),
                    onEnd: _onCornerEnd,
                  ),
                  _decalDot(
                    right: -_pad,
                    bottom: -_pad,
                    align: Alignment.topLeft,
                    onStart: _onCornerStart,
                    onPan: (u) => _onCornerUpdate(u, 1, 1),
                    onEnd: _onCornerEnd,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _decalDot({
    double? left,
    double? top,
    double? right,
    double? bottom,
    required Alignment align,
    required VoidCallback onStart,
    required void Function(DragUpdateDetails) onPan,
    required VoidCallback onEnd,
    Widget? innerTopLeftChild,
  }) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => onStart(),
              onPanUpdate: onPan,
              onPanEnd: (_) => onEnd(),
              child: Align(
                alignment: align,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1976D2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            if (innerTopLeftChild != null)
              Positioned(
                left: 0,
                top: 0,
                child: innerTopLeftChild,
              ),
          ],
        ),
      ),
    );
  }
}

/// Maks. tekstboksbredde: uden [\\n] bruges hele [maxWrap] (orddeling);
/// med [\\n] sættes bredden til længste linje (cappet [maxWrap]).
double _layoutStorybookTextBoxWidth(
  String? raw,
  TextStyle style,
  double maxWrap,
) {
  final t = (raw ?? '').replaceAll('\r', '\n');
  if (t.isEmpty) {
    return maxWrap;
  }
  if (!t.contains('\n')) {
    return maxWrap;
  }
  var m = 0.0;
  for (final line in t.split('\n')) {
    if (line.isEmpty) {
      continue;
    }
    final wLine = (TextPainter(
      text: TextSpan(text: line, style: style),
      textDirection: TextDirection.ltr,
    )..layout())
        .size
        .width;
    final capped = math.min(wLine, maxWrap);
    if (capped > m) m = capped;
  }
  if (m <= 0) {
    return maxWrap;
  }
  return m;
}

/// Tekstblok med pinching — [State] har **stabile** onScale-metoder så macOS/desktop
/// ikke mister genkenderen efter første skalering.
class _StorybookTextWithHandles extends StatefulWidget {
  const _StorybookTextWithHandles({
    super.key,
    required this.item,
    required this.selected,
    required this.maxPageWrapW,
    required this.innerMaxH,
    required this.cornerBaseW,
    required this.cornerBaseH,
    required this.textStyleForItem,
    required this.canScale,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.onCornerPanDelta,
    this.onCornerPanEnd,
    this.onDelete,
    required this.onTap,
    required this.onDoubleTap,
  });

  final KidStorybookPageItem item;
  final bool selected;
  /// Maks. ombrydning: typisk 50% af sidens bredde.
  final double maxPageWrapW;
  final double innerMaxH;
  final double cornerBaseW;
  final double cornerBaseH;
  final TextStyle Function(KidStorybookPageItem) textStyleForItem;
  final bool canScale;
  final VoidCallback? onDelete;
  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;
  final void Function(Offset delta, int sx, int sy)? onCornerPanDelta;
  final VoidCallback? onCornerPanEnd;
  final VoidCallback onTap;
  final Future<void> Function() onDoubleTap;

  @override
  State<_StorybookTextWithHandles> createState() =>
      _StorybookTextWithHandlesState();
}

class _StorybookTextWithHandlesState extends State<_StorybookTextWithHandles> {
  static const double _pad = 14;
  double? _pinchVisScale;
  double _pinchBase = 1.0;
  double? _cornerVisScale;

  double get _textScale {
    if (_pinchVisScale != null) return _pinchVisScale!;
    if (_cornerVisScale != null) return _cornerVisScale!;
    return widget.item.scale;
  }

  @override
  void didUpdateWidget(_StorybookTextWithHandles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected && !widget.selected) {
      _pinchVisScale = null;
      _cornerVisScale = null;
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    _pinchBase = widget.item.scale;
    _pinchVisScale = _pinchBase;
    widget.onScaleStart?.call(d);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _pinchVisScale = (_pinchBase * d.scale).clamp(
        KidStorybookPageLayout.kEditMinTextScale,
        KidStorybookPageLayout.kEditMaxTextScale,
      );
    });
    widget.onScaleUpdate?.call(d);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    setState(() => _pinchVisScale = null);
    widget.onScaleEnd?.call(d);
  }

  void _onCornerStart() {
    _cornerVisScale = widget.item.scale;
  }

  void _onCornerUpdate(DragUpdateDetails d, int sx, int sy) {
    if (_cornerVisScale == null) return;
    final baseW = widget.cornerBaseW;
    final baseH = widget.cornerBaseH;
    final diagonalLenSq = baseW * baseW + baseH * baseH;
    final scaleDelta = diagonalLenSq <= 0
        ? 0.0
        : (sx * d.delta.dx * baseW + sy * d.delta.dy * baseH) / diagonalLenSq;
    setState(() {
      _cornerVisScale = (_cornerVisScale! + scaleDelta).clamp(
        KidStorybookPageLayout.kEditMinTextScale,
        KidStorybookPageLayout.kEditMaxTextScale,
      );
    });
    widget.onCornerPanDelta?.call(d.delta, sx, sy);
  }

  void _onCornerEnd() {
    setState(() => _cornerVisScale = null);
    widget.onCornerPanEnd?.call();
  }

  void _onTap() => widget.onTap();
  Future<void> _onDoubleTap() => widget.onDoubleTap();

  @override
  Widget build(BuildContext context) {
    final s = widget.canScale;
    final textStyle = widget.textStyleForItem(widget.item);
    final maxWrap = widget.maxPageWrapW;
    final boxW = _layoutStorybookTextBoxWidth(
      widget.item.text,
      textStyle,
      maxWrap,
    );
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: _onTap,
      onDoubleTap: _onDoubleTap,
      onScaleStart: s ? _onScaleStart : null,
      onScaleUpdate: s ? _onScaleUpdate : null,
      onScaleEnd: s ? _onScaleEnd : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.zero,
            decoration: widget.selected
                ? BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    border: Border.all(
                      color: const Color(0xFF1976D2),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            child: Transform.scale(
              scale: _textScale,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: boxW,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: widget.innerMaxH,
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      Text(
                        widget.item.text ?? '',
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: textStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.selected && widget.onCornerPanDelta != null) ...[
            _textCorner(
              left: -_pad,
              top: -_pad,
              align: Alignment.bottomRight,
              onStart: _onCornerStart,
              onPan: (u) => _onCornerUpdate(u, -1, -1),
              onEnd: _onCornerEnd,
            ),
            _textCorner(
              right: -_pad,
              top: -_pad,
              align: Alignment.bottomLeft,
              onStart: _onCornerStart,
              onPan: (u) => _onCornerUpdate(u, 1, -1),
              onEnd: _onCornerEnd,
              innerTopLeftChild: widget.onDelete != null
                  ? Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) => _onTap(),
                      child: _StorybookItemCloseButton(
                        onPressed: widget.onDelete!,
                        semanticLabel: 'Fjern tekst',
                      ),
                    )
                  : null,
            ),
            _textCorner(
              left: -_pad,
              bottom: -_pad,
              align: Alignment.topRight,
              onStart: _onCornerStart,
              onPan: (u) => _onCornerUpdate(u, -1, 1),
              onEnd: _onCornerEnd,
            ),
            _textCorner(
              right: -_pad,
              bottom: -_pad,
              align: Alignment.topLeft,
              onStart: _onCornerStart,
              onPan: (u) => _onCornerUpdate(u, 1, 1),
              onEnd: _onCornerEnd,
            ),
          ],
        ],
      ),
    );
  }

  static Widget _textCorner({
    double? left,
    double? top,
    double? right,
    double? bottom,
    required Alignment align,
    required VoidCallback onStart,
    required void Function(DragUpdateDetails) onPan,
    required VoidCallback onEnd,
    Widget? innerTopLeftChild,
  }) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => onStart(),
              onPanUpdate: onPan,
              onPanEnd: (_) => onEnd(),
              child: Align(
                alignment: align,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1976D2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            if (innerTopLeftChild != null)
              Positioned(
                left: 0,
                top: 0,
                child: innerTopLeftChild,
              ),
          ],
        ),
      ),
    );
  }
}

class _StorybookPageLayoutEditor extends StatefulWidget {
  const _StorybookPageLayoutEditor({
    super.key,
    required this.draft,
    required this.textStyleForItem,
    required this.onEditText,
    required this.onContentChanged,
  });

  final _SpreadDraft draft;
  final TextStyle Function(KidStorybookPageItem) textStyleForItem;
  final Future<void> Function(String? editItemId) onEditText;
  final VoidCallback onContentChanged;

  @override
  State<_StorybookPageLayoutEditor> createState() =>
      _StorybookPageLayoutEditorState();
}

class _StorybookPageLayoutEditorState
    extends State<_StorybookPageLayoutEditor> {
  /// Max. højde for tekstblok på siden (linjer kan udvide boksen indtil denne grænse).
  static const double _kTextBlockMaxH = 0.92;
  String? _selectedId;
  double? _scale0;

  @override
  void didUpdateWidget(covariant _StorybookPageLayoutEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.draft, widget.draft)) {
      _selectedId = null;
      _scale0 = null;
    }
  }

  KidStorybookPageItem? _itemById(_SpreadDraft d, String id) {
    for (final e in d.items) {
      if (e.id == id) return e;
    }
    return null;
  }

  KidStorybookPageLayout _layoutForImageItem(KidStorybookPageItem it) {
    return KidStorybookPageLayout(
      imageCx: it.cx,
      imageCy: it.cy,
      imageScale: it.scale,
      textCx: 0.5,
      textCy: 0.12,
      textScale: 1.0,
    );
  }

  void _patch(_SpreadDraft d, String id, KidStorybookPageItem next) {
    final i = d.items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    if (!mounted) {
      d.items[i] = next;
      return;
    }
    setState(() {
      d.items[i] = next;
    });
  }

  double _scaleFromCornerDelta({
    required double scale,
    required double baseW,
    required double baseH,
    required Offset delta,
    required int sx,
    required int sy,
    required double minScale,
    required double maxScale,
  }) {
    final diagonalLenSq = baseW * baseW + baseH * baseH;
    if (diagonalLenSq <= 0) return scale.clamp(minScale, maxScale);
    final scaleDelta =
        (sx * delta.dx * baseW + sy * delta.dy * baseH) / diagonalLenSq;
    return (scale + scaleDelta).clamp(minScale, maxScale);
  }

  double _alignPosFromStart(
    double startPx,
    double parentSize,
    double childSize,
  ) {
    final den = parentSize - childSize;
    if (den.abs() < 1.0) return 0.5;
    return startPx / den;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    if (d.items.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        if (w <= 0 || h <= 0) {
          return const SizedBox.shrink();
        }
        final baseW = w * 0.58;
        final baseH = baseW * 0.75;
        final decSize = w * 0.22;
        final textMaxH = h * _kTextBlockMaxH;
        final imAndFig = d.items.where((e) => !e.isText);
        final texts = d.items.where((e) => e.isText);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_selectedId != null) {
                    setState(() => _selectedId = null);
                  }
                },
                child: const SizedBox.expand(),
              ),
            ),
            for (final item in imAndFig)
              _oneItem(d, w, h, baseW, baseH, decSize, textMaxH, item),
            for (final item in texts)
              _oneItem(d, w, h, baseW, baseH, decSize, textMaxH, item),
          ],
        );
      },
    );
  }

  Widget _oneItem(
    _SpreadDraft d,
    double w,
    double h,
    double baseW,
    double baseH,
    double decSize,
    double textMaxH,
    KidStorybookPageItem item,
  ) {
    if (item.isImage) {
      final u = (item.imageUrl ?? '').trim();
      if (u.isEmpty) return const SizedBox.shrink();
      final lay = _layoutForImageItem(item);
      return Positioned.fill(
        child: Align(
          alignment: lay.imageAlignment,
          child: _StorybookImageWithHandles(
            key: ValueKey(item.id),
            baseW: baseW,
            baseH: baseH,
            imageUrl: u,
            imageFullBleed: item.imageFullBleed,
            layout: lay,
            selected: _selectedId == item.id,
            onSelect: () => setState(() => _selectedId = item.id),
            onDelete: () {
              setState(() {
                d.items.removeWhere((e) => e.id == item.id);
                if (_selectedId == item.id) {
                  _selectedId = null;
                }
              });
              widget.onContentChanged();
            },
            onScaleStart: (_) {
              if (_selectedId != item.id) {
                setState(() => _selectedId = item.id);
              }
              _scale0 = _itemById(d, item.id)?.scale;
            },
            onScaleUpdate: (details) {
              final cur = _itemById(d, item.id);
              if (cur == null) return;
              final s0 = _scale0 ?? cur.scale;
              final nextScale = (s0 * details.scale).clamp(
                KidStorybookPageLayout.kEditMinImageScale,
                KidStorybookPageLayout.kEditMaxImageScale,
              );
              final scaleChanged =
                  (nextScale - cur.scale).abs() > 0.0001;
              final visualW = baseW * nextScale;
              final visualH = baseH * nextScale;
              // Align(2*cx-1) maps cx -> offset over (w - childW), not w.
              // Use the actual movement range so the finger tracks 1:1.
              final dxDen = (w - visualW).abs() < 1.0 ? 1.0 : (w - visualW);
              final dyDen = (h - visualH).abs() < 1.0 ? 1.0 : (h - visualH);
              _patch(
                d,
                item.id,
                cur.copyWith(
                  scale: nextScale,
                  imageFullBleed: scaleChanged ? false : cur.imageFullBleed,
                  cx: (cur.cx + details.focalPointDelta.dx / dxDen).clamp(
                    KidStorybookPageLayout.kEditMinPos,
                    KidStorybookPageLayout.kEditMaxPos,
                  ),
                  cy: (cur.cy + details.focalPointDelta.dy / dyDen).clamp(
                    KidStorybookPageLayout.kEditMinPos,
                    KidStorybookPageLayout.kEditMaxPos,
                  ),
                ),
              );
            },
            onScaleEnd: (_) {
              _scale0 = null;
              if (mounted) {
                setState(() {});
                widget.onContentChanged();
              }
            },
            onFillPage: () {
              final cur = _itemById(d, item.id);
              if (cur == null) return;
              final fullPageScale = math
                  .max(w / baseW, h / baseH)
                  .clamp(
                    KidStorybookPageLayout.kEditMinImageScale,
                    KidStorybookPageLayout.kEditMaxImageScale,
                  );
              _scale0 = null;
              _patch(
                d,
                item.id,
                cur.copyWith(
                  cx: 0.5,
                  cy: 0.5,
                  scale: fullPageScale,
                  imageFullBleed: true,
                ),
              );
              widget.onContentChanged();
            },
            onCornerPanDelta: _selectedId == item.id
                ? (delta, sx, sy) {
                    final cur = _itemById(d, item.id);
                    if (cur == null) return;
                    final oldW = baseW * cur.scale;
                    final oldH = baseH * cur.scale;
                    final oldLeft = cur.cx * (w - oldW);
                    final oldTop = cur.cy * (h - oldH);
                    final fixedX = sx > 0 ? oldLeft : oldLeft + oldW;
                    final fixedY = sy > 0 ? oldTop : oldTop + oldH;
                    final nextScale = _scaleFromCornerDelta(
                      scale: cur.scale,
                      baseW: baseW,
                      baseH: baseH,
                      delta: delta,
                      sx: sx,
                      sy: sy,
                      minScale: KidStorybookPageLayout.kEditMinImageScale,
                      maxScale: KidStorybookPageLayout.kEditMaxImageScale,
                    );
                    final nextW = baseW * nextScale;
                    final nextH = baseH * nextScale;
                    final nextLeft = sx > 0 ? fixedX : fixedX - nextW;
                    final nextTop = sy > 0 ? fixedY : fixedY - nextH;
                    _patch(
                      d,
                      item.id,
                      cur.copyWith(
                        scale: nextScale,
                        imageFullBleed: false,
                        cx: _alignPosFromStart(nextLeft, w, nextW).clamp(
                          KidStorybookPageLayout.kEditMinPos,
                          KidStorybookPageLayout.kEditMaxPos,
                        ),
                        cy: _alignPosFromStart(nextTop, h, nextH).clamp(
                          KidStorybookPageLayout.kEditMinPos,
                          KidStorybookPageLayout.kEditMaxPos,
                        ),
                      ),
                    );
                  }
                : null,
            onCornerPanEnd: _selectedId == item.id
                ? () {
                    if (mounted) {
                      setState(() {});
                      widget.onContentChanged();
                    }
                  }
                : null,
          ),
        ),
      );
    }
    if (item.isFigure) {
      final dec = item.decoration;
      if (dec == null) return const SizedBox.shrink();
      return Positioned.fill(
        child: Align(
          alignment: dec.layoutAlignment,
          child: _StorybookDecalWithHandles(
            key: ValueKey(item.id),
            baseSize: decSize,
            decoration: dec,
            selected: _selectedId == item.id,
            onSelect: () => setState(() => _selectedId = item.id),
            onDelete: () {
              setState(() {
                d.items.removeWhere((e) => e.id == item.id);
                if (_selectedId == item.id) {
                  _selectedId = null;
                }
              });
              widget.onContentChanged();
            },
            onScaleStart: (_) {
              if (_selectedId != item.id) {
                setState(() => _selectedId = item.id);
              }
              final cur0 = _itemById(d, item.id);
              final d0 = cur0?.decoration;
              _scale0 = d0?.scale ?? cur0?.scale;
            },
            onScaleUpdate: (details) {
              final cur = _itemById(d, item.id);
              final dCur = cur?.decoration;
              if (cur == null || dCur == null) return;
              final s0 = _scale0 ?? dCur.scale;
              final nextScale = (s0 * details.scale).clamp(
                KidStorybookPageDecoration.kEditMinScale,
                KidStorybookPageDecoration.kEditMaxScale,
              );
              final visualSize = decSize * nextScale;
              final dxDen = (w - visualSize).abs() < 1.0
                  ? 1.0
                  : (w - visualSize);
              final dyDen = (h - visualSize).abs() < 1.0
                  ? 1.0
                  : (h - visualSize);
              final nDec = dCur.copyWith(
                scale: nextScale,
                cx: (dCur.cx + details.focalPointDelta.dx / dxDen).clamp(
                  KidStorybookPageDecoration.kEditMinPos,
                  KidStorybookPageDecoration.kEditMaxPos,
                ),
                cy: (dCur.cy + details.focalPointDelta.dy / dyDen).clamp(
                  KidStorybookPageDecoration.kEditMinPos,
                  KidStorybookPageDecoration.kEditMaxPos,
                ),
              );
              _patch(
                d,
                item.id,
                cur.copyWith(
                  scale: nDec.scale,
                  cx: nDec.cx,
                  cy: nDec.cy,
                  decoration: nDec,
                ),
              );
            },
            onScaleEnd: (_) {
              _scale0 = null;
              if (mounted) {
                setState(() {});
                widget.onContentChanged();
              }
            },
            onCornerPanDelta: _selectedId == item.id
                ? (delta, sx, sy) {
                    final cur = _itemById(d, item.id);
                    final dCur = cur?.decoration;
                    if (cur == null || dCur == null) return;
                    final oldSize = decSize * dCur.scale;
                    final oldLeft = dCur.cx * (w - oldSize);
                    final oldTop = dCur.cy * (h - oldSize);
                    final fixedX = sx > 0 ? oldLeft : oldLeft + oldSize;
                    final fixedY = sy > 0 ? oldTop : oldTop + oldSize;
                    final nextScale = _scaleFromCornerDelta(
                      scale: dCur.scale,
                      baseW: decSize,
                      baseH: decSize,
                      delta: delta,
                      sx: sx,
                      sy: sy,
                      minScale: KidStorybookPageDecoration.kEditMinScale,
                      maxScale: KidStorybookPageDecoration.kEditMaxScale,
                    );
                    final nextSize = decSize * nextScale;
                    final nextLeft = sx > 0 ? fixedX : fixedX - nextSize;
                    final nextTop = sy > 0 ? fixedY : fixedY - nextSize;
                    final nDec = dCur.copyWith(
                      scale: nextScale,
                      cx: _alignPosFromStart(nextLeft, w, nextSize).clamp(
                        KidStorybookPageDecoration.kEditMinPos,
                        KidStorybookPageDecoration.kEditMaxPos,
                      ),
                      cy: _alignPosFromStart(nextTop, h, nextSize).clamp(
                        KidStorybookPageDecoration.kEditMinPos,
                        KidStorybookPageDecoration.kEditMaxPos,
                      ),
                    );
                    _patch(
                      d,
                      item.id,
                      cur.copyWith(
                        scale: nDec.scale,
                        cx: nDec.cx,
                        cy: nDec.cy,
                        decoration: nDec,
                      ),
                    );
                  }
                : null,
            onCornerPanEnd: _selectedId == item.id
                ? () {
                    if (mounted) {
                      setState(() {});
                      widget.onContentChanged();
                    }
                  }
                : null,
          ),
        ),
      );
    }
    if (item.isText) {
      final textWrapW = w * 0.5;
      final textCornerW = textWrapW * 0.5;
      // Samme areal som tidligere (0.36·h) til hjørne-skalering.
      final textCornerH = h * 0.36 * 0.92 * 0.35;
      return Positioned.fill(
        child: Align(
          alignment: Alignment(2 * item.cx - 1, 2 * item.cy - 1),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: textWrapW,
              maxHeight: textMaxH,
            ),
            child: _StorybookTextWithHandles(
              key: ValueKey('${item.id}_sel_${_selectedId == item.id}'),
              item: _itemById(d, item.id) ?? item,
              selected: _selectedId == item.id,
              maxPageWrapW: textWrapW,
              innerMaxH: textMaxH,
              cornerBaseW: textCornerW,
              cornerBaseH: textCornerH,
              textStyleForItem: widget.textStyleForItem,
              canScale: _selectedId == item.id,
              onDelete: _selectedId == item.id
                  ? () {
                      setState(() {
                        d.items.removeWhere((e) => e.id == item.id);
                        if (_selectedId == item.id) {
                          _selectedId = null;
                        }
                      });
                      widget.onContentChanged();
                    }
                  : null,
              onScaleStart: (_) {
                _scale0 = _itemById(d, item.id)?.scale;
              },
              onScaleUpdate: (details) {
                final cur = _itemById(d, item.id);
                if (cur == null) return;
                final s0 = _scale0 ?? cur.scale;
                // Tekst-blokken er væsentligt mindre end siden; brug
                // halv side som divisor så fingeren tracker teksten
                // nogenlunde 1:1 (eksakt mål kendes ikke pga. intrinsic size).
                final dxDen = w * 0.5;
                final band = h * 0.36;
                final dyDen = (h - band).abs() < 1.0 ? band : (h - band);
                _patch(
                  d,
                  item.id,
                  cur.copyWith(
                    scale: (s0 * details.scale).clamp(
                      KidStorybookPageLayout.kEditMinTextScale,
                      KidStorybookPageLayout.kEditMaxTextScale,
                    ),
                    cx: (cur.cx + details.focalPointDelta.dx / dxDen).clamp(
                      KidStorybookPageLayout.kEditMinPos,
                      KidStorybookPageLayout.kEditMaxPos,
                    ),
                    cy: (cur.cy + details.focalPointDelta.dy / dyDen).clamp(
                      KidStorybookPageLayout.kEditMinPos,
                      KidStorybookPageLayout.kEditMaxPos,
                    ),
                  ),
                );
              },
              onScaleEnd: (_) {
                _scale0 = null;
                if (mounted) {
                  setState(() {});
                  widget.onContentChanged();
                }
              },
              onTap: () => setState(() => _selectedId = item.id),
              onDoubleTap: () async {
                setState(() => _selectedId = item.id);
                await widget.onEditText(item.id);
                if (mounted) setState(() {});
              },
              onCornerPanDelta: _selectedId == item.id
                  ? (delta, sx, sy) {
                      final cur = _itemById(d, item.id);
                      if (cur == null) return;
                      _patch(
                        d,
                        item.id,
                        cur.copyWith(
                          scale: _scaleFromCornerDelta(
                            scale: cur.scale,
                            baseW: textCornerW,
                            baseH: textCornerH,
                            delta: delta,
                            sx: sx,
                            sy: sy,
                            minScale: KidStorybookPageLayout.kEditMinTextScale,
                            maxScale: KidStorybookPageLayout.kEditMaxTextScale,
                          ),
                        ),
                      );
                    }
                  : null,
              onCornerPanEnd: _selectedId == item.id
                  ? () {
                      if (mounted) {
                        setState(() {});
                        widget.onContentChanged();
                      }
                    }
                  : null,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _SpreadDraft {
  _SpreadDraft({this.dbId, List<KidStorybookPageItem>? items})
    : items = items ?? <KidStorybookPageItem>[];

  String localKey = UniqueKey().toString();
  String? dbId;
  final List<KidStorybookPageItem> items;
}

class _PageCenterAction extends StatelessWidget {
  const _PageCenterAction({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: const Color(0xFFF0F4F7),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Icon(icon, size: 44, color: Colors.black87),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _SpeechToTextDialog extends StatefulWidget {
  const _SpeechToTextDialog({required this.speech, required this.initialText});

  final stt.SpeechToText speech;
  final String initialText;

  @override
  State<_SpeechToTextDialog> createState() => _SpeechToTextDialogState();
}

class _SpeechToTextDialogState extends State<_SpeechToTextDialog> {
  late final TextEditingController _textC;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _textC = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    unawaited(widget.speech.stop());
    _textC.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_listening) {
      await widget.speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    // [ListenMode.dictation] (kun iOS ifølge plugin) passer bedre til
    // længere sætninger en [ListenMode.confirmation]. Det lærer ikke
    // Alfamon-navne; det skal Apples/Androids biasing til (ikke i plugin).
    await widget.speech.listen(
      onResult: (r) {
        final w = r.recognizedWords.trim();
        if (w.isNotEmpty && mounted) {
          setState(() {
            _textC.text = w;
            _textC.selection = TextSelection.fromPosition(
              TextPosition(offset: _textC.text.length),
            );
          });
        }
      },
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 3),
      localeId: 'da_DK',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tale til tekst'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _toggle,
              icon: Icon(_listening ? Icons.stop : Icons.mic),
              label: Text(_listening ? 'Stop optagelse' : 'Start optagelse'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textC,
              minLines: 3,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Redigér tekst',
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _closeInputDialog(context),
          child: const Text('Luk uden at gemme'),
        ),
        FilledButton(
          onPressed: () async {
            if (_listening) {
              await widget.speech.stop();
              if (mounted) setState(() => _listening = false);
            }
            if (context.mounted) {
              _closeInputDialog(context, _textC.text);
            }
          },
          child: const Text('Brug til siden'),
        ),
      ],
    );
  }
}

class _AlfamonPickerBody extends StatefulWidget {
  const _AlfamonPickerBody({required this.avatars, required this.onPick});

  final List<Map<String, dynamic>> avatars;
  final ValueChanged<String> onPick;

  @override
  State<_AlfamonPickerBody> createState() => _AlfamonPickerBodyState();
}

class _AlfamonPickerBodyState extends State<_AlfamonPickerBody> {
  String? _selId;
  List<String> _urls = [];
  bool _loading = false;

  Future<void> _load(String id) async {
    setState(() {
      _selId = id;
      _loading = true;
      _urls = [];
    });
    try {
      String? aname;
      String? aletter;
      for (final a in widget.avatars) {
        if (a['id'] == id) {
          aname = alfamonDisplayName(a['name'] as String? ?? 'Alfamon');
          aletter = a['letter'] as String?;
          break;
        }
      }
      _urls = await KidStorybookService.imageUrlsForAvatar(
        id,
        avatarName: aname,
        letter: aletter,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fejl: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selId == null) {
      final h = MediaQuery.sizeOf(context).height * 0.92;
      return SizedBox(
        height: h,
        child: AlfamonStorybookLetterPicker(
          avatars: widget.avatars,
          onAvatarSelected: (id) {
            unawaited(_load(id));
          },
        ),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_urls.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingen billeder for denne Alfamon lige nu.'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _selId = null;
                _urls = [];
              }),
              child: const Text('Tilbage'),
            ),
          ],
        ),
      );
    }
    return DraggableScrollableSheet(
      expand: false,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      initialChildSize: 0.75,
      builder: (ctx, scroll) {
        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.arrow_back),
              title: const Text('Vælg en anden Alfamon'),
              onTap: () {
                setState(() {
                  _selId = null;
                  _urls = [];
                });
              },
            ),
            Expanded(
              child: GridView.builder(
                controller: scroll,
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: _urls.length,
                itemBuilder: (ctx, i) {
                  final u = _urls[i];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        widget.onPick(u);
                        Navigator.of(context).pop();
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: AssetOrNetworkImage(src: u, fit: BoxFit.contain),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
