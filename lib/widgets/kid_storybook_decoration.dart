import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/kid_storybook_page_decoration.dart';

/// Søgning / visning: dansk label.
typedef KidStorybookIconEntry = ({String id, IconData icon, String label});

/// Foruddefineret figur med standardfarve.
typedef KidStorybookShapeEntry = ({String id, String label, Color color});

List<KidStorybookIconEntry> get kidStorybookIconCatalog => const [
      (id: 'pets', icon: Icons.pets, label: 'pote dyr'),
      (id: 'favorite', icon: Icons.favorite, label: 'hjerte'),
      (id: 'home', icon: Icons.home, label: 'hus'),
      (id: 'wb_sunny', icon: Icons.wb_sunny, label: 'sol'),
      (id: 'local_florist', icon: Icons.local_florist, label: 'blomst'),
      (id: 'park', icon: Icons.park, label: 'træ'),
      (id: 'water_drop', icon: Icons.water_drop, label: 'dråbe'),
      (id: 'face', icon: Icons.face, label: 'ansigt'),
      (id: 'groups', icon: Icons.groups, label: 'folk'),
      (id: 'person', icon: Icons.person, label: 'person'),
      (id: 'face_6', icon: Icons.face_6, label: 'barn'),
      (id: 'nightlight', icon: Icons.nightlight, label: 'måne'),
      (id: 'menu_book', icon: Icons.menu_book, label: 'bog'),
      (id: 'directions_car', icon: Icons.directions_car, label: 'bil'),
      (id: 'cloud', icon: Icons.cloud, label: 'sky'),
      (id: 'public', icon: Icons.public, label: 'globus'),
      (id: 'set_meal', icon: Icons.set_meal, label: 'fisk'),
      (id: 'auto_awesome', icon: Icons.auto_awesome, label: 'stjerner'),
      (id: 'check_circle', icon: Icons.check_circle, label: 'flueben'),
      (id: 'cancel', icon: Icons.cancel, label: 'kryds'),
      (id: 'lightbulb', icon: Icons.lightbulb, label: 'pære'),
      (id: 'sports_soccer', icon: Icons.sports_soccer, label: 'bold'),
      (id: 'flight', icon: Icons.flight, label: 'fly'),
      (id: 'beach_access', icon: Icons.beach_access, label: 'strand'),
    ];

List<KidStorybookShapeEntry> get kidStorybookShapeCatalog => const [
      (id: 's_square', label: 'Firkant', color: Color(0xFF1565C0)),
      (id: 's_rrect', label: 'Rund kant', color: Color(0xFFEC407A)),
      (id: 's_circle', label: 'Cirkel', color: Color(0xFF7E57C2)),
      (id: 's_star', label: 'Stjerne', color: Color(0xFFFFC107)),
      (id: 's_heart', label: 'Hjerte', color: Color(0xFFE53935)),
      (id: 's_tri', label: 'Trekant', color: Color(0xFF26C6DA)),
      (id: 's_rtri', label: 'Vinkel', color: Color(0xFF5E35B1)),
      (id: 's_pent', label: 'Femkant', color: Color(0xFF00897B)),
      (id: 's_hex', label: 'Sekskant', color: Color(0xFF43A047)),
      (id: 's_bubble', label: 'Taleboble (klassisk)', color: Color(0xFF78909C)),
      (id: 's_bubble_round', label: 'Rund taleboble', color: Color(0xFF90A4AE)),
      (id: 's_bubble_thought', label: 'Tankeboble', color: Color(0xFF5C6BC0)),
      (id: 's_bubble_shout', label: 'Råbe-boble', color: Color(0xFFEF5350)),
      (id: 's_bubble_cloud', label: 'Skyboble', color: Color(0xFF4FC3F7)),
      (id: 's_bubble_oval', label: 'Oval fra siden', color: Color(0xFF66BB6A)),
      (id: 's_bubble_double', label: 'Dobbeltboble', color: Color(0xFFAB47BC)),
      (id: 's_arrow', label: 'Pil', color: Color(0xFF37474F)),
      (id: 's_ribbon', label: 'Bånd', color: Color(0xFFFF8F00)),
    ];

IconData? kidStorybookIconDataForId(String id) {
  for (final e in kidStorybookIconCatalog) {
    if (e.id == id) return e.icon;
  }
  return null;
}

Color kidStorybookShapeColorForId(String id) {
  for (final e in kidStorybookShapeCatalog) {
    if (e.id == id) return e.color;
  }
  return const Color(0xFF1976D2);
}

/// Indhold til ikon- eller form-lag (kvadratisk lærred, centreres i [baseSize]).
Widget kidStorybookDecorationContent(
  KidStorybookPageDecoration d, {
  required double baseSize,
}) {
  if (d.isIcon) {
    final icon = kidStorybookIconDataForId(d.id) ?? Icons.star;
    return Icon(
      icon,
      size: baseSize * 0.88,
      color: Colors.black87,
    );
  }
  return _ShapeShape(
    id: d.id,
    size: baseSize * 0.92,
    color: d.colorValue != null
        ? Color(d.colorValue! & 0xFFFFFFFF)
        : kidStorybookShapeColorForId(d.id),
  );
}

class _ShapeShape extends StatelessWidget {
  const _ShapeShape({
    required this.id,
    required this.size,
    required this.color,
  });

  final String id;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (id) {
      case 's_square':
        return Container(
          width: size,
          height: size,
          color: color,
        );
      case 's_rrect':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size * 0.18),
          ),
        );
      case 's_circle':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        );
      case 's_star':
        return CustomPaint(
          size: Size(size, size),
          painter: _StarPainter(color: color),
        );
      case 's_heart':
        return Icon(
          Icons.favorite,
          size: size,
          color: color,
        );
      case 's_tri':
        return CustomPaint(
          size: Size(size, size),
          painter: _TriPainter(color: color),
        );
      case 's_rtri':
        return CustomPaint(
          size: Size(size, size),
          painter: _RTriPainter(color: color),
        );
      case 's_pent':
        return CustomPaint(
          size: Size(size, size),
          painter: _PolygonPainter(sides: 5, color: color),
        );
      case 's_hex':
        return CustomPaint(
          size: Size(size, size),
          painter: _PolygonPainter(sides: 6, color: color),
        );
      case 's_bubble':
        return CustomPaint(
          size: Size(size, size),
          painter: _SpeechBubblePainter(color: color),
        );
      case 's_bubble_round':
        return CustomPaint(
          size: Size(size, size),
          painter: _SpeechBubbleRoundPainter(color: color),
        );
      case 's_bubble_thought':
        return CustomPaint(
          size: Size(size, size),
          painter: _ThoughtBubblePainter(color: color),
        );
      case 's_bubble_shout':
        return CustomPaint(
          size: Size(size, size),
          painter: _ShoutBubblePainter(color: color),
        );
      case 's_bubble_cloud':
        return CustomPaint(
          size: Size(size, size),
          painter: _CloudBubblePainter(color: color),
        );
      case 's_bubble_oval':
        return CustomPaint(
          size: Size(size, size),
          painter: _OvalSideTailBubblePainter(color: color),
        );
      case 's_bubble_double':
        return CustomPaint(
          size: Size(size, size),
          painter: _DoubleBubblePainter(color: color),
        );
      case 's_arrow':
        return Icon(
          Icons.arrow_forward,
          size: size * 0.9,
          color: color,
        );
      case 's_ribbon':
        return CustomPaint(
          size: Size(size, size),
          painter: _RibbonPainter(color: color),
        );
      default:
        return CustomPaint(
          size: Size(size, size),
          painter: _PolygonPainter(sides: 4, color: color),
        );
    }
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.48;
    const points = 5;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final rad = (i * math.pi / points) - math.pi / 2;
      final dist = (i.isEven) ? r : r * 0.42;
      final x = c.dx + dist * math.cos(rad);
      final y = c.dy + dist * math.sin(rad);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => oldDelegate.color != color;
}

class _TriPainter extends CustomPainter {
  _TriPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TriPainter oldDelegate) => oldDelegate.color != color;
}

class _RTriPainter extends CustomPainter {
  _RTriPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, h)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RTriPainter oldDelegate) => oldDelegate.color != color;
}

class _PolygonPainter extends CustomPainter {
  _PolygonPainter({required this.sides, required this.color});

  final int sides;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.45;
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final a = (i * 2 * math.pi / sides) - math.pi / 2;
      final p = c + Offset(r * math.cos(a), r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PolygonPainter oldDelegate) =>
      oldDelegate.sides != sides || oldDelegate.color != color;
}

class _SpeechBubblePainter extends CustomPainter {
  _SpeechBubblePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.08;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(0, 0, w, h * 0.7),
      Radius.circular(r),
    );
    final path = Path()..addRRect(rect);
    final tail = Path()
      ..moveTo(w * 0.2, h * 0.68)
      ..lineTo(w * 0.35, h)
      ..lineTo(w * 0.5, h * 0.7)
      ..close();
    path.addPath(tail, Offset.zero);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Pilleform med hale midt for neden.
class _SpeechBubbleRoundPainter extends CustomPainter {
  _SpeechBubbleRoundPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyH = h * 0.72;
    final br = (bodyH * 0.5).clamp(2.0, w * 0.36);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, bodyH * 0.5),
        width: w * 0.92,
        height: bodyH,
      ),
      Radius.circular(br),
    );
    final path = Path()..addRRect(rect);
    final tail = Path()
      ..moveTo(w * 0.38, bodyH * 0.88)
      ..lineTo(w * 0.5, h * 0.98)
      ..lineTo(w * 0.62, bodyH * 0.88)
      ..close();
    path.addPath(tail, Offset.zero);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubbleRoundPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Tankeboble: hoved + to små cirkler.
class _ThoughtBubblePainter extends CustomPainter {
  _ThoughtBubblePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()..color = color;
    final rMain = w * 0.28;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.52, h * 0.34),
          width: w * 0.78,
          height: h * 0.48,
        ),
        const Radius.circular(16),
      ),
      p,
    );
    canvas.drawCircle(Offset(w * 0.22, h * 0.7), w * 0.09, p);
    canvas.drawCircle(Offset(w * 0.12, h * 0.86), w * 0.055, p);
  }

  @override
  bool shouldRepaint(covariant _ThoughtBubblePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// "Råbe" med takket kant.
class _ShoutBubblePainter extends CustomPainter {
  _ShoutBubblePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.42;
    const spikes = 16;
    final outerR = w * 0.46;
    final innerR = w * 0.34;
    final path = Path();
    for (var i = 0; i < spikes; i++) {
      final a = (i * 2 * math.pi / spikes) - math.pi / 2;
      final isOuter = i.isEven;
      final rr = isOuter ? outerR : innerR;
      final x = cx + rr * math.cos(a);
      final y = cy + rr * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    final tail = Path()
      ..moveTo(w * 0.4, h * 0.65)
      ..lineTo(w * 0.5, h * 0.95)
      ..lineTo(w * 0.6, h * 0.65)
      ..close();
    path.addPath(tail, Offset.zero);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ShoutBubblePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Fluffy sky: sammensatte buer.
class _CloudBubblePainter extends CustomPainter {
  _CloudBubblePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()..color = color;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.35, h * 0.42),
        width: w * 0.42,
        height: h * 0.38,
      ),
      p,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.65, h * 0.4),
        width: w * 0.48,
        height: h * 0.42,
      ),
      p,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.52),
        width: w * 0.55,
        height: h * 0.35,
      ),
      p,
    );
    final tail = Path()
      ..moveTo(w * 0.4, h * 0.68)
      ..lineTo(w * 0.5, h * 0.95)
      ..lineTo(w * 0.6, h * 0.68)
      ..close();
    canvas.drawPath(tail, p);
  }

  @override
  bool shouldRepaint(covariant _CloudBubblePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Oval med hale til venstre (tegneserie).
class _OvalSideTailBubblePainter extends CustomPainter {
  _OvalSideTailBubblePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.12, w * 0.72, h * 0.58),
      Radius.circular(h * 0.14),
    );
    final path = Path()..addRRect(rect);
    final tail = Path()
      ..moveTo(w * 0.18, h * 0.35)
      ..lineTo(0, h * 0.48)
      ..lineTo(w * 0.2, h * 0.55)
      ..close();
    path.addPath(tail, Offset.zero);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _OvalSideTailBubblePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// To overlappende bobler (dialog).
class _DoubleBubblePainter extends CustomPainter {
  _DoubleBubblePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final a = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.04, h * 0.18, w * 0.52, h * 0.48),
      Radius.circular(w * 0.12),
    );
    final b = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.34, h * 0.1, w * 0.58, h * 0.52),
      Radius.circular(w * 0.12),
    );
    final path = Path.combine(
      PathOperation.union,
      Path()..addRRect(a),
      Path()..addRRect(b),
    );
    final tail = Path()
      ..moveTo(w * 0.4, h * 0.7)
      ..lineTo(w * 0.5, h * 0.95)
      ..lineTo(w * 0.6, h * 0.7)
      ..close();
    path.addPath(tail, Offset.zero);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DoubleBubblePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.1, 0)
      ..lineTo(w * 0.9, 0)
      ..lineTo(w * 0.85, h * 0.55)
      ..lineTo(w * 0.5, h * 0.88)
      ..lineTo(w * 0.15, h * 0.55)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) => oldDelegate.color != color;
}
