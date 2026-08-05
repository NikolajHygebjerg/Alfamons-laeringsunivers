import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/kid_storybook_page_format.dart';
import 'kid_story_shelf_front_cover.dart';
import 'library_cabinet_background.dart';

/// Op til 2 pr. hylde (større forsider), fylder fra oven; overskud på nederste hylde.
List<List<Map<String, dynamic>>> distributeBooksOnCabinetShelves(
  List<Map<String, dynamic>> items,
) {
  const maxPerShelf = 2;
  final n = LibraryCabinetShelfLayout.shelfCount;
  if (items.isEmpty) {
    return List.generate(n, (_) => <Map<String, dynamic>>[]);
  }
  final rows = <List<Map<String, dynamic>>>[];
  for (var i = 0; i < items.length; i += maxPerShelf) {
    rows.add(
      items.sublist(
        i,
        math.min(i + maxPerShelf, items.length),
      ),
    );
  }
  if (rows.length > n) {
    final overflow = <Map<String, dynamic>>[];
    for (var r = n - 1; r < rows.length; r++) {
      overflow.addAll(rows[r]);
    }
    rows.removeRange(n, rows.length);
    rows[n - 1] = [...rows[n - 1], ...overflow];
  }
  while (rows.length < n) {
    rows.add([]);
  }
  return rows;
}

/// Hylder matchet til [LibraryCabinetShelfLayout.shelfBands] og [LibraryCabinetBackground].
class BogskabShelfOverlay extends StatelessWidget {
  const BogskabShelfOverlay({
    super.key,
    required this.maxWidth,
    required this.maxHeight,
    required this.kidId,
    required this.booksPerShelf,
    required this.isTablet,
    this.onBookTapOverride,
    this.onDeleteKidStoryBook,
  });

  final double maxWidth;
  final double maxHeight;
  final String kidId;
  final List<List<Map<String, dynamic>>> booksPerShelf;
  final bool isTablet;
  final void Function(Map<String, dynamic> item)? onBookTapOverride;
  /// Kun bogbygger: slet-knap på forsider.
  final void Function(Map<String, dynamic> item)? onDeleteKidStoryBook;

  static const double _coverAspect = 1.42;

  static double _sideInset(double w) =>
      (w * 0.055).clamp(12.0, 48.0) + 12.0;

  @override
  Widget build(BuildContext context) {
    if (maxHeight <= 1 || maxWidth <= 1) {
      return const SizedBox.shrink();
    }

    final inset = _sideInset(maxWidth);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var s = 0;
            s < booksPerShelf.length &&
                s < LibraryCabinetShelfLayout.shelfBands.length;
            s++)
          Positioned(
            left: inset,
            right: inset,
            top: maxHeight *
                LibraryCabinetShelfLayout.shelfBands[s].top.clamp(
                  0.0,
                  0.92,
                ),
            height: maxHeight *
                (LibraryCabinetShelfLayout.shelfBands[s].bottom -
                    LibraryCabinetShelfLayout.shelfBands[s].top),
            child: CabinetShelfRow(
              shelfBooks: booksPerShelf[s],
              kidId: kidId,
              isTablet: isTablet,
              coverAspect: _coverAspect,
              overlayOnArtwork: true,
              overlayLayoutWidthSlots: 2,
              onBookTapOverride: onBookTapOverride,
              onDeleteKidStoryBook: onDeleteKidStoryBook,
            ),
          ),
      ],
    );
  }
}

/// Én hylde – enten i overlay mod [bogskabbaggrund] eller tidligere skabs-layout.
class CabinetShelfRow extends StatelessWidget {
  const CabinetShelfRow({
    super.key,
    required this.shelfBooks,
    required this.kidId,
    required this.isTablet,
    required this.coverAspect,
    this.overlayOnArtwork = false,
    this.overlayLayoutWidthSlots,
    this.onBookTapOverride,
    this.onDeleteKidStoryBook,
  });

  final List<Map<String, dynamic>> shelfBooks;
  final String kidId;
  final bool isTablet;
  final double coverAspect;
  final bool overlayOnArtwork;
  final int? overlayLayoutWidthSlots;
  final void Function(Map<String, dynamic> item)? onBookTapOverride;
  final void Function(Map<String, dynamic> item)? onDeleteKidStoryBook;

  static ({double bookW, double bookH, double titleH, double gap})
      layoutForRow({
    required double innerW,
    required double rowMaxHeight,
    required int bookCount,
    required bool isTablet,
    required double coverAspect,
    bool captionBelow = true,
    int? widthSlots,
    double bookScaleFactor = 1.95,
    double widthCapFraction = 0.364,
  }) {
    final gap = isTablet ? 8.0 : 5.0;
    if (bookCount <= 0 || innerW <= 0 || rowMaxHeight <= 0) {
      return (bookW: 48.0, bookH: 48.0, titleH: 0.0, gap: gap);
    }

    final slotCount = math.max(1, widthSlots ?? bookCount);

    var titleH = captionBelow
        ? (rowMaxHeight * 0.24).clamp(10.0, 22.0)
        : 0.0;
    const verticalPad = 4.0;
    var maxBodyH = rowMaxHeight - titleH - verticalPad;
    if (maxBodyH < 6) {
      titleH = math.max(0.0, rowMaxHeight - verticalPad - 8);
      maxBodyH = math.max(4.0, rowMaxHeight - titleH - verticalPad);
    }

    final fromRow = (innerW - (slotCount - 1) * gap) / slotCount;
    final capW = math.min(
      innerW * widthCapFraction,
      rowMaxHeight * coverAspect * 0.92,
    );
    var bookW = math.min(fromRow, capW);
    var bookH = math.min(bookW * coverAspect, maxBodyH);
    bookW = bookH / coverAspect;

    var needW = slotCount * bookW + (slotCount - 1) * gap;
    if (needW > innerW + 0.5) {
      bookW = (innerW - (slotCount - 1) * gap) / slotCount;
      bookH = math.min(bookW * coverAspect, maxBodyH);
      bookW = bookH / coverAspect;
    }

    const minBookW = 30.0;
    if (bookW < minBookW) {
      final hAtMin = minBookW * coverAspect;
      if (hAtMin <= maxBodyH) {
        bookW = minBookW;
        bookH = hAtMin;
      } else {
        bookH = maxBodyH;
        bookW = bookH / coverAspect;
      }
    }

    bookW *= bookScaleFactor;
    bookH *= bookScaleFactor;
    bookH = math.min(bookH, maxBodyH);
    bookW = bookH / coverAspect;
    var totalW = bookCount * bookW + (bookCount - 1) * gap;
    if (totalW > innerW + 0.5) {
      bookW = (innerW - (bookCount - 1) * gap) / bookCount;
      bookH = math.min(bookW * coverAspect, maxBodyH);
      bookW = bookH / coverAspect;
    }

    return (bookW: bookW, bookH: bookH, titleH: titleH, gap: gap);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final innerW = c.maxWidth;
        final rowH = c.maxHeight;
        final n = shelfBooks.length;

        if (n == 0) {
          return overlayOnArtwork
              ? const SizedBox.expand()
              : ColoredBox(
                  color: const Color(0xFF4E342E).withValues(alpha: 0.25),
                  child: const Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(height: 3, width: double.infinity),
                  ),
                );
        }

        final layout = layoutForRow(
          innerW: innerW,
          rowMaxHeight: rowH,
          bookCount: n,
          isTablet: isTablet,
          coverAspect: coverAspect,
          captionBelow: !overlayOnArtwork,
          widthSlots: overlayOnArtwork ? overlayLayoutWidthSlots : null,
          bookScaleFactor: overlayOnArtwork ? 2.45 : 1.95,
          widthCapFraction: overlayOnArtwork ? 0.48 : 0.364,
        );

        final need =
            n * layout.bookW + (n > 0 ? (n - 1) * layout.gap : 0);
        final overflowW = need > innerW + 0.5;

        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) SizedBox(width: layout.gap),
              ShelfBookTile(
                item: shelfBooks[i],
                kidId: kidId,
                width: layout.bookW,
                height: layout.bookH,
                titleStripHeight: layout.titleH,
                titleFontSize: (layout.bookW * 0.2).clamp(7.0, 12.0),
                showCaptionBelow: !overlayOnArtwork,
                onBookTapOverride: onBookTapOverride,
                onDeleteKidStoryBook: onDeleteKidStoryBook,
              ),
            ],
          ],
        );

        final scroll = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(
            left: 4,
            right: 4,
            bottom: overlayOnArtwork ? 4 : 2,
          ),
          physics: overflowW
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: row,
        );

        if (overlayOnArtwork) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: scroll,
          );
        }

        return DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF5D4037), width: 5),
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: scroll,
          ),
        );
      },
    );
  }
}

class ShelfBookTile extends StatelessWidget {
  const ShelfBookTile({
    super.key,
    required this.item,
    required this.kidId,
    required this.width,
    required this.height,
    required this.titleStripHeight,
    required this.titleFontSize,
    this.showCaptionBelow = true,
    this.onBookTapOverride,
    this.onDeleteKidStoryBook,
  });

  final Map<String, dynamic> item;
  final String kidId;
  final double width;
  final double height;
  final double titleStripHeight;
  final double titleFontSize;
  final bool showCaptionBelow;
  final void Function(Map<String, dynamic> item)? onBookTapOverride;
  final void Function(Map<String, dynamic> item)? onDeleteKidStoryBook;

  bool get _isGroup => item['_kind'] == 'group';

  bool get _isKidStory => item['_kind'] == 'kid_story';

  @override
  Widget build(BuildContext context) {
    final id = item['id'] as String;
    final title = _isGroup
        ? (item['name'] as String? ?? 'Gruppe')
        : (item['title'] as String? ?? 'Bog');
    final coverUrl =
        _isGroup ? null : (item['cover_url'] as String?);

    final front = item['front_page'];
    final inner = _isGroup
        ? ColoredBox(
            color: const Color(0xFF6D4C41),
            child: Center(
              child: Icon(
                Icons.folder_special_rounded,
                size: (width * 0.55).clamp(22.0, 48.0),
                color: const Color(0xFFFFF8E1),
              ),
            ),
          )
        : _isKidStory && front is Map
            ? ColoredBox(
                color: const Color(0xFF4E342E),
                child: KidStoryShelfFrontCover(
                  frontPage: Map<String, dynamic>.from(front),
                  pageFormat: KidStorybookPageFormatX.fromDb(
                    item['page_format'] as String?,
                  ),
                ),
              )
            : (coverUrl != null && coverUrl.isNotEmpty
                ? ColoredBox(
                    color: const Color(0xFF4E342E),
                    child: Image.network(
                      coverUrl,
                      fit: BoxFit.contain,
                      width: width,
                      height: height,
                      alignment: Alignment.center,
                      errorBuilder: (_, _, _) => _bookFallback(title),
                    ),
                  )
                : _bookFallback(title));

    final tile = SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 6,
                    offset: Offset(3, 4),
                  ),
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 2,
                    offset: Offset(-1, 0),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF4E342E),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    inner,
                    if (onDeleteKidStoryBook != null &&
                        !_isGroup &&
                        _isKidStory)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Material(
                          color: const Color(0xB3000000),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints.tight(
                              Size.square((width * 0.22).clamp(26, 36)),
                            ),
                            icon: Icon(
                              Icons.delete_outline,
                              size: (width * 0.12).clamp(16, 22),
                              color: Colors.white,
                            ),
                            tooltip: 'Slet bog',
                            onPressed: () => onDeleteKidStoryBook!(item),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (showCaptionBelow && titleStripHeight > 0)
            SizedBox(
              height: titleStripHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width + 8),
                  child: Text(
                    title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.05,
                      shadows: const [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 4,
                          offset: Offset(0, 1),
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

    void onTap() {
      if (onBookTapOverride != null) {
        onBookTapOverride!(item);
        return;
      }
      if (_isGroup) {
        context.push('/kid/library/$kidId/group/$id');
      } else {
        context.push('/kid/library/$kidId/book/$id');
      }
    }

    void onLongPress() {
      if (onBookTapOverride != null) return;
      if (_isKidStory) {
        context.push('/kid/storybook/$kidId?book=$id');
      }
    }

    final ink = InkWell(
      onTap: onTap,
      onLongPress: _isKidStory ? onLongPress : null,
      borderRadius: BorderRadius.circular(4),
      child: showCaptionBelow
          ? tile
          : Semantics(
              label: title,
              button: true,
              child: tile,
            ),
    );

    return Material(
      color: Colors.transparent,
      child: showCaptionBelow
          ? ink
          : Tooltip(
              message: title,
              preferBelow: false,
              child: ink,
            ),
    );
  }

  Widget _bookFallback(String title) {
    return ColoredBox(
      color: const Color(0xFF5D4037),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            title,
            maxLines: 4,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFFF8E1),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
