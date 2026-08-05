import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Alignment;

/// Dekoration (ikon eller farvet figur) på en kids-bogside — gemmes i [page_layout] under `dec`.
@immutable
class KidStorybookPageDecoration {
  const KidStorybookPageDecoration({
    required this.kind,
    required this.id,
    this.cx = 0.52,
    this.cy = 0.48,
    this.scale = 1.0,
    this.colorValue,
  });

  /// [kKindIcon] = Material-ikon (id), [kKindShape] = foruddefineret figur + farve.
  final String kind;
  final String id;
  final double cx;
  final double cy;
  final double scale;
  final int? colorValue;

  static const String kKindIcon = 'i';
  static const String kKindShape = 's';

  static const double kEditMinPos = -0.5;
  static const double kEditMaxPos = 1.5;
  static const double kEditMinScale = 0.08;
  static const double kEditMaxScale = 14.0;

  bool get isIcon => kind == kKindIcon;
  bool get isShape => kind == kKindShape;

  KidStorybookPageDecoration copyWith({
    String? kind,
    String? id,
    double? cx,
    double? cy,
    double? scale,
    Object? colorValue = _sentinel,
  }) {
    return KidStorybookPageDecoration(
      kind: kind ?? this.kind,
      id: id ?? this.id,
      cx: cx ?? this.cx,
      cy: cy ?? this.cy,
      scale: scale ?? this.scale,
      colorValue: identical(colorValue, _sentinel)
          ? this.colorValue
          : colorValue as int?,
    );
  }

  static const Object _sentinel = Object();

  Map<String, dynamic> toJson() {
    return {
      'k': kind,
      'id': id,
      'cx': cx,
      'cy': cy,
      's': scale,
      if (colorValue != null) 'c': colorValue,
    };
  }

  static KidStorybookPageDecoration? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final k = (m['k'] as String?)?.trim() ?? '';
    if (k != kKindIcon && k != kKindShape) return null;
    final id = (m['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return null;
    return KidStorybookPageDecoration(
      kind: k,
      id: id,
      cx: _clampPos(m['cx'] as num?, 0.52),
      cy: _clampPos(m['cy'] as num?, 0.48),
      scale: _clampScale(m['s'] as num?, 1.0),
      colorValue: _parseColor(m['c']),
    );
  }

  static int? _parseColor(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double _clampPos(num? v, double d) {
    if (v == null) return d;
    return v.toDouble().clamp(kEditMinPos, kEditMaxPos);
  }

  static double _clampScale(num? v, double d) {
    if (v == null) return d;
    return v.toDouble().clamp(kEditMinScale, kEditMaxScale);
  }
}

extension KidStorybookPageDecorationAlignmentX on KidStorybookPageDecoration {
  Alignment get layoutAlignment => Alignment(2 * cx - 1, 2 * cy - 1);
}
