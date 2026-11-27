import 'dart:math' as math;

import 'package:flutter/material.dart';

/// أشكال السبحة الإلكترونية الخمسة.
///
/// كل شكل يستقبل العدد الحالي والهدف (0 = مفتوح بلا حد) ويستدعي [onCount]
/// عند كل تسبيحة. التصميم يعتمد هوية أذكاري: أسود نقي، أزرق ليلي وسماوي.
const Color kTasbihNavy = Color(0xFF0A192F);
const Color kTasbihSky = Color(0xFF38BDF8);
const Color kTasbihBlue = Color(0xFF0288D1);
const Color kTasbihGold = Color(0xFFF59E0B);

/// (1) الزر الزجاجي: المربع المستدير العصري مع حلقة تقدم سماوية متوهجة.
class GlassCounterTasbih extends StatefulWidget {
  const GlassCounterTasbih({
    super.key,
    required this.count,
    required this.target,
    required this.onCount,
    this.size = 190,
    this.gradientColors = const [Color(0xFF0D47A1), Color(0xFF0288D1)],
  });

  final int count;
  final int target;
  final VoidCallback onCount;
  final double size;
  final List<Color> gradientColors;

  @override
  State<GlassCounterTasbih> createState() => _GlassCounterTasbihState();
}

class _GlassCounterTasbihState extends State<GlassCounterTasbih> {
  bool _pressed = false;

  double get _progress {
    if (widget.target <= 0) return 0;
    final v = widget.count % widget.target;
    return (widget.count > 0 && v == 0) ? 1.0 : v / widget.target;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final radius = size * 0.30;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onCount();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(progress: _progress),
              ),
              Container(
                width: size * 0.78,
                height: size * 0.78,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    colors: widget.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kTasbihSky.withOpacity(_pressed ? 0.60 : 0.32),
                      blurRadius: _pressed ? 34 : 22,
                      spreadRadius: _pressed ? 6 : 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.count}',
                        style: TextStyle(
                          fontSize: size * 0.26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.05,
                        ),
                      ),
                      if (widget.target > 0)
                        Text(
                          '/ ${widget.target}',
                          style: TextStyle(
                            fontSize: size * 0.085,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
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

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.10);
    canvas.drawCircle(center, radius, bg);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..color = kTasbihSky.withOpacity(0.18);
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(arcRect, -math.pi / 2, 2 * math.pi * progress, false, glow);

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [kTasbihSky, Color(0xFF0288D1), kTasbihSky],
      ).createShader(arcRect);
    canvas.drawArc(arcRect, -math.pi / 2, 2 * math.pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

/// (2) شريط السبحة بالسحب: خرزات ثلاثية الأبعاد على خيط يسحبها المستخدم.
class BeadStripTasbih extends StatefulWidget {
  const BeadStripTasbih({
    super.key,
    required this.count,
    required this.target,
    required this.onCount,
    this.height = 300,
  });

  final int count;
  final int target;
  final VoidCallback onCount;
  final double height;

  @override
  State<BeadStripTasbih> createState() => _BeadStripTasbihState();
}

class _BeadStripTasbihState extends State<BeadStripTasbih>
    with SingleTickerProviderStateMixin {
  static const int _beads = 12;
  double _dragAccum = 0;
  double _offset = 0;
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  void _increment() {
    widget.onCount();
    _glow.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.target > 0
        ? (widget.count % widget.target == 0 && widget.count > 0
            ? widget.target
            : widget.count % widget.target)
        : widget.count;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _increment,
      onVerticalDragStart: (_) => _dragAccum = 0,
      onVerticalDragUpdate: (d) {
        _dragAccum += d.delta.dy;
        setState(() => _offset += d.delta.dy * 0.35);
        // كل 26 بكسل سحب = تسبيحة واحدة (سلاسة كالسبحة الحقيقية)
        while (_dragAccum <= -26) {
          _dragAccum += 26;
          _increment();
        }
        while (_dragAccum >= 26) {
          _dragAccum -= 26;
          _offset = 0;
        }
      },
      onVerticalDragEnd: (_) => setState(() => _offset = 0),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF071324), kTasbihNavy],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: kTasbihSky.withOpacity(0.22)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 12,
                child: Column(
                  children: [
                    Text(
                      '${widget.count}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.target > 0 ? '$active / ${widget.target}' : 'مفتوح',
                      style: const TextStyle(fontSize: 11.5, color: kTasbihSky),
                    ),
                  ],
                ),
              ),
              Center(
                child: AnimatedBuilder(
                  animation: _glow,
                  builder: (context, _) {
                    final t = _glow.value;
                    return Transform.translate(
                      offset: Offset(0, _offset.clamp(-40, 40)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_beads, (i) {
                          final isTop = i == 0;
                          final isLit = i == 0 && t > 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: isTop ? 54 : 44,
                              height: isTop ? 54 : 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: const Alignment(-0.35, -0.45),
                                  colors: isTop
                                      ? [
                                          const Color(0xFF7DD3FC),
                                          kTasbihSky,
                                          const Color(0xFF0369A1),
                                        ]
                                      : [
                                          Colors.white.withOpacity(0.30),
                                          const Color(0xFF1E3A5F),
                                          const Color(0xFF0B1B2E),
                                        ],
                                ),
                                boxShadow: [
                                  if (isTop)
                                    BoxShadow(
                                      color: kTasbihSky.withOpacity(
                                          isLit ? 0.75 : 0.42),
                                      blurRadius: isLit ? 26 : 14,
                                      spreadRadius: isLit ? 4 : 1,
                                    ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.45),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
              const Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Text(
                  'اسحب للأعلى أو اضغط للتسبيح',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// (3) الحلقة الدائرية: خرز كامل الاستدارة يضيء ويستمر بالدوران مع كل تسبيحة.
class RingTasbih extends StatefulWidget {
  const RingTasbih({
    super.key,
    required this.count,
    required this.target,
    required this.onCount,
    this.size = 280,
  });

  final int count;
  final int target;
  final VoidCallback onCount;
  final double size;

  @override
  State<RingTasbih> createState() => _RingTasbihState();
}

class _RingTasbihState extends State<RingTasbih>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final beads = widget.target > 0 ? widget.target.clamp(8, 66) : 33;
    final done = widget.target > 0
        ? (widget.count % widget.target)
        : (widget.count % beads);
    return GestureDetector(
      onTap: () {
        widget.onCount();
        _spin.forward(from: 0);
      },
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) => Transform.rotate(
          angle: _spin.value * (2 * math.pi / beads),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = 0; i < beads; i++)
                  Align(
                    alignment: Alignment(
                      math.sin((2 * math.pi * i) / beads),
                      -math.cos((2 * math.pi * i) / beads),
                    ),
                    child: Container(
                      width: i == done || (done == 0 && i == 0) ? 16 : 11,
                      height: i == done || (done == 0 && i == 0) ? 16 : 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < done
                            ? kTasbihSky
                            : Colors.white.withOpacity(0.20),
                        boxShadow: [
                          if (i == done || (done == 0 && i == 0))
                            BoxShadow(
                              color: kTasbihSky.withOpacity(0.85),
                              blurRadius: 16,
                              spreadRadius: 3,
                            ),
                        ],
                      ),
                    ),
                  ),
                Container(
                  width: widget.size * 0.55,
                  height: widget.size * 0.55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kTasbihNavy,
                    border: Border.all(color: kTasbihSky.withOpacity(0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: kTasbihSky.withOpacity(0.18),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${widget.count}',
                        style: TextStyle(
                          fontSize: widget.size * 0.16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${done.clamp(0, beads)} / $beads',
                        style: const TextStyle(
                            fontSize: 11, color: kTasbihSky),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// (4) خاتم التسبيح الرقمي: شاشة LCD وزر نقر مركزي وزر تصفير صغير.
class DigitalRingTasbih extends StatelessWidget {
  const DigitalRingTasbih({
    super.key,
    required this.count,
    required this.target,
    required this.onCount,
    required this.onReset,
  });

  final int count;
  final int target;
  final VoidCallback onCount;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final cycle = target > 0 ? count % target : count;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 260,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: const LinearGradient(
              colors: [Color(0xFF0F2137), Color(0xFF050B14)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: kTasbihSky.withOpacity(0.30), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: kTasbihSky.withOpacity(0.12),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF071A12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF134E4A)),
                ),
                child: FittedBox(
                  child: Text(
                    count.toString().padLeft(4, '0'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                target > 0 ? '$cycle / $target' : 'مفتوح بلا حد',
                style: const TextStyle(fontSize: 11.5, color: Colors.white54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        GestureDetector(
          onTap: onCount,
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [kTasbihSky, kTasbihBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: kTasbihSky.withOpacity(0.45),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.fingerprint_rounded,
                size: 40, color: Color(0xFF04121F)),
          ),
        ),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt_rounded, size: 16),
          label: const Text('تصفير', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

/// (5) نبضة النور: تسبيح بلمس أي مكان على الشاشة مع موجة نور سماوية.
class LightPulseTasbih extends StatefulWidget {
  const LightPulseTasbih({
    super.key,
    required this.count,
    required this.target,
    required this.onCount,
    this.height = 380,
  });

  final int count;
  final int target;
  final VoidCallback onCount;
  final double height;

  @override
  State<LightPulseTasbih> createState() => _LightPulseTasbihState();
}

class _LightPulseTasbihState extends State<LightPulseTasbih>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..addStatusListener((st) {
      if (st == AnimationStatus.completed) _pulse.reset();
    });

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.onCount();
        _pulse.forward(from: 0);
      },
      child: Container(
        height: widget.height,
        decoration: const BoxDecoration(color: Color(0xFF000000)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = Curves.easeOut.transform(_pulse.value);
                return IgnorePointer(
                  child: Container(
                    width: 120 + t * 240,
                    height: 120 + t * 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          kTasbihSky.withOpacity((1 - t).clamp(0.0, 0.5)),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.count}',
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w200,
                    color: Color(0xFFE0F2FE),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.target > 0
                      ? '${widget.count % widget.target} / ${widget.target}'
                      : 'مفتوح',
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
                const SizedBox(height: 26),
                const Text(
                  'المس أي مكان في الشاشة للتسبيح',
                  style: TextStyle(fontSize: 11.5, color: Colors.white30),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
