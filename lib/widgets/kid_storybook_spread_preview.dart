import 'package:flutter/material.dart';

import '../models/kid_storybook_page_decoration.dart';
import '../models/kid_storybook_page_item.dart';
import '../models/kid_storybook_page_layout.dart';
import 'asset_or_network_image.dart';
import 'kid_storybook_decoration.dart';

/// Én bogsides indhold (fri placering) — samme koordinater som læser og bogbygger.
class KidStorybookSpreadPreview extends StatelessWidget {
  const KidStorybookSpreadPreview({
    super.key,
    required this.spread,
  });

  final Map<String, dynamic> spread;

  static const _textBandH = 0.36;

  @override
  Widget build(BuildContext context) {
    final leftText = spread['left_text'] as String? ?? '';
    final rightImageUrl = spread['right_image_url'] as String?;
    final textBodyFontSize = (spread['text_font_size'] as num?)?.toDouble();
    final textFontKey = spread['text_font_key'] as String?;
    final items = KidStorybookPageItem.fromStoredPage(
      pageLayoutRaw: spread['page_layout'],
      leftText: leftText,
      rightImageUrl: rightImageUrl,
      textFontSize: textBodyFontSize,
      textFontKey: textFontKey,
    );
    if (items.isEmpty) {
      return const ColoredBox(
        color: Colors.white,
        child: SizedBox.expand(),
      );
    }
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
              for (final it in items)
                _itemLayer(
                  w: w,
                  h: h,
                  baseW: baseW,
                  baseH: baseH,
                  decSize: decSize,
                  item: it,
                ),
            ],
          );
        },
      ),
    );
  }

  static Widget _itemLayer({
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
              child: AssetOrNetworkImage(
                src: u,
                fit: item.imageFullBleed ? BoxFit.cover : BoxFit.contain,
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
              maxHeight: h * _textBandH,
            ),
            child: Transform.scale(
              scale: item.scale,
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: w * 0.86,
                  maxHeight: h * _textBandH * 0.92,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    t0,
                    textAlign: TextAlign.center,
                    style: textStyle,
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
}
