import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class RoundedSquareCounterButton extends StatefulWidget {
  final double progress;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color borderGlowColor;
  final double size;
  final VoidCallback onTap;

  const RoundedSquareCounterButton({
    super.key,
    required this.progress,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.borderGlowColor,
    this.size = 180,
    required this.onTap,
  });

  @override
  State<RoundedSquareCounterButton> createState() =>
      _RoundedSquareCounterButtonState();
}

class _RoundedSquareCounterButtonState
    extends State<RoundedSquareCounterButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size;
    final double radius = s * 0.30;
    final double strokeWidth = math.max(5.0, s * 0.036);
    final double clampedProgress = widget.progress.clamp(0.0, 1.0);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: SizedBox(
          width: s + 16,
          height: s + 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Raised 3D button body with shadow
              AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                width: s - 6,
                height: s - 6,
                transform: Matrix4.translationValues(0, _isPressed ? 4 : 0, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.gradientColors,
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 1.5,
                  ),
                  boxShadow: _isPressed
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: widget.gradientColors.last.withOpacity(0.55),
                            blurRadius: 0,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: widget.borderGlowColor.withOpacity(
                              isDark ? 0.32 : 0.28,
                            ),
                            blurRadius: 20,
                            spreadRadius: 1,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.6 : 0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: s * 0.24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: s * 0.09,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.88),
                      ),
                    ),
                  ],
                ),
              ),
              // Progress line wrapping around the rounded square
              IgnorePointer(
                child: CustomPaint(
                  size: Size(s + 12, s + 12),
                  painter: _RoundedSquareProgressPainter(
                    progress: clampedProgress,
                    radius: radius + 4,
                    strokeWidth: strokeWidth,
                    activeColor: widget.borderGlowColor,
                    trackColor: isDark
                        ? Colors.white.withOpacity(0.10)
                        : Colors.black.withOpacity(0.08),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundedSquareProgressPainter extends CustomPainter {
  final double progress;
  final double radius;
  final double strokeWidth;
  final Color activeColor;
  final Color trackColor;

  _RoundedSquareProgressPainter({
    required this.progress,
    required this.radius,
    required this.strokeWidth,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double inset = strokeWidth / 2 + 2;
    final Rect rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(rrect, trackPaint);

    if (progress <= 0) return;

    // Build path starting from top-center so it wraps cleanly clockwise
    final Path basePath = Path()..addRRect(rrect);
    final PathMetric? metric = basePath.computeMetrics().firstOrNull;
    if (metric == null) return;

    final double totalLen = metric.length;
    // Start near top-center (approx 1/8th offset depending on RRect start)
    final double startOffset = totalLen * 0.125;
    final double drawLen = totalLen * progress.clamp(0.0, 1.0);

    final Path activePath = Path();
    if (startOffset + drawLen <= totalLen) {
      activePath.addPath(
        metric.extractPath(startOffset, startOffset + drawLen),
        Offset.zero,
      );
    } else {
      activePath.addPath(
        metric.extractPath(startOffset, totalLen),
        Offset.zero,
      );
      activePath.addPath(
        metric.extractPath(0, (startOffset + drawLen) - totalLen),
        Offset.zero,
      );
    }

    final Paint glowPaint = Paint()
      ..color = activeColor.withOpacity(0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(activePath, glowPaint);

    final Paint activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(activePath, activePaint);
  }

  @override
  bool shouldRepaint(covariant _RoundedSquareProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor;
  }
}