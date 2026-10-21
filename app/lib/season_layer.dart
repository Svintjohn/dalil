import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'motion.dart';
import 'season.dart';
import 'theme.dart';

/// A few quiet holiday decorations drawn over the page. They never take a tap, stay faint, use a handful of shapes,
/// stop when the person turns them off or asks their device for less motion, and sit under the header and any dialog.
class SeasonLayer extends StatefulWidget {
  const SeasonLayer({super.key, this.season, this.settings});

  /// Forces a season (used by tests); otherwise today's season is used.
  final Season? season;
  final SeasonSettings? settings;

  @override
  State<SeasonLayer> createState() => _SeasonLayerState();
}

class _SeasonLayerState extends State<SeasonLayer> with SingleTickerProviderStateMixin {
  late Season season = widget.season ?? currentSeason();
  final ValueNotifier<double> time = ValueNotifier<double>(1.5);
  Ticker? _ticker;
  Duration _last = Duration.zero;

  SeasonSettings get settings => widget.settings ?? SeasonSettings.instance;

  @override
  void initState() {
    super.initState();
    settings.addListener(_onSettings);
  }

  void _onSettings() => _sync();

  @override
  void didUpdateWidget(SeasonLayer old) {
    super.didUpdateWidget(old);
    if (old.settings != widget.settings) {
      (old.settings ?? SeasonSettings.instance).removeListener(_onSettings);
      settings.addListener(_onSettings);
    }
    if (old.season != widget.season) season = widget.season ?? currentSeason();
    _sync(rebuild: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(rebuild: false);
  }

  void _sync({bool rebuild = true}) {
    if (!mounted) return;
    final want = season != Season.none && settings.enabled && Motion.ambient && !Motion.reduced(context);
    if (want && _ticker == null) {
      _ticker = createTicker((d) {
        if (d - _last < const Duration(milliseconds: 33)) return; // about 30 frames a second is plenty
        _last = d;
        time.value = d.inMicroseconds / 1e6;
      })
        ..start();
    } else if (!want && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
    }
    if (rebuild) setState(() {});
  }

  @override
  void dispose() {
    settings.removeListener(_onSettings);
    _ticker?.dispose();
    time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (season == Season.none || !settings.enabled || Motion.reduced(context)) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = Palette.of(context);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: SeasonPainter(season: season, time: time, dark: dark, ink: p.ink),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _Dot {
  _Dot(this.x, this.y, this.speed, this.size, this.phase, this.alpha);
  final double x, y, speed, size, phase;
  final int alpha;
}

List<_Dot> _dots(int n, int seed, {double speedMin = 0.015, double speedMax = 0.04, double sizeMin = 1.4, double sizeMax = 3.2, int alphaMin = 90, int alphaMax = 170}) {
  final r = math.Random(seed);
  return List.generate(
    n,
    (_) => _Dot(r.nextDouble(), r.nextDouble(), speedMin + r.nextDouble() * (speedMax - speedMin), sizeMin + r.nextDouble() * (sizeMax - sizeMin), r.nextDouble() * math.pi * 2, alphaMin + r.nextInt(alphaMax - alphaMin + 1)),
  );
}

final List<_Dot> _flakes = _dots(26, 11);
final List<_Dot> _embers = _dots(14, 23, speedMin: 0.02, speedMax: 0.05, sizeMin: 1.4, sizeMax: 2.8, alphaMin: 60, alphaMax: 120);
final List<_Dot> _confetti = _dots(26, 37, speedMin: 0.02, speedMax: 0.05, sizeMin: 4, sizeMax: 6, alphaMin: 120, alphaMax: 190);
final List<_Dot> _stars = _dots(9, 41, sizeMin: 3, sizeMax: 6, alphaMin: 100, alphaMax: 220);

class SeasonPainter extends CustomPainter {
  SeasonPainter({required this.season, required this.time, required this.dark, required this.ink}) : super(repaint: time);
  final Season season;
  final ValueNotifier<double> time;
  final bool dark;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    switch (season) {
      case Season.christmas:
        _snow(canvas, size, t);
      case Season.halloween:
        _embersUp(canvas, size, t);
        _bats(canvas, size, t);
      case Season.newYear:
        _fireworks(canvas, size, t, const [Color(0xFFF5B93A), Color(0xFFE4572E), Color(0xFF39B79A), Color(0xFF8B6FE0)], period: 2.6, rays: 24, reach: 90);
      case Season.uaeDay:
        _confettiFall(canvas, size, t);
      case Season.ramadan:
        _crescent(canvas, size, t);
      case Season.eid:
        _crescent(canvas, size, t);
        _fireworks(canvas, size, t, const [Color(0xFFF5B93A), Color(0xFFE9C46A)], period: 4.6, rays: 14, reach: 56);
      case Season.none:
        break;
    }
  }

  void _snow(Canvas canvas, Size size, double t) {
    final c = dark ? Colors.white : const Color(0xFF6F93B8); // pale snow would vanish on the light page
    final paint = Paint();
    for (final f in _flakes) {
      final y = ((f.y + t * f.speed) % 1.08) - 0.04;
      final x = f.x + math.sin(t * 0.5 + f.phase) * 0.015;
      paint.color = c.withAlpha(f.alpha);
      canvas.drawCircle(Offset(x * size.width, y * size.height), f.size, paint);
    }
  }

  void _embersUp(Canvas canvas, Size size, double t) {
    final paint = Paint();
    for (final f in _embers) {
      final y = 1.04 - ((f.y + t * f.speed) % 1.08);
      final x = f.x + math.sin(t * 0.7 + f.phase) * 0.012;
      paint.color = const Color(0xFFF08A24).withAlpha(f.alpha);
      canvas.drawCircle(Offset(x * size.width, y * size.height), f.size, paint);
    }
  }

  void _bats(Canvas canvas, Size size, double t) {
    final color = dark ? const Color(0xFFB4A5DC) : ink;
    final paint = Paint()..color = color.withAlpha(dark ? 190 : 150);
    for (var i = 0; i < 3; i++) {
      const cycle = 24.0;
      final u = ((t + i * 8.5) % cycle) / cycle;
      if (u > 0.5) continue; // each bat crosses the top of the page, then rests off screen
      final v = u / 0.5;
      final x = (-0.06 + v * 1.12) * size.width;
      final y = (0.1 + i * 0.05 + math.sin(v * math.pi * 4 + i) * 0.02) * size.height;
      final flap = math.sin(t * 11 + i * 2);
      canvas.save();
      canvas.translate(x, y);
      canvas.drawOval(const Rect.fromLTWH(-3, -4, 6, 9), paint);
      for (final side in [1.0, -1.0]) {
        canvas.save();
        canvas.scale(side, 1);
        final wing = Path()
          ..moveTo(2, -1)
          ..quadraticBezierTo(9, -10 - flap * 4, 18, -4 - flap * 6)
          ..quadraticBezierTo(12, 0, 9, 2)
          ..quadraticBezierTo(6, -1, 2, 3)
          ..close();
        canvas.drawPath(wing, paint);
        canvas.restore();
      }
      canvas.restore();
    }
  }

  void _fireworks(Canvas canvas, Size size, double t, List<Color> colors, {required double period, required int rays, required double reach}) {
    const life = 2.2;
    final k0 = (t / period).floor();
    for (var k = k0 - 1; k <= k0; k++) {
      final age = t - k * period;
      if (k < 0 || age < 0 || age > life) continue;
      final r = math.Random(k * 977 + 13);
      final cx = (0.12 + r.nextDouble() * 0.76) * size.width;
      final cy = (0.14 + r.nextDouble() * 0.28) * size.height;
      final color = colors[r.nextInt(colors.length)];
      final fade = math.pow(1 - age / life, 1.5).toDouble();
      final paint = Paint()
        ..color = color.withAlpha((210 * fade).round())
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < rays; i++) {
        final ang = i / rays * math.pi * 2 + r.nextDouble() * 0.2;
        final spread = 0.7 + r.nextDouble() * 0.5;
        Offset at(double a) => Offset(cx + math.cos(ang) * reach * spread * (1 - math.exp(-a * 2.4)), cy + math.sin(ang) * reach * spread * (1 - math.exp(-a * 2.4)) + a * a * 16);
        final head = at(age);
        final tail = at(math.max(0, age - 0.12));
        canvas.drawLine(tail, head, paint);
      }
    }
  }

  void _confettiFall(Canvas canvas, Size size, double t) {
    const colors = [Color(0xFFD7263D), Color(0xFF00732F), Color(0xFF15201E)];
    final paint = Paint();
    for (var i = 0; i < _confetti.length; i++) {
      final f = _confetti[i];
      final y = ((f.y + t * f.speed) % 1.08) - 0.04;
      final x = f.x + math.sin(t * 0.6 + f.phase) * 0.02;
      paint.color = (dark && i % 3 == 2 ? Colors.white : colors[i % 3]).withAlpha(f.alpha);
      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate(t * 0.9 + f.phase);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: f.size, height: f.size * 1.7), paint);
      canvas.restore();
    }
  }

  void _crescent(Canvas canvas, Size size, double t) {
    final gold = dark ? const Color(0xFFF5C76A) : const Color(0xFFC08A1E);
    final center = Offset(size.width - 58, 104);
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: center, radius: 15)),
      Path()..addOval(Rect.fromCircle(center: center.translate(7, -3), radius: 13)),
    );
    canvas.drawPath(moon, Paint()..color = gold.withAlpha(60)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawPath(moon, Paint()..color = gold.withAlpha(215));
    final star = Paint();
    for (var i = 0; i < _stars.length; i++) {
      final f = _stars[i];
      final tw = 0.35 + 0.35 * math.sin(t * 1.3 + f.phase);
      final c = Offset(size.width * (0.45 + 0.52 * f.x), 84 + size.height * 0.22 * f.y);
      if ((c - center).distance < 40) continue;
      star.color = gold.withAlpha((f.alpha * tw).round());
      _sparkle(canvas, c, f.size, star);
    }
  }

  void _sparkle(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SeasonPainter old) => old.season != season || old.dark != dark || old.ink != ink;
}
