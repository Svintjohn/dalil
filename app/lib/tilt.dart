import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';

/// Leans a card a few degrees toward the pointer, like paper on a desk. Touch screens have no hover, so nothing happens there,
/// and nothing moves when the device asks for reduced motion.
class TiltOnHover extends StatefulWidget {
  const TiltOnHover({super.key, required this.child, this.degrees = 5});
  final Widget child;
  final double degrees;

  @override
  State<TiltOnHover> createState() => _TiltOnHoverState();
}

class _TiltOnHoverState extends State<TiltOnHover> {
  Offset _t = Offset.zero; // where the pointer is, from -1 to 1 on each side of the center

  void _move(PointerEvent e) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    final next = Offset((e.localPosition.dx / size.width * 2 - 1).clamp(-1.0, 1.0).toDouble(), (e.localPosition.dy / size.height * 2 - 1).clamp(-1.0, 1.0).toDouble());
    if ((next - _t).distance > 0.02) setState(() => _t = next);
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    final max = widget.degrees * math.pi / 180;
    return MouseRegion(
      onHover: _move,
      onExit: (_) => setState(() => _t = Offset.zero),
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(end: _t),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        builder: (context, v, child) {
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(-v.dy * max)
            ..rotateY(v.dx * max);
          return Transform(transform: m, alignment: Alignment.center, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

/// A tile that leans toward the pointer and sinks a little when pressed.
class TiltPress extends StatelessWidget {
  const TiltPress({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TiltOnHover(child: Pressable(child: child));
}
