import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class AppleSpring extends Curve {
  const AppleSpring({this.bounce = 0});
  final double bounce;

  static const double _span = 9.0;

  @override
  double transformInternal(double t) {
    final zeta = (1 - bounce).clamp(0.3, 1.0);
    final s = t * _span;
    if (zeta >= 0.999) return 1 - (1 + s) * math.exp(-s);
    final wd = math.sqrt(1 - zeta * zeta);
    return 1 - math.exp(-zeta * s) * (math.cos(wd * s) + (zeta / wd) * math.sin(wd * s));
  }
}

class Motion {
  static const AppleSpring smooth = AppleSpring();
  static const AppleSpring lively = AppleSpring(bounce: 0.15);

  /// Endless background motion (the language ticker). Tests switch it off so they can settle.
  static bool ambient = true;

  static bool reduced(BuildContext c) => MediaQuery.maybeOf(c)?.disableAnimations ?? false;

  static Duration ms(BuildContext c, int value) => reduced(c) ? Duration.zero : Duration(milliseconds: value);
}

class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true, this.scale = 0.97});
  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final active = _down && widget.enabled && !Motion.reduced(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: active ? widget.scale : 1,
        duration: Motion.ms(context, 520),
        curve: Motion.lively,
        child: widget.child,
      ),
    );
  }
}

class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.delayMs = 0, this.lift = 0.04});
  final Widget child;
  final int delayMs;
  final double lift;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> {
  bool _on = false;
  bool _started = false;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context) || widget.delayMs == 0) {
      // Start on the next frame so the first frame is the "before" state and the move is visible.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _on = true);
      });
    } else {
      _t = Timer(Duration(milliseconds: widget.delayMs), () {
        if (mounted) setState(() => _on = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return AnimatedOpacity(
      opacity: _on ? 1 : 0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _on ? Offset.zero : Offset(0, widget.lift),
        duration: const Duration(milliseconds: 700),
        curve: Motion.smooth,
        child: widget.child,
      ),
    );
  }
}

class Marker extends StatefulWidget {
  const Marker({super.key, required this.child, required this.color, this.delayMs = 0, this.thickness = 0.5});
  final Widget child;
  final Color color;
  final int delayMs;
  final double thickness;

  @override
  State<Marker> createState() => _MarkerState();
}

class _MarkerState extends State<Marker> {
  bool _go = false;
  bool _started = false;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _go = true;
    } else {
      _t = Timer(Duration(milliseconds: widget.delayMs + 60), () {
        if (mounted) setState(() => _go = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fast = Motion.reduced(context);
    return Stack(
      children: [
        Positioned.fill(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: _go ? 1 : 0),
            duration: fast ? Duration.zero : const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => FractionallySizedBox(
              alignment: AlignmentDirectional.bottomStart,
              widthFactor: v,
              heightFactor: widget.thickness,
              child: DecoratedBox(decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(3))),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class ScanLine extends StatefulWidget {
  const ScanLine({super.key, required this.child, required this.active, required this.color});
  final Widget child;
  final bool active;
  final Color color;

  @override
  State<ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<ScanLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ScanLine old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    final still = Motion.reduced(context);
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, box) {
                return AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final v = still ? 0.5 : Curves.easeInOut.transform(_c.value);
                    final y = (box.maxHeight - 56) * v;
                    return Stack(children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: y,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [widget.color.withAlpha(0), widget.color.withAlpha(70), widget.color.withAlpha(0)],
                            ),
                          ),
                        ),
                      ),
                    ]);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delayMs = 0, this.alignment = Alignment.centerLeft});
  final Widget child;
  final int delayMs;
  final Alignment alignment;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> {
  bool _on = false;
  bool _started = false;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _on = true;
    } else {
      _t = Timer(Duration(milliseconds: widget.delayMs), () {
        if (mounted) setState(() => _on = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _on ? 1 : 0.86,
      alignment: widget.alignment,
      duration: Motion.ms(context, 650),
      curve: Motion.lively,
      child: AnimatedOpacity(opacity: _on ? 1 : 0, duration: Motion.ms(context, 260), child: widget.child),
    );
  }
}

class DashedLine extends StatelessWidget {
  const DashedLine({super.key, required this.color, this.thickness = 2, this.dash = 6, this.gap = 6, this.vertical = false, this.length});
  final Color color;
  final double thickness, dash, gap;
  final bool vertical;
  final double? length;

  @override
  Widget build(BuildContext context) {
    final painter = CustomPaint(painter: _DashPainter(color, thickness, dash, gap, vertical));
    if (length == null) return painter;
    return SizedBox(width: vertical ? thickness : length, height: vertical ? length : thickness, child: painter);
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.thickness, this.dash, this.gap, this.vertical);
  final Color color;
  final double thickness, dash, gap;
  final bool vertical;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    final total = vertical ? size.height : size.width;
    var d = 0.0;
    while (d < total) {
      final end = math.min(d + dash, total);
      if (vertical) {
        canvas.drawLine(Offset(size.width / 2, d), Offset(size.width / 2, end), paint);
      } else {
        canvas.drawLine(Offset(d, size.height / 2), Offset(end, size.height / 2), paint);
      }
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color || old.thickness != thickness || old.vertical != vertical;
}


class ScrollReveal extends StatefulWidget {
  const ScrollReveal({super.key, required this.child, this.lift = 0.025});
  final Widget child;
  final double lift;

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal> {
  bool _on = false;
  ScrollPosition? _pos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pos?.removeListener(_check);
    _pos = Scrollable.maybeOf(context)?.position;
    _pos?.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _pos?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (_on || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (_pos == null || top < MediaQuery.sizeOf(context).height * 0.9) {
      _pos?.removeListener(_check);
      setState(() => _on = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return AnimatedOpacity(
      opacity: _on ? 1 : 0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _on ? Offset.zero : Offset(0, widget.lift),
        duration: const Duration(milliseconds: 900),
        curve: Motion.smooth,
        child: widget.child,
      ),
    );
  }
}

class SmoothWheel extends StatefulWidget {
  const SmoothWheel({super.key, required this.controller, required this.child});
  final ScrollController controller;
  final Widget child;

  @override
  State<SmoothWheel> createState() => _SmoothWheelState();
}

class _SmoothWheelState extends State<SmoothWheel> {
  double? _target;
  int _token = 0;

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || Motion.reduced(context)) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (ev) {
      final c = widget.controller;
      if (!c.hasClients) return;
      final pos = c.position;
      final dy = (ev as PointerScrollEvent).scrollDelta.dy;
      final from = _target ?? pos.pixels;
      final to = (from + dy).clamp(pos.minScrollExtent, pos.maxScrollExtent).toDouble();
      _target = to;
      final mine = ++_token;
      pos.animateTo(to, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic).whenComplete(() {
        if (mine == _token) _target = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Listener(onPointerSignal: _onSignal, child: widget.child);
}
