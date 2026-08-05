import 'dart:async' show unawaited;

import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/kid_storybook_page_decoration.dart';
import '../../models/kid_storybook_page_format.dart';
import '../../models/kid_storybook_page_item.dart';
import '../../models/kid_storybook_page_layout.dart';
import '../../services/audio_cache_service.dart';
import '../../services/kid_word_recording_service.dart';
import '../../widgets/kid_word_record_menu.dart';
import '../../widgets/kid_storybook_decoration.dart';
import '../../services/kid_storybook_service.dart';
import '../../services/task_completion_service.dart';
import '../../widgets/kid_parent_admin_corner.dart';
import 'widgets/gold_coins_earned_overlay.dart';

/// Bog-læser for Læs-let bøger.
class KidBookReaderScreen extends StatefulWidget {
  final String kidId;
  final String bookId;

  const KidBookReaderScreen({super.key, required this.kidId, required this.bookId});

  @override
  State<KidBookReaderScreen> createState() => _KidBookReaderScreenState();
}

enum _TextCase { sentence, upper, lower }

class _KidBookReaderScreenState extends State<KidBookReaderScreen> {
  List<Map<String, dynamic>> _pages = [];
  String? _title;
  bool _loading = true;
  String? _error;
  bool _bookOpened = false;
  int _currentSpreadIndex = 0;
  _TextCase _textCase = _TextCase.sentence;
  /// Barnets egen [kid_story_books]-bog. Guldmønter som i shop-bøger kun når udgivet.
  bool _isKidStoryBook = false;
  bool _kidStoryPublishedToLibrary = false;
  KidStorybookPageFormat _kidStoryPageFormat =
      KidStorybookPageFormat.landscape;
  Map<String, String> _audioLibrary = {}; // word -> lokal sti; barn overskriver voksen-ord
  final Set<String> _kidOwnWords = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _flashGoldAmount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playWord(String path) async {
    await _audioPlayer.stop();
    final uri = Uri.tryParse(path);
    final isNetwork = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https');
    if (isNetwork) {
      await _audioPlayer.setUrl(path);
    } else {
      await _audioPlayer.setFilePath(path);
    }
    await _audioPlayer.play();
  }

  /// Admin + barnets optagelser (barn vinder ved samme nøgle).
  Future<void> _applyMergedWordAudio() async {
    final admin = await AudioCacheService.getWordToLocalPath();
    final kid = await KidWordRecordingService.getKidWordToLocalPath(
      widget.kidId,
    );
    if (!mounted) return;
    setState(() {
      _audioLibrary = Map<String, String>.from(admin);
      for (final e in kid.entries) {
        _audioLibrary[e.key] = e.value;
      }
      _kidOwnWords
        ..clear()
        ..addAll(kid.keys);
    });
  }

  void _onWordLongPress(String normalized, String display) {
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => KidWordRecordMenu(
        kidId: widget.kidId,
        normalizedWord: normalized,
        displayWord: display,
        hasExistingOwnRecording: _kidOwnWords.contains(normalized),
        onSaved: () {
          unawaited(_applyMergedWordAudio());
        },
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _isKidStoryBook = false;
      _kidStoryPublishedToLibrary = false;
    });
    try {
      final kidBook = await KidStorybookService.kidStoryBookRowForReader(
        bookId: widget.bookId,
        kidId: widget.kidId,
      );

      if (kidBook != null) {
        _isKidStoryBook = true;
        _kidStoryPublishedToLibrary =
            kidBook['published_to_library'] == true;
        _kidStoryPageFormat = KidStorybookPageFormatX.fromDb(
          kidBook['page_format'] as String?,
        );
        _title = (kidBook['title'] as String?) ?? 'Bog';
        dynamic pagesRes;
        try {
          pagesRes = await Supabase.instance.client
              .from('kid_story_book_pages')
              .select(
                'id, spread_index, left_text, right_image_url, text_font_size, text_font_key, page_layout',
              )
              .eq('book_id', widget.bookId)
              .order('spread_index');
        } catch (_) {
          try {
            pagesRes = await Supabase.instance.client
                .from('kid_story_book_pages')
                .select(
                  'id, spread_index, left_text, right_image_url, text_font_size, text_font_key',
                )
                .eq('book_id', widget.bookId)
                .order('spread_index');
          } catch (_) {
            pagesRes = await Supabase.instance.client
                .from('kid_story_book_pages')
                .select('id, spread_index, left_text, right_image_url')
                .eq('book_id', widget.bookId)
                .order('spread_index');
          }
        }
        final list = (pagesRes as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _pages = list;
        _pages.sort(
          (a, b) => ((a['spread_index'] ?? 0) as num)
              .toInt()
              .compareTo(((b['spread_index'] ?? 0) as num).toInt()),
        );
        if (mounted) {
          setState(() => _loading = false);
        }
        await _applyMergedWordAudio();
        return;
      }

      final bookRes = await Supabase.instance.client
          .from('shop_books')
          .select('id, title')
          .eq('id', widget.bookId)
          .maybeSingle();
      if (bookRes == null) {
        if (mounted) {
          setState(() {
            _error = 'Bog ikke fundet';
            _loading = false;
          });
        }
        return;
      }
      _title = (bookRes['title'] as String?) ?? 'Bog';

      final pagesRes = await Supabase.instance.client
          .from('shop_book_pages')
          .select('id, spread_index, left_text, right_image_url')
          .eq('book_id', widget.bookId)
          .order('spread_index');
      _pages = (pagesRes as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _pages.sort(
        (a, b) => ((a['spread_index'] ?? 0) as num)
            .toInt()
            .compareTo(((b['spread_index'] ?? 0) as num).toInt()),
      );

      if (mounted) {
        setState(() => _loading = false);
      }
      await _applyMergedWordAudio();
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  void _openBook() {
    setState(() => _bookOpened = true);
  }

  void _prevPage() {
    if (_currentSpreadIndex > 0) {
      setState(() => _currentSpreadIndex--);
    }
  }

  Future<void> _nextPage() async {
    if (_currentSpreadIndex >= _pages.length - 1) {
      await _showFinishBookDialog();
    } else {
      setState(() => _currentSpreadIndex++);
    }
  }

  Future<void> _showFinishBookDialog() async {
    if (_isKidStoryBook && !_kidStoryPublishedToLibrary) {
      if (mounted) context.go('/kid/library/${widget.kidId}');
      return;
    }
    final pointsToAward = _pages.length - 1;
    if (pointsToAward < 1) {
      if (mounted) context.go('/kid/library/${widget.kidId}');
      return;
    }

    final storedRes = await Supabase.instance.client
        .from('settings')
        .select('value')
        .eq('key', 'approval_code')
        .maybeSingle();
    if (!mounted) return;
    final storedCode = (storedRes?['value'] as String?)?.trim() ?? '';
    if (storedCode.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Forældrekode er ikke sat. En voksen skal logge ind som forælder og sætte koden.'),
          ),
        );
        context.go('/kid/library/${widget.kidId}');
      }
      return;
    }

    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BookFinishDialog(pointsToAward: pointsToAward),
    );
    if (code == null) {
      if (mounted) context.go('/kid/library/${widget.kidId}');
      return;
    }
    if (code.trim() != storedCode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Forkert forældrekode')),
        );
      }
      return;
    }

    try {
      final result = await TaskCompletionService.awardBookPoints(
        kidId: widget.kidId,
        points: pointsToAward,
        parentCode: code.trim(),
      );
      if (mounted) {
        if (result.dailyBonus != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🎉 Du fik ${result.dailyBonus} ekstra guldmønter for at have klaret alle dagens opgaver!',
              ),
            ),
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Du fik ${result.points} guldmønter i kisten for at læse bogen!',
            ),
          ),
        );
        final gained = result.points + (result.dailyBonus ?? 0);
        if (gained > 0) {
          setState(() => _flashGoldAmount = gained);
          Future.delayed(const Duration(milliseconds: 2800), () {
            if (mounted) setState(() => _flashGoldAmount = null);
          });
          await Future<void>.delayed(const Duration(milliseconds: 2900));
        }
        if (mounted) context.go('/kid/library/${widget.kidId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fejl: $e')),
        );
      }
    }
  }

  void _cycleTextCase() {
    setState(() {
      _textCase = switch (_textCase) {
        _TextCase.sentence => _TextCase.upper,
        _TextCase.upper => _TextCase.lower,
        _TextCase.lower => _TextCase.sentence,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF5A1A0D),
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF5A1A0D),
        appBar: AppBar(backgroundColor: const Color(0xFF5A1A0D), foregroundColor: Colors.white),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(onPressed: () => context.go('/kid/library/${widget.kidId}'), child: const Text('Tilbage', style: TextStyle(color: Colors.white))),
            ],
          ),
        ),
      );
    }

    final coverUrl = _pages.isNotEmpty ? _pages[0]['right_image_url'] as String? : null;

    return Scaffold(
      backgroundColor: const Color(0xFF2C1810),
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          if (!_bookOpened)
            _BuildCoverView(coverUrl: coverUrl, title: _title ?? 'Bog', onTap: _openBook)
          else
            _BuildBookContent(
              pages: _pages,
              currentIndex: _currentSpreadIndex,
              textCase: _textCase,
              audioLibrary: _audioLibrary,
              onPlayWord: _playWord,
              onLongPressWord: _onWordLongPress,
              onPrev: _prevPage,
              onNext: _nextPage,
              onCycleTextCase: _cycleTextCase,
              kidStoryPageFormat:
                  _isKidStoryBook ? _kidStoryPageFormat : null,
            ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  elevation: 4,
                  shadowColor: Colors.black45,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, size: 32, color: Colors.black87),
                    tooltip: 'Til bibliotek',
                    padding: const EdgeInsets.all(12),
                    onPressed: () {
                      if (!context.mounted) return;
                      context.go('/kid/library/${widget.kidId}');
                    },
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: KidParentAdminCornerButton(),
              ),
            ),
          ),
          if (_flashGoldAmount != null)
            Positioned.fill(
              child: GoldCoinsEarnedOverlay(amount: _flashGoldAmount!),
            ),
        ],
      ),
    );
  }
}

class _BuildCoverView extends StatelessWidget {
  final String? coverUrl;
  final String title;
  final VoidCallback onTap;

  const _BuildCoverView({this.coverUrl, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          coverUrl != null && coverUrl!.isNotEmpty
              ? Positioned.fill(
                  child: Center(
                    child: Image.network(coverUrl!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _placeholder()),
                  ),
                )
              : _placeholder(),
          if (coverUrl != null && coverUrl!.isNotEmpty)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Tryk for at åbne', style: TextStyle(color: Colors.white, fontSize: 14)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book, size: 80, color: Colors.brown.shade300),
          const SizedBox(height: 16),
          Padding(padding: const EdgeInsets.all(16), child: Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown.shade800))),
          const SizedBox(height: 24),
          Text('Tryk for at åbne', style: TextStyle(fontSize: 14, color: Colors.brown.shade600)),
        ],
      ),
    );
  }
}

/// Tappable tekst: tryk afspiller (hvis lyd), langt tryk = barnets egen optagelse.
///
/// Bruger [Wrap] med [Text] per segment — ikke [Text.rich] + [WidgetSpan], som
/// på nogle iOS-builds giver `dependents.isEmpty` under unmount.
class _ReaderInlineWords extends StatelessWidget {
  const _ReaderInlineWords({
    required this.text,
    required this.baseStyle,
    required this.audioLibrary,
    required this.onPlayWord,
    required this.onLongPressWord,
  });

  final String text;
  final TextStyle baseStyle;
  final Map<String, String> audioLibrary;
  final void Function(String localPath) onPlayWord;
  final void Function(String normalized, String display) onLongPressWord;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return Text('', textAlign: TextAlign.center, style: baseStyle);
    }
    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth;
        if (maxW <= 0) {
          return const SizedBox.shrink();
        }
        final wordRe = RegExp(r'\b\w+\b');
        final children = <Widget>[];
        var lastEnd = 0;
        for (final match in wordRe.allMatches(text)) {
          if (match.start > lastEnd) {
            children.add(
              Text(
                text.substring(lastEnd, match.start),
                style: baseStyle,
              ),
            );
          }
          final w = match.group(0)!;
          final k = w.toLowerCase();
          final path = audioLibrary[k];
          final has = path != null;
          final style = has
              ? baseStyle.copyWith(
                  color: const Color(0xFF5A1A0D),
                  decoration: TextDecoration.underline,
                  decorationColor: const Color(0xFF5A1A0D),
                )
              : baseStyle;
          children.add(
            GestureDetector(
              onTap: has ? () => onPlayWord(path) : null,
              onLongPress: () => onLongPressWord(k, w),
              behavior: HitTestBehavior.translucent,
              child: Text(w, style: style),
            ),
          );
          lastEnd = match.end;
        }
        if (lastEnd < text.length) {
          children.add(
            Text(
              text.substring(lastEnd),
              style: baseStyle,
            ),
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 0,
              runSpacing: 0,
              children: children,
            ),
          ),
        );
      },
    );
  }
}

/// Fuld skærm: venstre halvdel = tekst (hvid baggrund), højre halvdel = billede. Forside centreret.
class _BuildBookContent extends StatelessWidget {
  final List<Map<String, dynamic>> pages;
  final int currentIndex;
  final _TextCase textCase;
  final Map<String, String> audioLibrary;
  final void Function(String audioUrl) onPlayWord;
  final void Function(String normalized, String display) onLongPressWord;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onCycleTextCase;
  /// Kun for [kid_story_books] — styrer layout; `null` = ældre shop-bog (vandret split).
  final KidStorybookPageFormat? kidStoryPageFormat;

  const _BuildBookContent({
    required this.pages,
    required this.currentIndex,
    required this.textCase,
    required this.audioLibrary,
    required this.onPlayWord,
    required this.onLongPressWord,
    required this.onPrev,
    required this.onNext,
    required this.onCycleTextCase,
    this.kidStoryPageFormat,
  });

  String _applyTextCase(String text) {
    return switch (textCase) {
      _TextCase.sentence => _toSentenceCase(text),
      _TextCase.upper => text.toUpperCase(),
      _TextCase.lower => text.toLowerCase(),
    };
  }

  /// Stort begyndelsesbogstav og stort efter sætningstegn. Følger den indsatte tekst, ingen navneregler.
  String _toSentenceCase(String text) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();
    var capitalizeNext = true;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (capitalizeNext && char.trim().isNotEmpty) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
        if (char == '.' || char == '!' || char == '?' || char == '\n') {
          capitalizeNext = true;
        }
      }
    }
    return buffer.toString();
  }

  String _caseButtonLabel() {
    return switch (textCase) {
      _TextCase.sentence => 'Aa',
      _TextCase.upper => 'AA',
      _TextCase.lower => 'aa',
    };
  }

  static const _bodyTextStyle =
      TextStyle(fontSize: 36, height: 1.6, color: Colors.black);

  /// Frit lægge flere tekstblokke, billeder og figurer som i bogbyggeren, når [page_layout] findes.
  Widget _kidStoryFreeformLayout({
    required Map<String, dynamic> spread,
  }) {
    final leftText = spread['left_text'] as String? ?? '';
    final rightImageUrl = spread['right_image_url'] as String?;
    final textBodyFontSize =
        (spread['text_font_size'] as num?)?.toDouble();
    final textFontKey = spread['text_font_key'] as String?;
    final items = KidStorybookPageItem.fromStoredPage(
      pageLayoutRaw: spread['page_layout'],
      leftText: leftText,
      rightImageUrl: rightImageUrl,
      textFontSize: textBodyFontSize,
      textFontKey: textFontKey,
    );
    if (items.isEmpty) {
      return const ColoredBox(color: Colors.white, child: SizedBox.expand());
    }
    return _kidStoryPageItemsStack(items: items);
  }

  static const _freeformTextMaxBand = 0.36;

  Widget _kidStoryPageItemsStack({required List<KidStorybookPageItem> items}) {
    return ColoredBox(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          if (w <= 0 || h <= 0) {
            return const SizedBox.shrink();
          }
          final baseW = w * 0.58;
          final baseH = baseW * 0.75;
          final decSize = w * 0.22;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (final item in items)
                _kidStoryReaderItemLayer(
                  w: w,
                  h: h,
                  baseW: baseW,
                  baseH: baseH,
                  decSize: decSize,
                  item: item,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _kidStoryReaderItemLayer({
    required double w,
    required double h,
    required double baseW,
    required double baseH,
    required double decSize,
    required KidStorybookPageItem item,
  }) {
    if (item.isImage) {
      final u = (item.imageUrl ?? '').trim();
      if (u.isEmpty) return const SizedBox.shrink();
      final lay = KidStorybookPageLayout(
        imageCx: item.cx,
        imageCy: item.cy,
        imageScale: item.scale,
      );
      return Positioned.fill(
        child: Align(
          alignment: lay.imageAlignment,
          child: Transform.scale(
            scale: item.scale,
            alignment: Alignment.center,
            child: SizedBox(
              width: baseW,
              height: baseH,
              child: Image.network(
                u,
                fit: item.imageFullBleed ? BoxFit.cover : BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => _placeholder(),
              ),
            ),
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
          child: Transform.scale(
            scale: dec.scale,
            alignment: Alignment.center,
            child: SizedBox(
              width: decSize,
              height: decSize,
              child: Center(
                child: kidStorybookDecorationContent(
                  dec,
                  baseSize: decSize * 0.9,
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (item.isText) {
      final t0 = (item.text ?? '').trim();
      if (t0.isEmpty) return const SizedBox.shrink();
      final textStyle = TextStyle(
        fontSize: (item.textFontSize ?? 36).clamp(8, 300).toDouble(),
        height: 1.6,
        color: Colors.black,
        fontFamily: switch ((item.textFontKey ?? 'sans').toLowerCase().trim()) {
          'serif' => 'serif',
          'mono' => 'monospace',
          'system' => null,
          _ => null,
        },
      );
      return Positioned.fill(
        child: Align(
          alignment: Alignment(2 * item.cx - 1, 2 * item.cy - 1),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: w * 0.9,
              maxHeight: h * _freeformTextMaxBand,
            ),
            child: Transform.scale(
              scale: item.scale,
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: w * 0.86,
                  maxHeight: h * _freeformTextMaxBand * 0.92,
                ),
                child: SingleChildScrollView(
                  child: _ReaderInlineWords(
                    text: _applyTextCase(t0),
                    baseStyle: textStyle,
                    audioLibrary: audioLibrary,
                    onPlayWord: onPlayWord,
                    onLongPressWord: onLongPressWord,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// Skærmbøger: standard row; [kid_story_books] følger [KidStorybookPageFormat].
  Widget _kidStoryBodyForFormat({
    required String leftText,
    required String? rightImageUrl,
    required KidStorybookPageFormat? format,
    double? textBodyFontSize,
    String? textFontKey,
  }) {
    final textStyle = format != null
        ? TextStyle(
            fontSize: (textBodyFontSize ?? 36).clamp(8, 300).toDouble(),
            height: 1.6,
            color: Colors.black,
            fontFamily: switch ((textFontKey ?? 'sans').toLowerCase().trim()) {
              'serif' => 'serif',
              'mono' => 'monospace',
              'system' => null,
              _ => null,
            },
          )
        : _bodyTextStyle;
    final textWidget = Container(
      color: Colors.white,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: SingleChildScrollView(
          child: _ReaderInlineWords(
            text: _applyTextCase(leftText),
            baseStyle: textStyle,
            audioLibrary: audioLibrary,
            onPlayWord: onPlayWord,
            onLongPressWord: onLongPressWord,
          ),
        ),
      ),
    );

    Widget imageBox(String? url) {
      return url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : _placeholder();
    }

    if (format == null) {
      return Row(
        children: [
          Expanded(child: textWidget),
          Expanded(child: imageBox(rightImageUrl)),
        ],
      );
    }

    final ar = format.imageAspectWidthOverHeight;

    switch (format) {
      case KidStorybookPageFormat.portrait:
        return Column(
          children: [
            Expanded(
              flex: 3,
              child: Center(
                child: AspectRatio(
                  aspectRatio: ar,
                  child: imageBox(rightImageUrl),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: textWidget,
            ),
          ],
        );
      case KidStorybookPageFormat.landscape:
        return Row(
          children: [
            Expanded(
              flex: 4,
              child: textWidget,
            ),
            Expanded(
              flex: 5,
              child: Center(
                child: AspectRatio(
                  aspectRatio: ar,
                  child: imageBox(rightImageUrl),
                ),
              ),
            ),
          ],
        );
      case KidStorybookPageFormat.square:
        return Row(
          children: [
            Expanded(
              child: textWidget,
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: ar,
                  child: imageBox(rightImageUrl),
                ),
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return const Center(child: Text('Ingen sider', style: TextStyle(color: Colors.white)));
    }

    final spread = pages[currentIndex];
    final isCover = currentIndex == 0;
    final leftText = spread['left_text'] as String? ?? '';
    final rightImageUrl = spread['right_image_url'] as String?;
    final isLast = currentIndex >= pages.length - 1;
    final canGoBack = currentIndex > 0;
    final spreadId = spread['id']?.toString() ?? 'idx$currentIndex';
    // Ny undertræ for hver spredning: undgår iOS/WidgetSpan, hvor
    // renderObject-unmount for RichText+WidgetSpan kan ramme
    // assert(dependents.isEmpty) ved genbrug af element efter skift.
    final spreadSubtreeKey = ValueKey<String>(
      'reader_spread_${currentIndex}_${spreadId}_${textCase.name}',
    );

    return KeyedSubtree(
      key: spreadSubtreeKey,
      child: Stack(
      fit: StackFit.expand,
      children: [
        if (isCover && kidStoryPageFormat == null)
          rightImageUrl != null && rightImageUrl.isNotEmpty
              ? Positioned.fill(
                  child: Center(
                    child: Image.network(
                      rightImageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          _coverPlaceholder(),
                    ),
                  ),
                )
              : _coverPlaceholder()
        else
          (kidStoryPageFormat != null && spread['page_layout'] != null)
              ? _kidStoryFreeformLayout(spread: spread)
              : _kidStoryBodyForFormat(
                  leftText: leftText,
                  rightImageUrl: rightImageUrl,
                  format: kidStoryPageFormat,
                  textBodyFontSize: (spread['text_font_size'] as num?)?.toDouble(),
                  textFontKey: spread['text_font_key'] as String?,
                ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Center(
            child: Material(
              color: Colors.white.withValues(alpha: 0.9),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                icon: Icon(
                  isLast ? Icons.check_circle : Icons.arrow_forward,
                  size: 48,
                  color: Colors.black87,
                ),
                tooltip: isLast ? 'Færdig' : 'Næste side',
                onPressed: onNext,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canGoBack)
                      FilledButton.tonal(
                        onPressed: onPrev,
                        child: const Text('Forrige side', style: TextStyle(fontSize: 16)),
                      ),
                    FilledButton.tonal(
                      onPressed: onCycleTextCase,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        _caseButtonLabel(),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(child: Icon(Icons.menu_book, size: 80, color: Colors.grey)),
    );
  }

  Widget _placeholder() {
    return Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.image, size: 48, color: Colors.grey)));
  }
}

/// Dialog til forældrekode ved afslutning af bog – tildeler point.
class _BookFinishDialog extends StatefulWidget {
  final int pointsToAward;

  const _BookFinishDialog({required this.pointsToAward});

  @override
  State<_BookFinishDialog> createState() => _BookFinishDialogState();
}

class _BookFinishDialogState extends State<_BookFinishDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Afslut bog'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Barnet har læst bogen og kan få ${widget.pointsToAward} point. Indtast forældrekoden for at tildele point.',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
            decoration: const InputDecoration(
              hintText: '••••',
              counterText: '',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Spring over'),
        ),
        FilledButton(
          onPressed: _controller.text.length == 4 ? _submit : null,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5A1A0D)),
          child: const Text('Tildel point'),
        ),
      ],
    );
  }

  void _submit() {
    if (_controller.text.length != 4) return;
    Navigator.of(context).pop(_controller.text);
  }
}
