import 'package:flutter/material.dart';
import '../utils/angreb_assets.dart';

/// Delt duel-tile med angreb-figur og barometer – bruges af både computer og PvP.
/// name, stageIndex, letter bruges til Angreb-billede.
class DuelAngrebTile extends StatelessWidget {
  final String name;
  final int stageIndex;
  final String? letter;
  final bool faceRight;
  final String? strengthName;
  final int powerValue;
  final bool barometerOnRight;
  final int animationDelayMs;
  final bool barometersReady;
  final VoidCallback? onBarometerStart;
  final VoidCallback? onBarometerComplete;

  const DuelAngrebTile({
    super.key,
    required this.name,
    required this.stageIndex,
    this.letter,
    required this.faceRight,
    this.strengthName,
    this.powerValue = 0,
    this.barometerOnRight = true,
    this.animationDelayMs = 0,
    this.barometersReady = true,
    this.onBarometerStart,
    this.onBarometerComplete,
  });

  @override
  Widget build(BuildContext context) {
    final path = AngrebAssets.getAngrebAssetPath(
      name,
      stageIndex,
      letter: letter,
    );

    Widget imageWidget;
    if (path != null) {
      imageWidget = Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(name),
      );
    } else {
      imageWidget = _placeholder(name);
    }

    final flipOverride = path != null && path.contains('Atiachangreb2');
    final shouldFlip = flipOverride ? faceRight : !faceRight;
    if (shouldFlip) {
      imageWidget = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
        child: imageWidget,
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight.clamp(40.0, 120.0);
              final delay = barometersReady ? animationDelayMs : 999999;
              final barometer = powerValue > 0
                  ? PowerBarometer(
                      value: powerValue,
                      height: h,
                      animationDelayMs: delay,
                      onBarometerStart: onBarometerStart,
                      onBarometerComplete: onBarometerComplete,
                    )
                  : null;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!barometerOnRight && barometer != null) ...[
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: barometer,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Center(child: imageWidget),
                  ),
                  if (barometerOnRight && barometer != null) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: barometer,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        if (strengthName != null && strengthName!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            strengthName!,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(color: Colors.black54, offset: Offset(1, 1)),
                Shadow(color: Colors.black38, blurRadius: 4),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _placeholder(String name) {
    return Container(
      color: Colors.white12,
      child: Center(
        child: Text(
          name,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
    );
  }
}

/// Vertikalt barometer 0–100. 300% størrelse.
class PowerBarometer extends StatefulWidget {
  final int value;
  final double? height;
  final int animationDelayMs;
  final VoidCallback? onBarometerStart;
  final VoidCallback? onBarometerComplete;

  const PowerBarometer({
    super.key,
    required this.value,
    this.height,
    this.animationDelayMs = 0,
    this.onBarometerStart,
    this.onBarometerComplete,
  });

  @override
  State<PowerBarometer> createState() => _PowerBarometerState();
}

class _PowerBarometerState extends State<PowerBarometer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  static const double _scale = 3.0;
  static const double _barWidth = 14 * _scale;
  static const double _labelsWidth = 12 * _scale;
  static const double _gap = 2 * _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onBarometerComplete?.call();
      }
    });
    _animation = Tween<double>(begin: 0, end: widget.value / 100.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _maybeStartAnimation();
  }

  void _maybeStartAnimation() {
    if (widget.animationDelayMs >= 999999) return;
    if (widget.animationDelayMs <= 0) {
      widget.onBarometerStart?.call();
      _controller.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.animationDelayMs), () {
        if (mounted) {
          widget.onBarometerStart?.call();
          _controller.forward();
        }
      });
    }
  }

  @override
  void didUpdateWidget(PowerBarometer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.animationDelayMs != widget.animationDelayMs) {
      _animation = Tween<double>(begin: 0, end: widget.value / 100.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.reset();
      _maybeStartAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final pct = _animation.value.clamp(0.0, 1.0);
        final h = (widget.height ?? 80.0) * _scale;
        final style = TextStyle(
          fontSize: 8 * _scale,
          fontWeight: FontWeight.bold,
          color: Colors.white.withValues(alpha: 0.95),
        );
        final totalWidth = _labelsWidth + _gap + _barWidth;
        return ClipRect(
          child: SizedBox(
            width: totalWidth,
            height: h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: _labelsWidth,
                  height: h,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var v = 100; v >= 0; v -= 10) ...[
                        Positioned(
                          left: 0,
                          bottom: 2 * _scale +
                              (v / 100) * (h - 4 * _scale) -
                              (8 * _scale) / 2,
                          child: Text('$v', style: style),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: _gap),
                SizedBox(
                  width: _barWidth,
                  height: h,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Container(
                        width: _barWidth,
                        height: h,
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(4 * _scale),
                          border: Border.all(color: Colors.white38, width: 1),
                        ),
                      ),
                      Positioned(
                        left: 2 * _scale,
                        right: 2 * _scale,
                        bottom: 2 * _scale,
                        height: (h - 4 * _scale) * pct,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9C433),
                            borderRadius: BorderRadius.circular(3 * _scale),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
