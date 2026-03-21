import 'package:flutter/material.dart';

import '../../../services/alfamon_evolution.dart';

/// Fremgang 0–130 med lodrette streger ved udviklingstrin (0, 10, 40, 80, 130).
class AlfamonEvolutionProgressBar extends StatelessWidget {
  final int points;

  const AlfamonEvolutionProgressBar({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final p = points.clamp(0, AlfamonEvolution.maxProgressPoints);
    final maxP = AlfamonEvolution.maxProgressPoints.toDouble();
    final thresholds = AlfamonEvolution.stageThresholds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            const h = 18.0;
            final fillW = (w * p / maxP).clamp(0.0, w);

            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: h,
                width: w,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Container(
                      width: w,
                      height: h,
                      color: Colors.grey.shade700,
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: fillW,
                      child: Container(color: Colors.orange),
                    ),
                    for (final t in thresholds)
                      Positioned(
                        left: _tickLeft(w, t, maxP),
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            width: t == 0 || t >= maxP ? 3 : 2,
                            height: h,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return SizedBox(
              height: 14,
              child: Stack(
                children: [
                  for (final t in thresholds)
                    Positioned(
                      left: _labelLeft(w, t, maxP),
                      top: 0,
                      child: Text(
                        '$t',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  static double _tickLeft(double width, int threshold, double maxP) {
    if (threshold == 0) return 0;
    if (threshold >= maxP) return width - 3;
    return width * threshold / maxP - 1;
  }

  static double _labelLeft(double width, int threshold, double maxP) {
    final x = width * threshold / maxP;
    if (threshold == 0) return 0;
    if (threshold >= maxP) return width - 22;
    return (x - 8).clamp(0.0, width - 20);
  }
}
