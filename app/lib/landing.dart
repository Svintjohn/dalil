import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fonts.dart';
import 'models.dart';
import 'motion.dart';
import 'theme.dart';

bool isWide(BuildContext c) => MediaQuery.sizeOf(c).width >= 960;
double pagePad(BuildContext c) => MediaQuery.sizeOf(c).width >= 600 ? 32 : 20;

class Band extends StatelessWidget {
  const Band({super.key, required this.child, this.color, this.top = 96, this.bottom = 96, this.background});
  final Widget child;
  final Color? color;
  final double top, bottom;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final pad = pagePad(context);
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(padding: EdgeInsets.fromLTRB(pad, top, pad, bottom), child: child),
      ),
    );
    return Container(
      width: double.infinity,
      color: color,
      child: background == null ? content : ClipRect(child: Stack(children: [Positioned.fill(child: background!), content])),
    );
  }
}

TextStyle h2Style(BuildContext context, {Color? color}) {
  final wide = isWide(context);
  return TextStyle(fontSize: wide ? 48 : 34, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: wide ? -1.6 : -1.0, color: color);
}

class HeroSection extends StatelessWidget {
  const HeroSection({super.key, required this.onTry, required this.onHow, required this.languageCount});
  final VoidCallback onTry, onHow;
  final int languageCount;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final wide = isWide(context);
    final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Understand anything you have been handed.',
        style: TextStyle(fontSize: wide ? 72 : 42, height: 0.98, fontWeight: FontWeight.w800, letterSpacing: wide ? -3 : -1.6),
      ),
      SizedBox(height: wide ? 26 : 20),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Text(
          'Take a photo of a letter, bill, school notice, medical paper or contract. Dalil explains it in your language and tells you what to do next.',
          style: TextStyle(fontSize: wide ? 20 : 17, height: 1.5, color: p.inkSoft),
        ),
      ),
      const SizedBox(height: 32),
      Wrap(spacing: 14, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Pressable(
          child: FilledButton(
            onPressed: onTry,
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            child: const Text('Explain a document'),
          ),
        ),
        TextButton.icon(
          onPressed: onHow,
          style: TextButton.styleFrom(foregroundColor: p.ink, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          icon: const Icon(Icons.arrow_downward, size: 18),
          iconAlignment: IconAlignment.end,
          label: const Text('See how it works'),
        ),
      ]),
      const SizedBox(height: 30),
      Wrap(spacing: 22, runSpacing: 8, children: [
        for (final t in ['Not saved', '$languageCount languages', 'Official sources'])
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check, size: 18, color: p.accent),
            const SizedBox(width: 6),
            Text(t, style: TextStyle(color: p.inkSoft, fontWeight: FontWeight.w600)),
          ]),
      ]),
    ]);
    return Band(
      top: wide ? 150 : 108,
      bottom: wide ? 96 : 56,
      background: const HeroBackdrop(),
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(flex: 11, child: left),
              const SizedBox(width: 56),
              const Expanded(flex: 10, child: AnnotatedPaper()),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 44), const AnnotatedPaper()]),
    );
  }
}

class AnnotatedPaper extends StatelessWidget {
  const AnnotatedPaper({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final serif = Fonts.doc(TextStyle(fontSize: 17, height: 1.7, color: p.ink));

    InlineSpan hl(String t, int delay) => WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Marker(color: p.marker, delayMs: delay, thickness: 0.42, child: Text(t, style: serif)),
        );

    Widget note(String title, String text, int delay, bool side) {
      final box = Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
        decoration: BoxDecoration(
          color: p.accentTint,
          borderRadius: const BorderRadiusDirectional.only(topStart: Radius.circular(14), topEnd: Radius.circular(14), bottomEnd: Radius.circular(14), bottomStart: Radius.circular(4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, fontSize: 12.5)),
          const SizedBox(height: 3),
          Text(text, style: TextStyle(color: p.ink, fontSize: 14.5, height: 1.4)),
        ]),
      );
      if (!side) return Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: PopIn(delayMs: delay, child: box));
      return PopIn(
        delayMs: delay,
        child: Row(children: [
          DashedLine(color: p.accent, thickness: 1.5, dash: 4, gap: 3, length: 22),
          Expanded(child: box),
        ]),
      );
    }

    Widget block(InlineSpan text, Widget n, bool side) {
      final t = Text.rich(text, style: serif);
      if (!side) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [t, n]);
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(flex: 5, child: t), const SizedBox(width: 8), Expanded(flex: 4, child: n)]);
    }

    return LayoutBuilder(builder: (context, c) {
      final side = c.maxWidth >= 560;
      final paper = Container(
        padding: EdgeInsets.fromLTRB(side ? 36 : 24, side ? 36 : 28, side ? 30 : 24, side ? 40 : 28),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: p.shadow, blurRadius: 60, spreadRadius: -18, offset: const Offset(0, 30))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('See how Dalil reads a notice', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.inkSoft)),
          const SizedBox(height: 16),
          const Text('Notice to tenant', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 14),
          Text('Dear tenant,', style: serif),
          const SizedBox(height: 10),
          block(
            TextSpan(children: [const TextSpan(text: 'from 1 January 2027 your yearly rent will be '), hl('AED 62,000', 700), const TextSpan(text: ',')]),
            note('In plain words', 'New yearly rent: AED 62,000.', 1100, side),
            side,
          ),
          const SizedBox(height: 14),
          block(
            TextSpan(children: [const TextSpan(text: 'paid in '), hl('two cheques', 1500), const TextSpan(text: '.')]),
            note('In plain words', 'You pay in 2 parts, by cheque.', 1900, side),
            side,
          ),
          const SizedBox(height: 14),
          block(
            TextSpan(children: [const TextSpan(text: 'If we do not hear from you '), hl('within 15 days', 2300), const TextSpan(text: ', we will treat this as your acceptance.')]),
            note('Deadline', 'Answer within 15 days. Staying silent counts as yes.', 2700, side),
            side,
          ),
        ]),
      );
      return Transform.rotate(angle: side ? -0.016 : 0, child: paper);
    });
  }
}

class BringAnything extends StatelessWidget {
  const BringAnything({super.key});

  static const items = <(IconData, String, String)>[
    (Icons.mail_outline, 'Government letters', 'Notices, fines, summons, forms'),
    (Icons.school_outlined, 'School notices', 'Circulars, permission slips, fees'),
    (Icons.receipt_long_outlined, 'Bills and statements', 'Utilities, phone, bank messages'),
    (Icons.medical_services_outlined, 'Medical papers', 'Prescriptions, results, instructions'),
    (Icons.description_outlined, 'Contracts', 'Job offers, rental agreements'),
    (Icons.badge_outlined, 'Visa and ID papers', 'Permits, renewals, requirements'),
    (Icons.home_work_outlined, 'Housing', 'Rent notices, deposits, moving out'),
    (Icons.gpp_maybe_outlined, 'Suspicious messages', 'Links, payment demands, prizes'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 12) / 2;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final it in items)
          Container(
            width: w,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: p.accentTint, borderRadius: BorderRadius.circular(12)),
                child: Icon(it.$1, color: p.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  const SizedBox(height: 3),
                  Text(it.$3, style: TextStyle(color: p.inkSoft, fontSize: 13.5, height: 1.4)),
                ]),
              ),
            ]),
          ),
      ]);
    });
  }
}

class RouteSection extends StatelessWidget {
  const RouteSection({super.key});

  static const stops = <(String, String)>[
    ('Photograph', 'One photo per page. If a photo is blurry or cut off, Dalil says so and asks for a retake before it reads anything.'),
    ('Read and check', 'Dalil reads the document and, when it quotes a rule, checks it against an official government page and shows you the link.'),
    ('Know what to do', 'You get plain words, any deadline, what to do next and which office to contact. You can ask follow-up questions or draft a letter.'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final wide = isWide(context);
    Widget dot(int i) => Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.markSolid, shape: BoxShape.circle),
          child: Text('${i + 1}', style: const TextStyle(color: Color(0xFF0B1B1E), fontSize: 22, fontWeight: FontWeight.w800)),
        );
    Widget stop(int i) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(stops[i].$1, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: p.signInk)),
          const SizedBox(height: 10),
          Text(stops[i].$2, style: TextStyle(fontSize: 16.5, height: 1.55, color: p.signInk.withAlpha(205))),
        ]);
    final line = p.signInk.withAlpha(110);
    return Band(
      color: p.sign,
      top: 100,
      bottom: 110,
      background: Align(
        alignment: AlignmentDirectional.bottomEnd,
        child: Transform.translate(
          offset: const Offset(60, 120),
          child: Text('دليل', style: Fonts.mark(TextStyle(fontSize: wide ? 460 : 260, height: 1, color: p.signInk.withAlpha(18), fontWeight: FontWeight.w700))),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Three stops from confused to clear.', style: h2Style(context, color: p.signInk)),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text('No account, no forms. You only need a phone and the paper in front of you.', style: TextStyle(fontSize: 18, height: 1.5, color: p.signInk.withAlpha(205))),
        ),
        const SizedBox(height: 48),
        if (wide)
          Stack(children: [
            Positioned(left: 28, right: 28, top: 26, child: SizedBox(height: 3, child: DashedLine(color: line, thickness: 3, dash: 10, gap: 8))),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 44),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [dot(i), const SizedBox(height: 22), stop(i)]),
                ),
              ],
            ]),
          ])
        else
          Column(children: [
            for (var i = 0; i < 3; i++)
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    width: 56,
                    child: Column(children: [
                      dot(i),
                      if (i < 2) Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: SizedBox(width: 3, child: DashedLine(color: line, thickness: 3, dash: 8, gap: 7, vertical: true)))),
                    ]),
                  ),
                  const SizedBox(width: 18),
                  Expanded(child: Padding(padding: EdgeInsets.only(bottom: i < 2 ? 34 : 0, top: 8), child: stop(i))),
                ]),
              ),
          ]),
      ]),
    );
  }
}

class LanguageWall extends StatelessWidget {
  const LanguageWall({super.key, required this.languages, required this.selected, required this.onPick});
  final List<Language> languages;
  final String? selected;
  final ValueChanged<Language> onPick;

  static const _big = <double>[58, 44, 52, 40, 56, 42, 48, 38, 54, 46];
  static const _small = <double>[30, 26, 34, 28, 32];

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final wide = isWide(context);
    final k = wide ? 1.0 : 0.62;
    final feat = languages.where((l) => l.featured).toList();
    final rest = languages.where((l) => !l.featured).toList();
    final ordered = [...feat, ...rest];
    return Band(
      color: p.wall,
      top: 100,
      bottom: 110,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reply in the language you think in.', style: h2Style(context, color: p.wallInk)),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            '${languages.length} languages. Tap one to use it. Quality is best in widely used languages, and Dalil marks the others as less accurate.',
            style: TextStyle(fontSize: 18, height: 1.5, color: p.wallInk.withAlpha(170)),
          ),
        ),
        const SizedBox(height: 48),
        Wrap(
          spacing: 30 * k,
          runSpacing: 8 * k,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < ordered.length; i++)
              LangWord(
                key: ValueKey('${ordered[i].code}-${ordered[i].code == selected}'),
                language: ordered[i],
                size: (i < feat.length ? _big[i % _big.length] : _small[i % _small.length]) * k,
                selected: ordered[i].code == selected,
                onTap: () => onPick(ordered[i]),
              ),
          ],
        ),
      ]),
    );
  }
}

class LangWord extends StatefulWidget {
  const LangWord({super.key, required this.language, required this.size, required this.selected, required this.onTap});
  final Language language;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<LangWord> createState() => _LangWordState();
}

class _LangWordState extends State<LangWord> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final text = AnimatedDefaultTextStyle(
      duration: Motion.ms(context, 250),
      style: TextStyle(fontSize: widget.size, height: 1.2, fontWeight: FontWeight.w600, color: hover ? p.markSolid : p.wallInk),
      child: Text(widget.language.native.isEmpty ? widget.language.name : widget.language.native),
    );
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.language.name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: widget.selected ? Marker(color: p.markSolid.withAlpha(150), thickness: 0.2, child: text) : text,
        ),
      ),
    );
  }
}

class TrustSection extends StatelessWidget {
  const TrustSection({super.key, required this.countries});
  final List<CountryCoverage> countries;

  static const items = <(String, String)>[
    ('Not saved', 'Your document is read once to write the explanation. Dalil keeps no copy and no history.'),
    ('Numbers hidden', 'ID, card and bank numbers are covered before the text is read. Photos are stripped of location data.'),
    ('Official sources only', 'When Dalil quotes a rule it links the government page and shows the date it was last checked.'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final wide = isWide(context);
    Widget col(int i) => Container(
          padding: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.ink, width: 3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(items[i].$1, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            const SizedBox(height: 8),
            Text(items[i].$2, style: TextStyle(color: p.inkSoft, height: 1.55, fontSize: 16)),
          ]),
        );
    return Band(
      top: 100,
      bottom: 80,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Built so you can trust it.', style: h2Style(context)),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text('Documents are personal. Dalil is designed to handle them carefully, and to say when it is not sure.', style: TextStyle(fontSize: 18, height: 1.5, color: p.inkSoft)),
        ),
        const SizedBox(height: 44),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < 3; i++) ...[if (i > 0) const SizedBox(width: 28), Expanded(child: col(i))],
          ])
        else
          Column(children: [for (var i = 0; i < 3; i++) Padding(padding: const EdgeInsets.only(bottom: 24), child: col(i))]),
        if (countries.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Rules checked so far for: ${countries.map((c) => c.name).join(', ')}.', style: TextStyle(color: p.inkSoft, height: 1.7, fontSize: 14.5)),
        ],
      ]),
    );
  }
}

class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final a = Text('Dalil is a guide, not a lawyer, doctor or accountant. It does not give legal, medical or financial advice.', style: TextStyle(color: p.inkSoft, fontSize: 14, height: 1.5));
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
      child: Band(
        top: 28,
        bottom: 44,
        child: a,
      ),
    );
  }
}

class HeroBackdrop extends StatelessWidget {
  const HeroBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _GlowPainter(accent: p.accent, dark: dark))),
        Positioned.fill(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Colors.transparent], stops: [0.0, 0.9]).createShader(r),
            child: CustomPaint(painter: _LatticePainter(color: p.ink.withAlpha(dark ? 30 : 24))),
          ),
        ),
      ]),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({required this.accent, required this.dark});
  final Color accent;
  final bool dark;

  void _blob(Canvas canvas, Offset c, double r, Color col) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()..shader = RadialGradient(colors: [col, col.withAlpha(0)]).createShader(rect));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    _blob(canvas, Offset(w * 0.12, h * 0.18), w * 0.40, accent.withAlpha(dark ? 95 : 62));
    _blob(canvas, Offset(w * 0.88, h * 0.10), w * 0.36, const Color(0xFF3A6FE0).withAlpha(dark ? 80 : 46));
    _blob(canvas, Offset(w * 0.70, h * 0.92), w * 0.34, const Color(0xFFF0B84B).withAlpha(dark ? 44 : 58));
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.accent != accent || old.dark != dark;
}

class _LatticePainter extends CustomPainter {
  _LatticePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 96.0;
    final r = cell * 0.35;
    final d = r * math.sqrt2;
    final path = Path();
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final c = Offset(x + cell / 2, y + cell / 2);
        path.addRect(Rect.fromCenter(center: c, width: 2 * r, height: 2 * r));
        path.moveTo(c.dx, c.dy - d);
        path.lineTo(c.dx + d, c.dy);
        path.lineTo(c.dx, c.dy + d);
        path.lineTo(c.dx - d, c.dy);
        path.close();
      }
    }
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_LatticePainter old) => old.color != color;
}
