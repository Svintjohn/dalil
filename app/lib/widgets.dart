import 'package:flutter/material.dart';

import 'models.dart';
import 'motion.dart';
import 'theme.dart';

class Sheet extends StatelessWidget {
  const Sheet({super.key, required this.child, this.padding = const EdgeInsets.all(24)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: p.shadow, blurRadius: 40, offset: const Offset(0, 16))],
      ),
      padding: padding,
      child: child,
    );
  }
}

Future<T?> showSpringDialog<T>(BuildContext context, WidgetBuilder builder) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withAlpha(96),
    transitionDuration: Motion.ms(context, 480),
    pageBuilder: (c, a, b) => builder(c),
    transitionBuilder: (c, anim, secondary, child) {
      final v = Motion.smooth.transform(anim.value.clamp(0.0, 1.0));
      return Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.94 + 0.06 * v, child: child),
      );
    },
  );
}

class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.labels, required this.icons, required this.index, required this.onChanged});
  final List<String> labels;
  final List<IconData> icons;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final n = labels.length;
    return Container(
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.inset, borderRadius: BorderRadius.circular(13)),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: AlignmentDirectional(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
            duration: Motion.ms(context, 560),
            curve: Motion.smooth,
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: p.shadow, blurRadius: 6, offset: const Offset(0, 2))],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: labels[i],
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(icons[i], size: 18, color: i == index ? p.ink : p.inkSoft),
                          const SizedBox(width: 8),
                          Text(labels[i], style: TextStyle(fontWeight: FontWeight.w600, color: i == index ? p.ink : p.inkSoft)),
                        ]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class Disclosure extends StatefulWidget {
  const Disclosure({super.key, required this.title, required this.child, this.icon});
  final String title;
  final Widget child;
  final IconData? icon;

  @override
  State<Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<Disclosure> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => open = !open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              if (widget.icon != null) ...[Icon(widget.icon, size: 18, color: p.inkSoft), const SizedBox(width: 8)],
              Expanded(child: Text(widget.title, style: TextStyle(fontWeight: FontWeight.w600, color: p.ink))),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: Motion.ms(context, 480),
                curve: Motion.smooth,
                child: Icon(Icons.expand_more, color: p.inkSoft),
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: Motion.ms(context, 520),
          curve: Motion.smooth,
          alignment: Alignment.topCenter,
          child: open ? Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: widget.child) : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class SettingRow extends StatelessWidget {
  const SettingRow({super.key, required this.label, required this.child, this.onTap});
  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final row = Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
      decoration: BoxDecoration(color: p.inset, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Text(label, style: TextStyle(color: p.inkSoft)),
        const SizedBox(width: 16),
        Expanded(child: Align(alignment: AlignmentDirectional.centerEnd, child: child)),
      ]),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: row),
    );
  }
}

class LanguageDialog extends StatefulWidget {
  const LanguageDialog({super.key, required this.languages, required this.selected});
  final List<Language> languages;
  final Language selected;

  @override
  State<LanguageDialog> createState() => _LanguageDialogState();
}

class _LanguageDialogState extends State<LanguageDialog> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final q = query.trim().toLowerCase();
    final shown = widget.languages.where((l) => q.isEmpty || l.name.toLowerCase().contains(q) || l.native.toLowerCase().contains(q) || l.code.toLowerCase() == q).toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Reply language', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search ${widget.languages.length} languages'),
                  onChanged: (v) => setState(() => query = v),
                ),
              ]),
            ),
            Expanded(
              child: shown.isEmpty
                  ? Center(child: Text('No language found.', style: TextStyle(color: p.inkSoft)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final l = shown[i];
                        final on = l.code == widget.selected.code;
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          selected: on,
                          selectedTileColor: p.accentTint,
                          title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(l.tier == 'basic' ? '${l.native}  ·  less accurate' : l.native),
                          trailing: on ? Icon(Icons.check, color: p.accent) : null,
                          onTap: () => Navigator.pop(context, l),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacyDialog extends StatelessWidget {
  const PrivacyDialog({super.key, required this.headline, required this.points});
  final String headline;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lock_outline, color: p.accent),
            const SizedBox(height: 12),
            Text(headline.isEmpty ? 'Your document stays yours' : headline, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            for (final l in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 3), child: Icon(Icons.check, size: 18, color: p.ok)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l, style: const TextStyle(height: 1.45))),
                ]),
              ),
            const SizedBox(height: 8),
            Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),
          ]),
        ),
      ),
    );
  }
}

class PaperDemo extends StatelessWidget {
  const PaperDemo({super.key, required this.scanning});
  final bool scanning;

  static const _widths = <double>[0.55, 1, 0.94, 0.98, 0.62, 1, 0.9, 0.97, 0.7, 0.95, 0.8];

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final line = p.ink.withAlpha(Theme.of(context).brightness == Brightness.dark ? 60 : 42);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScanLine(
          active: scanning,
          color: p.accent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: p.shadow, blurRadius: 40, offset: const Offset(0, 18))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _widths.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == 0 ? 26 : 14),
                    child: FractionallySizedBox(
                      widthFactor: _widths[i],
                      child: Container(height: i == 0 ? 14 : 11, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(4))),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('Reading your document. Longer ones can take up to a minute.', style: TextStyle(color: p.inkSoft, height: 1.45)),
      ],
    );
  }
}
