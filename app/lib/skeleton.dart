import 'package:flutter/material.dart';

import 'landing.dart';
import 'motion.dart';
import 'theme.dart';

/// A calm placeholder shaped like the home page, shown while the first answer from the server is on its way.
class PageSkeleton extends StatefulWidget {
  const PageSkeleton({super.key});

  @override
  State<PageSkeleton> createState() => _PageSkeletonState();
}

class _PageSkeletonState extends State<PageSkeleton> with SingleTickerProviderStateMixin {
  AnimationController? _ctl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final move = Motion.ambient && !Motion.reduced(context);
    if (move && _ctl == null) {
      _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    } else if (!move && _ctl != null) {
      _ctl!.dispose();
      _ctl = null;
    }
  }

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  Widget _bar(Palette p, double height, {double? width, double factor = 1, double radius = 10}) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: p.inset, borderRadius: BorderRadius.circular(radius)),
    );
    return width == null ? FractionallySizedBox(widthFactor: factor, alignment: AlignmentDirectional.centerStart, child: box) : box;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final wide = isWide(context);
    final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _bar(p, 28, width: 210, radius: 999),
      const SizedBox(height: 22),
      _bar(p, wide ? 56 : 38, factor: 0.92),
      const SizedBox(height: 12),
      _bar(p, wide ? 56 : 38, factor: 0.7),
      const SizedBox(height: 26),
      _bar(p, 16, factor: 0.8),
      const SizedBox(height: 10),
      _bar(p, 16, factor: 0.6),
      const SizedBox(height: 30),
      Row(children: [_bar(p, 52, width: 200, radius: 999), const SizedBox(width: 12), _bar(p, 52, width: 140, radius: 999)]),
    ]);
    final right = Container(
      height: wide ? 380 : 240,
      decoration: BoxDecoration(color: p.inset, borderRadius: BorderRadius.circular(32)),
    );
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: EdgeInsets.fromLTRB(pagePad(context), wide ? 130 : 100, pagePad(context), 40),
          child: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(flex: 11, child: left), const SizedBox(width: 48), Expanded(flex: 10, child: right)])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 28), right]),
        ),
      ),
    );
    final ctl = _ctl;
    return Semantics(
      label: 'Loading Dalil',
      child: ctl == null
          ? content
          : FadeTransition(opacity: Tween<double>(begin: 0.55, end: 1).animate(CurvedAnimation(parent: ctl, curve: Curves.easeInOut)), child: content),
    );
  }
}
