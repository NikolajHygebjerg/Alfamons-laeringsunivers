import 'package:flutter/material.dart';

import '../../../models/kid_storybook_page_format.dart';
import '../../../models/kid_storybook_page_item.dart';
import '../../../widgets/kid_storybook_spread_preview.dart';

/// Forside (spread 0) med barnets [page_format] og samme layout som læser/bogbygger.
class KidStoryShelfFrontCover extends StatelessWidget {
  const KidStoryShelfFrontCover({
    super.key,
    required this.frontPage,
    this.pageFormat,
  });

  final Map<String, dynamic> frontPage;
  final KidStorybookPageFormat? pageFormat;

  static bool _hasRenderableContent(Map<String, dynamic> p) {
    final left = (p['left_text'] as String? ?? '').trim();
    final url = (p['right_image_url'] as String? ?? '').trim();
    if (left.isNotEmpty || url.isNotEmpty) return true;
    final items = KidStorybookPageItem.fromStoredPage(
      pageLayoutRaw: p['page_layout'],
      leftText: p['left_text'] as String? ?? '',
      rightImageUrl: p['right_image_url'] as String?,
      textFontSize: (p['text_font_size'] as num?)?.toDouble(),
      textFontKey: p['text_font_key'] as String?,
    );
    return items.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final f =
        pageFormat ?? KidStorybookPageFormat.landscape;
    final ar = f.imageAspectWidthOverHeight;

    if (!_hasRenderableContent(frontPage)) {
      return AspectRatio(
        aspectRatio: ar,
        child: const ColoredBox(
          color: Color(0xFFEFEEF0),
          child: Center(
            child: Icon(
              Icons.menu_book,
              size: 32,
              color: Color(0xFF5D4037),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth;
        final maxH = c.maxHeight;
        if (maxW <= 0 || maxH <= 0) {
          return const SizedBox.shrink();
        }
        // Indpas hvid side (format) i hyldetile, som i bogbyggeren.
        double pageW;
        double pageH;
        if (maxW / maxH > ar) {
          pageH = maxH;
          pageW = pageH * ar;
        } else {
          pageW = maxW;
          pageH = pageW / ar;
        }
        return Center(
          child: SizedBox(
            width: pageW,
            height: pageH,
            child: ColoredBox(
              color: Colors.white,
              child: KidStorybookSpreadPreview(spread: frontPage),
            ),
          ),
        );
      },
    );
  }
}
