import 'dart:convert' show jsonDecode;

import 'package:flutter/material.dart';

import 'kid_storybook_page_decoration.dart';

/// Frit lægge tekst/billede/figur på siden: normaliserede midtpunkter (0–1) og skalaer.
@immutable
class KidStorybookPageLayout {
  const KidStorybookPageLayout({
    this.imageCx = 0.5,
    this.imageCy = 0.38,
    this.imageScale = 1.0,
    this.textCx = 0.5,
    this.textCy = 0.12,
    this.textScale = 1.0,
    this.decoration,
  });

  final double imageCx;
  final double imageCy;
  final double imageScale;
  final double textCx;
  final double textCy;
  final double textScale;
  final KidStorybookPageDecoration? decoration;

  static const int jsonVersion = 1;

  /// Grænser (redigering) — matcher [fromJson].
  static const double kEditMinPos = -0.5;
  static const double kEditMaxPos = 1.5;
  static const double kEditMinImageScale = 0.05;
  static const double kEditMaxImageScale = 32.0;
  static const double kEditMinTextScale = 0.12;
  static const double kEditMaxTextScale = 12.0;

  KidStorybookPageLayout copyWith({
    double? imageCx,
    double? imageCy,
    double? imageScale,
    double? textCx,
    double? textCy,
    double? textScale,
    KidStorybookPageDecoration? decoration,
    bool clearDecoration = false,
  }) {
    return KidStorybookPageLayout(
      imageCx: imageCx ?? this.imageCx,
      imageCy: imageCy ?? this.imageCy,
      imageScale: imageScale ?? this.imageScale,
      textCx: textCx ?? this.textCx,
      textCy: textCy ?? this.textCy,
      textScale: textScale ?? this.textScale,
      decoration:
          clearDecoration ? null : (decoration ?? this.decoration),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'v': jsonVersion,
      'icx': imageCx,
      'icy': imageCy,
      'is': imageScale,
      'tcx': textCx,
      'tcy': textCy,
      'ts': textScale,
      if (decoration != null) 'dec': decoration!.toJson(),
    };
  }

  /// [kid_story_book_pages.page_layout] fra PostgREST: jsonb som `Map`, nogle gange `String`, eller `null`.
  static KidStorybookPageLayout fromDb(dynamic raw) {
    if (raw == null) return const KidStorybookPageLayout();
    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return const KidStorybookPageLayout();
      try {
        final d = jsonDecode(t);
        return fromJson(d);
      } catch (_) {
        return const KidStorybookPageLayout();
      }
    }
    if (raw is Map) {
      return fromJson(Map<String, dynamic>.from(raw));
    }
    return const KidStorybookPageLayout();
  }

  static KidStorybookPageLayout fromJson(dynamic raw) {
    if (raw is! Map) {
      return const KidStorybookPageLayout();
    }
    final m = Map<String, dynamic>.from(raw);
    final v = (m['v'] as num?)?.toInt();
    // `v` manglede i ældre klienter: må ikke nulstille hele layoutet. v2 bruger [items] i [kid_storybook_page_item].
    if (v != null && v != jsonVersion && v != 2) {
      return const KidStorybookPageLayout();
    }
    if (v == 2) {
      return const KidStorybookPageLayout();
    }
    return KidStorybookPageLayout(
      imageCx: _clampPos(
        m['icx'] as num?,
        0.5,
      ),
      imageCy: _clampPos(
        m['icy'] as num?,
        0.38,
      ),
      imageScale: _clampImageScale(
        m['is'] as num?,
        1.0,
      ),
      textCx: _clampTextPos(
        m['tcx'] as num?,
        0.5,
      ),
      textCy: _clampTextPos(
        m['tcy'] as num?,
        0.12,
      ),
      textScale: _clampTextScale(
        m['ts'] as num?,
        1.0,
      ),
      decoration: KidStorybookPageDecoration.fromJson(m['dec']),
    );
  }

  static double _clampPos(num? v, double d) {
    if (v == null) return d;
    return v.toDouble().clamp(kEditMinPos, kEditMaxPos);
  }

  static double _clampTextPos(num? v, double d) {
    if (v == null) return d;
    return v.toDouble().clamp(kEditMinPos, kEditMaxPos);
  }

  static double _clampImageScale(num? v, double d) {
    if (v == null) return d;
    return v
        .toDouble()
        .clamp(kEditMinImageScale, kEditMaxImageScale);
  }

  static double _clampTextScale(num? v, double d) {
    if (v == null) return d;
    return v.toDouble().clamp(kEditMinTextScale, kEditMaxTextScale);
  }
}

extension KidStorybookPageLayoutAlignment on KidStorybookPageLayout {
  Alignment get imageAlignment => Alignment(2 * imageCx - 1, 2 * imageCy - 1);
  Alignment get textAlignment => Alignment(2 * textCx - 1, 2 * textCy - 1);
}
