import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fonts.dart';
import 'motion.dart';
import 'profile.dart';
import 'theme.dart';

/// The wheel has 24 hues (every 15 degrees, red at the top, clockwise) in 3 rings of strength: outer vivid, then soft, then muted.
const wheelHues = 24;
const wheelSats = <double>[0.80, 0.55, 0.32];
const wheelTones = <String>['Vivid', 'Soft', 'Muted'];

const hueNames = <String>[
  'Red', 'Vermilion', 'Orange', 'Amber', 'Yellow', 'Chartreuse', 'Lime', 'Fern',
  'Green', 'Emerald', 'Mint', 'Aqua', 'Cyan', 'Sky', 'Azure', 'Cobalt',
  'Blue', 'Indigo', 'Violet', 'Purple', 'Magenta', 'Fuchsia', 'Rose', 'Crimson', //
];

String hueName(double hue) => hueNames[((hue / 15).round() % wheelHues + wheelHues) % wheelHues];

/// The ring (0 outer, 2 inner) whose strength is closest to [sat].
int ringOfSat(double sat) {
  var best = 0;
  for (var i = 1; i < wheelSats.length; i++) {
    if ((wheelSats[i] - sat).abs() < (wheelSats[best] - sat).abs()) best = i;
  }
  return best;
}

typedef WheelCell = (int ring, int hue); // ring 0 to 2, hue index 0 to 23

/// Where the rings sit and which cell a point is on. Kept apart from the drawing so it can be tested.
class WheelGeometry {
  const WheelGeometry(this.size);
  final double size;

  double get c => size / 2;
  double get r => size / 2 - 10; // a little room so a cell can pop outwards

  /// Inner and outer edge of each ring, as a share of [r].
  static const rings = <(double, double)>[(0.79, 1.0), (0.56, 0.77), (0.34, 0.54)];

  /// Half the width of the hub, as a share of [r].
  static const hub = 0.30;

  WheelCell? hit(Offset p) {
    final dx = p.dx - c, dy = p.dy - c;
    final d = math.sqrt(dx * dx + dy * dy) / r;
    int? ring;
    for (var i = 0; i < rings.length; i++) {
      if (d >= rings[i].$1 && d <= rings[i].$2) {
        ring = i;
        break;
      }
    }
    if (ring == null) return null;
    var deg = math.atan2(dx, -dy) * 180 / math.pi; // 0 at the top, clockwise
    if (deg < 0) deg += 360;
    return (ring, (deg / 15).round() % wheelHues);
  }

  Offset centerOf(WheelCell cell) {
    final mid = (rings[cell.$1].$1 + rings[cell.$1].$2) / 2 * r;
    final a = cell.$2 * 15 * math.pi / 180;
    return Offset(c + mid * math.sin(a), c - mid * math.cos(a));
  }
}

/// The colour wheel: move over it to preview a colour, click or lift your finger to use it.
class ColorStudio extends StatefulWidget {
  const ColorStudio({super.key, this.profile});
  final Profile? profile;

  @override
  State<ColorStudio> createState() => _ColorStudioState();
}

class _ColorStudioState extends State<ColorStudio> with TickerProviderStateMixin {
  late final AnimationController intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 1);
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
  final focus = FocusNode(debugLabel: 'colour wheel');

  WheelCell? hover;
  bool _mouse = false;
  bool _started = false;
  bool _pulsing = false;
  bool? _dark;
  List<Color> _colors = const [];

  Profile get profile => widget.profile ?? Profile.instance;

  @override
  void initState() {
    super.initState();
    focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_dark != dark) {
      _dark = dark;
      _colors = [
        for (var ring = 0; ring < wheelSats.length; ring++)
          for (var h = 0; h < wheelHues; h++) Palette.custom(h * 15.0, wheelSats[ring], dark).accent,
      ];
    }
    if (!_started) {
      _started = true;
      if (Motion.ambient && !Motion.reduced(context)) {
        intro.forward();
        pulse.repeat();
        _pulsing = true;
      } else {
        intro.value = 1;
      }
    }
  }

  @override
  void dispose() {
    intro.dispose();
    pop.dispose();
    pulse.dispose();
    focus.dispose();
    super.dispose();
  }

  WheelCell? get _selected => profile.accent == Accent.custom ? (ringOfSat(profile.customSat), (profile.customHue / 15).round() % wheelHues) : null;

  void _setHover(WheelCell? c) {
    if (c == hover) return;
    setState(() => hover = c);
    if (c != null) pop.forward(from: 0);
  }

  void _commit(WheelCell? c) {
    if (c == null) return;
    profile.setCustom(c.$2 * 15.0, wheelSats[c.$1]);
    pop.forward(from: 0);
  }

  KeyEventResult _key(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final cur = hover ?? _selected ?? (0, 0);
    if (k == LogicalKeyboardKey.arrowRight) {
      _setHover((cur.$1, (cur.$2 + 1) % wheelHues));
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _setHover((cur.$1, (cur.$2 + wheelHues - 1) % wheelHues));
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _setHover((math.max(0, cur.$1 - 1), cur.$2));
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _setHover((math.min(wheelSats.length - 1, cur.$1 + 1), cur.$2));
    } else if ((k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space) && hover != null) {
      _commit(hover);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: profile,
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final p = Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shown = hover;
    // what the hub and the preview show: the colour under the pointer, or else the colour in use
    final Palette pal = shown != null ? Palette.custom(shown.$2 * 15.0, wheelSats[shown.$1], dark) : p;
    final selected = _selected;
    final title = shown != null ? hueName(shown.$2 * 15.0) : (selected != null ? hueName(selected.$2 * 15.0) : accentLabel(profile.accent));
    final tone = shown != null ? wheelTones[shown.$1] : (selected != null ? wheelTones[selected.$1] : '');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, box) {
          final size = math.min(box.maxWidth.isFinite ? box.maxWidth : 300.0, 300.0);
          final geo = WheelGeometry(size);
          final hubD = geo.r * WheelGeometry.hub * 2 - 6;
          return Center(
            child: Semantics(
              container: true,
              label: 'Colour wheel. Now: $title${tone.isEmpty ? '' : ', $tone'}. Use the arrow keys to move and Enter to choose.',
              child: SizedBox(
                width: size,
                height: size,
                child: Focus(
                  focusNode: focus,
                  onKeyEvent: _key,
                  child: MouseRegion(
                    onEnter: (_) => _mouse = true,
                    onHover: (e) => _setHover(geo.hit(e.localPosition)),
                    onExit: (_) => _setHover(null),
                    cursor: hover == null ? MouseCursor.defer : SystemMouseCursors.click,
                    child: GestureDetector(
                      key: const ValueKey('color-wheel'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) {
                        focus.requestFocus();
                        _setHover(geo.hit(d.localPosition));
                      },
                      onTapUp: (d) {
                        _commit(geo.hit(d.localPosition));
                        if (!_mouse) _setHover(null);
                      },
                      onTapCancel: () {
                        if (!_mouse) _setHover(null);
                      },
                      onPanStart: (d) => _setHover(geo.hit(d.localPosition)),
                      onPanUpdate: (d) => _setHover(geo.hit(d.localPosition)),
                      onPanEnd: (_) {
                        _commit(hover);
                        if (!_mouse) _setHover(null);
                      },
                      child: Stack(alignment: Alignment.center, children: [
                        CustomPaint(
                          size: Size(size, size),
                          painter: _WheelPainter(
                            geo: geo,
                            colors: _colors,
                            hover: hover,
                            selected: selected,
                            focused: focus.hasFocus,
                            pulsing: _pulsing,
                            intro: intro,
                            pop: pop,
                            pulse: pulse,
                            ink: p.ink,
                            surface: p.surface,
                            accent: p.accent,
                          ),
                        ),
                        IgnorePointer(
                          child: TweenAnimationBuilder<Color?>(
                            tween: ColorTween(end: pal.accent),
                            duration: Motion.ms(context, 240),
                            builder: (context, color, _) => Container(
                              width: hubD,
                              height: hubD,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: p.ink, width: 2),
                                boxShadow: [BoxShadow(color: p.ink, offset: const Offset(3, 3))],
                              ),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.display(TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: pal.onAccent))),
                                if (tone.isNotEmpty) Text(tone.toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1, color: pal.onAccent.withAlpha(210))),
                              ]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 14),
        // a small preview of what the colour does to the page
        AnimatedContainer(
          duration: Motion.ms(context, 220),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(color: p.inset, borderRadius: BorderRadius.circular(16)),
          child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Preview', style: TextStyle(color: p.inkSoft, fontWeight: FontWeight.w700, fontSize: 13)),
            AnimatedContainer(
              duration: Motion.ms(context, 220),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(color: pal.accent, borderRadius: BorderRadius.circular(999)),
              child: Text('Button', style: TextStyle(color: pal.onAccent, fontWeight: FontWeight.w700)),
            ),
            AnimatedContainer(
              duration: Motion.ms(context, 220),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: pal.accentTint, borderRadius: BorderRadius.circular(999)),
              child: Text('Highlight', style: TextStyle(color: pal.accent, fontWeight: FontWeight.w700)),
            ),
            Text('Link', style: TextStyle(color: pal.accent, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: pal.accent)),
          ]),
        ),
        const SizedBox(height: 8),
        Text(
          'Move over the wheel to preview, click to use it. On a phone, touch and drag, then lift. The app always keeps the text readable.',
          style: TextStyle(color: p.inkSoft, height: 1.4, fontSize: 13),
        ),
    ]);
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.geo,
    required this.colors,
    required this.hover,
    required this.selected,
    required this.focused,
    required this.pulsing,
    required this.intro,
    required this.pop,
    required this.pulse,
    required this.ink,
    required this.surface,
    required this.accent,
  }) : super(repaint: Listenable.merge([intro, pop, pulse]));

  final WheelGeometry geo;
  final List<Color> colors;
  final WheelCell? hover, selected;
  final bool focused, pulsing;
  final Animation<double> intro, pop, pulse;
  final Color ink, surface, accent;

  static Path _sector(Offset c, double r0, double r1, double centerDeg, double halfDeg) {
    final start = (-90 + centerDeg - halfDeg) * math.pi / 180;
    final sweep = halfDeg * 2 * math.pi / 180;
    return Path()
      ..arcTo(Rect.fromCircle(center: c, radius: r1), start, sweep, true)
      ..arcTo(Rect.fromCircle(center: c, radius: r0), start + sweep, -sweep, false)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.length < wheelSats.length * wheelHues) return;
    final c = Offset(geo.c, geo.c);
    final r = geo.r;
    for (var ring = 0; ring < WheelGeometry.rings.length; ring++) {
      for (var h = 0; h < wheelHues; h++) {
        if (hover == (ring, h)) continue; // drawn last, on top
        // the cells grow out of the middle one after another, clockwise from the top
        final t = ((intro.value - h / wheelHues * 0.45 - ring * 0.06) / 0.45).clamp(0.0, 1.0);
        if (t <= 0) continue;
        final k = Curves.easeOutBack.transform(t);
        final path = _sector(c, WheelGeometry.rings[ring].$1 * r * k, WheelGeometry.rings[ring].$2 * r * k, h * 15.0, 7.1);
        canvas.drawPath(path, Paint()..color = colors[ring * wheelHues + h].withValues(alpha: t));
      }
    }
    final hv = hover;
    if (hv != null) {
      final k = Curves.easeOutBack.transform(pop.value.clamp(0.0, 1.0));
      final ring = WheelGeometry.rings[hv.$1];
      final path = _sector(c, ring.$1 * r - 3 * k, ring.$2 * r + 8 * k, hv.$2 * 15.0, 7.1 + 1.6 * k);
      canvas.drawShadow(path, const Color(0xFF000000), 7 * k, false);
      canvas.drawPath(path, Paint()..color = colors[hv.$1 * wheelHues + hv.$2]);
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeJoin = StrokeJoin.round..color = ink);
    }
    final sel = selected;
    if (sel != null && intro.value >= 1) {
      final at = geo.centerOf(sel);
      if (pulsing) {
        final v = pulse.value;
        canvas.drawCircle(at, 9 + 12 * v, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = ink.withValues(alpha: (1 - v) * 0.55));
      }
      // the seal that marks the colour in use, like the puck on the sound matrix
      canvas.drawCircle(at + const Offset(1.5, 2), 9, Paint()..color = ink.withValues(alpha: 0.35));
      canvas.drawCircle(at, 9, Paint()..color = surface);
      canvas.drawCircle(at, 9, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..color = ink);
      canvas.drawCircle(at, 4, Paint()..color = accent);
    }
    if (focused) {
      canvas.drawCircle(c, r + 6, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = ink.withValues(alpha: 0.35));
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.hover != hover || old.selected != selected || old.focused != focused || old.pulsing != pulsing || !identical(old.colors, colors) || old.ink != ink || old.accent != accent || old.surface != surface;
}
