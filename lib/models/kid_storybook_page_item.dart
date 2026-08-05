import 'dart:convert' show jsonDecode;

import 'package:flutter/foundation.dart';

import 'kid_storybook_page_decoration.dart';
import 'kid_storybook_page_layout.dart';

/// Frit lægge indhold: flere billeder, tekstblokke og figurer pr. side (JSON v2 i [page_layout]).
@immutable
class KidStorybookPageItem {
  const KidStorybookPageItem({
    required this.id,
    required this.kind,
    this.cx = 0.5,
    this.cy = 0.4,
    this.scale = 1.0,
    this.imageUrl,
    /// Billeder: [Fyld hele siden] benytter [BoxFit.cover] så siden er uden «huller».
    this.imageFullBleed = false,
    this.text,
    this.textFontSize = 24.0,
    this.textFontKey = 'sans',
    this.decoration,
  });

  static const String kImage = 'im';
  static const String kText = 'tx';
  static const String kFigure = 'fg';

  final String id;
  final String kind;
  final double cx;
  final double cy;
  final double scale;
  final String? imageUrl;
  final bool imageFullBleed;
  final String? text;
  final double? textFontSize;
  final String? textFontKey;
  final KidStorybookPageDecoration? decoration;

  bool get isImage => kind == kImage;
  bool get isText => kind == kText;
  bool get isFigure => kind == kFigure;

  KidStorybookPageItem copyWith({
    String? id,
    String? kind,
    double? cx,
    double? cy,
    double? scale,
    String? imageUrl,
    String? text,
    double? textFontSize,
    String? textFontKey,
    KidStorybookPageDecoration? decoration,
    bool clearDecoration = false,
    bool? imageFullBleed,
  }) {
    return KidStorybookPageItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      cx: cx ?? this.cx,
      cy: cy ?? this.cy,
      scale: scale ?? this.scale,
      imageUrl: imageUrl ?? this.imageUrl,
      imageFullBleed: imageFullBleed ?? this.imageFullBleed,
      text: text ?? this.text,
      textFontSize: textFontSize ?? this.textFontSize,
      textFontKey: textFontKey ?? this.textFontKey,
      decoration:
          clearDecoration ? null : (decoration ?? this.decoration),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'k': kind,
      'cx': cx,
      'cy': cy,
      's': scale,
      if (isImage) ...{
        'u': (imageUrl ?? '').trim().isNotEmpty ? imageUrl : null,
        if (imageFullBleed) 'ib': true,
      },
      if (isText) ...{
        't': text ?? '',
        'fs': textFontSize ?? 24.0,
        'fk': textFontKey ?? 'sans',
      },
      if (isFigure && decoration != null) 'dec': decoration!.toJson(),
    };
  }

  static KidStorybookPageItem? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = (m['id'] as String?)?.trim() ?? '';
    final k = (m['k'] as String?)?.trim() ?? '';
    if (id.isEmpty || (k != kImage && k != kText && k != kFigure)) {
      return null;
    }
    final tScaleMin = KidStorybookPageLayout.kEditMinTextScale;
    final tScaleMax = KidStorybookPageLayout.kEditMaxTextScale;
    final iScaleMin = KidStorybookPageLayout.kEditMinImageScale;
    final iScaleMax = KidStorybookPageLayout.kEditMaxImageScale;
    final fScaleMin = KidStorybookPageDecoration.kEditMinScale;
    final fScaleMax = KidStorybookPageDecoration.kEditMaxScale;
    return KidStorybookPageItem(
      id: id,
      kind: k,
      cx: _cl(
        m['cx'],
        0.5,
        KidStorybookPageLayout.kEditMinPos,
        KidStorybookPageLayout.kEditMaxPos,
      ),
      cy: _cl(
        m['cy'],
        0.4,
        KidStorybookPageLayout.kEditMinPos,
        KidStorybookPageLayout.kEditMaxPos,
      ),
      scale: k == kText
          ? _cl(m['s'], 1.0, tScaleMin, tScaleMax)
          : (k == kImage
              ? _cl(m['s'], 1.0, iScaleMin, iScaleMax)
              : _cl(m['s'], 1.0, fScaleMin, fScaleMax)),
      imageUrl: (m['u'] as String?)?.trim(),
      text: m['t'] as String? ?? '',
      textFontSize: (m['fs'] as num?)?.toDouble() ?? 24.0,
      textFontKey: (m['fk'] as String?)?.trim().isNotEmpty == true
          ? m['fk'] as String
          : 'sans',
      decoration: KidStorybookPageDecoration.fromJson(m['dec']),
      imageFullBleed: k == kImage && m['ib'] == true,
    );
  }

  static double _cl(num? v, double d, double lo, double hi) {
    if (v == null) return d;
    return v.toDouble().clamp(lo, hi);
  }

  static String newId() {
    return 'i${DateTime.now().microsecondsSinceEpoch}';
  }

  static Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return null;
      try {
        final d = jsonDecode(t);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return null;
  }

  static List<KidStorybookPageItem> fromStoredPage({
    required dynamic pageLayoutRaw,
    String? leftText,
    String? rightImageUrl,
    double? textFontSize,
    String? textFontKey,
  }) {
    final m = _asMap(pageLayoutRaw);
    if (m != null) {
      final v = (m['v'] as num?)?.toInt();
      if (v == 2 && m['items'] is List) {
        final out = <KidStorybookPageItem>[];
        for (final e in m['items'] as List) {
          final it = fromJson(e);
          if (it != null) out.add(it);
        }
        if (out.isNotEmpty) return out;
      }
    }
    final layout = KidStorybookPageLayout.fromDb(pageLayoutRaw);
    return _migrateV1(
      leftText: leftText,
      rightImageUrl: rightImageUrl,
      textFontSize: textFontSize,
      textFontKey: textFontKey,
      layout: layout,
    );
  }

  static List<KidStorybookPageItem> _migrateV1({
    String? leftText,
    String? rightImageUrl,
    double? textFontSize,
    String? textFontKey,
    required KidStorybookPageLayout layout,
  }) {
    final list = <KidStorybookPageItem>[];
    final u = (rightImageUrl ?? '').trim();
    if (u.isNotEmpty) {
      list.add(
        KidStorybookPageItem(
          id: newId(),
          kind: kImage,
          cx: layout.imageCx,
          cy: layout.imageCy,
          scale: layout.imageScale,
          imageUrl: u,
        ),
      );
    }
    final t = (leftText ?? '').trim();
    if (t.isNotEmpty) {
      list.add(
        KidStorybookPageItem(
          id: newId(),
          kind: kText,
          cx: layout.textCx,
          cy: layout.textCy,
          scale: layout.textScale,
          text: t,
          textFontSize: textFontSize ?? 24.0,
          textFontKey: (textFontKey != null && textFontKey.trim().isNotEmpty)
              ? textFontKey
              : 'sans',
        ),
      );
    }
    if (layout.decoration != null) {
      list.add(
        KidStorybookPageItem(
          id: newId(),
          kind: kFigure,
          cx: layout.decoration!.cx,
          cy: layout.decoration!.cy,
          scale: layout.decoration!.scale,
          decoration: layout.decoration,
        ),
      );
    }
    return list;
  }

  static Map<String, dynamic> pageLayoutV2Json(List<KidStorybookPageItem> items) {
    return {
      'v': 2,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  static String? firstImageUrl(List<KidStorybookPageItem> items) {
    for (final e in items) {
      if (e.isImage) {
        final u = (e.imageUrl ?? '').trim();
        if (u.isNotEmpty) return u;
      }
    }
    return null;
  }

  static String joinedText(List<KidStorybookPageItem> items) {
    final buf = StringBuffer();
    for (final e in items) {
      if (!e.isText) continue;
      final t0 = (e.text ?? '').trim();
      if (t0.isEmpty) continue;
      if (buf.isNotEmpty) buf.writeln();
      buf.write(t0);
    }
    return buf.toString();
  }

  static double? firstTextFontSize(List<KidStorybookPageItem> items) {
    for (final e in items) {
      if (e.isText) return e.textFontSize ?? 24.0;
    }
    return null;
  }

  static String? firstTextFontKey(List<KidStorybookPageItem> items) {
    for (final e in items) {
      if (e.isText) return e.textFontKey ?? 'sans';
    }
    return null;
  }
}
