import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'fonts.dart';
import 'motion.dart';
import 'sfx.dart';
import 'sfx_engine.dart';
import 'theme.dart';
import 'tilt.dart';
import 'widgets.dart';

/// Click sounds, a 2D sound matrix, ambient sounds and tuning, with a live spectrum.
class SoundStudio extends StatefulWidget {
  const SoundStudio({super.key, this.sfx});
  final Sfx? sfx;

  @override
  State<SoundStudio> createState() => _SoundStudioState();
}

class _SoundStudioState extends State<SoundStudio> {
  int tab = 0;
  String group = 'All';

  Sfx get sfx => widget.sfx ?? Sfx.instance;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780),
        child: AnimatedBuilder(
          animation: sfx,
          builder: (context, _) => Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 0),
              child: Row(children: [
                Expanded(
                  child: Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text('Sound studio', style: Fonts.display(const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.6))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: p.accentTint, borderRadius: BorderRadius.circular(999)),
                      child: Text('Made in your browser', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ]),
                ),
                IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('Tactile click sounds, ambient focus sounds and tuning. Off until you turn it on. Nothing is downloaded or sent.', style: TextStyle(color: p.inkSoft, height: 1.4, fontSize: 14)),
              ),
            ),
            if (!sfx.available)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                child: Align(alignment: AlignmentDirectional.centerStart, child: Text('Sound is not available in this browser. Try Chrome, Edge or Safari.', style: TextStyle(color: p.mid, fontWeight: FontWeight.w600))),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: _master(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Segmented(
                labels: const ['Sounds', 'Matrix', 'Ambient', 'Tuning'],
                icons: const [Icons.keyboard_alt_outlined, Icons.scatter_plot_outlined, Icons.cloud_outlined, Icons.tune],
                index: tab,
                onChanged: (i) => setState(() => tab = i),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                child: AnimatedSwitcher(
                  duration: Motion.ms(context, 320),
                  child: KeyedSubtree(
                    key: ValueKey(tab),
                    child: [_sounds(context), _matrix(context), _ambient(context), _tuning(context)][tab],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 22, 14),
              child: Row(children: [
                TextButton.icon(
                  key: const ValueKey('sfx-reset'),
                  onPressed: sfx.reset,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reset defaults'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 30)),
                  child: const Text('Done'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _master(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(color: p.inset, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Row(children: [
          Switch(key: const ValueKey('sfx-master'), value: sfx.enabled, onChanged: sfx.setEnabled),
          const SizedBox(width: 6),
          Flexible(child: Text(sfx.enabled ? 'Sound on' : 'Sound off', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(width: 14),
          Expanded(child: SizedBox(height: 34, child: SpectrumBars(active: sfx.enabled))),
        ]),
        Row(children: [
          Icon(Icons.volume_down_outlined, size: 20, color: p.inkSoft),
          Expanded(child: Slider(key: const ValueKey('sfx-volume'), value: sfx.volume, onChanged: sfx.setVolume, semanticFormatterCallback: (v) => 'Volume ${(v * 100).round()} percent')),
          Icon(Icons.volume_up_outlined, size: 20, color: p.inkSoft),
        ]),
      ]),
    );
  }

  Widget _sounds(BuildContext context) {
    final p = Palette.of(context);
    final shown = sfxPresets.where((s) => group == 'All' || s.group == group).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _mixes(context),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final g in ['All', ...sfxGroups])
          ChoiceChip(
            label: Text(g),
            selected: group == g,
            showCheckmark: false,
            onSelected: (_) => setState(() => group = g),
            selectedColor: p.ink,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, color: group == g ? p.bg : p.ink),
            backgroundColor: p.surface,
            side: BorderSide(color: p.line),
            shape: const StadiumBorder(),
          ),
      ]),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 620 ? 3 : 2;
        final w = (c.maxWidth - 10 * (cols - 1)) / cols;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final s in shown)
            SizedBox(
              width: w,
              child: TiltPress(
                child: GestureDetector(
                  key: ValueKey('preset-${s.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => sfx.selectPreset(s.id),
                  child: AnimatedContainer(
                    duration: Motion.ms(context, 250),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: s.id == sfx.presetId ? p.accentTint : p.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: s.id == sfx.presetId ? p.accent : p.line, width: s.id == sfx.presetId ? 1.6 : 1),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                        if (s.id == sfx.presetId) Icon(Icons.check_circle, size: 18, color: p.accent),
                      ]),
                      const SizedBox(height: 3),
                      Text(s.hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.inkSoft, fontSize: 13, height: 1.3)),
                      const SizedBox(height: 6),
                      Text(s.group.toUpperCase(), style: TextStyle(color: p.inkSoft, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                    ]),
                  ),
                ),
              ),
            ),
        ]);
      }),
    ]);
  }

  Future<void> _saveMix() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this sound'),
        content: TextField(
          key: const ValueKey('mix-name'),
          controller: c,
          autofocus: true,
          maxLength: 16,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v),
          decoration: const InputDecoration(hintText: 'For example: Quiet desk'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('mix-save'), onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || !mounted) return;
    sfx.saveMix(name);
  }

  Widget _mixes(BuildContext context) {
    final p = Palette.of(context);
    final full = sfx.mixes.length >= Sfx.maxMixes;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
      decoration: BoxDecoration(color: p.inset, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('My mixes', style: Fonts.display(const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)))),
          TextButton.icon(
            key: const ValueKey('mix-save-open'),
            onPressed: full ? null : _saveMix,
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('Save this sound'),
          ),
        ]),
        if (sfx.mixes.isEmpty)
          Text('Pick a sound, tune it until it feels right, then save it here with a name.', style: TextStyle(color: p.inkSoft, height: 1.4, fontSize: 14))
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < sfx.mixes.length; i++)
              InputChip(
                key: ValueKey('mix-$i'),
                label: Text(sfx.mixes[i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                avatar: const Icon(Icons.graphic_eq, size: 16),
                onPressed: () => sfx.applyMix(i),
                onDeleted: () => sfx.deleteMix(i),
                deleteButtonTooltipMessage: 'Delete ${sfx.mixes[i].name}',
                backgroundColor: p.surface,
                side: BorderSide(color: p.line),
                shape: const StadiumBorder(),
              ),
          ]),
        if (full)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${Sfx.maxMixes} of ${Sfx.maxMixes} saved. Delete one to add another.', style: TextStyle(color: p.inkSoft, fontSize: 13)),
          ),
      ]),
    );
  }

  Widget _matrix(BuildContext context) {
    final p = Palette.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Tap a dot to pick a sound, or drag the puck to mix your own: left to right is low to high, top to bottom is heavy to light.', style: TextStyle(color: p.inkSoft, height: 1.4)),
      const SizedBox(height: 14),
      MatrixPad(sfx: sfx),
    ]);
  }

  Widget _ambient(BuildContext context) {
    final p = Palette.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 560 ? 3 : 2;
        final w = (c.maxWidth - 10 * (cols - 1)) / cols;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final a in ambientSounds)
            SizedBox(
              width: w,
              child: TiltPress(
                child: GestureDetector(
                  key: ValueKey('ambient-${a.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => sfx.toggleAmbient(a.id),
                  child: AnimatedContainer(
                    duration: Motion.ms(context, 250),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: sfx.ambient.contains(a.id) ? p.accent : p.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: sfx.ambient.contains(a.id) ? p.accent : p.line),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(a.icon, color: sfx.ambient.contains(a.id) ? p.onAccent : p.accent),
                      const SizedBox(height: 10),
                      Text(a.name, style: TextStyle(fontWeight: FontWeight.w700, color: sfx.ambient.contains(a.id) ? p.onAccent : p.ink)),
                      const SizedBox(height: 2),
                      Text(a.hint, style: TextStyle(fontSize: 13, height: 1.3, color: sfx.ambient.contains(a.id) ? p.onAccent.withAlpha(215) : p.inkSoft)),
                    ]),
                  ),
                ),
              ),
            ),
        ]);
      }),
      const SizedBox(height: 16),
      _slider('Ambient volume', sfx.ambientVolume, 0, 1, (v) => sfx.setAmbientVolume(v), '${(sfx.ambientVolume * 100).round()}%', const ValueKey('sfx-ambient-volume')),
      Text('You can mix several. They keep playing while you read your result.', style: TextStyle(color: p.inkSoft, height: 1.4)),
    ]);
  }

  Widget _slider(String label, double v, double min, double max, ValueChanged<double> on, String shown, Key key, {VoidCallback? end}) {
    final p = Palette.of(context);
    return Row(children: [
      SizedBox(width: 118, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
      Expanded(child: Slider(key: key, value: v.clamp(min, max).toDouble(), min: min, max: max, onChanged: on, onChangeEnd: end == null ? null : (_) => end())),
      SizedBox(width: 52, child: Text(shown, textAlign: TextAlign.end, style: TextStyle(color: p.inkSoft, fontWeight: FontWeight.w600))),
    ]);
  }

  Widget _tuning(BuildContext context) {
    final p = Palette.of(context);
    String semi(double v) => '${v >= 0 ? '+' : ''}${v.round()} st';
    String pct(double v) => '${(v * 100).round()}%';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _slider('Pitch', sfx.pitch, -12, 12, (v) => sfx.setTune(pitch: v.roundToDouble()), semi(sfx.pitch), const ValueKey('sfx-pitch'), end: sfx.preview),
      _slider('Decay', sfx.decay, 0.4, 2.5, (v) => sfx.setTune(decay: v), '${sfx.decay.toStringAsFixed(1)}x', const ValueKey('sfx-decay'), end: sfx.preview),
      _slider('Brightness', sfx.bright, 0, 1, (v) => sfx.setTune(bright: v), pct(sfx.bright), const ValueKey('sfx-bright'), end: sfx.preview),
      _slider('Room (reverb)', sfx.reverb, 0, 1, (v) => sfx.setTune(reverb: v), pct(sfx.reverb), const ValueKey('sfx-reverb'), end: sfx.preview),
      _slider('Humanize', sfx.human, 0, 1, (v) => sfx.setTune(human: v), pct(sfx.human), const ValueKey('sfx-human'), end: sfx.preview),
      _slider('Stereo spread', sfx.pan, 0, 1, (v) => sfx.setTune(pan: v), pct(sfx.pan), const ValueKey('sfx-pan'), end: sfx.preview),
      const SizedBox(height: 8),
      Material(
        color: p.inset,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          SwitchListTile(
            key: const ValueKey('sfx-clicks'),
            title: const Text('Click sounds', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('A sound for each tap or click'),
            value: sfx.clicks,
            onChanged: (v) => sfx.setToggles(clicks: v),
          ),
          SwitchListTile(
            key: const ValueKey('sfx-typing'),
            title: const Text('Typing sounds', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('A key sound when you type in a text box'),
            value: sfx.typing,
            onChanged: (v) => sfx.setToggles(typing: v),
          ),
          SwitchListTile(
            key: const ValueKey('sfx-chimes'),
            title: const Text('Result sounds', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('A chime when your result is ready, a low tone for a scam warning'),
            value: sfx.chimes,
            onChanged: (v) => sfx.setToggles(chimes: v),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(key: const ValueKey('sfx-test'), onPressed: sfx.preview, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Play a test sound')),
      ),
    ]);
  }
}

/// The 2D sound map, drawn like a ruled ledger page. Every preset is an ink dot; the puck is a seal that shows the sound in use.
class MatrixPad extends StatelessWidget {
  const MatrixPad({super.key, required this.sfx});
  final Sfx sfx;

  static const double _padL = 34, _padR = 16, _padT = 16, _padB = 34; // room for the axis words

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = math.min(380.0, w * 0.68);
      final iw = w - _padL - _padR, ih = h - _padT - _padB;
      Offset toPos(double x, double y) => Offset(_padL + x * iw, _padT + (1 - y) * ih); // y = 1 (heavy) is at the top
      void pick(Offset local, {required bool drag, bool end = false}) {
        final x = ((local.dx - _padL) / iw).clamp(0.0, 1.0).toDouble();
        final y = (1 - (local.dy - _padT) / ih).clamp(0.0, 1.0).toDouble();
        if (!drag) {
          // a tap near a dot picks that preset
          SfxPreset? hit;
          var best = 26.0;
          for (final s in sfxPresets) {
            final d = (toPos(s.x, s.y) - local).distance;
            if (d < best) {
              best = d;
              hit = s;
            }
          }
          if (hit != null) {
            sfx.selectPreset(hit.id);
            return;
          }
        }
        sfx.movePuck(x, y, preview: end);
      }

      final puck = toPos(sfx.puckX, sfx.puckY);
      final tagLeft = (puck.dx - 52).clamp(4.0, math.max(4.0, w - 108)).toDouble();
      final tagBelow = puck.dy < h - _padB - 52;
      final axis = TextStyle(color: p.inkSoft, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.2);
      return GestureDetector(
        key: const ValueKey('matrix-pad'),
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => pick(d.localPosition, drag: false, end: true),
        onPanStart: (d) => pick(d.localPosition, drag: true),
        onPanUpdate: (d) => pick(d.localPosition, drag: true),
        onPanEnd: (_) => sfx.preview(),
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: p.inset,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.ink.withAlpha(46), width: 1.2),
          ),
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MatrixPainter(line: p.line, ink: p.ink, accent: p.accent, current: sfx.presetId, left: _padL, top: _padT, right: _padR, bottom: _padB),
              ),
            ),
            PositionedDirectional(bottom: 8, start: _padL, end: _padR, child: Row(children: [Text('Low', style: axis), Expanded(child: Center(child: Text('Pitch', style: axis.copyWith(color: p.ink)))), Text('High', style: axis)])),
            Positioned(
              left: 4,
              top: _padT,
              bottom: _padB,
              width: 24,
              child: RotatedBox(quarterTurns: 3, child: Row(children: [Text('Light', style: axis), Expanded(child: Center(child: Text('Weight', style: axis.copyWith(color: p.ink)))), Text('Heavy', style: axis)])),
            ),
            AnimatedPositioned(
              duration: Motion.ms(context, 90),
              left: puck.dx - 16,
              top: puck.dy - 16,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.surface, width: 2.5),
                  boxShadow: [BoxShadow(color: p.ink.withAlpha(60), offset: const Offset(0, 3))],
                ),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.onAccent.withAlpha(190), width: 1.4)),
                  child: Icon(Icons.graphic_eq, size: 12, color: p.onAccent),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: Motion.ms(context, 90),
              left: tagLeft,
              top: tagBelow ? puck.dy + 22 : puck.dy - 50,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: p.ink.withAlpha(60))),
                  child: Text(sfx.customX == null ? sfx.preset.name : '${sfx.preset.name}, mixed', style: Fonts.display(TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink))),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }
}

class _MatrixPainter extends CustomPainter {
  _MatrixPainter({required this.line, required this.ink, required this.accent, required this.current, required this.left, required this.top, required this.right, required this.bottom});
  final Color line, ink, accent;
  final String current;
  final double left, top, right, bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - left - right, h = size.height - top - bottom;
    final hair = Paint()
      ..color = line
      ..strokeWidth = 1;
    final strong = Paint()
      ..color = ink.withAlpha(90)
      ..strokeWidth = 1.2;
    // ruled lines, like an account book
    for (var i = 0; i <= 8; i++) {
      final y = top + h * i / 8;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), i == 8 ? strong : hair);
    }
    for (var i = 0; i <= 12; i++) {
      final x = left + w * i / 12;
      canvas.drawLine(Offset(x, top), Offset(x, top + h), i == 0 ? strong : hair);
    }
    // the middle cross
    canvas.drawLine(Offset(left + w / 2, top), Offset(left + w / 2, top + h), Paint()..color = ink.withAlpha(40)..strokeWidth = 1.2);
    for (final s in sfxPresets) {
      final o = Offset(left + s.x * w, top + (1 - s.y) * h);
      final on = s.id == current;
      canvas.drawCircle(o, on ? 8 : 5, Paint()..color = on ? accent.withAlpha(70) : ink.withAlpha(215));
      if (on) {
        canvas.drawCircle(
          o,
          8,
          Paint()
            ..color = ink.withAlpha(200)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MatrixPainter old) => old.current != current || old.ink != ink || old.accent != accent || old.line != line;
}

/// Live bars that move with the sound that is playing.
class SpectrumBars extends StatefulWidget {
  const SpectrumBars({super.key, required this.active});
  final bool active;

  @override
  State<SpectrumBars> createState() => _SpectrumBarsState();
}

class _SpectrumBarsState extends State<SpectrumBars> with SingleTickerProviderStateMixin {
  static const n = 24;
  Ticker? _ticker;
  List<double> bars = List<double>.filled(n, 0);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (Motion.ambient) {
      _ticker = createTicker((t) {
        if (t - _last < const Duration(milliseconds: 40)) return;
        _last = t;
        final next = widget.active ? sfxBands(n) : List<double>.filled(n, 0);
        if (mounted) setState(() => bars = next.length == n ? next : List<double>.filled(n, 0));
      })
        ..start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return RepaintBoundary(child: CustomPaint(painter: _BarsPainter(bars: bars, color: widget.active ? p.accent : p.inkSoft.withAlpha(90)), size: Size.infinite));
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.bars, required this.color});
  final List<double> bars;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final n = bars.length;
    const gap = 3.0;
    final bw = (size.width - gap * (n - 1)) / n;
    final paint = Paint()..color = color;
    for (var i = 0; i < n; i++) {
      final v = bars[i].clamp(0.0, 1.0).toDouble();
      final bh = math.max(3.0, v * size.height);
      final x = i * (bw + gap);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - bh, bw, bh), const Radius.circular(2)), paint);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => true;
}
